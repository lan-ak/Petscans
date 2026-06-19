import { Env } from "../src/types.js";

/// Minimal in-memory KVNamespace stub supporting the get/put surface we use.
export class FakeKV {
  store = new Map<string, string>();
  async get(key: string): Promise<string | null> {
    return this.store.has(key) ? (this.store.get(key) as string) : null;
  }
  async put(key: string, value: string): Promise<void> {
    this.store.set(key, value);
  }
  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }
}

export function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    CACHE: new FakeKV() as unknown as KVNamespace,
    RATE: new FakeKV() as unknown as KVNamespace,
    AUTH_SECRET: "test-secret-0123456789abcdef",
    OPENAI_API_KEY: "openai-key",
    FIRECRAWL_API_KEY: "firecrawl-key",
    SERPER_API_KEY: "serper-key",
    UPCITEMDB_API_KEY: "upc-key",
    UNWRANGLE_API_KEY: "unwrangle-key",
    DEVICE_RATE_PER_HOUR: "60",
    DAILY_SPEND_LIMIT_CENTS: "2000",
    TOKEN_TTL_DAYS: "30",
    KILL_SWITCH: "off",
    ATTEST_REQUIRED: "off",
    ...overrides,
  };
}
