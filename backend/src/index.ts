/// PetScans API proxy — Cloudflare Worker entry point.
///
/// Flow for a proxy request:
///   1. verify anonymous device token (auth.ts)
///   2. enforce per-device hourly cap (rateLimit.ts)
///   3. serve from KV cache if present (cache.ts) — free, no spend
///   4. otherwise check the global spend kill-switch, call upstream with the
///      real key injected (routes.ts), record spend, and cache the result
///
/// The upstream body is returned verbatim so the iOS client only swaps its base
/// URL + auth header.

import { Env } from "./types.js";
import { issueToken, verifyAttestation, verifyRequest } from "./auth.js";
import { allowDevice, recordSpend, spendBlocked } from "./rateLimit.js";
import { cacheKey, readCache, writeCache } from "./cache.js";
import { ROUTES, RouteContext, forward } from "./routes.js";

function jsonResponse(obj: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...extraHeaders },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const routeId = `${request.method} ${url.pathname}`;

    // Health check (unauthenticated).
    if (routeId === "GET /healthz") {
      return jsonResponse({ ok: true });
    }

    // Token issuance — the only unauthenticated POST.
    if (routeId === "POST /v1/auth/token") {
      let payload: { deviceId?: string; attestation?: string };
      try {
        payload = await request.json();
      } catch {
        return jsonResponse({ error: "invalid_json" }, 400);
      }
      const deviceId = (payload.deviceId ?? "").trim();
      if (deviceId.length < 8 || deviceId.length > 200) {
        return jsonResponse({ error: "invalid_device_id" }, 400);
      }
      if (!verifyAttestation(env, payload.attestation)) {
        return jsonResponse({ error: "attestation_required" }, 401);
      }
      // Rate-limit minting so a token can't be farmed to bypass per-device caps.
      if (!(await allowDevice(env, `mint:${deviceId}`))) {
        return jsonResponse({ error: "rate_limited" }, 429);
      }
      const { token, expiresAt } = await issueToken(env, deviceId);
      return jsonResponse({ token, expiresAt });
    }

    // Everything below requires a valid device token.
    const route = ROUTES[routeId];
    if (!route) {
      return jsonResponse({ error: "not_found" }, 404);
    }

    const auth = await verifyRequest(env, request);
    if (!auth.ok || !auth.deviceId) {
      return jsonResponse({ error: "unauthorized", reason: auth.reason }, 401);
    }

    if (!(await allowDevice(env, auth.deviceId))) {
      return jsonResponse({ error: "rate_limited" }, 429);
    }

    // Build the route context (parse body once for POST routes).
    const ctx: RouteContext = { env, url };
    if (route.method === "POST") {
      ctx.rawBody = await request.text();
      try {
        ctx.body = ctx.rawBody.length ? JSON.parse(ctx.rawBody) : undefined;
      } catch {
        return jsonResponse({ error: "invalid_json" }, 400);
      }
    }

    // Cache lookup (free path).
    const input = route.cacheInput(ctx);
    const key = input != null ? await cacheKey(routeId, input) : null;
    if (key) {
      const hit = await readCache(env, key);
      if (hit) {
        return new Response(hit.body, {
          status: hit.status,
          headers: { "Content-Type": hit.contentType, "X-PetScans-Cache": "hit" },
        });
      }
    }

    // Miss → respect the spend kill-switch before paying an upstream.
    if (await spendBlocked(env)) {
      return jsonResponse({ error: "service_unavailable", reason: "spend_limit" }, 503);
    }

    let result;
    try {
      result = await forward(route, ctx);
    } catch {
      return jsonResponse({ error: "upstream_error" }, 502);
    }

    if (result.status >= 200 && result.status < 300) {
      await recordSpend(env, route.estCents);
      if (key) await writeCache(env, key, result, route.cacheTtlSeconds);
    }

    return new Response(result.body, {
      status: result.status,
      headers: { "Content-Type": result.contentType, "X-PetScans-Cache": key ? "miss" : "bypass" },
    });
  },
};
