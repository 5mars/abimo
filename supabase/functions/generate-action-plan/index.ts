import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { gate, jsonError, CORS_HEADERS } from "../_shared/gate.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const DAILY_LIMIT = { free: 6, plus: 12 };
const MAX_TRANSCRIPTION_CHARS = 8000;
const MAX_SWOT_CONTEXT_CHARS = 6000;

const ACTION_PLAN_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: { type: "string" },
          done_criteria: { type: "string" },
          time_estimate_minutes: { type: "integer", minimum: 5, maximum: 30 },
          priority: { type: "integer", minimum: 1, maximum: 7 },
          quadrant: {
            type: "string",
            enum: ["strength", "weakness", "opportunity", "threat"],
          },
          template: { type: "string" },
          action_type: {
            type: "string",
            enum: ["message", "search", "email", "post", "generic"],
          },
          deep_link_data: {
            type: "object",
            properties: {
              url_scheme: { type: "string" },
              body: { type: "string" },
              subject: { type: "string" },
              query: { type: "string" },
            },
            required: ["url_scheme", "body", "subject", "query"],
            additionalProperties: false,
          },
        },
        required: ["text", "done_criteria", "time_estimate_minutes", "priority", "quadrant", "template", "action_type", "deep_link_data"],
        additionalProperties: false,
      },
    },
  },
  required: ["title", "summary", "actions"],
  additionalProperties: false,
};

const SYSTEM_PROMPT = `You are a startup action coach. You turn SWOT analyses into tiny, concrete actions.

RULES FOR EVERY FIELD:

"text" — The action title. ONE sentence. Max 10 words. Starts with a verb. It is printed beside a node on the path, so it must read as a label.
GOOD: "Search Google for 3 direct competitors and save their URLs."
GOOD: "Message 3 friends asking how they solve this problem."
BAD: "Open Google and search for competitors in the meal-prep space. Look at the top 5 results and write down their pricing model and main differentiator."

"done_criteria" — ONE short sentence. Binary yes/no check.
GOOD: "3 URLs saved"
GOOD: "3 replies received"
BAD: "You have a better understanding of the competitive landscape"

"template" — A COPY-PASTE READY block the user can use RIGHT NOW. This is the most important field.
Examples:
- For messaging someone: "Hey [name]! Quick question — do you ever struggle with [problem]? If so, what do you currently use to deal with it?"
- For a Google search: "[idea keyword] alternatives 2024 pricing"
- For a pitch: "[Product name] helps [target user] do [outcome] without [pain point]. Unlike [competitor], we [key difference]."
- For a Reddit post: "I'm building [brief description]. Has anyone here tried solving [problem]? What worked and what didn't?"
- For a survey: "1. How often do you experience [problem]? 2. What do you currently do about it? 3. Would you pay $X/month for [solution]?"

The template should reference the founder's SPECIFIC idea, market, and problem. Fill in as much as possible — only use [brackets] for things you truly can't know (like a friend's name).

"action_type" — Classify what the user needs to DO with the template:
- "message" — send a text/DM to someone (template is the message body)
- "search" — search Google/web (template is the search query)
- "email" — send an email (template is the email body)
- "post" — post on Reddit/Twitter/LinkedIn (template is the post body)
- "generic" — anything else (write on paper, brainstorm, etc.)

"deep_link_data" — Data to pre-fill the target app. ALL fields required (use empty string "" if not applicable):
- "body" — message/email body text (for message, email, post types)
- "query" — search query string (for search type)
- "subject" — email subject line (for email type)
- "url_scheme" — full URL for post types (e.g. "https://www.reddit.com/submit?title=...")

For "message" type: fill "body" with the exact message to send. Leave query/subject/url_scheme as "".
For "search" type: fill "query" with the exact search string. Leave body/subject/url_scheme as "".
For "email" type: fill "body" and "subject". Leave query/url_scheme as "".
For "post" type: fill "body" and "url_scheme" with the platform URL. Leave query/subject as "".
For "generic" type: all fields as "".

"time_estimate_minutes" — 5, 10, 15, 20, or 30.

"priority" — 1 = do first.

"quadrant" — which SWOT area this addresses.

"title" — 2-4 word plan name. E.g. "Customer Pulse Check"

"summary" — One sentence stating what this plan will FIND OUT, referencing the specific idea. It is shown as the plan's headline. E.g. "Find out if busy parents will pay for prepped dinners."

ORDERING:
0. When DIMENSION SCORES are provided, the first 1-2 actions must attack the WEAKEST dimension.
1. Address biggest weakness/risk
2. Validate top opportunity
3. Leverage a strength
4. Monitor threats

When REAL SMALL COMPARABLES are provided, reference them by name in search/message templates (e.g. "PoolTrak alternatives pricing") instead of [competitor] placeholders.

Generate exactly 7-9 actions. Spread across quadrants, ordered so a founder can do them top to bottom.

STRATEGY BY VIABILITY (scores spread the full range — treat the band as truth):
0-19: The idea as described doesn't survive. Actions should hunt for a pivot or the real problem underneath.
20-39: Something's there but unproven. Actions should find out if the problem actually exists.
40-59: Real problem, unproven demand. Actions should test whether anyone cares enough to act.
60-79: Promising. Actions should test willingness to pay.
80-100: Rare. Actions should get real users fast.

Each action must take 5-30 min, cost nothing, require no coding.
The template is what makes the user actually DO it — make it so easy they just copy, paste, and send.
`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const g = await gate(req, "generate-action-plan", DAILY_LIMIT);
  if (g instanceof Response) return g;

  try {
    const {
      analysis_id: _analysis_id,   // client bookkeeping; the plan is stored client-side
      transcription_text,
      swot_summary,
      strengths,
      weaknesses,
      opportunities,
      threats,
      viability_score,
      dimension_scores,
      score_rationale,
      comparables,
    } = await req.json();

    if (!transcription_text || typeof transcription_text !== "string") {
      return jsonError("transcription_text field required", 400);
    }
    if (transcription_text.length > MAX_TRANSCRIPTION_CHARS) {
      return jsonError("transcription_text too long", 400);
    }

    const dims = dimension_scores
      ? `problem ${dimension_scores.problemSeverity}, demand ${dimension_scores.demandEvidence}, market ${dimension_scores.marketQuality}, buildable ${dimension_scores.feasibility}, different ${dimension_scores.differentiation}`
      : "Not available.";

    const clip = (arr: unknown) =>
      ((arr as string[] | undefined) || []).join("; ").slice(0, MAX_SWOT_CONTEXT_CHARS) || "None.";

    const userMessage = `Founder's idea and SWOT analysis:

VOICE NOTE:
${transcription_text}

SUMMARY: ${String(swot_summary || "None.").slice(0, MAX_SWOT_CONTEXT_CHARS)}
STRENGTHS: ${clip(strengths)}
WEAKNESSES: ${clip(weaknesses)}
OPPORTUNITIES: ${clip(opportunities)}
THREATS: ${clip(threats)}
VIABILITY: ${viability_score ?? 50}/100
DIMENSION SCORES (0-10): ${dims}
WEAKEST LINK: ${score_rationale || "Not available."}
REAL SMALL COMPARABLES (from live web research): ${((comparables || []).join(" | ")).slice(0, MAX_SWOT_CONTEXT_CHARS) || "None found."}

Generate 7-9 micro-actions with copy-paste templates.`;

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini", // step lists don't need the scored model; 16× cheaper,
        temperature: 0.4,
        max_tokens: 2500,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "action_plan",
            schema: ACTION_PLAN_SCHEMA,
            strict: true,
          },
        },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userMessage },
        ],
      }),
    });

    if (!openaiRes.ok) {
      const errBody = await openaiRes.text();
      console.error(`OpenAI error ${openaiRes.status}:`, errBody);
      return new Response(
        JSON.stringify({ error: "OpenAI request failed", status: openaiRes.status, detail: errBody }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const openaiData = await openaiRes.json();
    const content = openaiData.choices?.[0]?.message?.content;

    if (!content) {
      console.error("No content in OpenAI response:", JSON.stringify(openaiData));
      return new Response(
        JSON.stringify({ error: "Empty response from OpenAI" }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const result = JSON.parse(content);

    return new Response(JSON.stringify(result), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-action-plan unhandled error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
