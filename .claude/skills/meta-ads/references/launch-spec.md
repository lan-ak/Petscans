# The launch spec

One JSON file describing a whole campaign tree. `launch` walks it: campaign → ad set → upload media → creative → ad. Everything lands PAUSED.

Get a valid starting point with `npm run meta -- spec example`.

## Schema

```jsonc
{
  // Required. The idempotency key. Re-running with the same runKey RESUMES; it never
  // duplicates. Becomes a filename in functions/.meta-runs/.
  "runKey": "us-installs-2026-07",

  "campaign": {
    "name": "PickleGo | iOS Installs | US | Jul 2026",   // required
    // Budget HERE (not on the ad sets) is Advantage+ / campaign budget optimization.
    // Meta shifts spend between ad sets for you. Recommended for small budgets.
    "dailyBudgetCents": 3000,                            // integer cents. 3000 = $30.00
    "bidStrategy": "LOWEST_COST_WITHOUT_CAP",
    "specialAdCategories": [],                           // default. Housing/credit/etc if applicable
    "objective": "OUTCOME_APP_PROMOTION",                // default; you can omit it
    "skadnetwork": true                                  // default. Only turn off for Android/web
  },

  "adsets": [{                                           // max 5 (SKAdNetwork limit)
    "name": "Broad | US | 25-55",                        // required
    "dailyBudgetCents": 3000,       // ONLY if the campaign has no budget. Never both.
    "optimizationGoal": "APP_INSTALLS",                  // default
    "billingEvent": "IMPRESSIONS",                       // default. Never APP_INSTALLS.
    "bidStrategy": "LOWEST_COST_WITHOUT_CAP",
    "bidAmountCents": 400,          // ONLY with a capped strategy (COST_CAP etc)
    "customEventType": "PURCHASE",  // required when optimizationGoal is OFFSITE_CONVERSIONS
    "startTime": "2026-07-20T09:00:00-04:00",            // optional ISO 8601
    "endTime": null,

    "targeting": {
      "countries": ["US"],                               // default ["US"]
      "ageMin": 25,
      "ageMax": 55,
      "genders": "all",
      "interestIds": ["6003..."],   // from `interests search` — NEVER invent one
      "excludeAudienceIds": [],     // allowed under SKAN
      "includeAudienceIds": [],     // REJECTED under SKAN (subcode 1870125)
      "publisherPlatforms": [],     // OMIT for Advantage+ placements. Naming any opts OUT.
      "advantageAudience": true,    // default
      "raw": {}                     // escape hatch, deep-merged last
    },

    "ads": [{                                            // at least one
      "name": "Ad | Static | Rally",                     // required
      "creative": {
        "primaryText": "Find a pickleball game tonight.", // required — the body copy
        "headline": "Play more pickleball",               // required
        "description": "Free to join",
        "cta": "INSTALL_MOBILE_APP",                      // default
        "media": { "type": "image", "path": "./creative/rally.png" }
      }
    }]
  }]
}
```

**There is no `status` field, anywhere.** You cannot express "launch this live". Everything is created PAUSED and the human activates it. A spec containing `status` is rejected.

## Media

Paths resolve **relative to the spec file**, not the shell's working directory.

```jsonc
{ "type": "image", "path": "./creative/rally.png" }        // uploads it
{ "type": "image", "hash": "abc123..." }                   // already uploaded
{ "type": "video", "path": "./creative/rally.mp4",
                   "thumbnailPath": "./creative/thumb.png" } // thumbnail strongly recommended
{ "type": "video", "id": "1234567890" }                    // already uploaded
```

Uploads are recorded in the run ledger, so a `--resume` does not re-upload and re-transcode a video.

## Advantage+ (recommended for a small budget)

You do not declare it — it is **derived**. You get it only when all three are true at once:

1. budget is on the **campaign**, not the ad sets
2. `targeting.advantageAudience` is `true` (the default)
3. `targeting.publisherPlatforms` is **omitted** — naming any placement opts you out

`launch` reads `advantage_state_info` back afterwards and warns if the campaign did **not** qualify, because the fallback to a manual campaign is silent.

Why bother: SKAdNetwork caps you at 5 ad sets that must share one optimization goal anyway, so manual segmentation buys little while fragmenting the learning phase — and a small budget cannot feed several ad sets past learning.

## Worked example: broad install test

```json
{
  "runKey": "ca-installs-2026-07",
  "campaign": {
    "name": "PickleGo | iOS Installs | CA | Jul 2026",
    "dailyBudgetCents": 2000,
    "bidStrategy": "LOWEST_COST_WITHOUT_CAP"
  },
  "adsets": [{
    "name": "Broad | CA | 25-55",
    "optimizationGoal": "APP_INSTALLS",
    "billingEvent": "IMPRESSIONS",
    "targeting": { "countries": ["CA"], "ageMin": 25, "ageMax": 55, "advantageAudience": true },
    "ads": [
      {
        "name": "Ad | Static | Rally",
        "creative": {
          "primaryText": "Find a pickleball game near you tonight. Free to join.",
          "headline": "Play more pickleball",
          "media": { "type": "image", "path": "./creative/rally.png" }
        }
      },
      {
        "name": "Ad | Static | Stats",
        "creative": {
          "primaryText": "Track every match. See who you actually beat.",
          "headline": "Know your game",
          "media": { "type": "image", "path": "./creative/stats.png" }
        }
      }
    ]
  }]
}
```

Two ads in one ad set is the right shape for a creative test: Meta rotates them against the same audience and budget, so the comparison is clean.

## Optimizing for purchases instead of installs

Only worth doing once you have enough purchase volume for Meta to learn from (~50/week). Below that, optimize for installs.

```jsonc
"optimizationGoal": "OFFSITE_CONVERSIONS",
"customEventType": "PURCHASE"
```

Under SKAdNetwork every ad set in the campaign must share this goal — you cannot mix an install ad set and a purchase ad set in one campaign.
