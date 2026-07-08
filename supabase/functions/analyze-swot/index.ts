import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
    "ideaTitle", "verdictBand", "verdictReason", "scoring",
    "fatalFlaw", "fatalFlawReason", "scoreRationale",
    "strengths", "weaknesses", "opportunities", "threats",
    "marketContext", "marketInsights", "ideaVariants", "summary",
  ],
  additionalProperties: false,
};

// Final score bands matching the app's ScoreVerdict. 96-100 is reserved —
// nothing earns it from a voice note.
const BAND_RANGES: Record<string, [number, number]> = {
  burnt:           [5, 19],
  half_baked:      [20, 39],
  needs_seasoning: [40, 59],
  simmering:       [60, 79],
  chefs_kiss:      [80, 95],
};

// The model commits to a verdict band FIRST (categorical — resists the pull
// to the middle), then scores five dimensions with evidence. The weighted
// average positions the score, a 1.35x stretch undoes averaging compression,
// and the band clamp keeps number and verdict consistent. Hard caps win.
function computeViabilityScore(result: {
  scoring: Record<string, { score: number }>;
  verdictBand: string;
  fatalFlaw: boolean;
}): number {
  const d: Record<string, number> = Object.fromEntries(
    Object.entries(result.scoring).map(([k, v]) => [k, v.score])
  );
  const raw =
    (d.problemSeverity * 0.30 +
     d.demandEvidence  * 0.25 +
     d.marketQuality   * 0.20 +
     d.feasibility     * 0.15 +
     d.differentiation * 0.10) * 10;

  let score = Math.round(45 + (raw - 45) * 1.35);

  const [lo, hi] = BAND_RANGES[result.verdictBand] ?? [0, 100];
  score = Math.max(lo, Math.min(hi, score));

  if (Math.min(...Object.values(d)) <= 1) score = Math.min(score, 35);
  if (result.fatalFlaw) score = Math.min(score, 20);

  return Math.max(0, Math.min(100, score));
}

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

The user message may include a RESEARCH DIGEST: real small businesses and demand signals found by live web search.

When a digest is PRESENT:
- Treat it as ground truth. Ground your demandEvidence and marketQuality scores in it.
- Copy its comparables into marketInsights.comparables (you may tighten wording; never change names, pricing, or status).
- Real small players doing this successfully is a GOOD sign for demand ("this has been done small and it works") — and a differentiation question at the same time.

When the digest is ABSENT or empty:
- Score from the transcript alone.
- Return an empty comparables array. NEVER invent company names, pricing, or market statistics. An empty plate beats a fake one.

--------------------------------------------------

STEP 1 — COMMIT TO A VERDICT BAND (do this first, before any numbers)

Pick exactly one verdictBand:

- "burnt" (5-19): No real buyer, fatal contradiction, or pure wish disguised as an idea.
- "half_baked" (20-39): A guess. Plausible-sounding, but no evidence anyone wants it, or a crowded space with no angle. Most raw voice notes land here or below.
- "needs_seasoning" (40-59): A real problem and a workable direction, but demand is unproven or the angle is thin. Worth testing this month.
- "simmering" (60-79): Real problem + concrete evidence people pay for solutions + a credible wedge this founder can execute. Rare from a raw voice note.
- "chefs_kiss" (80-95): Proven demand (real signals, not vibes), a clear underserved niche, and the founder can reach it. You would tell a friend to start this weekend.

Sitting on the fence is a failure. If you are torn between two bands, the evidence is insufficient — pick the LOWER one and say why in verdictReason.

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
  7-8: Research shows small players charging real money, or clear existing spend
  9-10: Concrete demand signals: waitlists, communities begging, proven willingness to pay

marketQuality — Is the BEACHHEAD NICHE worth entering? (Not the global market — the first few hundred customers this founder could actually reach.)
  0-2: The niche is tiny AND shrinking, or served well for free
  3-4: Crowded niche with no visible gap for a newcomer
  5-6: Viable niche; competitive but with visible gaps a small player can fill
  7-8: Underserved niche where small players already make a living
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

Your dimension scores must be consistent with your verdictBand — as a rough guide:
burnt: dims mostly 0-3 · half_baked: mostly 2-4 with maybe one 5-6 · needs_seasoning: mostly 4-6 · simmering: mostly 6-8 · chefs_kiss: mostly 7-9.
If your dims average a band higher than your verdict, one of them is wrong — reread the evidence and fix whichever is lying.
Real ideas are jagged — strong somewhere, weak somewhere else. Five 5s is a refusal to judge, not a judgment.

fatalFlaw: true only if one issue kills the idea AS DESCRIBED (no possible buyer, illegal, impossible economics, already free and ubiquitous). Name it in fatalFlawReason and the summary; otherwise fatalFlawReason is "".

scoreRationale: One blunt sentence naming the weakest dimension and what would raise it.

--------------------------------------------------

CALIBRATION ANCHORS — score against these, not against politeness

A. "I want to build an app that uses AI to help people be more productive, like with everything — tasks, email, life stuff."
   → burnt. problem 2, demand 1, market 2, feasibility 3, differentiation 0. Final ~7.
   A wish, not an idea. No user, no problem, competing with everyone.

B. "An app where you book dog walkers, like Uber but for dogs."
   → half_baked. problem 5, demand 3, market 2, feasibility 4, differentiation 1. Final ~30.
   Real problem, but Rover and Wag already own it and there is no angle.

C. "A meal planning app for busy parents — my sister always complains about deciding what to cook."
   → half_baked. problem 4, demand 3, market 3, feasibility 5, differentiation 2. Final ~32.
   Real annoyance, one anecdote, brutally crowded, no wedge yet.

D. "Freelance designers hate chasing overdue invoices — I do it every week and it's humiliating. Existing tools bury the reminder feature in $40/mo suites. I'd build just the polite-nagging bit for $8/mo and I know three designers who'd try it."
   → needs_seasoning. problem 7, demand 4, market 4, feasibility 7, differentiation 5. Final ~57.
   Founder lives the problem, sharp wedge, demand still anecdotal.

E. "I run a pool service route. The scheduling software we all use costs $300/mo and everyone in my 2,000-member trade Facebook group complains monthly. I'd build a $29/mo routes-only tool; four other techs already said they'd switch tomorrow."
   → simmering. problem 8, demand 6, market 6, feasibility 6, differentiation 6. Final ~73.
   Insider founder, priced-out users, named channel, early hand-raisers.

F. "My newsletter for wedding photographers has 4,000 subscribers. I posted a mockup of a client-gallery-delivery tool and 210 people joined the waitlist; 30 pre-paid $49. Current options cost $600/yr and photographers hate them."
   → chefs_kiss. problem 8, demand 8, market 8, feasibility 7, differentiation 7. Final ~89.
   Pre-payments, a waitlist, and owned distribution. Almost nothing scores here.

DISTRIBUTION MANDATE: across many ideas your finals must actually spread — empty wishes 10-25, plausible guesses 25-45, real problems with a credible wedge 45-65, evidence-backed ideas 65-80, proven demand 80+. Do not park ideas in the middle out of caution. Deliver low scores with wit, not cruelty — the words can smile while the number frowns.

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
- comparables: copied from the research digest; empty array if no digest. For EACH comparable, add two idea-aware sentences:
  - overlap: what it shares with the founder's idea ("Same dish" — plain words, one sentence).
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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Not authenticated" }),
      { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  try {
    const { transcription, research, pivot } = await req.json();

    if (!transcription || typeof transcription !== "string") {
      return new Response(
        JSON.stringify({ error: "transcription field required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    let userMessage = `Startup idea voice note transcription:\n\n${transcription}\n\n`;
    if (pivot && typeof pivot.title === "string") {
      userMessage += `FOUNDER'S PIVOT — the founder tasted the original and chose this remix instead. Analyze THE REMIX as the idea; the transcript above is background context only. ideaTitle must reflect the remix.\nRemix: ${pivot.title}\nPitch: ${pivot.pitch ?? ""}\nDifferentiator: ${pivot.differentiator ?? ""}\n\n`;
    }
    const hasResearch = research &&
      ((research.comparables?.length ?? 0) > 0 ||
       (research.niche_notes ?? "") !== "" ||
       (research.demand_signals?.length ?? 0) > 0);
    if (hasResearch) {
      userMessage += `RESEARCH DIGEST (from live web search — treat as ground truth):\n${JSON.stringify(research, null, 2)}\n\n`;
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
        model: "gpt-4o",
        temperature: 0.4,
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

    // Flatten for the client: five plain ints, computed final score, and the
    // scaffolding fields the model needed but the app doesn't.
    result.viabilityScore = computeViabilityScore(result);
    result.dimensionScores = Object.fromEntries(
      Object.entries(result.scoring as Record<string, { score: number }>)
        .map(([k, v]) => [k, v.score])
    );
    delete result.scoring;
    delete result.verdictBand;
    delete result.verdictReason;
    delete result.fatalFlawReason;

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
