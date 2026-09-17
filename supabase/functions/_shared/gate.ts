import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

// Native app traffic ignores CORS; locking the origin just stops casual
// browser-based abuse of the endpoints.
export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://ymbfqlrarlnqtzatgfah.supabase.co",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function jsonError(msg: string, status: number, code?: string, extra: Record<string, unknown> = {}): Response {
  return new Response(JSON.stringify({ error: msg, code, ...extra }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export interface GateResult {
  user: { id: string };
  supabase: SupabaseClient;
  /** Server-side view of Abimo Plus, from profiles (never the client's word). */
  isPlus: boolean;
  /** True for calibration accounts listed in AI_LIMIT_EXEMPT_USER_IDS — no
   *  daily budget, and their scoring audits are flagged is_calibration. */
  limitExempt: boolean;
}

/** Per-day caps by tier. A bare number means the same cap for both. */
export type TierLimits = number | { free: number; plus: number };

function isLimitExempt(userId: string): boolean {
  const raw = Deno.env.get("AI_LIMIT_EXEMPT_USER_IDS") ?? "";
  return raw.split(",").map((s) => s.trim()).filter(Boolean).includes(userId);
}

function nextUtcMidnight(): string {
  const d = new Date();
  d.setUTCHours(24, 0, 0, 0);
  return d.toISOString();
}

/** Resolve the caller and their tier without spending a credit. */
export async function authenticate(req: Request): Promise<GateResult | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonError("Not authenticated", 401);

  // SUPABASE_URL / SUPABASE_ANON_KEY are injected into every deployed function.
  // The client is user-scoped: RPCs and RLS run as the caller.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } },
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) return jsonError("Invalid or expired session", 401);

  // profiles is readable by its owner only; a missing row is a free user.
  let isPlus = false;
  try {
    const { data } = await supabase
      .from("profiles")
      .select("is_premium, premium_expires_at")
      .eq("user_id", user.id)
      .maybeSingle();
    if (data?.is_premium) {
      const exp = data.premium_expires_at ? new Date(data.premium_expires_at).getTime() : null;
      const grace = 3 * 24 * 60 * 60 * 1000;
      isPlus = exp === null || exp > Date.now() - grace;
    }
  } catch (e) {
    console.error("gate: profiles lookup failed:", e);
  }

  return { user: { id: user.id }, supabase, isPlus, limitExempt: isLimitExempt(user.id) };
}

/**
 * Verifies the caller's JWT, resolves the user and tier, and atomically
 * consumes one daily credit for `fn` via the consume_ai_credit RPC with the
 * tier's limit. Returns a ready-to-send error Response on failure: 401 for
 * bad auth, 429 (with tier, limit, resets_at) when the budget is spent.
 */
export async function gate(
  req: Request,
  fn: string,
  limits: TierLimits,
): Promise<GateResult | Response> {
  const auth = await authenticate(req);
  if (auth instanceof Response) return auth;
  return await consumeCredit(auth, fn, limits);
}

/** The budget half of gate(), for functions that check the tier first. */
export async function consumeCredit(
  auth: GateResult,
  fn: string,
  limits: TierLimits,
): Promise<GateResult | Response> {
  // Calibration accounts skip the budget so a 30-run batch can complete.
  if (auth.limitExempt) return { ...auth, limitExempt: true };

  const limit = typeof limits === "number" ? limits : (auth.isPlus ? limits.plus : limits.free);

  const { data: allowed, error: rpcErr } = await auth.supabase.rpc("consume_ai_credit", {
    p_fn: fn,
    p_limit: limit,
  });
  if (rpcErr) {
    console.error(`gate(${fn}): consume_ai_credit failed:`, rpcErr.message);
    return jsonError("Usage check failed", 500);
  }
  if (!allowed) {
    return jsonError(
      auth.isPlus
        ? "Even Plus chefs rest. Burners back on tomorrow."
        : "The free kitchen closes after today's tastings. Plus keeps the burners on.",
      429,
      "rate_limited",
      { tier: auth.isPlus ? "plus" : "free", limit, resets_at: nextUtcMidnight() },
    );
  }

  return { ...auth, limitExempt: false };
}

/** 403 for Plus-only paths. */
export function requirePlus(g: GateResult): Response | null {
  if (g.isPlus || g.limitExempt) return null;
  return jsonError("This table is Plus-only.", 403, "plus_required");
}
