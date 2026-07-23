# Troubleshooting

Graph API errors are unhelpful by design: `code` is almost always `100`, and the real meaning is in **`error_subcode`**. The CLI already maps the subcodes below to a fix and prints it as a `→ hint` line — this file is the longer version. (Kept in sync with the hint table in `scripts/meta/errors.ts`.)

**First move, always:** `npm run meta -- doctor`. It checks every prerequisite below that a human has to satisfy.

## Setup / permissions

> **Subcodes are overloaded.** Meta reuses `1885183` for at least two unrelated errors. Always read the `message`, not just the subcode — the CLI matches on the message first for this reason.

| Subcode | Means | Fix |
|---|---|---|
| **1885183** + *"app that is in development mode"* | The Meta app is in **Development Mode** | Toggle App Mode → **Live** at the top of the App Dashboard (may require a Privacy Policy URL first). **Campaigns and ad sets are accepted regardless — only the CREATIVE fails**, so this ambushes you late. |
| **1885093** | "The application doesn't match the provided object store url" | The Meta app has **no iOS platform**. App Dashboard → Settings → Basic → Add Platform → iOS → Bundle ID `com.picklego.picklego`, iPhone Store ID `6743630735`. **The campaign is accepted without this and only the AD SET fails.** |
| **1885183** + *"terms of service"* | Custom Audience TOS not accepted | Business Settings → Ad Accounts → Custom Audience Terms. Blocks audiences only; campaigns unaffected. |
| **1815589** | "Link title and link description are deprecated" | `call_to_action.value` may not carry `link_title`. The title belongs in `link_data.name` / `video_data.title`. The CLI handles this; you'd only hit it via `graph --method POST`. |
| **2446685 / 2490247** | Ad account not authorised to advertise this app | App Dashboard → Settings → Advanced → Advertising Accounts. May need approval. |
| **3285010** | App ownership not verified | Verify the app in Business Settings. |
| **2446686 / 2446697** | Another ad account already promotes this app | SKAdNetwork allows **one ad account per app**. Use that one. |
| code **190** | Token expired/invalid | Regenerate the System User token; update `META_ACCESS_TOKEN`. **Do not retry.** |
| code **200** | Token lacks permission | Needs `ads_management` (not just `ads_read`). Also: the System User must be *assigned to the ad account itself* in Business Settings → Assign Assets — having the scope on the token is not enough. This is a very common trap. |

## SKAdNetwork

| Subcode | Means | Fix |
|---|---|---|
| **2446692** | 9-campaign limit hit | An app gets 9 SKAN campaigns **total, across every ad account**. Delete or archive one. `doctor` counts them. |
| **2490238** | >5 ad sets in a campaign | Make a new campaign. |
| **2490208 / 3285009** | Ad sets disagree on optimization goal | Every ad set in a SKAN campaign must share one goal. |
| **2490249** | `user_os` doesn't specify iOS 14+ | The CLI sets `iOS_ver_14.0_and_above` automatically — you only see this if you overrode `targeting.raw`. |
| **2490217** | `billing_event` and `optimization_goal` both `APP_INSTALLS` | CPA billing is blocked. Use `IMPRESSIONS`. |
| **2490216** | `TARGET_COST` bid strategy | Not available on SKAN. Use `LOWEST_COST_WITHOUT_CAP`. |
| **2490256** | `LINK_CLICKS` optimization | Not supported on iOS 14+. |
| **2446698** | Editing `promoted_object` / SKAN flag on a live campaign | **Immutable.** No edit path — delete and recreate, which burns a SKAN slot. Do not retry the update. |
| **1870125** | App-activity audience used for inclusion | Not allowed on SKAN. Seed a lookalike instead. See `audiences.md`. |
| **3285008** | Deferred deep link in the creative | Unavailable on SKAN. Drop `app_link`. |

## Creative

| Symptom | Cause |
|---|---|
| "Missing page_id" / creative create fails | `META_PAGE_ID` not set, or the System User cannot publish as that Page. Find pages: `npm run meta -- graph me/accounts` |
| Video creative fails intermittently | The video was still transcoding. Always `video upload --wait`; `launch` does this automatically. |
| Video creative rejected for no thumbnail | `video_data` needs a thumbnail. Pass `--thumbnail <path>` / `thumbnailPath` in the spec. |

## Budgets

| Symptom | Cause |
|---|---|
| "Budget below minimum" | Each account has a currency-dependent floor. This one: **CAD 1.43/day**. `doctor` prints it. |
| Guardrail: "exceeds the ceiling" | Working as intended. Do **not** raise `--max-daily-budget` unless the human said a number. |
| Budget looks 100× off | Money is **integer minor units**. `3000` = $30.00. `30` = 30 cents. |
| Meta spent more than the daily budget | Normal — Meta may exceed a daily budget by up to **25%** on a given day, balancing across the week. |

## Exit codes

| | |
|---|---|
| `0` | ok |
| `1` | Graph API error — read `error.subcode` and `error.hint` |
| `2` | validation / usage error (caught before the network) |
| `3` | **guardrail refused it.** Nothing was sent. Do not route around it. |
| `4` | **unknown state** — a write may or may not have landed. **Never blindly retry.** Re-run `launch --resume`, which reconciles by name. |

## Rate limits

The CLI parses `X-Business-Use-Case-Usage` and warns at 90% of quota. Values are percentages; `estimated_time_to_regain_access` is in minutes. GETs retry automatically with backoff. Writes retry **only** on explicit rate-limit codes, never on a timeout — a timed-out POST may have created something whose id was never returned.
