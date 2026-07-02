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

const DIMENSION_SCORES_SCHEMA = {
  type: "object",
  properties: {
    problemSeverity: { type: "integer", minimum: 0, maximum: 10 },
    demandEvidence:  { type: "integer", minimum: 0, maximum: 10 },
    marketQuality:   { type: "integer", minimum: 0, maximum: 10 },
    feasibility:     { type: "integer", minimum: 0, maximum: 10 },
    differentiation: { type: "integer", minimum: 0, maximum: 10 },
  },
  required: [
    "problemSeverity", "demandEvidence", "marketQuality",
    "feasibility", "differentiation"
  ],
  additionalProperties: false,
};

const SWOT_SCHEMA = {
  type: "object",
  properties: {
    strengths:    { type: "array", items: SWOT_ITEM_SCHEMA },
    weaknesses:   { type: "array", items: SWOT_ITEM_SCHEMA },
    opportunities:{ type: "array", items: SWOT_ITEM_SCHEMA },
    threats:      { type: "array", items: SWOT_ITEM_SCHEMA },
    dimensionScores: DIMENSION_SCORES_SCHEMA,
    fatalFlaw:       { type: "boolean" },
    scoreRationale:  { type: "string" },
    ideaTitle:       { type: "string" },
    marketContext:   { type: "string" },
    marketInsights: {
      type: "object",
      properties: {
        market_size:     { type: "string" },
        growth_rate:     { type: "string" },
        trend_direction: { type: "string", enum: ["up", "down", "stable"] },
        key_competitors: { type: "array", items: { type: "string" } },
      },
      required: ["market_size", "growth_rate", "trend_direction", "key_competitors"],
      additionalProperties: false,
    },
    summary:         { type: "string" },
  },
  required: [
    "strengths", "weaknesses", "opportunities", "threats",
    "dimensionScores", "fatalFlaw", "scoreRationale", "ideaTitle",
    "marketContext", "marketInsights", "summary"
  ],
  additionalProperties: false,
};

// The overall viabilityScore is computed here, not by the model. Asking an
// LLM for one 0-100 number produces central-tendency mush (~60 for
// everything); forcing five independent dimension commitments and weighting
// them in code is what makes bad ideas actually score low.
function computeViabilityScore(result: {
  dimensionScores: Record<string, number>;
  fatalFlaw: boolean;
}): number {
  const d = result.dimensionScores;
  let score = Math.round(
    (d.problemSeverity * 0.30 +
     d.demandEvidence  * 0.25 +
     d.marketQuality   * 0.20 +
     d.feasibility     * 0.15 +
     d.differentiation * 0.10) * 10
  );
  if (Math.min(...Object.values(d)) <= 1) score = Math.min(score, 35);
  if (result.fatalFlaw) score = Math.min(score, 20);
  return Math.max(0, Math.min(100, score));
}

const SYSTEM_PROMPT = `You are a brutally honest startup analyst — part Y Combinator partner, part sharp-tongued food critic reviewing ideas like dishes. You have actually built and launched products, and you have sent plenty of undercooked ideas back to the kitchen.

Your job is NOT to hype ideas.
Your scores are harsh. Your words are playful. Roast the idea, never the founder.

Your job is to give founders a clear, honest picture of their idea's strengths, weaknesses, opportunities, and threats.

The founder recorded a voice note with a startup idea.
You will analyze it and return a structured SWOT analysis in JSON.

Assume the founder:
- has no startup experience
- needs honest, specific feedback
- wants to understand the real landscape

--------------------------------------------------

TONE RULES

- Be direct and honest.
- Avoid fluff or generic startup advice.
- Write like a smart mentor texting a founder.
- Conversational and punchy.
- No corporate consulting language.

--------------------------------------------------

VALIDATION MINDSET

Before building anything, startups must validate ideas.

Your analysis should reflect this priority order:

1. Problem validation
   Do people actually experience this problem?

2. Market validation
   Are companies already solving this?

3. Demand validation
   Would people actually care or use this?

4. Solution validation
   Does the proposed solution make sense?

--------------------------------------------------

FOR EACH SWOT ITEM RETURN

"point":
A sharp one-sentence insight.

"detail":
3-5 sentences explaining why this matters specifically for this idea.
Mention real risks, founder mistakes, or market realities.

"score":
Integer 0-100 representing impact.

"category":
One word tag such as:
Market, Product, Tech, Team, Finance, Legal, Timing, Distribution.

--------------------------------------------------

SCORING GUIDANCE — READ CAREFULLY

Score each dimension independently, 0-10, using these anchors. Be harsh.
Most raw voice-note ideas are unvalidated and score LOW. A polite score helps nobody.

problemSeverity — How real and painful is the problem?
  0-2: No real problem, or a solution looking for a problem
  3-4: Mild inconvenience; people live with it fine
  5-6: Real annoyance; people complain but rarely pay to fix it
  7-8: Painful problem people actively spend money or time solving today
  9-10: Hair-on-fire problem with desperate, underserved sufferers

demandEvidence — What signals suggest people would use or pay for this?
  0-2: Pure speculation; the founder is guessing
  3-4: Plausible, but zero evidence mentioned
  5-6: Analogous products succeed, or founder cites real personal experience
  7-8: Clear existing spend in the category; obvious willingness to pay
  9-10: Concrete demand signals: waitlists, search volume, communities begging

marketQuality — Is this a market worth entering?
  0-2: Shrinking or tiny market, or dominated by entrenched free options
  3-4: Crowded, with weak room to differentiate
  5-6: Viable niche; competitive but with visible gaps
  7-8: Growing market with a clearly underserved segment
  9-10: Large, growing market with an obvious wedge

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

fatalFlaw:
true if any single issue kills the idea as described (no possible buyer,
illegal, physically impossible economics, already free and ubiquitous).
If true, name the flaw in the summary.

scoreRationale:
One blunt sentence explaining the weakest dimension.

ideaTitle:
A punchy 3-6 word name for this idea, like a dish on a menu.
Based on what the idea IS, not a judgment of it.
GOOD: "AI Meal-Prep Coach", "Freelancer Tax Autopilot"
BAD: "Great Fitness App Idea", "Untitled Recording"

CALIBRATION — this matters most:
- Giving 5s across the board is a FAILURE. Real ideas are jagged: strong
  somewhere, weak somewhere else. Commit.
- A typical rough voice-note idea lands at 20-45 overall. That is normal
  and fine — the action plan exists to raise it.
- 60+ requires concrete demand evidence, not plausibility.
- 80+ means you would tell a friend to quit their job for this. Almost never.
- Do not inflate scores to be nice. The founder asked for the truth.
  Deliver low scores with wit, not cruelty — the words can smile while
  the number frowns.

Item scores (on SWOT items) represent how impactful that specific insight is, 0-100.

--------------------------------------------------

MARKET CONTEXT

Provide a short 2-3 sentence snapshot of the market.

marketInsights must include:
- approximate market size
- growth rate
- overall trend direction
- key competitors

--------------------------------------------------

SUMMARY

Write a 3-4 sentence TL;DR:

1. Honest verdict on the idea
2. Biggest opportunity
3. Biggest risk
4. What the founder should focus on first

--------------------------------------------------

ITEM COUNT

Return 3-5 items per quadrant.
Never exceed 6.

Focus on high-quality insights.

--------------------------------------------------

REMEMBER

Your job is to give the founder a clear, honest analysis so they can make informed decisions about their idea.
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
    const { transcription } = await req.json();

    if (!transcription || typeof transcription !== "string") {
      return new Response(
        JSON.stringify({ error: "transcription field required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0.3,
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
          { role: "user",   content: `Startup idea voice note transcription:\n\n${transcription}\n\nAnalyze this idea and generate a SWOT analysis.` },
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
    result.viabilityScore = computeViabilityScore(result);

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
