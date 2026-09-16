import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

// Native app traffic ignores CORS; locking the origin just stops casual
// browser-based abuse of the endpoints.
export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://ymbfqlrarlnqtzatgfah.supabase.co",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function jsonError(msg: string, status: number, code?: string): Response {
  return new Response(JSON.stringify({ error: msg, code }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export interface GateResult {
  user: { id: string };
  supabase: SupabaseClient;
  /** True for calibration accounts listed in AI_LIMIT_EXEMPT_USER_IDS — no
   *  daily budget, and their scoring audits are flagged is_calibration. */
  limitExempt: boolean;
}

function isLimitExempt(userId: string): boolean {
  const raw = Deno.env.get("AI_LIMIT_EXEMPT_USER_IDS") ?? "";
  return raw.split(",").map((s) => s.trim()).filter(Boolean).includes(userId);
}

/**
 * Verifies the caller's JWT, resolves the user, and atomically consumes one
 * daily credit for `fn` via the consume_ai_credit RPC. Returns a ready-to-send
 * error Response on failure: 401 for bad auth, 429 when the daily budget for
 * this function is spent.
 */
export async function gate(
  req: Request,
  fn: string,
  dailyLimit: number,
): Promise<GateResult | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonError("Not authenticated", 401);

  // SUPABASE_URL / SUPABASE_ANON_KEY are injected into every deployed function.
  // The client is user-scoped: RPCs run with the caller's auth.uid().
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } },
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) return jsonError("Invalid or expired session", 401);

  // Calibration accounts skip the budget so a 30-run batch can complete.
  if (isLimitExempt(user.id)) {
    return { user: { id: user.id }, supabase, limitExempt: true };
  }

  const { data: allowed, error: rpcErr } = await supabase.rpc("consume_ai_credit", {
    p_fn: fn,
    p_limit: dailyLimit,
  });
  if (rpcErr) {
    console.error(`gate(${fn}): consume_ai_credit failed:`, rpcErr.message);
    return jsonError("Usage check failed", 500);
  }
  if (!allowed) {
    return jsonError("Daily AI budget reached — try again tomorrow.", 429, "rate_limited");
  }

  return { user: { id: user.id }, supabase, limitExempt: false };
}
