# Superwall Placements & User Attributes

Reference for every Superwall **placement** (event the app registers) and **user
attribute** (targeting value the app sets) in PetScans. Use it when writing
campaign audiences / paywall copy in the dashboard.

- **Placement** = a named event fired via `SuperwallSafe.register(...)`. Attach it
  to a campaign in the dashboard to present a paywall; unattached placements fire
  harmlessly and show nothing.
- **User attribute** = a value set via `SuperwallSafe.setUserAttributes(...)`. It
  persists for the session and is addressable in audience rules (`user.<key>`) and
  paywall copy (`{{ user.<key> }}`).
- **Placement param** = passed with a single `register` call; addressable as
  `params.<key>` in that placement's audience rules only (not persisted).

Source of truth in code:
`Services/SuperwallSafe.swift` (wrapper), `Services/SuperwallUserAttributes.swift`
(pet / groups / searched-food / focused-pet), `Views/Onboarding/OnboardingView.swift`
(onboarding placements), `ViewModels/ScannerViewModel.swift` (scan placements/attrs).

> Keep this file in sync when adding or renaming a placement/attribute.

---

## Placements

| Placement | Params | Gated? | Fired from | Current campaign |
|---|---|---|---|---|
| `onboarding_step` | `step` (Int, page index) | No | Every onboarding page change (`logStep`) | — (diagnostic only; keep OUT of campaigns) |
| `onboarding_finished` | `created_pet` (Bool), `avoid_group_count` (Int) | No | `persistAndSync` — both onboarding exit paths | — |
| `onboarding_complete` | none | **Yes** (feature block → enters app) | Skip / early-exit and the AHA-skip fallback | ✅ **Onboarding** (64348) |
| `aha_food_result` | `verdict` (String), `score` (Int 0–100), `flag_count` (Int) | **Yes** | Onboarding AHA result CTA (peak intent) | ❌ **not attached** — CTA shows no paywall until wired |
| `analysis_complete` | none | No (register w/o feature block) | After a scan analysis resolves (`ScannerViewModel`) | ✅ **In-App** (65702) |
| `session_start` | — (Superwall built-in) | — | Automatic (SDK) | ✅ **Testing** (97284) |

**Gated vs not:** gated placements register with a `feature { }` block, so the app
proceeds even if the SDK/paywall can't load — they never strand the user. Non-gated
placements are pure signals; attaching a paywall to one still works but there's no
completion callback.

**Onboarding exit logic** (`OnboardingView`): a user hits exactly one gating path —
- taps the AHA result CTA → `aha_food_result`
- skips the AHA search, or skips pet setup entirely → `onboarding_complete`

Because the two paths are mutually exclusive, both campaigns can be active at once
without a user seeing two paywalls back-to-back.

---

## User Attributes

### Pet — `SuperwallUserAttributes.syncPets` / `setFocusedPet`
Set at onboarding finish and refreshed on every scan (pointed at the scanned pet).

| Key | Type | Notes |
|---|---|---|
| `pet_name` | String | Primary/focused pet. Never empty — falls back to `"your pet"`. |
| `pet_names` | String | All pets, comma-joined. |
| `pet_count` | Int | Number of pets on the roster. |
| `pet_species` | String | `Species` rawValue (e.g. `dog`, `cat`). |

### Avoidance groups — `SuperwallUserAttributes.setAvoidanceGroups`
Set at onboarding finish. Sent three ways (string for copy, count for engagement,
booleans for easy targeting). Every boolean is always set — an absent attribute and
an explicit `false` mean different things in targeting.

| Key | Type | Notes |
|---|---|---|
| `avoid_groups` | String | Comma-joined rawValues, stable enum order. `""` if none. |
| `avoid_group_count` | Int | How many groups were selected. |
| `avoids_ultra_processed` | Bool | per-group boolean |
| `avoids_artificial_colours` | Bool | |
| `avoids_artificial_preservatives` | Bool | |
| `avoids_common_allergens` | Bool | |
| `avoids_added_sugars` | Bool | |
| `avoids_meat_byproducts` | Bool | |
| `avoids_grain_fillers` | Bool | |
| `avoids_gums_thickeners` | Bool | |

Boolean key = `avoids_<rawValue in snake_case>`. `avoid_groups` rawValues (camelCase):
`ultraProcessed, artificialColours, artificialPreservatives, commonAllergens, addedSugars, meatByproducts, grainFillers, gumsThickeners`.

### Searched food (onboarding AHA) — `SuperwallUserAttributes.setSearchedFood`
Set the instant the AHA food is scored, so it's available on `aha_food_result` **and**
persists to any later placement (e.g. `onboarding_complete`). Absence ⇒ user skipped
the search.

| Key | Type | Notes |
|---|---|---|
| `searched_food` | Bool | `true` once a food was scored. |
| `searched_food_name` | String | Product name. |
| `searched_food_brand` | String | `""` if unknown. |
| `searched_food_score` | Int | Rounded 0–100. |
| `searched_food_verdict` | String | `RatingLabel` raw (see below). |
| `searched_food_flag_count` | Int | Allergen + watch-list hits. |

### Onboarding — `OnboardingView.persistAndSync`
| Key | Type | Notes |
|---|---|---|
| `onboarding_completed_at` | Date | Set once on finish. |

### Scan activity — `ScannerViewModel`
| Key | Type | Notes |
|---|---|---|
| `analysis_count` | Int | Cumulative analyses run (`totalAnalysisCount`). Set before `analysis_complete`. |
| `scan_count` | Int | Cumulative scans saved to History (`totalScanCount`). |
| `last_scan_source` | String | `catalog` \| `cache` \| `ocr` \| `web` \| `miss`. |
| `last_scan_elapsed_ms` | Int | Resolve latency of the last scan. |

---

## Enum value reference

**`RatingLabel`** (used by `verdict` param and `searched_food_verdict`) — raw values:
`Excellent`, `Good`, `Caution`, `Avoid`.

Score → label mapping: `75–100 → Excellent`, `50–74 → Good`, `25–49 → Caution`,
`<25 → Avoid`. A toxic ingredient or an allergen match can override the score and
force `Avoid` regardless of the number.

---

## Targeting examples

- **Harder paywall when the AHA scared them** — on `aha_food_result`, audience
  `params.flag_count > 0` or `params.verdict == "Avoid"`.
- **Peace-of-mind paywall on a clean result** — `params.flag_count == 0`.
- **Branch a later placement on the AHA outcome** — `onboarding_complete` (or any
  post-onboarding placement) can read the persisted `user.searched_food_verdict`.
- **Segment by engagement** — `user.avoid_group_count > 0`, or specific concerns via
  `user.avoids_artificial_colours == true`.
- **Returning / power users** — `user.scan_count >= N` or `user.analysis_count >= N`.

## Paywall copy examples

- `We found {{ user.searched_food_flag_count }} things in {{ user.searched_food_name }} {{ user.pet_name }} should avoid.`
- `Keep {{ user.pet_name }} safe — scan every food before you buy.`
