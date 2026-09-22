import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { authenticate, consumeCredit, jsonError, requirePlus, CORS_HEADERS } from "../_shared/gate.ts";
import {
  buildSystemPrompt, buildUserMessage, CHAPTER_SCHEMA, LADDER, MIN_CHAPTER_STEPS, nextChapterFor, parseBrief,
} from "../_shared/chapters.ts";

// "Plus is the second chapter": appends the next chapter (2-5) to a finished
// plan. Chapter one is the free taste (micro-actions); chapters two to five
// are concrete build steps on a fixed ladder, sized to the founder's skill,
// time, budget and goal — the `brief` the app asks for before each chapter.
// Plus-only. The client sends ids and the brief; the transcript, analysis and
// completed steps are read here through the caller's own RLS-scoped client.

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const DAILY_LIMIT = { free: 0, plus: 12 };

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
    const { action_plan_id, brief: rawBrief } = await req.json();
    if (typeof action_plan_id !== "string" || !/^[0-9a-f-]{36}$/i.test(action_plan_id)) {
      return jsonError("action_plan_id required", 400);
    }
    const brief = parseBrief(rawBrief);
    if (!brief) return jsonError("brief required: tech_skill, hours_per_week, budget, goal", 400, "brief_required");

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
    const next = nextChapterFor(done);
    if (!next.ok) {
      switch (next.code) {
        case "empty": return jsonError("Plan has no steps", 400);
        case "chapter_open": return jsonError("Finish the current chapter first", 409, "chapter_open");
        case "final_chapter": return jsonError("This plan has reached its final chapter. Time to re-taste — or ship.", 409, "final_chapter");
      }
    }
    const nextChapter = next.chapter;

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

    const userMessage = buildUserMessage({
      chapter: nextChapter,
      transcript: String(transcription?.text ?? ""),
      planTitle: plan.title,
      planSummary: plan.summary,
      analysisSummary: String(analysis.summary ?? "None."),
      strengths: points(analysis.strength_items),
      weaknesses: points(analysis.weakness_items),
      opportunities: points(analysis.opportunity_items),
      threats: points(analysis.threat_items),
      viability: Number(analysis.viability_score ?? 50),
      dims,
      weakestLink: String(analysis.score_rationale ?? "Not available."),
      comparables,
      history,
    });

    const askOpenAI = async (extraNudge: string) => {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "gpt-4o-mini", // step lists don't need the scored model; 16× cheaper
          temperature: 0.4,
          max_tokens: 3500,
          response_format: { type: "json_schema", json_schema: { name: "plan_chapter", schema: CHAPTER_SCHEMA, strict: true } },
          messages: [
            { role: "system", content: buildSystemPrompt(nextChapter, brief) },
            { role: "user", content: userMessage + extraNudge },
          ],
        }),
      });
      if (!res.ok) {
        console.error(`OpenAI error ${res.status}:`, await res.text());
        return { error: jsonError("OpenAI request failed", 502) };
      }
      const content = (await res.json()).choices?.[0]?.message?.content;
      if (!content) return { error: jsonError("Empty response from OpenAI", 502) };
      return { result: JSON.parse(content) as { title?: string; summary?: string; actions?: unknown[] } };
    };

    let attempt = await askOpenAI("");
    if (attempt.error) return attempt.error;
    let result = attempt.result!;
    if ((result.actions?.length ?? 0) < MIN_CHAPTER_STEPS) {
      console.warn(`extend-action-plan: only ${result.actions?.length ?? 0} steps, retrying`);
      const retry = await askOpenAI(`\n\nYour previous answer had only ${result.actions?.length ?? 0} steps. This chapter MUST have between 6 and 10 steps. Add distinct, non-overlapping steps until it does.`);
      if (!retry.error && (retry.result!.actions?.length ?? 0) > (result.actions?.length ?? 0)) result = retry.result!;
    }

    // The brief and the model's chapter name land on one row (RLS: the caller's
    // own). Best-effort — a storage hiccup must not cost the founder the chapter.
    const { error: briefErr } = await g.supabase.from("chapter_briefs").upsert({
      user_id: g.user.id,
      action_plan_id: plan.id,
      chapter: nextChapter,
      tech_skill: brief.tech_skill,
      hours_per_week: brief.hours_per_week,
      budget: brief.budget,
      goal: brief.goal,
      notes: brief.notes ?? null,
      title: String(result.title ?? LADDER[nextChapter as 2 | 3 | 4 | 5].title).slice(0, 80),
      summary: String(result.summary ?? "").slice(0, 400),
    }, { onConflict: "action_plan_id,chapter" });
    if (briefErr) console.error("chapter_briefs upsert failed:", briefErr.message);

    return new Response(JSON.stringify({ ...result, chapter: nextChapter, ladder_title: LADDER[nextChapter as 2 | 3 | 4 | 5].title }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("extend-action-plan unhandled error:", err);
    return jsonError(String(err), 500);
  }
});
