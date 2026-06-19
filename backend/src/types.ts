/// Environment bindings injected by Cloudflare Workers at runtime.
/// Secrets are configured via `wrangler secret put`; vars via wrangler.toml [vars].
export interface Env {
  // KV namespaces
  CACHE: KVNamespace;
  RATE: KVNamespace;

  // Secrets
  AUTH_SECRET: string;
  OPENAI_API_KEY: string;
  FIRECRAWL_API_KEY: string;
  SERPER_API_KEY: string;
  UPCITEMDB_API_KEY: string;
  UNWRANGLE_API_KEY: string;

  // Tuning vars (strings; parsed by config helpers)
  DEVICE_RATE_PER_HOUR: string;
  DAILY_SPEND_LIMIT_CENTS: string;
  TOKEN_TTL_DAYS: string;
  KILL_SWITCH: string;
  ATTEST_REQUIRED: string;
}

/// Describes one cacheable upstream proxy route.
export interface UpstreamResult {
  status: number;
  body: string;
  contentType: string;
  /// Whether this response was served from the KV cache (no upstream cost).
  cached: boolean;
}

export function intVar(value: string | undefined, fallback: number): number {
  const n = Number.parseInt(value ?? "", 10);
  return Number.isFinite(n) ? n : fallback;
}

export function boolVar(value: string | undefined): boolean {
  return value === "on" || value === "true" || value === "1";
}
