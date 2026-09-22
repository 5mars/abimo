import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { gate, jsonError, requirePlus, CORS_HEADERS } from "../_shared/gate.ts";
import {
  computeScoreV2,
  deriveResearchFacts,
  flattenDims,
  NO_FOUNDER_EVIDENCE,
  SCORING_VERSION,
  sha256Hex,
} from "../_shared/scoring.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const MODEL = "gpt-4o";

// Free tier gets a real week of tasting; Plus gets the old ceiling.
const DAILY_LIMIT = { free: 6, plus: 12 };
const MAX_TRANSCRIPTION_CHARS = 8000;
const MAX_PIVOT_FIELD_CHARS = 500;
const MAX_RETASTE_ACTIONS = 30;

const SWOT_ITEM_SCHEMA = {
  type: "object",
  properties: {
    point:    { type: "string" },
    detail:   { type: "string" },
    score:    { type: "integer", minimum: 0, maximum: 100 },
    category: { type: "string" },
  },
  required: ["point", "detail", "score", "category"],
  additionalProperties: false,
};

// Evidence sentence BEFORE the number — the model must justify, then commit.
const DIM_SCHEMA = {
  type: "object",
  properties: {
    evidence: { type: "string" },
    score:    { type: "integer", minimum: 0, maximum: 10 },
  },
  required: ["evidence", "score"],
  additionalProperties: false,
};

const COMPARABLE_SCHEMA = {
  type: "object",
  properties: {
    name:    { type: "string" },
    what:    { type: "string" },
    pricing: { type: "string" },
    status:  { type: "string" },
    url:     { type: "string" },
    overlap: { type: "string" },   // what it shares with the founder's idea
    edge:    { type: "string" },   // how the founder's idea differs / could win
  },
  required: ["name", "what", "pricing", "status", "url", "overlap", "edge"],
  additionalProperties: false,
};

// Property ORDER is generation order — verdict band first (categorical
// commitment), then per-dimension evidence-then-score. That ordering is the
// anti-central-tendency mechanism; do not reorder casually.
const SWOT_SCHEMA = {
  type: "object",
  properties: {
    ideaTitle:     { type: "string" },
    verdictBand:   { type: "string", enum: ["burnt", "half_baked", "needs_seasoning", "simmering", "chefs_kiss"] },
    verdictReason: { type: "string" },
    // Facts before judgment: the founder's concrete numbers are extracted
    // here so the code (not the model) decides what they unlock.
    founderEvidence: {
      type: "object",
      properties: {
        citesConcreteNumbers: { type: "boolean" },
        quotes:    { type: "array", items: { type: "string" } },
        strongest: {
          type: "string",
          enum: ["none", "anecdote", "personal_experience", "community_size", "poll", "waitlist", "prepayments", "revenue"],
        },
      },
      required: ["citesConcreteNumbers", "quotes", "strongest"],
      additionalProperties: false,
    },
    scoring: {
      type: "object",
      properties: {
        problemSeverity: DIM_SCHEMA,
        demandEvidence:  DIM_SCHEMA,
        marketQuality:   DIM_SCHEMA,
        feasibility:     DIM_SCHEMA,
        differentiation: DIM_SCHEMA,
      },
      required: ["problemSeverity", "demandEvidence", "marketQuality", "feasibility", "differentiation"],
      additionalProperties: false,
    },
    fatalFlaw:       { type: "boolean" },
    fatalFlawReason: { type: "string" },
    scoreRationale:  { type: "string" },
    strengths:    { type: "array", items: SWOT_ITEM_SCHEMA },
    weaknesses:   { type: "array", items: SWOT_ITEM_SCHEMA },
    opportunities:{ type: "array", items: SWOT_ITEM_SCHEMA },
    threats:      { type: "array", items: SWOT_ITEM_SCHEMA },
    marketContext:{ type: "string" },
    marketInsights: {
      type: "object",
      properties: {
        market_size:     { type: "string" },
        growth_rate:     { type: "string" },
        trend_direction: { type: "string", enum: ["up", "down", "stable"] },
        key_competitors: { type: "array", items: { type: "string" } },
        comparables:     { type: "array", items: COMPARABLE_SCHEMA },
      },
      required: ["market_size", "growth_rate", "trend_direction", "key_competitors", "comparables"],
      additionalProperties: false,
    },
    ideaVariants: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title:          { type: "string" },
          pitch:          { type: "string" },
          keeps:          { type: "string" },   // what stays from the original
          changes:        { type: "string" },   // what's different or added
          differentiator: { type: "string" },
        },
        required: ["title", "pitch", "keeps", "changes", "differentiator"],
        additionalProperties: false,
      },
    },
    summary: { type: "string" },
  },
  required: [
    "ideaTitle", "verdictBand", "verdictReason", "founderEvidence", "scoring",
    "fatalFlaw", "fatalFlawReason", "scoreRationale",
    "strengths", "weaknesses", "opportunities", "threats",
    "marketContext", "marketInsights", "ideaVariants", "summary",
  ],
  additionalProperties: false,
};

// Scoring math lives in ../_shared/scoring.ts (unit-tested, versioned).
// The model commits to a verdict band FIRST (categorical commitment), then
// scores five dimensions with evidence; code aggregates.

const SYSTEM_PROMPT = `You are a brutally honest startup analyst — part Y Combinator partner, part sharp-tongued food critic reviewing ideas like dishes. You have actually built and launched small products, and you have sent plenty of undercooked ideas back to the kitchen.

Your scores are harsh but fair. Your words are playful. Roast the idea, never the founder.

The founder recorded a voice note with an idea. They are an everyday person considering a side project — NOT a venture-scale founder. Judge the idea as a small business: could THIS person get their first 10 paying customers and grow from there?

Assume the founder:
- has no startup experience
- has nights-and-weekends time and a small budget
- needs honest, specific feedback, not hype and not reflexive pessimism

--------------------------------------------------

TONE RULES

- Direct and honest. Conversational and punchy.
- Write like a smart mentor texting a founder.
- No corporate consulting language. No billion-dollar-TAM talk. Ever.

--------------------------------------------------

RESEARCH DIGEST

The user message may include a RESEARCH DIGEST from live web search, with a "market" block of numbers.

When a digest is PRESENT: treat it as ground truth. It can raise OR lower a score:
- market.paid_comparables_found of 2 or more, with prices → demandEvidence may reach 6. It reaches 7-8 ONLY with a strong positive signal in the digest or the founder's own numbers (poll, waitlist). Comparables prove a market exists, not that people want this founder's version. In a crowded or dominated niche with differentiation ≤ 3, demand is capped at differentiation + 1 — the category's demand isn't theirs.
- paid_comparables_found 0 with search_quality ok or rich → demandEvidence at most 4: we looked, and nobody is paying.
- saturation "dominated" or giant_blocks_niche yes → marketQuality at most 4. "crowded" → at most 5. free_alternatives_dominate yes → at most 4.
- small_players_making_money yes → marketQuality may reach 7-8; otherwise at most 6.
- a strong negative signal caps demandEvidence at 5.
Code enforces these caps after you score; score honestly within them and cite the digest field in your evidence sentence. Real small players making money here is a GOOD sign for demand ("this has been done small and it works") — and a differentiation question at the same time.
Copy the digest's comparables into marketInsights.comparables (tighten wording; never change names, prices, or status).

When the digest is ABSENT or empty: score from the transcript alone. Without research, demandEvidence and marketQuality are capped at 5 unless the founder cites concrete numbers. Return an empty comparables array. NEVER invent company names, pricing, or market statistics. An empty plate beats a fake one.

--------------------------------------------------

STEP 1 — COMMIT TO A VERDICT BAND (do this first, before any numbers)

Pick exactly one verdictBand:

- "burnt" (5-19): No real buyer, fatal contradiction, or pure wish disguised as an idea.
- "half_baked" (20-39): A guess. Plausible-sounding, but no evidence anyone wants it, or a crowded space with no angle. Most raw voice notes land here or below.
- "needs_seasoning" (40-59): A real problem and a workable direction, but demand is unproven or the angle is thin. Worth testing this month.
- "simmering" (60-79): Real problem + concrete evidence people pay for solutions + a credible wedge this founder can execute. Rare from a raw voice note.
- "chefs_kiss" (80-95): Proven demand (real signals, not vibes), a clear underserved niche, and the founder can reach it. You would tell a friend to start this weekend.

Sitting on the fence is a failure. If you are torn between two bands, the evidence is insufficient — pick the LOWER one and say why in verdictReason.

Your band is a commitment and a sanity check. The final number is computed by code from your five dimension scores and the evidence rules; it will not be forced into your band.

--------------------------------------------------

STEP 1.5 — EXTRACT FOUNDER EVIDENCE (facts, not judgment)

Pull every concrete number the founder states about demand into founderEvidence.quotes, verbatim: group sizes, poll counts, waitlist sign-ups, pre-payments, revenue, what people pay today. Set strongest to the best kind present:
- "My sister complains" → anecdote. "I do this every week" → personal_experience. "A 2,000-member group" → community_size.
- "140 said they'd pay" → poll. "210 joined the waitlist" → waitlist. "30 pre-paid $49" → prepayments. "40 sold at $19" → revenue.
Numbers unlock higher demand rows; adjectives do not. No numbers → citesConcreteNumbers false, strongest none or anecdote.

--------------------------------------------------

STEP 2 — SCORE THE FIVE DIMENSIONS

For each dimension write ONE evidence sentence FIRST (quote the transcript or the research digest), THEN the 0-10 score. The sentence must justify the number.

problemSeverity — How real and painful is the problem?
  0-2: No real problem, or a solution looking for a problem
  3-4: Mild inconvenience; people live with it fine
  5-6: Real annoyance; people complain but rarely pay to fix it
  7-8: Painful problem people actively spend money or time solving today
  9-10: Hair-on-fire problem with desperate, underserved sufferers

demandEvidence — What signals suggest people would use or pay for this?
  0-2: Pure speculation; the founder is guessing
  3-4: Plausible, but zero evidence in the transcript or research
  5-6: Analogous small products succeed, or founder cites real personal experience
  7-8: The founder cites a poll or waitlist with numbers, OR the digest holds a STRONG positive signal (many people asking or paying). Paid comparables alone justify 6, not 7
  9-10: Founder cites pre-payments, revenue, or a waitlist of 50+ — numbers, not vibes

marketQuality — Is the BEACHHEAD NICHE worth entering? (Not the global market — the first few hundred customers this founder could actually reach.)
  0-2: The niche is tiny AND shrinking, or served well for free
  3-4: Crowded niche with no visible gap for a newcomer, or the digest says dominated / free alternatives dominate
  5-6: Viable niche; competitive but with visible gaps a small player can fill
  7-8: Underserved niche where the digest shows small_players_making_money yes and saturation sparse or competitive
  9-10: Hungry, reachable niche with an obvious opening right now

feasibility — Can a first-time solo founder realistically build and distribute this?
  0-2: Needs regulatory approval, hardware, network effects, or deep pockets
  3-4: Needs a team, funding, or partnerships just to test
  5-6: Buildable, but distribution is unclear
  7-8: Buildable in weeks with a plausible first channel
  9-10: Could be validated this weekend with no code

differentiation — Why this instead of what already exists?
  0-2: Identical to established products (a generic clone)
  3-4: Minor twist a competitor could copy in a sprint
  5-6: Meaningful angle, but not defensible
  7-8: Distinct approach or audience that competitors ignore
  9-10: Genuinely novel insight or unfair advantage

Real ideas are jagged — strong somewhere, weak somewhere else. A flat profile with every dimension in 4-6 is a hedge, not a judgment: code docks it 4 points and the app labels it "the critic hedged". If you genuinely see a 4-6 idea, find the dimension that is actually a 3 or a 7 and say why.
Rough band guide: burnt → dims mostly 0-3 · half_baked → mostly 2-4 · needs_seasoning → mostly 4-6 with a real strength or weakness · simmering → mostly 6-8 · chefs_kiss → mostly 7-9.

fatalFlaw: true only if one issue kills the idea AS DESCRIBED (no possible buyer, illegal, impossible economics, already free and ubiquitous). Name it in fatalFlawReason and the summary; otherwise fatalFlawReason is "".

scoreRationale: One blunt sentence naming the weakest dimension and what would raise it.

--------------------------------------------------

CALIBRATION ANCHORS — score against these, not against politeness

A. "I want to build an app that uses AI to help people be more productive, like with everything — tasks, email, life stuff."
   → burnt. problem 2, demand 1, market 2, feasibility 3, differentiation 0. Final ~7.
   A wish, not an idea. No user, no problem, competing with everyone.

B. "An app where you book dog walkers, like Uber but for dogs."
   → half_baked. problem 5, demand 3, market 2, feasibility 4, differentiation 1. Final ~23.
   Real problem, but Rover and Wag already own it and there is no angle.

C. "A meal planning app for busy parents — my sister always complains about deciding what to cook."
   → half_baked. problem 4, demand 3, market 3, feasibility 5, differentiation 2. Final ~29.
   Real annoyance, one anecdote, brutally crowded, no wedge yet.

D. "Freelance designers hate chasing overdue invoices — I do it every week and it's humiliating. Existing tools bury the reminder feature in $40/mo suites. I'd build just the polite-nagging bit for $8/mo and I know three designers who'd try it."
   → needs_seasoning. problem 7, demand 4, market 5, feasibility 7, differentiation 5. Final ~55.
   Founder lives the problem (personal_experience), sharp wedge in a gap the $40 suites leave open, demand still anecdotal.

E. "I run a pool service route. The scheduling software we all use costs $300/mo and everyone in my 2,000-member trade Facebook group complains monthly. I'd build a $29/mo routes-only tool; four other techs already said they'd switch tomorrow."
   → simmering. problem 8, demand 6, market 6, feasibility 6, differentiation 6. Final ~71.
   Insider founder, priced-out users, named channel (community_size 2,000), early hand-raisers.

F. "My newsletter for wedding photographers has 4,000 subscribers. I posted a mockup of a client-gallery-delivery tool and 210 people joined the waitlist; 30 pre-paid $49. Current options cost $600/yr and photographers hate them."
   → chefs_kiss. problem 8, demand 8, market 8, feasibility 7, differentiation 7. Final ~89 (86 + 3 for the pre-payments).
   Pre-payments (founderEvidence prepayments), a waitlist, and owned distribution. Almost nothing scores here.

DISTRIBUTION MANDATE: across many ideas your finals must actually spread — empty wishes 5-20, plausible guesses 20-40, real problems with a credible wedge 40-62, evidence-backed ideas 62-80, proven demand 80+. Do not park ideas in the middle out of caution. Deliver low scores with wit, not cruelty — the words can smile while the number frowns.

--------------------------------------------------

SWOT ITEMS

For each item return:
"point": a sharp one-sentence insight.
"detail": 3-5 sentences on why this matters for THIS idea. Real risks, founder mistakes, market realities. Reference research comparables by name when relevant.
"score": integer 0-100 for how impactful that specific insight is.
"category": one word — Market, Product, Tech, Team, Finance, Legal, Timing, Distribution.

Return 3-5 items per quadrant. Never exceed 6.

--------------------------------------------------

MARKET INTEL — SMALL-SCOPE RULES (this section talks to a side-project founder)

Never cite TAM, billions, or CAGR percentages. The founder needs to know if a SMALL version of this works, not whether Sequoia would fund it.

marketContext: 2-3 sentences about the beachhead — who the first 100 customers are, where they hang out, and whether small players already make money here.

marketInsights:
- market_size: the beachhead niche in plain words, sized humanly.
  GOOD: "Roughly 30k pool-route operators in the US — winning 100 of them is a real $3k/mo business." BAD: "$4.2B TAM".
- growth_rate: plain-words demand direction. GOOD: "More photographers ditch all-in-one suites every year." BAD: "11% CAGR".
- trend_direction: up, down, or stable — for the NICHE.
- key_competitors: the small/indie players closest to this idea (from the research digest when present). Name a giant only if it genuinely blocks the niche.
- comparables: copied from the research digest; empty array if no digest. For EACH comparable, add two idea-aware sentences (plain sentences only — the app adds its own labels, so never start with "Same dish" or "Your edge"):
  - overlap: what it shares with the founder's idea, one sentence.
  - edge: how the founder's idea differs or could beat it — a concrete angle, not a platitude. If there is genuinely no edge, say so honestly; that IS the insight.

--------------------------------------------------

IDEA VARIANTS — "Remix the Recipe"

Return 2-3 remixes of the founder's idea. Keep the core ingredient; change exactly one axis per remix (narrower audience, different business model, different channel, or a sharper wedge feature). Each remix:
- title: menu-dish style, 3-6 words ("Invoice Nagger for Design Studios")
- pitch: 1-2 sentences describing the remixed version.
- keeps: one short sentence — what stays from the original idea (the core ingredient).
- changes: one short sentence — exactly what this remix changes or adds versus the original.
- differentiator: one sentence on why this remix beats the plain version — what sets the founder apart and who specifically it wins.
At least one remix should aim at the weakest dimension you scored.

--------------------------------------------------

ideaTitle: a punchy 3-6 word name for the idea, like a dish on a menu. Based on what the idea IS, not a judgment of it. GOOD: "AI Meal-Prep Coach". BAD: "Untitled Recording".

SUMMARY: 3-4 sentence TL;DR — honest verdict, biggest opportunity, biggest risk, what to do first. If research found small players succeeding, say so: proof the dish sells.
`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const g = await gate(req, "analyze-swot", DAILY_LIMIT);
  if (g instanceof Response) return g;

  try {
    // retaste.analysis_id is accepted for the client's bookkeeping but the
    // score is re-judged from the transcript + work done, not read back.
    const { transcription, research, pivot, calibration, retaste } = await req.json();

    if (!transcription || typeof transcription !== "string") {
      return jsonError("transcription field required", 400);
    }
    if (transcription.length > MAX_TRANSCRIPTION_CHARS) {
      return jsonError("transcription too long", 400);
    }
    if (pivot && [pivot.title, pivot.pitch, pivot.differentiator].some(
      (f) => typeof f === "string" && f.length > MAX_PIVOT_FIELD_CHARS,
    )) {
      return jsonError("pivot fields too long", 400);
    }

    // Re-taste = the critic re-judges AFTER the founder did the work. Plus-only:
    // it's a second full analysis, and it's the reason to stay subscribed.
    if (retaste) {
      const denied = requirePlus(g);
      if (denied) return denied;
      if (!Array.isArray(retaste.completed_actions) || retaste.completed_actions.length > MAX_RETASTE_ACTIONS) {
        return jsonError("retaste.completed_actions invalid", 400);
      }
    }

    let userMessage = `Startup idea voice note transcription:\n\n${transcription}\n\n`;
    if (pivot && typeof pivot.title === "string") {
      userMessage += `FOUNDER'S PIVOT — the founder tasted the original and chose this remix instead. Analyze THE REMIX as the idea; the transcript above is background context only. ideaTitle must reflect the remix.\nRemix: ${pivot.title}\nPitch: ${pivot.pitch ?? ""}\nDifferentiator: ${pivot.differentiator ?? ""}\n\n`;
    }
    if (retaste) {
      const lines = (retaste.completed_actions as Array<{ text?: string; outcome?: string; note?: string }>)
        .map((a) => {
          const outcome = a.outcome === "didnt_work" ? "TRIED, DIDN'T WORK" : "DID IT";
          const note = typeof a.note === "string" && a.note ? ` — "${a.note.slice(0, 300)}"` : "";
          return `- ${String(a.text ?? "").slice(0, 200)} [${outcome}]${note}`;
        })
        .join("\n");
      userMessage += `WORK DONE SINCE LAST TASTING (previous Critic's Score: ${Number(retaste.previous_score ?? 0)}/100)
The founder went and did these steps. Treat their outcomes and notes as NEW evidence:
${lines || "- (none recorded)"}

Re-judge the idea with this evidence. Real replies, sign-ups, or payments raise demandEvidence; "didn't work" outcomes are information, not failure — if they reveal the problem isn't real, say so and score it. If nothing material was learned, the score should barely move. Set founderEvidence from the work above as well as the transcript.\n\n`;
    }
    // Prefer the structured (v2) digest. Older app builds forward only the
    // prose fields, so fall back to the digest research-market cached for
    // this transcript within the last hour.
    const pivotTitle: string | undefined =
      pivot && typeof pivot.title === "string" ? pivot.title : undefined;
    const digestHash = await sha256Hex(
      pivotTitle ? `${transcription}\n#pivot:${pivotTitle}` : transcription,
    );
    let digest = research ?? null;
    let facts = deriveResearchFacts(digest);
    if (facts.present && !facts.structured) {
      const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
      const { data: cached } = await g.supabase
        .from("research_digests")
        .select("digest")
        .eq("transcription_sha256", digestHash)
        .gte("created_at", since)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (cached?.digest) {
        const cachedFacts = deriveResearchFacts(cached.digest);
        if (cachedFacts.structured) {
          digest = cached.digest;
          facts = cachedFacts;
        }
      }
    }
    const hasResearch = facts.present;
    if (hasResearch) {
      userMessage += `RESEARCH DIGEST (from live web search — treat as ground truth; the "market" block holds the numbers):\n${JSON.stringify(digest, null, 2)}\n\n`;
    } else {
      userMessage += `RESEARCH DIGEST: none available for this run. Score from the transcript alone and return an empty comparables array.\n\n`;
    }
    userMessage += `Analyze this idea and generate the full tasting report.`;

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.3,
        // Calibration batches pin the seed so run-to-run noise is the
        // model's, not the sampler's.
        ...(calibration === true ? { seed: 42 } : {}),
        max_tokens: 4096,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "swot_analysis",
            schema: SWOT_SCHEMA,
            strict: true,
          },
        },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user",   content: userMessage },
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

    // Flatten for the client: five plain ints + the computed final score.
    // The band, reasons and per-dimension evidence are kept (and audited) so
    // the number can be explained and the distribution measured.
    const rawDims = flattenDims(result.scoring as Record<string, { score: number }>);
    const founder = result.founderEvidence ?? NO_FOUNDER_EVIDENCE;
    const { score, meta } = computeScoreV2({
      dims: rawDims,
      verdictBand: result.verdictBand,
      fatalFlaw: result.fatalFlaw,
      founder,
      research: facts,
      comparableCount: digest?.comparables?.length ?? 0,
    });
    result.viabilityScore = score;
    result.dimensionScores = meta.cappedDims;      // what the app shows
    result.rawDimensionScores = rawDims;           // what the model said
    result.dimensionEvidence = Object.fromEntries(
      Object.entries(result.scoring as Record<string, { evidence: string }>)
        .map(([k, v]) => [k, v.evidence])
    );
    result.scoreMeta = meta;
    result.evidenceStrength = meta.evidenceStrength;
    result.scoringVersion = SCORING_VERSION;
    delete result.scoring;

    // Server-side audit row — independent of whether the client saves the
    // analysis. Best-effort: an audit failure must never fail the tasting.
    try {
      const { data: audit, error: auditErr } = await g.supabase
        .from("score_audits")
        .insert({
          user_id: g.user.id,
          transcription_sha256: digestHash,
          scoring_version: SCORING_VERSION,
          viability_score: score,
          verdict_band: result.verdictBand,
          computed_band: meta.computedBand,
          dimension_scores: meta.cappedDims,
          raw_dimension_scores: rawDims,
          dimension_evidence: result.dimensionEvidence,
          founder_evidence: founder,
          research_digest: hasResearch ? digest : null,
          evidence_strength: meta.evidenceStrength,
          score_meta: meta,
          model: MODEL,
          is_pivot: Boolean(pivot) || Boolean(retaste),
          is_calibration: Boolean(g.limitExempt) || calibration === true,
        })
        .select("id")
        .single();
      if (auditErr) console.error("score_audits insert failed:", auditErr.message);
      else result.scoreAuditId = audit?.id ?? null;
    } catch (auditErr) {
      console.error("score_audits insert threw:", auditErr);
    }

    return new Response(JSON.stringify(result), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("analyze-swot unhandled error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
