// Viability scoring — the code that turns the model's five 0-10 dimension
// judgments into the 0-100 number the app shows.
//
// The LLM extracts facts and judges rubric rows WITH evidence; this module
// aggregates deterministically so the result is calibratable and auditable.
//
// v1 is frozen here as a regression reference (see scoring_test.ts). v2 is
// the live formula: no band clamp, evidence caps driven by research facts,
// weakest-link gate, calibrated piecewise map, hedge penalty.

export const SCORING_VERSION = 2;

export type DimKey =
  | "problemSeverity"
  | "demandEvidence"
  | "marketQuality"
  | "feasibility"
  | "differentiation";

export const DIM_KEYS: DimKey[] = [
  "problemSeverity",
  "demandEvidence",
  "marketQuality",
  "feasibility",
  "differentiation",
];

export type Dims = Record<DimKey, number>;

export type Band = "burnt" | "half_baked" | "needs_seasoning" | "simmering" | "chefs_kiss";

/** Final score bands matching the app's ScoreVerdict. 96-100 is reserved. */
export const BAND_RANGES: Record<Band, [number, number]> = {
  burnt:           [5, 19],
  half_baked:      [20, 39],
  needs_seasoning: [40, 59],
  simmering:       [60, 79],
  chefs_kiss:      [80, 95],
};

/** Band a final score lands in — mirrors ScoreVerdict(score:) on iOS. */
export function bandFor(score: number): Band {
  if (score < 20) return "burnt";
  if (score < 40) return "half_baked";
  if (score < 60) return "needs_seasoning";
  if (score < 80) return "simmering";
  return "chefs_kiss";
}

export function flattenDims(scoring: Record<string, { score: number }>): Dims {
  return Object.fromEntries(
    DIM_KEYS.map((k) => [k, Number(scoring[k]?.score ?? 0)]),
  ) as Dims;
}

// ---------------------------------------------------------------------------
// v1 — frozen. Weighted mean → 1.35x stretch about 45 → clamp into the
// model's verdict band → hard caps. Kept only so tests can prove the refactor
// changed nothing and so audits can attribute old rows.
// ---------------------------------------------------------------------------

export function computeScoreV1(input: {
  dims: Dims;
  verdictBand: string;
  fatalFlaw: boolean;
}): number {
  const d = input.dims;
  const raw =
    (d.problemSeverity * 0.30 +
     d.demandEvidence  * 0.25 +
     d.marketQuality   * 0.20 +
     d.feasibility     * 0.15 +
     d.differentiation * 0.10) * 10;

  let score = Math.round(45 + (raw - 45) * 1.35);

  const [lo, hi] = BAND_RANGES[input.verdictBand as Band] ?? [0, 100];
  score = Math.max(lo, Math.min(hi, score));

  if (Math.min(...Object.values(d)) <= 1) score = Math.min(score, 35);
  if (input.fatalFlaw) score = Math.min(score, 20);

  return Math.max(0, Math.min(100, score));
}

// ---------------------------------------------------------------------------
// v2 inputs
// ---------------------------------------------------------------------------

export type FounderStrongest =
  | "none"
  | "anecdote"
  | "personal_experience"
  | "community_size"
  | "poll"
  | "waitlist"
  | "prepayments"
  | "revenue";

export interface FounderEvidence {
  citesConcreteNumbers: boolean;
  quotes: string[];
  strongest: FounderStrongest;
}

export const NO_FOUNDER_EVIDENCE: FounderEvidence = {
  citesConcreteNumbers: false,
  quotes: [],
  strongest: "none",
};

/** Founder-supplied numbers that unlock the upper demand rows. */
const FOUNDER_NUMBERS: FounderStrongest[] = ["poll", "waitlist", "prepayments", "revenue"];
/** Money or commitment actually changed hands / was pledged. */
const FOUNDER_MONEY: FounderStrongest[] = ["waitlist", "prepayments", "revenue"];

export type SearchQuality = "none" | "thin" | "ok" | "rich";
export type Saturation = "empty" | "sparse" | "competitive" | "crowded" | "dominated";
export type YesNoUnknown = "yes" | "no" | "unknown";

/** Everything the caps need, derived from a research digest in code. */
export interface ResearchFacts {
  /** A digest with any content at all was supplied. */
  present: boolean;
  /** The digest carries the v2 `market` block (numbers), not just prose. */
  structured: boolean;
  quality: SearchQuality;
  paidComparables: number;
  freeDominant: YesNoUnknown;
  saturation: Saturation;
  smallPlayersMakingMoney: YesNoUnknown;
  giantBlocks: YesNoUnknown;
  giantName: string;
  strongPositive: boolean;
  strongNegative: boolean;
  strongNegativeText: string;
  priceHigh: number;
  /** Best guess whether typical pricing is a monthly subscription. */
  monthlyPricing: boolean;
}

export const NO_RESEARCH: ResearchFacts = {
  present: false,
  structured: false,
  quality: "none",
  paidComparables: 0,
  freeDominant: "unknown",
  saturation: "empty",
  smallPlayersMakingMoney: "unknown",
  giantBlocks: "unknown",
  giantName: "",
  strongPositive: false,
  strongNegative: false,
  strongNegativeText: "",
  priceHigh: 0,
  monthlyPricing: false,
};

// deno-lint-ignore no-explicit-any
type AnyRecord = Record<string, any>;

/**
 * Reads a research digest of either shape — the legacy prose digest or the
 * v2 digest with `signals[]` and a `market` block — into ResearchFacts.
 */
export function deriveResearchFacts(digest: unknown): ResearchFacts {
  if (!digest || typeof digest !== "object") return NO_RESEARCH;
  const r = digest as AnyRecord;

  const comparables: AnyRecord[] = Array.isArray(r.comparables) ? r.comparables : [];
  const demandSignals: unknown[] = Array.isArray(r.demand_signals) ? r.demand_signals : [];
  const present =
    comparables.length > 0 ||
    (typeof r.niche_notes === "string" && r.niche_notes !== "") ||
    demandSignals.length > 0 ||
    (Array.isArray(r.signals) && r.signals.length > 0);
  if (!present) return NO_RESEARCH;

  const market: AnyRecord | null = r.market && typeof r.market === "object" ? r.market : null;
  if (!market) {
    return { ...NO_RESEARCH, present: true, structured: false, quality: "ok" };
  }

  const signals: AnyRecord[] = Array.isArray(r.signals) ? r.signals : [];
  const strongNeg = signals.find((s) => s.direction === "negative" && s.strength === "strong");
  const strongPos = signals.some((s) => s.direction === "positive" && s.strength === "strong");

  const paidFromMarket = Number(market.paid_comparables_found ?? 0);
  const paidFromList = comparables.filter((c) => c.charges_money === "yes").length;

  const periods = comparables
    .filter((c) => c.charges_money === "yes")
    .map((c) => String(c.price_period ?? "unknown"));
  const monthlyPricing = periods.length > 0 &&
    periods.filter((p) => p === "month").length * 2 >= periods.length;

  const quality = (["none", "thin", "ok", "rich"] as SearchQuality[]).includes(market.search_quality)
    ? market.search_quality as SearchQuality
    : "ok";
  const saturation = (["empty", "sparse", "competitive", "crowded", "dominated"] as Saturation[])
      .includes(market.saturation)
    ? market.saturation as Saturation
    : "sparse";
  const yn = (v: unknown): YesNoUnknown => (v === "yes" || v === "no") ? v : "unknown";

  return {
    present: true,
    structured: true,
    quality,
    paidComparables: Math.max(paidFromMarket, paidFromList),
    freeDominant: yn(market.free_alternatives_dominate),
    saturation,
    smallPlayersMakingMoney: yn(market.small_players_making_money),
    giantBlocks: yn(market.giant_blocks_niche),
    giantName: typeof market.giant_name === "string" ? market.giant_name : "",
    strongPositive: strongPos,
    strongNegative: Boolean(strongNeg),
    strongNegativeText: strongNeg ? String(strongNeg.text ?? "") : "",
    priceHigh: Number(market.typical_price_high ?? 0),
    monthlyPricing,
  };
}

/** The evidence-strength label the app shows above the breakdown. */
export function evidenceStrength(facts: ResearchFacts, comparableCount = 0): SearchQuality {
  if (!facts.present) return "none";
  if (!facts.structured) return comparableCount <= 1 ? "thin" : "ok";
  if (facts.quality === "none" || facts.quality === "thin") return "thin";
  return facts.quality;
}

// ---------------------------------------------------------------------------
// v2 — caps, aggregation, map, adjustments
// ---------------------------------------------------------------------------

export const WEIGHTS: Record<DimKey, number> = {
  problemSeverity: 0.20,
  demandEvidence:  0.25,
  marketQuality:   0.20,
  feasibility:     0.10,
  differentiation: 0.25,
};

/** raw (0-10) → 0-100. Slope is steepest through the middle. */
export const KNOTS: [number, number][] = [
  [0, 0], [1, 8], [3, 30], [5, 50], [6.5, 72], [8, 90], [10, 100],
];

export function piecewiseLinear(knots: [number, number][], x: number): number {
  if (x <= knots[0][0]) return knots[0][1];
  for (let i = 1; i < knots.length; i++) {
    const [x0, y0] = knots[i - 1];
    const [x1, y1] = knots[i];
    if (x <= x1) return y0 + ((x - x0) / (x1 - x0)) * (y1 - y0);
  }
  return knots[knots.length - 1][1];
}

export interface ScoreCap {
  dim: DimKey;
  from: number;
  to: number;
  reason: string;
}

export interface ScoreAdjustment {
  kind: "hedged" | "founder_numbers" | "dead_dimension" | "fatal_flaw" | "ceiling";
  delta?: number;
  cap?: number;
  reason: string;
}

export interface ScoreMeta {
  version: number;
  weights: Record<DimKey, number>;
  rawDims: Dims;
  cappedDims: Dims;
  wm: number;
  gate: number;
  demandFactor: number;
  raw: number;
  mapped: number;
  caps: ScoreCap[];
  adjustments: ScoreAdjustment[];
  hedged: boolean;
  verdictBand: string;
  computedBand: Band;
  bandMismatch: boolean;
  evidenceStrength: SearchQuality;
}

/**
 * Stage 1 — deterministic upper bounds on the evidence dimensions. The model
 * still judges within them; the caps are what make "everything is a 5-6"
 * rare by construction rather than by arithmetic. Every cap carries a reason
 * that the app can show.
 */
export function applyEvidenceCaps(
  dims: Dims,
  facts: ResearchFacts,
  founder: FounderEvidence,
): { dims: Dims; caps: ScoreCap[] } {
  const out: Dims = { ...dims };
  const caps: ScoreCap[] = [];
  const founderNumbers = FOUNDER_NUMBERS.includes(founder.strongest);

  const cap = (dim: DimKey, to: number, reason: string) => {
    if (out[dim] > to) {
      caps.push({ dim, from: out[dim], to, reason });
      out[dim] = to;
    }
  };

  if (!facts.present) {
    let demandCeiling = 4;
    if (founderNumbers) demandCeiling = 8;
    else if (founder.strongest === "personal_experience" || founder.strongest === "community_size") {
      demandCeiling = 5;
    }
    cap("demandEvidence", demandCeiling, "unverified: no market research for this run");
    cap("marketQuality", 5, "unverified: no market research for this run");
  } else if (!facts.structured) {
    cap("demandEvidence", founderNumbers ? 8 : 6, "research found comparables but no prices or counts");
    cap("marketQuality", 6, "research found comparables but no prices or counts");
  } else {
    if (facts.quality === "none" || facts.quality === "thin") {
      cap("demandEvidence", founderNumbers ? 8 : 5, "the scout found almost nothing relevant");
      cap("marketQuality", 5, "the scout found almost nothing relevant");
    }
    if (facts.paidComparables === 0 && (facts.quality === "ok" || facts.quality === "rich") &&
        !facts.strongPositive) {
      cap("demandEvidence", 4, "we looked: nobody is charging money for this");
    } else if (!founderNumbers && !facts.strongPositive) {
      // Comparables charging money prove a market exists — not that anyone
      // wants THIS founder's version. Calibration 2026-09-17: without this,
      // "decent, unproven" ideas landed at 73 beside poll-backed ones at 80.
      cap("demandEvidence", 6, "paid comparables prove a market, not your demand: 7+ needs your own numbers or a strong signal");
    }
    if ((facts.saturation === "crowded" || facts.saturation === "dominated") && out.differentiation <= 3) {
      cap("demandEvidence", Math.max(3, out.differentiation + 1),
          "crowded niche and nothing different: the category's demand isn't yours yet");
    }
    if (facts.strongNegative) {
      cap("demandEvidence", 5, `strong negative signal: ${facts.strongNegativeText}`.trim());
    }
    if (facts.saturation === "dominated" || facts.giantBlocks === "yes") {
      const who = facts.giantName ? ` by ${facts.giantName}` : "";
      cap("marketQuality", 4, `the niche is dominated${who}`);
    } else if (facts.saturation === "crowded") {
      cap("marketQuality", 5, "crowded niche: six or more similar products");
    }
    if (facts.freeDominant === "yes") {
      cap("marketQuality", 4, "people solve this for free today");
    }
    if (facts.smallPlayersMakingMoney !== "yes") {
      cap("marketQuality", 6, "no small player seen making a living here");
    }
    if (facts.paidComparables >= 1 && facts.priceHigh > 0 && facts.priceHigh < 5 && facts.monthlyPricing) {
      cap("marketQuality", 5, "thin monetization: paid comparables charge under $5/month");
    }
  }

  // Demand 9-10 is reserved for money or commitment actually on the table.
  if (!FOUNDER_MONEY.includes(founder.strongest)) {
    cap("demandEvidence", 8, "demand 9+ needs a waitlist, pre-payments, or revenue");
  }

  // Consistency: a hair-on-fire problem shows up as spend somewhere.
  cap("problemSeverity", out.demandEvidence + 3,
      "severity this high implies people already spend; demand evidence doesn't show it");

  return { dims: out, caps };
}

export function computeScoreV2(input: {
  dims: Dims;
  verdictBand: string;
  fatalFlaw: boolean;
  founder?: FounderEvidence | null;
  research?: ResearchFacts | null;
  comparableCount?: number;
}): { score: number; meta: ScoreMeta } {
  const founder = input.founder ?? NO_FOUNDER_EVIDENCE;
  const facts = input.research ?? NO_RESEARCH;

  // Stage 1 — evidence caps
  const { dims: d, caps } = applyEvidenceCaps(input.dims, facts, founder);

  // Stage 2 — aggregate
  const wm = DIM_KEYS.reduce((sum, k) => sum + WEIGHTS[k] * d[k], 0);
  const minDim = Math.min(...DIM_KEYS.map((k) => d[k]));
  const gate = 1 - 0.08 * Math.max(0, 3 - minDim);
  const demandFactor = Math.min(1, 0.85 + 0.05 * d.demandEvidence);
  const raw = wm * gate * demandFactor;

  // Stage 3 — map
  const mapped = piecewiseLinear(KNOTS, raw);

  // Stage 4 — adjustments
  const adjustments: ScoreAdjustment[] = [];
  let score = mapped;

  const hedged = DIM_KEYS.every((k) => d[k] >= 4 && d[k] <= 6);
  if (hedged) {
    score -= 4;
    adjustments.push({ kind: "hedged", delta: -4, reason: "every dimension sat in 4-6: a hedge, not a judgment" });
  }
  if (FOUNDER_MONEY.includes(founder.strongest) && facts.present) {
    score += 3;
    adjustments.push({ kind: "founder_numbers", delta: 3, reason: `founder cites ${founder.strongest} and research corroborates the niche` });
  }
  if (minDim <= 1) {
    score = Math.min(score, 35);
    adjustments.push({ kind: "dead_dimension", cap: 35, reason: "a dimension scored 0-1" });
  }
  if (input.fatalFlaw) {
    score = Math.min(score, 20);
    adjustments.push({ kind: "fatal_flaw", cap: 20, reason: "fatal flaw as described" });
  }
  score = Math.max(0, Math.min(95, Math.round(score)));

  const computedBand = bandFor(score);
  const meta: ScoreMeta = {
    version: SCORING_VERSION,
    weights: WEIGHTS,
    rawDims: input.dims,
    cappedDims: d,
    wm: round2(wm),
    gate: round2(gate),
    demandFactor: round2(demandFactor),
    raw: round2(raw),
    mapped: round2(mapped),
    caps,
    adjustments,
    hedged,
    verdictBand: input.verdictBand,
    computedBand,
    bandMismatch: computedBand !== input.verdictBand,
    evidenceStrength: evidenceStrength(facts, input.comparableCount ?? 0),
  };
  return { score, meta };
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** sha256 hex of a string — keys research digests and audits to a transcript. */
export async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
