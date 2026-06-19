/// Proxy route table. Each route is a transparent pass-through to one upstream
/// provider: the Worker injects the real API key, optionally serves/stores a
/// cached response, and returns the upstream body verbatim so the iOS client's
/// existing decoders keep working unchanged. Only the base URL and auth header
/// change on the client.

import { Env, UpstreamResult } from "./types.js";

export interface ProxyRoute {
  method: "GET" | "POST";
  /// Build the upstream Request (URL + headers + body) with the key injected.
  buildUpstream(ctx: RouteContext): { url: string; init: RequestInit };
  /// Stable cache input for this request, or null if it should not be cached.
  cacheInput(ctx: RouteContext): string | null;
  cacheTtlSeconds: number;
  /// Rough per-call cost in cents, charged against the daily budget on a miss.
  estCents: number;
}

export interface RouteContext {
  env: Env;
  url: URL;
  /// Parsed JSON body for POST routes (undefined for GET).
  body?: unknown;
  /// Raw body text for POST routes, used for forwarding + cache hashing.
  rawBody?: string;
}

const json = { "Content-Type": "application/json" };

export const ROUTES: Record<string, ProxyRoute> = {
  // OpenAI GPT-4o Vision — product identification from a packaging photo.
  "POST /v1/openai/identify": {
    method: "POST",
    buildUpstream: ({ env, rawBody }) => ({
      url: "https://api.openai.com/v1/chat/completions",
      init: {
        method: "POST",
        headers: { ...json, Authorization: `Bearer ${env.OPENAI_API_KEY}` },
        body: rawBody,
      },
    }),
    // Cache on the full body (includes the image), so identical photos are free.
    cacheInput: ({ rawBody }) => rawBody ?? null,
    cacheTtlSeconds: 60 * 60 * 24 * 30,
    estCents: 1,
  },

  // Firecrawl — scrape ingredients from a retailer/manufacturer product page.
  "POST /v1/firecrawl/scrape": {
    method: "POST",
    buildUpstream: ({ env, rawBody }) => ({
      url: "https://api.firecrawl.dev/v1/scrape",
      init: {
        method: "POST",
        headers: { ...json, Authorization: `Bearer ${env.FIRECRAWL_API_KEY}` },
        body: rawBody,
      },
    }),
    cacheInput: ({ body }) => fieldString(body, "url"),
    cacheTtlSeconds: 60 * 60 * 24 * 30,
    estCents: 1,
  },

  // Serper — Google search to locate a product's page.
  "POST /v1/serper/search": {
    method: "POST",
    buildUpstream: ({ env, rawBody }) => ({
      url: "https://google.serper.dev/search",
      init: {
        method: "POST",
        headers: { ...json, "X-API-KEY": env.SERPER_API_KEY },
        body: rawBody,
      },
    }),
    cacheInput: ({ body }) => fieldString(body, "q"),
    cacheTtlSeconds: 60 * 60 * 24 * 7,
    estCents: 1,
  },

  // UPCitemdb (paid v1) — barcode → product lookup.
  "GET /v1/upcitemdb/lookup": {
    method: "GET",
    buildUpstream: ({ env, url }) => {
      const upc = url.searchParams.get("upc") ?? "";
      const target = new URL("https://api.upcitemdb.com/prod/v1/lookup");
      target.searchParams.set("upc", upc);
      return {
        url: target.toString(),
        init: {
          method: "GET",
          headers: {
            Accept: "application/json",
            "User-Agent": "PetScans/1.0 (proxy)",
            user_key: env.UPCITEMDB_API_KEY,
            key_type: "3scale",
          },
        },
      };
    },
    cacheInput: ({ url }) => url.searchParams.get("upc"),
    cacheTtlSeconds: 60 * 60 * 24 * 60,
    estCents: 1,
  },

  // Unwrangle — structured Chewy product data (incl. ingredients).
  "GET /v1/unwrangle/getter": {
    method: "GET",
    buildUpstream: ({ env, url }) => {
      const target = new URL("https://data.unwrangle.com/api/getter/");
      // Forward all client params except any client-supplied key, then inject.
      url.searchParams.forEach((v, k) => {
        if (k !== "api_key") target.searchParams.set(k, v);
      });
      target.searchParams.set("api_key", env.UNWRANGLE_API_KEY);
      return { url: target.toString(), init: { method: "GET", headers: { Accept: "application/json" } } };
    },
    cacheInput: ({ url }) => url.searchParams.get("url"),
    cacheTtlSeconds: 60 * 60 * 24 * 30,
    estCents: 1,
  },
};

function fieldString(body: unknown, key: string): string | null {
  if (body && typeof body === "object" && key in (body as Record<string, unknown>)) {
    const v = (body as Record<string, unknown>)[key];
    return typeof v === "string" ? v : null;
  }
  return null;
}

/// Perform the upstream call and normalize the response.
export async function forward(route: ProxyRoute, ctx: RouteContext): Promise<UpstreamResult> {
  const { url, init } = route.buildUpstream(ctx);
  const res = await fetch(url, init);
  const text = await res.text();
  return {
    status: res.status,
    body: text,
    contentType: res.headers.get("Content-Type") ?? "application/json",
    cached: false,
  };
}
