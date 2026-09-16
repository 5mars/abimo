// Verifies a StoreKit 2 signed transaction (JWS) the app sends us and turns
// it into an entitlement decision. Nothing here calls Apple: the signature
// and certificate chain are checked locally against the pinned Apple Root
// CA G3, so this works offline from Apple's servers and needs no API key.
//
// Xcode's StoreKit Testing environment signs with a local certificate that
// does NOT chain to Apple. Those transactions are accepted only when the
// ALLOW_STOREKIT_TEST_ENV secret is "true" — set it on a dev project, never
// in production.

import * as x509 from "npm:@peculiar/x509@1";
import * as jose from "npm:jose@5";

x509.cryptoProvider.set(crypto);

/** Apple Root CA - G3, SHA-256 fingerprint of the DER certificate.
 *  Verify against https://www.apple.com/certificateauthority/ before trusting
 *  a change; overridable via the APPLE_ROOT_CA_G3_SHA256 secret. */
const APPLE_ROOT_G3_SHA256_DEFAULT = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

// Read lazily: the pure helpers (decode, entitlement) must import without
// env permission so they stay unit-testable.
function appleRootFingerprint(): string {
  return Deno.env.get("APPLE_ROOT_CA_G3_SHA256")?.replace(/[^0-9a-f]/gi, "").toLowerCase()
    ?? APPLE_ROOT_G3_SHA256_DEFAULT;
}

export interface TransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;        // ms
  expiresDate?: number;        // ms
  revocationDate?: number;     // ms
  environment: "Production" | "Sandbox" | "Xcode" | string;
  type?: string;
  offerType?: number;
  signedDate?: number;
}

export interface Entitlement {
  isPremium: boolean;
  expiresAt: string | null;
  productId: string;
  originalTransactionId: string;
  environment: string;
}

const KNOWN_PRODUCTS = new Set(["com.mars.Abimo.plus.monthly", "com.mars.Abimo.plus.yearly"]);
const BUNDLE_ID = "com.mars.Abimo";

function b64urlToBytes(s: string): Uint8Array<ArrayBuffer> {
  const pad = s.length % 4 === 0 ? "" : "=".repeat(4 - (s.length % 4));
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  const bytes = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function sha256Hex(bytes: ArrayBuffer): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Decode without verifying — for the payload's own claims (environment). */
export function decodePayload(jws: string): TransactionPayload {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("malformed JWS");
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[1])));
}

/**
 * Full verification: x5c chain (leaf ← intermediate ← pinned Apple root),
 * ES256 signature with the leaf key, then the payload's claims.
 */
export async function verifyTransactionJWS(jws: string): Promise<TransactionPayload> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("malformed JWS");
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[0])));
  const payload = decodePayload(jws);

  const allowXcode = Deno.env.get("ALLOW_STOREKIT_TEST_ENV") === "true";
  if (payload.environment === "Xcode") {
    if (!allowXcode) throw new Error("StoreKit Testing transactions are not accepted here");
    return payload;   // local test cert — nothing to chain to
  }

  const chain: string[] = header.x5c ?? [];
  if (chain.length < 2) throw new Error("x5c chain missing");
  const certs = chain.map((c) => new x509.X509Certificate(b64urlToBytes(c.replace(/-/g, "+").replace(/_/g, "/"))));

  // Root must be Apple Root CA - G3, byte for byte.
  const root = certs[certs.length - 1];
  const rootFp = await sha256Hex(root.rawData);
  if (rootFp !== appleRootFingerprint()) throw new Error("certificate chain does not end at Apple Root CA G3");

  // Each cert must be signed by the next one up.
  for (let i = 0; i < certs.length - 1; i++) {
    const ok = await certs[i].verify({ publicKey: await certs[i + 1].publicKey.export(), signatureOnly: true });
    if (!ok) throw new Error(`certificate ${i} is not signed by its issuer`);
    const now = new Date();
    if (now < certs[i].notBefore || now > certs[i].notAfter) throw new Error(`certificate ${i} is not currently valid`);
  }

  // Signature over the JWS with the leaf's key.
  const leafKey = await jose.importX509(certs[0].toString("pem"), "ES256");
  await jose.compactVerify(jws, leafKey);   // throws on a bad signature

  return payload;
}

/** The entitlement a verified payload grants right now. */
export function entitlement(payload: TransactionPayload, now: Date = new Date()): Entitlement {
  const graceMs = 3 * 24 * 60 * 60 * 1000;
  const known = payload.bundleId === BUNDLE_ID && KNOWN_PRODUCTS.has(payload.productId);
  const revoked = payload.revocationDate != null;
  const expires = payload.expiresDate ?? null;
  const live = expires === null || expires + graceMs > now.getTime();
  return {
    isPremium: known && !revoked && live,
    expiresAt: expires ? new Date(expires).toISOString() : null,
    productId: payload.productId,
    originalTransactionId: payload.originalTransactionId,
    environment: payload.environment,
  };
}
