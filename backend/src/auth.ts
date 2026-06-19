/// Anonymous device-token auth.
///
/// The iOS app requests a token once per device. Tokens are stateless, signed
/// with HMAC-SHA256 over `{deviceId, exp}` so no per-token storage is needed.
/// This keeps the upstream API keys off the client; abuse is bounded by the
/// per-device rate limiter and the global spend kill-switch (see rateLimit.ts).
///
/// Hardening hook: `verifyAttestation` is where Apple App Attest should be
/// validated before minting a token. It is a no-op unless ATTEST_REQUIRED=on,
/// so the MVP works today and attestation can be switched on later.

import { Env, boolVar, intVar } from "./types.js";
import { base64UrlDecodeString, base64UrlEncodeString, hmacSign, hmacVerify } from "./crypto.js";

interface TokenPayload {
  d: string; // deviceId
  exp: number; // epoch seconds
}

export interface AuthResult {
  ok: boolean;
  deviceId?: string;
  reason?: string;
}

/// Mint a signed token of the form `<payloadB64Url>.<sigB64Url>`.
export async function issueToken(env: Env, deviceId: string): Promise<{ token: string; expiresAt: number }> {
  const ttlDays = intVar(env.TOKEN_TTL_DAYS, 30);
  const exp = Math.floor(Date.now() / 1000) + ttlDays * 86400;
  const payload: TokenPayload = { d: deviceId, exp };
  const payloadStr = base64UrlEncodeString(JSON.stringify(payload));
  const sig = await hmacSign(env.AUTH_SECRET, payloadStr);
  return { token: `${payloadStr}.${sig}`, expiresAt: exp };
}

/// Validate the `Authorization: Bearer <token>` header. Returns the deviceId
/// on success so downstream rate limiting can key off it.
export async function verifyRequest(env: Env, request: Request): Promise<AuthResult> {
  const header = request.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) return { ok: false, reason: "missing_bearer_token" };

  const token = match[1];
  const dot = token.lastIndexOf(".");
  if (dot <= 0) return { ok: false, reason: "malformed_token" };

  const payloadStr = token.slice(0, dot);
  const sig = token.slice(dot + 1);

  if (!(await hmacVerify(env.AUTH_SECRET, payloadStr, sig))) {
    return { ok: false, reason: "bad_signature" };
  }

  let payload: TokenPayload;
  try {
    payload = JSON.parse(base64UrlDecodeString(payloadStr));
  } catch {
    return { ok: false, reason: "bad_payload" };
  }

  if (typeof payload.exp !== "number" || payload.exp < Math.floor(Date.now() / 1000)) {
    return { ok: false, reason: "expired" };
  }
  if (typeof payload.d !== "string" || payload.d.length === 0) {
    return { ok: false, reason: "bad_device" };
  }

  return { ok: true, deviceId: payload.d };
}

/// Placeholder for Apple App Attest verification. Returns true unless
/// ATTEST_REQUIRED is on and no attestation is supplied. Implement full
/// attestation validation here before relying on it in production.
export function verifyAttestation(env: Env, attestation: string | undefined): boolean {
  if (!boolVar(env.ATTEST_REQUIRED)) return true;
  return typeof attestation === "string" && attestation.length > 0;
}
