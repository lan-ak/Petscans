/// KV-backed response cache for idempotent upstream lookups. The same product
/// scanned twice should never cost a second upstream call. Cache keys are a
/// SHA-256 of the route + canonical request input, so they are stable and
/// collision-resistant across devices (this is also the seed of the future
/// shared product database).

import { Env, UpstreamResult } from "./types.js";
import { sha256Hex } from "./crypto.js";

interface CachedEntry {
  status: number;
  body: string;
  contentType: string;
}

export async function cacheKey(route: string, input: string): Promise<string> {
  return `cache:${route}:${await sha256Hex(input)}`;
}

export async function readCache(env: Env, key: string): Promise<UpstreamResult | null> {
  const raw = await env.CACHE.get(key);
  if (!raw) return null;
  try {
    const entry = JSON.parse(raw) as CachedEntry;
    return { ...entry, cached: true };
  } catch {
    return null;
  }
}

/// Only successful (2xx) responses are cached, so transient upstream errors are
/// retried rather than pinned.
export async function writeCache(
  env: Env,
  key: string,
  result: UpstreamResult,
  ttlSeconds: number,
): Promise<void> {
  if (result.status < 200 || result.status >= 300) return;
  const entry: CachedEntry = {
    status: result.status,
    body: result.body,
    contentType: result.contentType,
  };
  await env.CACHE.put(key, JSON.stringify(entry), { expirationTtl: ttlSeconds });
}
