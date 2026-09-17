// deno test supabase/functions/_shared/appleJWS_test.ts
import { assertEquals, assert, assertThrows } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { decodePayload, entitlement, type TransactionPayload } from "./appleJWS.ts";

function fakeJWS(payload: Record<string, unknown>): string {
  const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${enc({ alg: "ES256", x5c: [] })}.${enc(payload)}.sig`;
}

const base: TransactionPayload = {
  transactionId: "1",
  originalTransactionId: "1",
  bundleId: "com.mars.Abimo",
  productId: "com.mars.Abimo.plus.monthly",
  purchaseDate: Date.now() - 1000,
  expiresDate: Date.now() + 30 * 24 * 3600 * 1000,
  environment: "Production",
};

Deno.test("decodePayload reads the middle segment", () => {
  const p = decodePayload(fakeJWS({ ...base }));
  assertEquals(p.productId, "com.mars.Abimo.plus.monthly");
  assertThrows(() => decodePayload("not.a.jws.at.all"));
});

Deno.test("live known product is premium", () => {
  const e = entitlement(base);
  assert(e.isPremium);
  assertEquals(e.productId, base.productId);
});

Deno.test("expired beyond grace is not premium; inside grace still is", () => {
  const day = 24 * 3600 * 1000;
  assert(!entitlement({ ...base, expiresDate: Date.now() - 4 * day }).isPremium);
  assert(entitlement({ ...base, expiresDate: Date.now() - 2 * day }).isPremium);
});

Deno.test("revoked, wrong bundle or unknown product are never premium", () => {
  assert(!entitlement({ ...base, revocationDate: Date.now() }).isPremium);
  assert(!entitlement({ ...base, bundleId: "com.evil.App" }).isPremium);
  assert(!entitlement({ ...base, productId: "com.mars.Abimo.lifetime" }).isPremium);
});
