import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { authenticate, consumeCredit, jsonError, requirePlus, CORS_HEADERS } from "../_shared/gate.ts";

// "Plus is the second chapter": appends 5-7 new micro-actions to a finished
// plan, built from what the founder actually did. Plus-only. The client
// sends only ids — the transcript, analysis and the completed steps are read
// here through the caller's own RLS-scoped client, so nothing can be forged.

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const DAILY_LIMIT = { free: 0, plus: 20 };
const MAX_CHAPTER = 6;

// Same shape generate-action-plan returns, so the app reuses ActionPlanResponse.
const CHAPTER_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },     // this chapter's 2-4 word name
    summary: { type: "string" },   // what THIS chapter will find out
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: { type: "string" },
          done_criteria: { type: "string" },
          time_estimate_minutes: { type: "integer", minimum: 5, maximum: 30 },
          priority: { type: "integer", minimum: 1, maximum: 7 },
          quadrant: { type: "string", enum: ["strength", "weakness", "opportunity", "threat"] },
          template: { type: "string" },
          action_type: { type: "string", enum: ["message", "search", "email", "post", "generic"] },
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

const SYSTEM_PROMPT = `You are a startup action coach writing the NEXT CHAPTER of a founder's plan. They finished the previous chapter; you have their outcomes and notes.

FIELD RULES (identical to chapter one):
"text" — ONE sentence, max 10 words, starts with a verb. It is a label beside a node on a path.
"done_criteria" — ONE short binary check ("3 replies received").
"template" — a COPY-PASTE READY block referencing the founder's specific idea. Only [brackets] for what you truly can't know.
"action_type" — message | search | email | post | generic.
"deep_link_data" — all four fields present; "" when not applicable (message → body; search → query; email → body+subject; post → body+url_scheme; generic → all "").
"time_estimate_minutes" — 5, 10, 15, 20 or 30. "priority" — 1 = do first. "quadrant" — the SWOT area served.
"title" — 2-4 word chapter name. "summary" — one sentence: what THIS chapter will find out.

CHAPTER RULES:
- Never repeat a step from earlier chapters, even reworded. Build on what was learned: a "didn't work" outcome means change approach, not retry.
- Escalate by chapter number:
  Chapter 2 — talk to REAL strangers, not friends: 3+ conversations, posts in communities where the buyers are, a landing page or one-question survey.
  Chapter 3 — ask for money or commitment: pre-orders, a paid pilot, a waitlist with a price shown, a deposit.
  Chapter 4+ — ship something tiny and real: a manual/concierge version, a Gumroad/Etsy listing, a one-page offer, a first delivery.
- Quote the founder's own notes back in templates where it makes the ask more credible ("A few people told me X — is that true for you?").
- Exactly 5-7 actions, 5-30 minutes each, zero cost, no coding.`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  // Tier check BEFORE spending a credit: a free user gets 403, not a burned credit.
  const auth = await authenticate(req);
  if (auth instanceof Response) return auth;
  const denied = requirePlus(auth);
  if (denied) return denied;
  const g = await consumeCredit(auth, "extend-action-plan", DAILY_LIMIT);
  if (g instanceof Response) return g;

  try {
    const { action_plan_id } = await req.json();
    if (typeof action_plan_id !== "string" || !/^[0-9a-f-]{36}$/i.test(action_plan_id)) {
      return jsonError("action_plan_id required", 400);
    }

    const { data: plan, error: planErr } = await g.supabase
      .from("action_plans")
      .select("id, analysis_id, title, summary")
      .eq("id", action_plan_id)
      .maybeSingle();
    if (planErr || !plan) return jsonError("Plan not found", 404);

    const { data: actions } = await g.supabase
      .from("micro_actions")
      .select("text, done_criteria, quadrant, chapter, is_completed, completion_outcome, completion_note")
      .eq("action_plan_id", plan.id)
      .order("chapter", { ascending: true })
      .order("priority", { ascending: true });
    const done = actions ?? [];
    if (done.length === 0) return jsonError("Plan has no steps", 400);
    if (done.some((a) => !a.is_completed)) {
      return jsonError("Finish the current chapter first", 409, "chapter_open");
    }
    const nextChapter = Math.max(1, ...done.map((a) => Number(a.chapter ?? 1))) + 1;
    if (nextChapter > MAX_CHAPTER) {
      return jsonError("This plan has reached its final chapter. Time to re-taste — or ship.", 409, "final_chapter");
    }

    const { data: analysis } = await g.supabase
      .from("swot_analyses")
      .select("transcription_id, summary, viability_score, dimension_scores, score_rationale, strength_items, weakness_items, opportunity_items, threat_items, market_insights")
      .eq("id", plan.analysis_id)
      .maybeSingle();
    if (!analysis) return jsonError("Analysis not found", 404);

    const { data: transcription } = await g.supabase
      .from("transcriptions")
      .select("text")
      .eq("id", analysis.transcription_id)
      .maybeSingle();

    const points = (items: unknown) =>
      (Array.isArray(items) ? items : []).map((i) => (i as { point?: string }).point ?? "").filter(Boolean).join("; ").slice(0, 2000) || "None.";
    const dims = analysis.dimension_scores
      ? Object.entries(analysis.dimension_scores as Record<string, number>).map(([k, v]) => `${k} ${v}`).join(", ")
      : "Not available.";
    const history = done.map((a) => {
      const outcome = a.completion_outcome === "didnt_work" ? "DIDN'T WORK" : "DID IT";
      const note = a.completion_note ? ` — "${String(a.completion_note).slice(0, 300)}"` : "";
      return `- [ch${a.chapter ?? 1}] ${a.text} [${outcome}]${note}`;
    }).join("\n");
    const comparables = ((analysis.market_insights as { comparables?: Array<{ name: string; what: string; pricing: string }> } | null)?.comparables ?? [])
      .map((c) => `${c.name} — ${c.what}, ${c.pricing}`).join(" | ").slice(0, 2000) || "None found.";

    const userMessage = `WRITE CHAPTER ${nextChapter}.

VOICE NOTE:
${String(transcription?.text ?? "").slice(0, 8000)}

PLAN SO FAR: "${plan.title}" — ${plan.summary}
SUMMARY: ${String(analysis.summary ?? "None.").slice(0, 2000)}
STRENGTHS: ${points(analysis.strength_items)}
WEAKNESSES: ${points(analysis.weakness_items)}
OPPORTUNITIES: ${points(analysis.opportunity_items)}
THREATS: ${points(analysis.threat_items)}
VIABILITY: ${analysis.viability_score ?? 50}/100
DIMENSION SCORES (0-10): ${dims}
WEAKEST LINK: ${analysis.score_rationale ?? "Not available."}
REAL SMALL COMPARABLES: ${comparables}

EVERYTHING DONE IN EARLIER CHAPTERS (do not repeat any of these):
${history}

Generate chapter ${nextChapter}: 5-7 new micro-actions with copy-paste templates.`;

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0.4,
        max_tokens: 2500,
        response_format: { type: "json_schema", json_schema: { name: "plan_chapter", schema: CHAPTER_SCHEMA, strict: true } },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userMessage },
        ],
      }),
    });

    if (!openaiRes.ok) {
      console.error(`OpenAI error ${openaiRes.status}:`, await openaiRes.text());
      return jsonError("OpenAI request failed", 502);
    }
    const content = (await openaiRes.json()).choices?.[0]?.message?.content;
    if (!content) return jsonError("Empty response from OpenAI", 502);

    const result = JSON.parse(content);
    return new Response(JSON.stringify({ ...result, chapter: nextChapter }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("extend-action-plan unhandled error:", err);
    return jsonError(String(err), 500);
  }
});
