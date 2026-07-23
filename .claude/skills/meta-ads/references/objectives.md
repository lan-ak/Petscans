# Objectives, goals, and the SKAdNetwork rules

## The field everyone gets wrong

| Field | Level | Value |
|---|---|---|
| `objective` | campaign | `OUTCOME_APP_PROMOTION` |
| `optimization_goal` | ad set | `APP_INSTALLS` |

**`APP_INSTALLS` is an optimization goal, not an objective.** The legacy `APP_INSTALLS` *objective* is dead. If you put it on the campaign, the spec validator rejects it by name.

## Valid combinations for an iOS app-install ad set

| optimization_goal | billing_event | Needs | Use when |
|---|---|---|---|
| `APP_INSTALLS` | `IMPRESSIONS` | — | Default. Cold start, small budget. |
| `OFFSITE_CONVERSIONS` | `IMPRESSIONS` | `customEventType` | You have ~50+ of that event/week for Meta to learn from. |
| `VALUE` | `IMPRESSIONS` | allowlist | Value optimization is gated to allowlisted accounts. Don't build on it without checking. |
| `APP_INSTALLS_AND_OFFSITE_CONVERSIONS` | `IMPRESSIONS` | `customEventType` | Rare. |

Hard rules:

- **`billing_event` must be `IMPRESSIONS`.** It can never also be `APP_INSTALLS` — CPA billing is blocked on SKAdNetwork (subcode 2490217).
- **`LINK_CLICKS` is not a valid goal** on iOS 14+ (subcode 2490256).
- `bid_amount` is **required** with `COST_CAP` / `LOWEST_COST_WITH_BID_CAP` / `LOWEST_COST_WITH_MIN_ROAS`, and must be **absent** with `LOWEST_COST_WITHOUT_CAP`.
- `TARGET_COST` is **unavailable** on SKAdNetwork (subcode 2490216).

For a small budget, use `LOWEST_COST_WITHOUT_CAP` and let Meta bid.

## SKAdNetwork constraints

Every iOS install campaign this repo creates sets `is_skadnetwork_attribution: true`. That imports a lot of rules, and they are the source of most confusing failures:

| Constraint | Subcode |
|---|---|
| **9 SKAN campaigns per app**, across every ad account. A hard wall. | 2446692 |
| **5 ad sets per campaign** | 2490238 |
| All ad sets in a campaign must share **one optimization goal** | 2490208 |
| All ad sets must promote the **same app** | 2490239 |
| **One ad account per app** — two accounts cannot both promote it | 2446686 |
| `user_os` must specify **iOS 14+** (`iOS_ver_14.0_and_above`) | 2490249 |
| `buying_type` must be `AUCTION` | 2490255 |
| **App-activity Custom Audiences cannot be used for INCLUSION targeting** | 1870125 |
| Deferred deep links unavailable (so no `app_link` in the creative CTA) | 3285008 |
| **`promoted_object` and the SKAN flag are IMMUTABLE once live** | 2446698 |

That last one is the expensive one. There is no edit path — only delete-and-recreate, and that burns one of your 9 slots. `doctor` reports how many remain.

## Prerequisites a human must satisfy

None of these can be fixed from code. `doctor` checks all of them.

Each one fails at a *different* step, which is why they are so confusing — a green campaign create tells you nothing about whether an ad set or a creative will work.

1. **The Meta app must be LIVE, not in Development Mode.** App Dashboard → App Mode toggle. *Campaigns and ad sets are accepted regardless — only the CREATIVE fails.*
2. **The Meta app needs an iOS platform** with the Bundle ID (`com.picklego.picklego`) and iPhone Store ID (`6743630735`): App Dashboard → Settings → Basic → Add Platform → iOS. *The campaign is accepted without this and only the AD SET fails (subcode 1885093).*
3. **A Facebook Page** the System User can publish as. Every creative needs `object_story_spec.page_id`; there is no default.
   *Note: the token does **not** need `pages_read_engagement` to run ads — that scope only lets you read the Page's metadata. `ads_management` plus a role on the Page (same Business) is enough to create creatives. `doctor` will warn that it cannot read the Page name; that is not a blocker.*
4. **The ad account must be authorised to advertise the app** — App Dashboard → Settings → Advanced → Advertising Accounts.
5. **Custom Audience Terms of Service** accepted, if you want audiences.

## Advantage+

Not a flag. Derived from: campaign-level budget + `advantage_audience: 1` + no placement restrictions, all at once. Read it back with:

```bash
npm run meta -- get <campaignId> --fields advantage_state_info
```

`advantage_state: ADVANTAGE_PLUS_APP` means you got it. Anything else means it silently fell back to a manual campaign. `launch` warns you when this happens.

The old `smart_promotion_type: SMART_APP_PROMOTION` API was **removed across all API versions in May 2026**. If you find it in a blog post or an old snippet, it is dead — do not use it.
