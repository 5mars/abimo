import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

"text" — The action title. ONE sentence. Max 15 words. Starts with a verb.
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

"summary" — One sentence. Reference the specific idea.

ORDERING:
1. Address biggest weakness/risk
2. Validate top opportunity
3. Leverage a strength
4. Monitor threats

Generate exactly 5-7 actions. Spread across quadrants.

STRATEGY BY VIABILITY (scores are harsh by design — 20-45 is a normal starting point):
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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Not authenticated" }),
      { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  try {
    const {
      analysis_id,
      transcription_text,
      swot_summary,
      strengths,
      weaknesses,
      opportunities,
      threats,
      viability_score,
    } = await req.json();

    if (!transcription_text || typeof transcription_text !== "string") {
      return new Response(
        JSON.stringify({ error: "transcription_text field required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const userMessage = `Founder's idea and SWOT analysis:

VOICE NOTE:
${transcription_text}

SUMMARY: ${swot_summary || "None."}
STRENGTHS: ${(strengths || []).join("; ") || "None."}
WEAKNESSES: ${(weaknesses || []).join("; ") || "None."}
OPPORTUNITIES: ${(opportunities || []).join("; ") || "None."}
THREATS: ${(threats || []).join("; ") || "None."}
VIABILITY: ${viability_score ?? 50}/100

Generate 5-7 micro-actions with copy-paste templates.`;

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0.4,
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
