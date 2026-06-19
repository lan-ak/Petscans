import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import worker from "../src/index.js";
import { issueToken } from "../src/auth.js";
import { makeEnv } from "./helpers.js";
import type { Env } from "../src/types.js";

function req(method: string, path: string, opts: { token?: string; body?: unknown } = {}): Request {
  const headers: Record<string, string> = {};
  if (opts.token) headers.Authorization = `Bearer ${opts.token}`;
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";
  return new Request(`https://api.test${path}`, {
    method,
    headers,
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });
}

async function tokenFor(env: Env): Promise<string> {
  return (await issueToken(env, "device-abcdef12")).token;
}

describe("router", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("serves health check without auth", async () => {
    const res = await worker.fetch(req("GET", "/healthz"), makeEnv());
    expect(res.status).toBe(200);
  });

  it("issues a token for a valid device id", async () => {
    const res = await worker.fetch(
      req("POST", "/v1/auth/token", { body: { deviceId: "device-abcdef12" } }),
      makeEnv(),
    );
    expect(res.status).toBe(200);
    const data = (await res.json()) as { token: string };
    expect(typeof data.token).toBe("string");
  });

  it("rejects token issuance for a too-short device id", async () => {
    const res = await worker.fetch(req("POST", "/v1/auth/token", { body: { deviceId: "x" } }), makeEnv());
    expect(res.status).toBe(400);
  });

  it("returns 401 on a proxy route without a token", async () => {
    const res = await worker.fetch(req("POST", "/v1/serper/search", { body: { q: "dog food" } }), makeEnv());
    expect(res.status).toBe(401);
  });

  it("returns 404 for unknown routes", async () => {
    const env = makeEnv();
    const res = await worker.fetch(req("GET", "/v1/nope", { token: await tokenFor(env) }), env);
    expect(res.status).toBe(404);
  });

  it("proxies a miss to upstream, injects the key, records spend, then caches", async () => {
    const env = makeEnv();
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response('{"organic":[]}', { status: 200, headers: { "Content-Type": "application/json" } }));

    const token = await tokenFor(env);

    // First call: miss → upstream.
    const r1 = await worker.fetch(req("POST", "/v1/serper/search", { token, body: { q: "blue buffalo" } }), env);
    expect(r1.status).toBe(200);
    expect(r1.headers.get("X-PetScans-Cache")).toBe("miss");
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Upstream was called with the injected key, not a client key.
    const [calledUrl, calledInit] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(calledUrl).toBe("https://google.serper.dev/search");
    expect((calledInit.headers as Record<string, string>)["X-API-KEY"]).toBe("serper-key");

    // Second identical call: cache hit, no new upstream call.
    const r2 = await worker.fetch(req("POST", "/v1/serper/search", { token, body: { q: "blue buffalo" } }), env);
    expect(r2.headers.get("X-PetScans-Cache")).toBe("hit");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("honors the spend kill-switch on a cache miss", async () => {
    const env = makeEnv({ KILL_SWITCH: "on" });
    const fetchMock = vi.spyOn(globalThis, "fetch");
    const token = await tokenFor(env);
    const res = await worker.fetch(req("POST", "/v1/serper/search", { token, body: { q: "x" } }), env);
    expect(res.status).toBe(503);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("injects the bearer key for firecrawl scrape", async () => {
    const env = makeEnv();
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } }));
    const token = await tokenFor(env);
    await worker.fetch(
      req("POST", "/v1/firecrawl/scrape", { token, body: { url: "https://chewy.com/x" } }),
      env,
    );
    const [calledUrl, calledInit] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(calledUrl).toBe("https://api.firecrawl.dev/v1/scrape");
    expect((calledInit.headers as Record<string, string>).Authorization).toBe("Bearer firecrawl-key");
  });
});
