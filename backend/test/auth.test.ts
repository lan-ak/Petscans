import { describe, it, expect } from "vitest";
import { issueToken, verifyRequest, verifyAttestation } from "../src/auth.js";
import { makeEnv } from "./helpers.js";

function bearer(token: string): Request {
  return new Request("https://api.test/v1/serper/search", {
    headers: { Authorization: `Bearer ${token}` },
  });
}

describe("device token auth", () => {
  it("round-trips a valid token", async () => {
    const env = makeEnv();
    const { token } = await issueToken(env, "device-abcdef12");
    const res = await verifyRequest(env, bearer(token));
    expect(res.ok).toBe(true);
    expect(res.deviceId).toBe("device-abcdef12");
  });

  it("rejects a tampered payload", async () => {
    const env = makeEnv();
    const { token } = await issueToken(env, "device-abcdef12");
    const [, sig] = token.split(".");
    const forgedPayload = btoa(JSON.stringify({ d: "attacker", exp: 9999999999 }))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
    const forged = `${forgedPayload}.${sig}`;
    const res = await verifyRequest(env, bearer(forged));
    expect(res.ok).toBe(false);
    expect(res.reason).toBe("bad_signature");
  });

  it("rejects a token signed with a different secret", async () => {
    const minted = await issueToken(makeEnv({ AUTH_SECRET: "other-secret" }), "device-abcdef12");
    const res = await verifyRequest(makeEnv(), bearer(minted.token));
    expect(res.ok).toBe(false);
  });

  it("rejects an expired token", async () => {
    const env = makeEnv({ TOKEN_TTL_DAYS: "-1" });
    const { token } = await issueToken(env, "device-abcdef12");
    const res = await verifyRequest(env, bearer(token));
    expect(res.ok).toBe(false);
    expect(res.reason).toBe("expired");
  });

  it("rejects a missing bearer header", async () => {
    const env = makeEnv();
    const res = await verifyRequest(env, new Request("https://api.test/x"));
    expect(res.ok).toBe(false);
    expect(res.reason).toBe("missing_bearer_token");
  });

  it("attestation is optional unless required", () => {
    expect(verifyAttestation(makeEnv(), undefined)).toBe(true);
    expect(verifyAttestation(makeEnv({ ATTEST_REQUIRED: "on" }), undefined)).toBe(false);
    expect(verifyAttestation(makeEnv({ ATTEST_REQUIRED: "on" }), "blob")).toBe(true);
  });
});
