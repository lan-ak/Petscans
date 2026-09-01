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
| `onboarding_step` | `step` (Int, page index), `step_name` (String) | No | Every onboarding page change (`logStep`) | — (diagnostic only; keep OUT of campaigns) |
| `onboarding_finished` | `created_pet` (Bool), `avoid_group_count` (Int) | No | `persistAndSync` — both onboarding exit paths | — |
| `onboarding_complete` | `viewed_food_result` (Bool), `personalized` (Bool), `verdict` (String), `score` (Int), `flag_count` (Int) | **Yes** (feature block → enters app) | Every onboarding exit — the personalised result CTA and the pet-setup "Not now" | ✅ **Onboarding** (64348) |
| `analysis_complete` | none | No (register w/o feature block) | After a scan analysis resolves (`ScannerViewModel`) | ✅ **In-App** (65702) |
| `session_start` | — (Superwall built-in) | — | Automatic (SDK) | ✅ **Testing** (97284) |

**Gated vs not:** gated placements register with a `feature { }` block, so the app
proceeds even if the SDK/paywall can't load — they never strand the user. Non-gated
placements are pure signals; attaching a paywall to one still works but there's no
completion callback.

**Onboarding flow** (`OnboardingView`) — reordered to demo-first. `step_name` is the stable
key; the `step` index changed meaning at this release, so anything keyed on the number
silently changes at the cutover:

| `step` | `step_name` | screen |
|---|---|---|
| 0 | `promise` | welcome |
| 1 | `search` | catalog search (the demo) |
| 2 | `demo_result` | the food scored with no pet yet |
| 3 | `pet_setup` | name, species, allergens |
| 4 | `watch_list` | avoidance groups |
| 5 | `personalized_result` | same food re-scored against the profile |

**Exit logic:** **every** exit routes through `onboarding_complete` — the personalised result CTA,
and the pet-setup "Not now" for users who stop before building a profile. There is no
longer an `aha_food_result` placement in code (removed in 1.4.4): gating the payoff CTA on
its own placement meant the paywall could only reach users whose downloaded config already
carried that name, silently excluding everyone else. Which paywall a user sees is an
audience decision on the persisted `user.searched_food*` attributes.

`viewed_food_result` is true when the user saw the demo verdict; `personalized` is true when
they also reached the personalised result screen, where `verdict`/`score`/`flag_count` are the **re-scored**
values. A user who took "Not now" reports the demo's general verdict instead.

> ⚠️ The `aha_food_result` **placement 127396 is still enabled on campaign 64348** in the
> dashboard. It is dead — nothing fires it — and should be disabled.

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
Written **twice**: once when the demo scores the food with no pet, then again on the personalised
result screen with the re-score. Audiences therefore read the verdict the user was
actually left looking at, while a user who drops out mid-flow still carries the general one.
Absence ⇒ user skipped the search.

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

- **Harder paywall when the AHA scared them** — on `onboarding_complete`, audience
  `params.flag_count > 0` or `params.verdict == "Avoid"`.
- **Peace-of-mind paywall on a clean result** — `params.flag_count == 0`.
- **Branch a later placement on the AHA outcome** — `onboarding_complete` (or any
  post-onboarding placement) can read the persisted `user.searched_food_verdict`.
- **Segment by engagement** — `user.avoid_group_count > 0`, or specific concerns via
  `user.avoids_artificial_colours == true`.

> ⚠️ **Do not write audiences against `searched_food_score`.** Measured over the full
> catalog, 99.72% of products score ≥ 75 (p50 = 95.3), so `score < 60` addresses ~0.7% of
> possible foods. Use `verdict`/`flag_count`, which still discriminate via the allergen and
> toxic overrides.
- **Returning / power users** — `user.scan_count >= N` or `user.analysis_count >= N`.

## Paywall copy examples

- `We found {{ user.searched_food_flag_count }} things in {{ user.searched_food_name }} {{ user.pet_name }} should avoid.`
- `Keep {{ user.pet_name }} safe — scan every food before you buy.`
