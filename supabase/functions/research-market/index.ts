import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { gate, CORS_HEADERS } from "../_shared/gate.ts";
import { sha256Hex } from "../_shared/scoring.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const DAILY_LIMIT = 10;
const MAX_TRANSCRIPTION_CHARS = 8000;
const MAX_PIVOT_FIELD_CHARS = 500;

// Research is best-effort by design: ANY failure returns an empty digest with
// HTTP 200 so the analysis pipeline never blocks on a flaky search.
//
// v2 digest = the legacy prose fields (kept byte-for-byte so shipped app
// builds still decode) PLUS numbers: per-comparable prices/counts, individual
// signals with direction and strength, and a `market` block the scorer turns
// into deterministic caps. Absence of evidence is reported as a fact.
const EMPTY_DIGEST = {
  comparables: [],
  niche_notes: "",
  demand_signals: [],
  signals: [],
  market: {
    paid_comparables_found: 0,
    free_alternatives_dominate: "unknown",
    saturation: "empty",
    small_players_making_money: "unknown",
    giant_blocks_niche: "unknown",
    giant_name: "",
    typical_price_low: 0,
    typical_price_high: 0,
    price_currency: "",
    search_quality: "none",
    queries_run: [],
  },
};

const COMPARABLE_SCHEMA = {
  type: "object",
  properties: {
    name:    { type: "string" },   // real product/business name
    what:    { type: "string" },   // one sentence: what they sell
    pricing: { type: "string" },   // legacy prose: "$9/mo", "free + tips", "unknown"
    status:  { type: "string" },   // legacy prose size hint
    url:     { type: "string" },   // "" if unknown
    price_amount:      { type: "number" },                                  // 0 if unknown/free
    price_currency:    { type: "string" },                                  // "USD", "" if unknown
    price_period:      { type: "string", enum: ["month", "year", "one_time", "free", "unknown"] },
    charges_money:     { type: "string", enum: ["yes", "no", "unknown"] },
    size:              { type: "string", enum: ["solo", "small_team", "company", "giant", "unknown"] },
    user_count_hint:   { type: "number" },                                  // a number you saw, else 0
    user_count_source: { type: "string" },                                  // where you saw it, "" if none
    last_active:       { type: "string", enum: ["2025_or_later", "2023_2024", "older", "unknown"] },
  },
  required: [
    "name", "what", "pricing", "status", "url",
    "price_amount", "price_currency", "price_period", "charges_money",
    "size", "user_count_hint", "user_count_source", "last_active",
  ],
  additionalProperties: false,
};

const SIGNAL_SCHEMA = {
  type: "object",
  properties: {
    text:        { type: "string" },
    url:         { type: "string" },
    source_type: { type: "string", enum: ["reddit", "forum", "review", "app_store", "news", "blog", "social", "marketplace", "other"] },
    direction:   { type: "string", enum: ["positive", "negative"] },
    strength:    { type: "string", enum: ["weak", "moderate", "strong"] },
    recency:     { type: "string", enum: ["2025_or_later", "2023_2024", "older", "unknown"] },
    count_hint:  { type: "number" },   // upvotes/replies/reviews/members you saw, else 0
  },
  required: ["text", "url", "source_type", "direction", "strength", "recency", "count_hint"],
  additionalProperties: false,
};

const MARKET_SCHEMA = {
  type: "object",
  properties: {
    paid_comparables_found:     { type: "integer" },
    free_alternatives_dominate: { type: "string", enum: ["yes", "no", "unknown"] },
    saturation:                 { type: "string", enum: ["empty", "sparse", "competitive", "crowded", "dominated"] },
    small_players_making_money: { type: "string", enum: ["yes", "no", "unknown"] },
    giant_blocks_niche:         { type: "string", enum: ["yes", "no", "unknown"] },
    giant_name:                 { type: "string" },
    typical_price_low:          { type: "number" },
    typical_price_high:         { type: "number" },
    price_currency:             { type: "string" },
    search_quality:             { type: "string", enum: ["none", "thin", "ok", "rich"] },
    queries_run:                { type: "array", items: { type: "string" } },
  },
  required: [
    "paid_comparables_found", "free_alternatives_dominate", "saturation",
    "small_players_making_money", "giant_blocks_niche", "giant_name",
    "typical_price_low", "typical_price_high", "price_currency",
    "search_quality", "queries_run",
  ],
  additionalProperties: false,
};

const RESEARCH_SCHEMA = {
  type: "object",
  properties: {
    comparables:    { type: "array", items: COMPARABLE_SCHEMA },
    niche_notes:    { type: "string" },                            // 2-3 sentences on the beachhead niche
    demand_signals: { type: "array", items: { type: "string" } },  // legacy: one plain sentence per signal
    signals:        { type: "array", items: SIGNAL_SCHEMA },
    market:         MARKET_SCHEMA,
  },
  required: ["comparables", "niche_notes", "demand_signals", "signals", "market"],
  additionalProperties: false,
};

const RESEARCH_PROMPT = `You are a market scout for everyday people starting small side projects. You report FACTS you can point to — including the absence of facts.

Run at least four searches before answering:
1. "<idea in 3-6 words> app" / "<idea> tool" / "<idea> software"
2. "<idea> pricing" or "<idea> $/month"
3. site:reddit.com OR site:news.ycombinator.com "<the problem in the founder's words>"
4. "<idea>" on a marketplace that fits (App Store, Gumroad, Etsy, Product Hunt, Shopify app store)
Record every query you ran in market.queries_run.

COMPARABLES (2-6): real, preferably SMALL and current — indie apps, micro-SaaS, Etsy/Gumroad sellers, local services, solo-founder products. For each report name, what, url, and the NUMBERS:
- price_amount as a plain number (12, not "$12"); price_period; price_currency ("" if unknown). Free → price_amount 0, price_period "free".
- charges_money: yes only if you saw a price or a paid tier.
- size, user_count_hint (a number you saw, 0 if none) and where you saw it (user_count_source).
- last_active: the newest date evidence you saw (release note, review, post).
- Also fill the legacy prose fields: pricing ("$12/mo", "free", "unknown") and status (size hint in words).
Report giants only when they block the niche; then set market.giant_blocks_niche and giant_name.

SIGNALS (0-8): individual demand signals with url, source_type, direction, strength, recency, count_hint (upvotes/replies/reviews/members — a number you saw, else 0).
- direction "positive": people asking for this, paying for it, or complaining about an incumbent's price.
- direction "negative": people saying free tools are fine, churn or refund complaints about this category, "nobody needs this", dead comparables.
- strength: strong = many people or money changing hands; moderate = several independent posts; weak = one post.
Also fill demand_signals with one plain sentence per signal (legacy field).

MARKET block — answer from what you found, not from intuition:
- paid_comparables_found: count of comparables with charges_money = yes.
- free_alternatives_dominate: yes if the most common way people solve this today is free (a spreadsheet, a free app, a built-in phone feature).
- saturation: empty (found nothing), sparse (1-2 comparables), competitive (3-5 with visible gaps), crowded (6+ similar), dominated (one player everyone names).
- small_players_making_money: yes only if you saw a small/indie player with a price AND signs of customers (reviews, user counts, activity).
- typical_price_low / typical_price_high across paid comparables (0 if none), price_currency.
- search_quality: none (nothing relevant), thin (1 relevant result), ok, rich.

RULES
- Never invent names, prices, counts, or URLs. A 0 or "unknown" beats a guess.
- Absence is a finding: if you searched well and found nobody charging money, say so — paid_comparables_found 0 with search_quality ok or rich. That LOWERS the idea's score, and it should.
- niche_notes: 2-3 plain sentences a beginner would understand — who the buyers are and whether small players make money here. No TAM, no billions.`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** Digest cache key: the transcript, plus the remix title when re-tasting a pivot. */
export async function digestKey(transcription: string, pivotTitle?: string): Promise<string> {
  return await sha256Hex(pivotTitle ? `${transcription}\n#pivot:${pivotTitle}` : transcription);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  // Best-effort applies to OpenAI hiccups only; auth/rate-limit failures must
  // surface as real errors, not silently look like "no research found".
  const g = await gate(req, "research-market", DAILY_LIMIT);
  if (g instanceof Response) return g;

  try {
    const { transcription, pivot } = await req.json();
    if (!transcription || typeof transcription !== "string" ||
        transcription.length > MAX_TRANSCRIPTION_CHARS) {
      return jsonResponse(EMPTY_DIGEST);
    }
    const pivotTitle: string | undefined =
      pivot && typeof pivot.title === "string" && pivot.title.length <= MAX_PIVOT_FIELD_CHARS
        ? pivot.title
        : undefined;

    let userContent = `Idea (voice note transcript):\n\n${transcription}\n\n`;
    if (pivotTitle) {
      userContent += `The founder is now pursuing this remix of the idea — research THE REMIX:\nRemix: ${pivotTitle}\nPitch: ${String(pivot.pitch ?? "").slice(0, MAX_PIVOT_FIELD_CHARS)}\n\n`;
    }
    userContent += `Search the web and report comparables, signals, and the market block.`;

    const openaiRes = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        max_output_tokens: 4000,
        tools: [{ type: "web_search" }],
        input: [
          { role: "system", content: RESEARCH_PROMPT },
          { role: "user", content: userContent },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "market_research",
            schema: RESEARCH_SCHEMA,
            strict: true,
          },
        },
      }),
    });

    if (!openaiRes.ok) {
      console.error(`research-market OpenAI error ${openaiRes.status}:`, await openaiRes.text());
      return jsonResponse(EMPTY_DIGEST);
    }

    const data = await openaiRes.json();
    // Responses API: the final assistant message is the last `message` item
    // in data.output; its content holds an `output_text` entry with the JSON.
    const message = (data.output ?? []).filter((o: { type: string }) => o.type === "message").pop();
    const text = message?.content?.find((c: { type: string }) => c.type === "output_text")?.text;
    if (!text) {
      console.error("research-market: no output_text in response");
      return jsonResponse(EMPTY_DIGEST);
    }

    const digest = JSON.parse(text);

    // Cache by transcript hash so analyze-swot can recover the structured
    // digest even when an older app build forwards only the prose fields.
    try {
      const { error } = await g.supabase.from("research_digests").insert({
        user_id: g.user.id,
        transcription_sha256: await digestKey(transcription, pivotTitle),
        digest,
      });
      if (error) console.error("research_digests insert failed:", error.message);
    } catch (e) {
      console.error("research_digests insert threw:", e);
    }

    return jsonResponse(digest);
  } catch (err) {
    console.error("research-market unhandled error:", err);
    return jsonResponse(EMPTY_DIGEST);
  }
});
