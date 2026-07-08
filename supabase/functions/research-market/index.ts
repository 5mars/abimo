import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Research is best-effort by design: ANY failure returns an empty digest with
// HTTP 200 so the analysis pipeline never blocks on a flaky search.
const EMPTY_DIGEST = { comparables: [], niche_notes: "", demand_signals: [] };

const RESEARCH_SCHEMA = {
  type: "object",
  properties: {
    comparables: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name:    { type: "string" },   // real product/business name
          what:    { type: "string" },   // one sentence: what they sell
          pricing: { type: "string" },   // "$9/mo", "free + tips", "unknown"
          status:  { type: "string" },   // size hint: "solo dev, ~2k users", "small team"
          url:     { type: "string" },   // "" if unknown
        },
        required: ["name", "what", "pricing", "status", "url"],
        additionalProperties: false,
      },
    },
    niche_notes:    { type: "string" },                            // 2-3 sentences on the beachhead niche
    demand_signals: { type: "array", items: { type: "string" } },  // real signals found on the web
  },
  required: ["comparables", "niche_notes", "demand_signals"],
  additionalProperties: false,
};

const RESEARCH_PROMPT = `You are a market scout for everyday people starting small side projects.

Given a startup idea from a voice note, search the web for REAL, SMALL comparable
businesses: indie apps, micro-SaaS, Etsy/Gumroad sellers, local services, solo-founder
products — things similar to this idea that exist AND are still small. Skip the giants
unless nothing small exists (a giant blocking the niche is worth reporting).

For each comparable report:
- its real name
- what it does, in one sentence
- real pricing if findable ("unknown" if not)
- a size hint (solo dev, small team, rough user count if mentioned anywhere)
- a URL if you have one

Also collect real demand signals you find: forum complaints, reviews, Reddit threads,
"I wish X existed" posts, people describing workarounds.

Rules:
- Report ONLY what you actually found in search results. Never invent names, prices,
  user counts, or URLs. An empty list beats a fake one.
- Find 2-5 comparables. Prefer small and current over famous and stale.
- niche_notes: 2-3 plain-English sentences about the specific niche a beginner would
  start in — who the buyers are and whether small players make money here.`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Not authenticated" }, 401);
  }

  try {
    const { transcription } = await req.json();
    if (!transcription || typeof transcription !== "string") {
      return jsonResponse(EMPTY_DIGEST);
    }

    const openaiRes = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        tools: [{ type: "web_search" }],
        input: [
          { role: "system", content: RESEARCH_PROMPT },
          {
            role: "user",
            content: `Idea (voice note transcript):\n\n${transcription}\n\nSearch the web and report small comparables and demand signals.`,
          },
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

    return jsonResponse(JSON.parse(text));
  } catch (err) {
    console.error("research-market unhandled error:", err);
    return jsonResponse(EMPTY_DIGEST);
  }
});
