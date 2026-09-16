// deno test supabase/functions/_shared/scoring_test.ts
import { assertEquals, assert } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  applyEvidenceCaps,
  bandFor,
  computeScoreV1,
  computeScoreV2,
  deriveResearchFacts,
  type Dims,
  type FounderEvidence,
  NO_FOUNDER_EVIDENCE,
  NO_RESEARCH,
  piecewiseLinear,
  KNOTS,
  type ResearchFacts,
} from "./scoring.ts";

const dims = (p: number, d: number, m: number, f: number, x: number): Dims => ({
  problemSeverity: p,
  demandEvidence: d,
  marketQuality: m,
  feasibility: f,
  differentiation: x,
});

/** Research that corroborates the niche and triggers no caps. */
const GROUNDED: ResearchFacts = {
  ...NO_RESEARCH,
  present: true,
  structured: true,
  quality: "rich",
  paidComparables: 3,
  saturation: "competitive",
  smallPlayersMakingMoney: "yes",
  freeDominant: "no",
  giantBlocks: "no",
  priceHigh: 29,
  monthlyPricing: true,
};

const founder = (strongest: FounderEvidence["strongest"]): FounderEvidence => ({
  citesConcreteNumbers: strongest !== "none" && strongest !== "anecdote",
  quotes: [],
  strongest,
});

// ---------------------------------------------------------------- v1 frozen

Deno.test("v1 reproduces the six prompt anchors exactly", () => {
  assertEquals(computeScoreV1({ dims: dims(2, 1, 2, 3, 0), verdictBand: "burnt", fatalFlaw: false }), 7);
  assertEquals(computeScoreV1({ dims: dims(5, 3, 2, 4, 1), verdictBand: "half_baked", fatalFlaw: false }), 29);
  assertEquals(computeScoreV1({ dims: dims(4, 3, 3, 5, 2), verdictBand: "half_baked", fatalFlaw: false }), 32);
  assertEquals(computeScoreV1({ dims: dims(7, 4, 4, 7, 5), verdictBand: "needs_seasoning", fatalFlaw: false }), 58);
  assertEquals(computeScoreV1({ dims: dims(8, 6, 6, 6, 6), verdictBand: "simmering", fatalFlaw: false }), 73);
  assertEquals(computeScoreV1({ dims: dims(8, 8, 8, 7, 7), verdictBand: "chefs_kiss", fatalFlaw: false }), 89);
});

Deno.test("v1 band clamp forces mid regardless of dims (the bug we are fixing)", () => {
  // Weak dims but the model said needs_seasoning → clamped UP to 40
  assertEquals(computeScoreV1({ dims: dims(3, 3, 3, 3, 3), verdictBand: "needs_seasoning", fatalFlaw: false }), 40);
  // Strong dims but needs_seasoning → clamped DOWN to 59
  assertEquals(computeScoreV1({ dims: dims(8, 7, 7, 7, 7), verdictBand: "needs_seasoning", fatalFlaw: false }), 59);
});

// ---------------------------------------------------------------- v2 math

Deno.test("piecewise map hits every knot and the mid slope", () => {
  for (const [x, y] of KNOTS) assertEquals(piecewiseLinear(KNOTS, x), y);
  assertEquals(piecewiseLinear(KNOTS, 4), 40);
  assertEquals(piecewiseLinear(KNOTS, 11), 100);
  assertEquals(piecewiseLinear(KNOTS, -1), 0);
});

Deno.test("v2 anchors land where the prompt will say they do", () => {
  const s = (d: Dims, band: string, f: FounderEvidence = NO_FOUNDER_EVIDENCE) =>
    computeScoreV2({ dims: d, verdictBand: band, fatalFlaw: false, founder: f, research: GROUNDED }).score;
  assertEquals(s(dims(2, 1, 2, 3, 0), "burnt"), 7);            // A
  assertEquals(s(dims(5, 3, 2, 4, 1), "half_baked"), 23);      // B
  assertEquals(s(dims(4, 3, 3, 5, 2), "half_baked"), 29);      // C
  assertEquals(s(dims(7, 4, 5, 7, 5), "needs_seasoning"), 55); // D (market 5)
  assertEquals(s(dims(8, 6, 6, 6, 6), "simmering"), 71);       // E
  assertEquals(s(dims(8, 8, 8, 7, 7), "chefs_kiss", founder("prepayments")), 89); // F
});

Deno.test("five 5s is docked as a hedge and lands clearly apart from a jagged mid profile", () => {
  const flat = computeScoreV2({ dims: dims(5, 5, 5, 5, 5), verdictBand: "needs_seasoning", fatalFlaw: false, research: GROUNDED });
  const jagged = computeScoreV2({ dims: dims(6, 6, 6, 6, 3), verdictBand: "needs_seasoning", fatalFlaw: false, research: GROUNDED });
  assertEquals(flat.score, 46);
  assert(flat.meta.hedged);
  assertEquals(jagged.score, 54);
  assert(!jagged.meta.hedged);
  assert(Math.abs(flat.score - jagged.score) >= 5);
  assert(flat.score !== 58 && jagged.score !== 58 && flat.score !== 59 && jagged.score !== 59);
});

Deno.test("band is diagnostic only — never clamps", () => {
  const weak = computeScoreV2({ dims: dims(3, 3, 3, 3, 3), verdictBand: "needs_seasoning", fatalFlaw: false, research: GROUNDED });
  assertEquals(weak.score, 30);
  assert(weak.meta.bandMismatch);
  const strong = computeScoreV2({ dims: dims(8, 7, 7, 7, 7), verdictBand: "needs_seasoning", fatalFlaw: false, research: GROUNDED });
  assert(strong.score >= 78, `expected strong profile ≥78, got ${strong.score}`);
});

Deno.test("great problem with guessed demand is pulled down by the consistency cap", () => {
  const r = computeScoreV2({ dims: dims(8, 2, 6, 7, 7), verdictBand: "simmering", fatalFlaw: false, research: GROUNDED });
  assertEquals(r.meta.cappedDims.problemSeverity, 5);
  assertEquals(r.score, 45);
  assert(r.meta.caps.some((c) => c.dim === "problemSeverity"));
});

Deno.test("dead dimension and fatal flaw caps still bite", () => {
  const dead = computeScoreV2({ dims: dims(8, 8, 8, 8, 0), verdictBand: "chefs_kiss", fatalFlaw: false, founder: founder("revenue"), research: GROUNDED });
  assert(dead.score <= 35);
  const fatal = computeScoreV2({ dims: dims(7, 7, 7, 7, 7), verdictBand: "simmering", fatalFlaw: true, research: GROUNDED });
  assert(fatal.score <= 20);
  assert(fatal.meta.adjustments.some((a) => a.kind === "fatal_flaw"));
});

// ---------------------------------------------------------------- caps

Deno.test("no research caps demand at 4 and market at 5 unless the founder brings numbers", () => {
  const plain = applyEvidenceCaps(dims(6, 6, 6, 6, 6), NO_RESEARCH, NO_FOUNDER_EVIDENCE);
  assertEquals(plain.dims.demandEvidence, 4);
  assertEquals(plain.dims.marketQuality, 5);
  const lived = applyEvidenceCaps(dims(6, 6, 6, 6, 6), NO_RESEARCH, founder("personal_experience"));
  assertEquals(lived.dims.demandEvidence, 5);
  const polled = applyEvidenceCaps(dims(6, 8, 6, 6, 6), NO_RESEARCH, founder("poll"));
  assertEquals(polled.dims.demandEvidence, 8);
});

Deno.test("all 6s without research lands low-mid, not 58", () => {
  // Caps pull demand to 4 and market to 5 (6,4,5,6,6 → wm 5.3 → 54.4), and
  // the now-flat profile is docked as a hedge → 50. Unverified optimism
  // reads as "edible, nobody's ordering seconds".
  const r = computeScoreV2({ dims: dims(6, 6, 6, 6, 6), verdictBand: "needs_seasoning", fatalFlaw: false, research: NO_RESEARCH });
  assertEquals(r.score, 50);
  assert(r.meta.hedged);
  assertEquals(r.meta.evidenceStrength, "none");
  // With lived experience the demand cap loosens to 5 → 54
  const lived = computeScoreV2({ dims: dims(6, 6, 6, 6, 6), verdictBand: "needs_seasoning", fatalFlaw: false, research: NO_RESEARCH, founder: founder("personal_experience") });
  assertEquals(lived.score, 54);
});

Deno.test("searching well and finding nobody paying caps demand at 4", () => {
  const facts: ResearchFacts = { ...GROUNDED, paidComparables: 0, smallPlayersMakingMoney: "no" };
  const { dims: d, caps } = applyEvidenceCaps(dims(6, 7, 7, 6, 6), facts, NO_FOUNDER_EVIDENCE);
  assertEquals(d.demandEvidence, 4);
  assertEquals(d.marketQuality, 6);
  assert(caps.some((c) => c.reason.includes("nobody is charging")));
});

Deno.test("dominated or free-dominant niches cap market at 4", () => {
  const dominated = applyEvidenceCaps(dims(6, 6, 8, 6, 6), { ...GROUNDED, saturation: "dominated", giantName: "Rover" }, NO_FOUNDER_EVIDENCE);
  assertEquals(dominated.dims.marketQuality, 4);
  assert(dominated.caps.some((c) => c.reason.includes("Rover")));
  const free = applyEvidenceCaps(dims(6, 6, 8, 6, 6), { ...GROUNDED, freeDominant: "yes" }, NO_FOUNDER_EVIDENCE);
  assertEquals(free.dims.marketQuality, 4);
});

Deno.test("demand 9+ is reserved for money on the table", () => {
  const talk = applyEvidenceCaps(dims(8, 10, 8, 8, 8), GROUNDED, founder("poll"));
  assertEquals(talk.dims.demandEvidence, 8);
  const paid = applyEvidenceCaps(dims(8, 10, 8, 8, 8), GROUNDED, founder("prepayments"));
  assertEquals(paid.dims.demandEvidence, 10);
});

Deno.test("legacy prose digest caps demand and market at 6", () => {
  const facts = deriveResearchFacts({ comparables: [{ name: "X", what: "", pricing: "$9/mo", status: "", url: "" }], niche_notes: "n", demand_signals: [] });
  assert(facts.present && !facts.structured);
  const { dims: d } = applyEvidenceCaps(dims(7, 8, 8, 7, 7), facts, NO_FOUNDER_EVIDENCE);
  assertEquals(d.demandEvidence, 6);
  assertEquals(d.marketQuality, 6);
});

// ---------------------------------------------------------------- digest parsing

Deno.test("deriveResearchFacts reads the v2 market block", () => {
  const facts = deriveResearchFacts({
    comparables: [
      { name: "A", what: "", pricing: "$12/mo", status: "", url: "", charges_money: "yes", price_period: "month", price_amount: 12 },
      { name: "B", what: "", pricing: "free", status: "", url: "", charges_money: "no", price_period: "free", price_amount: 0 },
    ],
    niche_notes: "n",
    demand_signals: ["s"],
    signals: [{ text: "people say spreadsheets are fine", url: "", source_type: "reddit", direction: "negative", strength: "strong", recency: "2025_or_later", count_hint: 40 }],
    market: { paid_comparables_found: 1, free_alternatives_dominate: "no", saturation: "competitive", small_players_making_money: "yes", giant_blocks_niche: "no", giant_name: "", typical_price_low: 12, typical_price_high: 12, price_currency: "USD", search_quality: "ok", queries_run: [] },
  });
  assert(facts.structured);
  assertEquals(facts.paidComparables, 1);
  assert(facts.strongNegative);
  assert(facts.monthlyPricing);
  assertEquals(facts.quality, "ok");
});

Deno.test("empty digest is no research", () => {
  assertEquals(deriveResearchFacts({ comparables: [], niche_notes: "", demand_signals: [] }).present, false);
  assertEquals(deriveResearchFacts(null).present, false);
});

Deno.test("bandFor mirrors ScoreVerdict", () => {
  assertEquals(bandFor(0), "burnt");
  assertEquals(bandFor(19), "burnt");
  assertEquals(bandFor(20), "half_baked");
  assertEquals(bandFor(59), "needs_seasoning");
  assertEquals(bandFor(60), "simmering");
  assertEquals(bandFor(80), "chefs_kiss");
});
