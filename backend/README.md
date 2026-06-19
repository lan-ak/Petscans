# PetScans API Proxy (Cloudflare Workers)

A small Cloudflare Worker that sits between the iOS app and the paid third-party
providers (OpenAI Vision, Firecrawl, Serper, UPCitemdb, Unwrangle). It exists to
fix the launch-blocking risk that **API keys were compiled into the iOS binary**
and every scan called providers directly with no cost control.

## What it does

- **Keeps keys server-side.** The real provider keys live as Worker secrets and
  are injected per request. The client never sees them.
- **Anonymous device tokens.** The app mints a signed token once per device
  (`POST /v1/auth/token`); every proxy call must present it. No accounts needed.
- **Caching.** Idempotent lookups (barcode, scrape, search, vision) are cached in
  KV keyed by a hash of the request, so repeat scans of the same product cost
  nothing. This shared cache is also the seed of a future product database.
- **Rate limiting + kill-switch.** A per-device hourly cap plus a global daily
  spend limit and a manual `KILL_SWITCH` flag bound abuse and runaway bills.
- **Transparent proxy.** Upstream responses are returned verbatim, so the iOS
  client only changes its base URL and auth header — existing decoders are kept.

## Endpoints

| Method & path                 | Upstream                                   | Cache key |
|-------------------------------|--------------------------------------------|-----------|
| `POST /v1/auth/token`         | — (mints a device token)                   | —         |
| `GET  /healthz`               | — (health check)                           | —         |
| `POST /v1/openai/identify`    | `api.openai.com/v1/chat/completions`       | full body |
| `POST /v1/firecrawl/scrape`   | `api.firecrawl.dev/v1/scrape`              | `url`     |
| `POST /v1/serper/search`      | `google.serper.dev/search`                 | `q`       |
| `GET  /v1/upcitemdb/lookup`   | `api.upcitemdb.com/prod/v1/lookup`         | `upc`     |
| `GET  /v1/unwrangle/getter`   | `data.unwrangle.com/api/getter/`           | `url`     |

Responses carry `X-PetScans-Cache: hit | miss | bypass`.

## Local development

```bash
cd backend
npm install
cp .dev.vars.example .dev.vars   # fill in AUTH_SECRET + provider keys
npm test                         # vitest unit + router tests
npm run typecheck
npm run dev                      # wrangler dev (local)
```

## Deploy

```bash
# one-time: create KV namespaces and paste the ids into wrangler.toml
wrangler kv:namespace create CACHE
wrangler kv:namespace create RATE
wrangler kv:namespace create CACHE --preview
wrangler kv:namespace create RATE --preview

# set secrets (never commit these)
wrangler secret put AUTH_SECRET        # openssl rand -hex 32
wrangler secret put OPENAI_API_KEY
wrangler secret put FIRECRAWL_API_KEY
wrangler secret put SERPER_API_KEY
wrangler secret put UPCITEMDB_API_KEY
wrangler secret put UNWRANGLE_API_KEY

wrangler deploy
```

## Configuration knobs (wrangler.toml `[vars]`)

| Var                       | Default | Meaning                                   |
|---------------------------|---------|-------------------------------------------|
| `DEVICE_RATE_PER_HOUR`    | `60`    | Max proxy calls per device per hour       |
| `DAILY_SPEND_LIMIT_CENTS` | `2000`  | Global daily spend cap (kill-switch)      |
| `TOKEN_TTL_DAYS`          | `30`    | Device token lifetime                     |
| `KILL_SWITCH`             | `off`   | Set `on` to immediately stop upstreams    |
| `ATTEST_REQUIRED`         | `off`   | Require App Attest before minting tokens  |

## iOS client changes (next step)

Replace the five direct-API services
(`FirecrawlService`, `ProductVisionService`, `SerperService`, `UPCitemdbService`,
`UnwrangleService`) with calls to this proxy: point them at the Worker base URL,
attach `Authorization: Bearer <deviceToken>`, and delete the third-party keys
from `APIKeys.swift` (keep only the Superwall publishable key). The request and
response bodies are unchanged.

## Hardening roadmap

- Implement full **Apple App Attest** verification in `verifyAttestation`
  (auth.ts) and flip `ATTEST_REQUIRED=on`.
- Promote the cache into a queryable shared product database.
- Add per-route spend weighting if one provider dominates cost.
