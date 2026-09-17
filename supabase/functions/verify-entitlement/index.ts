import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { authenticate, jsonError, CORS_HEADERS } from "../_shared/gate.ts";
import { entitlement, verifyTransactionJWS } from "../_shared/appleJWS.ts";

// The app posts its current StoreKit 2 entitlement (a signed transaction
// JWS). We verify it against Apple's root locally and mirror the result
// into profiles — the only writer of that table. No credit is consumed.
//
// A null jws means "I have no entitlement": the row is downgraded.

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const auth = await authenticate(req);
  if (auth instanceof Response) return auth;

  try {
    const { jws } = await req.json();

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    if (jws == null) {
      await admin.from("profiles").upsert({
        user_id: auth.user.id,
        is_premium: false,
        premium_expires_at: null,
        premium_product_id: null,
        last_verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
      return json({ is_premium: false, expires_at: null });
    }

    if (typeof jws !== "string" || jws.length > 16_000) {
      return jsonError("jws must be a string", 400);
    }

    let payload;
    try {
      payload = await verifyTransactionJWS(jws);
    } catch (e) {
      console.error("verify-entitlement: JWS rejected:", String(e));
      return jsonError("Transaction could not be verified", 400, "invalid_jws");
    }

    const ent = entitlement(payload);
    const { error } = await admin.from("profiles").upsert({
      user_id: auth.user.id,
      is_premium: ent.isPremium,
      premium_expires_at: ent.expiresAt,
      premium_product_id: ent.productId,
      original_transaction_id: ent.originalTransactionId,
      environment: ent.environment,
      last_verified_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    if (error) {
      console.error("verify-entitlement: profiles upsert failed:", error.message);
      return jsonError("Could not record entitlement", 500);
    }

    return json({ is_premium: ent.isPremium, expires_at: ent.expiresAt, environment: ent.environment });
  } catch (err) {
    console.error("verify-entitlement unhandled error:", err);
    return jsonError(String(err), 500);
  }
});

function json(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
