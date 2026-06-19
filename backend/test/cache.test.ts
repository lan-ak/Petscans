import { describe, it, expect } from "vitest";
import { cacheKey, readCache, writeCache } from "../src/cache.js";
import { makeEnv } from "./helpers.js";

describe("cache", () => {
  it("produces stable keys for identical input and distinct keys otherwise", async () => {
    const a = await cacheKey("GET /v1/upcitemdb/lookup", "012345678905");
    const b = await cacheKey("GET /v1/upcitemdb/lookup", "012345678905");
    const c = await cacheKey("GET /v1/upcitemdb/lookup", "999999999999");
    expect(a).toBe(b);
    expect(a).not.toBe(c);
  });

  it("stores and reads back a successful response", async () => {
    const env = makeEnv();
    const key = await cacheKey("r", "x");
    await writeCache(env, key, { status: 200, body: '{"ok":true}', contentType: "application/json", cached: false }, 60);
    const hit = await readCache(env, key);
    expect(hit?.body).toBe('{"ok":true}');
    expect(hit?.cached).toBe(true);
  });

  it("does not cache non-2xx responses", async () => {
    const env = makeEnv();
    const key = await cacheKey("r", "y");
    await writeCache(env, key, { status: 500, body: "err", contentType: "text/plain", cached: false }, 60);
    expect(await readCache(env, key)).toBeNull();
  });
});
