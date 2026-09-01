# PetScans — App Store Optimization Plan

> Research date: July 30, 2026. Sources: Appfigures (store listings, download/revenue estimates), live App Store pages, web research. Competitor revenue/download figures are Appfigures **estimates**, not reported numbers.
>
> App: PetScans (Apple ID `6757314496`, Appfigures product `338457749246`), released Jan 21 2026, developer Akinyemi & Co Ltd.

---

## 1. Where PetScans stands today

| Field | Current state | Problem |
|---|---|---|
| **Title** | `PetScans` (8 chars) | Wastes 22 of 30 characters in the single heaviest-weighted keyword field. Only the brand term is indexed at title weight. |
| **Subtitle** | `Dog & Cat Food Safety Scanner` (29 chars) | Good — recently improved from "Food Safety Scanner for Pets". Keep the keyword density, but see §3 for de-duplication once the title changes. |
| **Primary category** | Lifestyle (secondary: Health & Fitness) | Lifestyle is enormous, low-intent, and not where scanner apps live. Yuka & Cal AI: Health & Fitness. Hapu (direct competitor): Health & Fitness + Medical. |
| **Countries** | **5** (US, CA, GB, AU, NZ) | Cal AI, PictureThis, Rock Identifier: 172+ countries. Availability is free reach — even English-only apps ship worldwide. |
| **Languages** | English only | PictureThis: 26 store languages. Rock Identifier: 14. Store-listing-only localization is cheap and indexes local keywords. |
| **Ratings** | 1 rating (5.0) | Rating count is a top conversion + ranking signal. No in-app prompt strategy visible. |
| **Screenshots** | 6, no app preview video | Winners run 8–15 (PictureThis 10, Fig 15) plus video. |
| **IAP hygiene** | Public IAP list shows `monthly_3.99`, plus duplicate/overlapping SKUs (Annual $39.99 *and* $59.99; Monthly $4.99 *and* $9.99) | Raw SKU names render on the public listing — looks broken and untrustworthy. IAP display names are also indexed for search. |
| **Description** | Strong opening ("20,000+ dog and cat foods, scored instantly") | Good. iOS description isn't keyword-indexed; it's a conversion asset. Minor improvements in §7. |

**Traction context (Appfigures estimates, Feb–Jul 2026):** Pawdi iOS ~640 downloads / ~$590 net revenue; Hapu ~negligible. PetScans doesn't yet register in the estimate model. **Nobody has won this vertical yet** — and demand is proven: Yuka (est. ~1M downloads and ~$1M net revenue *per month*) has public reviews explicitly saying *"I do wish that an app like this existed for pets"*, and TikTok search is full of "app like Yuka for dog food" content. This is a land-grab window.

---

## 2. What the winners do (pattern library)

### Direct vertical (small, beatable)
| App | Title | Subtitle | Categories | Countries |
|---|---|---|---|---|
| Pawdi | `Pawdi - Pet Food Scanner` | `Pet Nutrition & Pet Care` | Reference, Lifestyle | 175 |
| Hapu | `Hapu: Cat & Dog Food Scanner` | `Healthy Dog & Cat Food Check` | Health & Fitness, Medical | 8 |
| Open Pet Food Facts | keyword-rich, free, no monetization | — | — | wide |

Both direct competitors put the category keyword ("Pet Food Scanner" / "Cat & Dog Food Scanner") **in the title**. PetScans is the only one that doesn't.

### Cross-vertical ASO winners (the playbook to copy)
| App | Title | Subtitle | Lesson |
|---|---|---|---|
| Yuka (~1M dl/mo est.) | `Yuka - Food & Cosmetic Scanner` | `Check What's in Your Products` | Brand + category keywords in title; benefit-led subtitle; social proof as the first description line ("85 MILLION USERS"). |
| Cal AI (~590K dl / ~$3M/mo est.) | `Cal AI - Calorie Tracker` | `Food & Macro Counter` | Title = brand + highest-volume keyword. Subtitle = **zero-overlap** second keyword set. 172 countries. |
| PictureThis (~2M dl / ~$18M/mo est.) | `PictureThis - Plant Identifier` | `Plant care and identification` | Owns the category keyword in title; 26 languages; 10 screenshots. |
| Rock Identifier (~280K dl / ~$640K/mo est.) | `Rock Identifier: Stone ID` | `Gem Mineral Crystal Identifier` | Subtitle is pure keyword stacking with **no words repeated from title** — maximizes indexed terms. |
| Spoonful (human allergy scanner) | `Spoonful: Diet & Food Scanner` | `FODMAP, Gluten, Vegan & More!` | Subtitle stacks *condition* keywords — the analog for PetScans is allergy/sensitivity terms. |
| Fig (human allergy scanner, ~55K dl/mo est.) | `Fig: Food Scanner & Guide` | — | 15 screenshots; social proof first line ("1M+ satisfied members"); the closest human analog to PetScans' pet-profile/allergen model. |

**The universal formula:** `Brand: Category Keyword` title + non-overlapping keyword subtitle + max country availability + localized listings + heavy screenshot count + social proof line 1.

---

## 3. Metadata changes (highest impact, do first)

Apple indexes each word once across title + subtitle + keyword field. Never repeat a word across the three fields; use every character.

### Title (30 chars max)
```
PetScans: Pet Food Scanner
```
(26 chars. Alternative if you want species terms at max weight: `PetScans: Dog & Cat Food Scan` — 29 chars — but "pet food scanner" is the cleaner exact-match phrase and "dog/cat" then move to subtitle.)

### Subtitle (30 chars max) — no words repeated from title
```
Dog & Cat Ingredient Checker
```
(28 chars. Indexes: dog, cat, ingredient, checker. Alternative: `Dog & Cat Allergy & Safety` if allergy terms test better.)

### Keyword field (100 chars, comma-separated, no spaces, no words already in title/subtitle)
```
allergy,allergen,safe,safety,kibble,treats,nutrition,barcode,label,puppy,kitten,toxic,recall,vet
```
(98 chars. Do **not** include "Yuka" — trademark in metadata risks rejection; capture that demand with Apple Search Ads instead, §8.)

### Category
- **Primary: Health & Fitness** (where Yuka, Cal AI, Hapu, Spoonful, Fig all live — matches user intent "is this healthy/safe")
- **Secondary: Medical** (Hapu's pairing; reinforces the science-based positioning)
- Drop Lifestyle.

### Rationale on search terms (priority order)
1. `pet food scanner` — exact category term, both direct competitors title-target it
2. `dog food scanner` / `cat food scanner` — species variants (title+subtitle combo covers these)
3. `dog food ingredient checker` / `pet food ingredients` — covered by subtitle + keyword field
4. `dog food allergy` / `pet allergy` — keyword field; highest-intent long tail (your one review is literally a chicken-allergy story)
5. `pet food safety`, `is this safe for dogs` class queries — safety/safe/toxic in keyword field

---

## 4. Availability & localization

1. **Expand from 5 to all ~175 territories immediately.** Zero cost, pure incremental installs. English metadata is fine everywhere as a start (Cal AI shipped 172 countries with 7 languages; Pawdi ships 175 with 1).
2. **Phase 2 — localize the store listing only** (title/subtitle/keywords/screenshot captions) into: French, German, Spanish (ES + MX), Portuguese (BR), Italian, Japanese, Korean, Simplified Chinese, Dutch. Pet-food-safety anxiety is global; PictureThis' 26-language footprint is a large share of its 2M monthly downloads.
3. Note: French (Canada) is already exposed on your CA URL — make sure fr-CA metadata isn't just falling back to English.

---

## 5. Ratings engine (currently 1 rating — this is the #1 conversion blocker)

1. Trigger `SKStoreReviewController.requestReview()` at the **peak-positive moment**: immediately after a scan returns a **"safe / good score"** result for the user's own pet (not after a scary red result), and only after ≥2 successful scans + ≥1 pet profile created.
2. Cap: never on first session, respect Apple's 3-prompts/year limit, suppress after a crash or a failed photo-analysis.
3. Add a soft in-app "Enjoying PetScans?" pre-prompt gate so the native dialog only fires for likely-5-star users.
4. Target: 50+ ratings in 60 days. Below ~20 ratings the listing converts poorly regardless of metadata.

---

## 6. Visual assets

Current: 6 screenshots (`HeroScore → UnsafeIngredients → AllergenAlert → IngredientDetail → Library → Sources`), no video.

1. **Add an App Preview video** (15–20s): hand scans a recognizable-style kibble bag → score appears instantly → red allergen flag for "Max's chicken allergy". Yuka's scan-motion preview is the model. Video autoplays in search results — it's effectively an extra ranking-free CTR weapon.
2. **Go from 6 → 10 screenshots** (PictureThis standard). Additions: pet profile setup, photo-label analysis (the "not in database? snap the label" moment), before/after food swap ("We found a better food for Bella"), social proof card once you have ratings.
3. **First 3 screenshots carry ~80% of conversion.** Recommended order + captions:
   - 1: Scan-to-score moment — *"Scan any pet food. Know in seconds."*
   - 2: Allergen alert personalized to a named pet — *"Flags what YOUR dog can't eat"*
   - 3: 20,000+ database — *"20,000+ dog & cat foods, scored"*
4. Caption style: large, 3–6 words, benefit-first (all six winners do this; avoid feature-labels like "Ingredient Detail").
5. Test dog-led vs cat-led hero imagery via **Product Page Optimization** (native A/B, free) — dog owners are the larger segment but cat-specific pages may convert cat searches better (see CPPs, §8).

---

## 7. Listing copy & IAP hygiene

1. **Fix IAP display names now.** The public listing currently shows `monthly_3.99` (a raw SKU) and four overlapping products (Annual $39.99 + $59.99, Monthly $4.99 + $9.99). This reads as broken/scammy on the page and IAP names are search-indexed. Rename to `PetScans Pro (Annual)` / `PetScans Pro (Monthly)` and hide legacy SKUs from the listing.
2. **Description line 1** is already strong ("20,000+ dog and cat foods, scored instantly"). Once ratings accumulate, prepend social proof the way Yuka/Fig do: `Trusted by X,000 pet parents.`
3. Add a "PERFECT FOR" block (Hapu does this well): pets with allergies/sensitive stomachs, multi-pet households, raw/grain-free feeders, worried label-readers. This is conversion copy, not keywords — iOS doesn't index descriptions.
4. Keep the AAFCO/FDA/ASPCA trusted-sources block — it's a genuine differentiator vs. Pawdi/Hapu.

---

## 8. Paid + platform amplifiers (ASO force-multipliers)

1. **Apple Search Ads discovery campaign** ($10–20/day) on: `pet food scanner`, `dog food scanner`, `yuka`, `yuka for pets`, `dog food checker`, `pawdi`, `hapu`, `cat food app`. Two purposes: (a) capture the proven "Yuka for pets" demand you can't put in metadata, (b) harvest the actual search-term report to refine the keyword field in §3. ASA impression share also correlates with organic rank lift.
2. **Custom Product Pages (CPPs):** one dog-focused page (dog hero imagery + dog captions) and one cat-focused page; route ASA keyword groups to the matching CPP.
3. **In-App Events:** run recurring events tied to news moments ("New recall alerts added", "5,000 new foods scored") — events surface in search and on the Today tab for free.
4. **What's New copy:** current release notes are good (benefit-led). Ship an update at least every 3–4 weeks; update recency is a ranking input and re-triggers featured-consideration.

---

## 9. Prioritized checklist

| # | Action | Effort | Impact |
|---|---|---|---|
| 1 | Title → `PetScans: Pet Food Scanner` | 5 min | 🔥🔥🔥 |
| 2 | Subtitle → `Dog & Cat Ingredient Checker` + keyword field from §3 | 5 min | 🔥🔥🔥 |
| 3 | Fix IAP display names (`monthly_3.99` → proper names) | 30 min | 🔥🔥🔥 |
| 4 | Primary category → Health & Fitness (secondary Medical) | 5 min | 🔥🔥 |
| 5 | Expand availability 5 → all territories | 15 min | 🔥🔥 |
| 6 | Ship in-app rating prompt (post-safe-scan trigger) | 1 day | 🔥🔥🔥 |
| 7 | App Preview video + 4 new screenshots + caption rewrite | 2–3 days | 🔥🔥 |
| 8 | ASA discovery campaign incl. "yuka for pets" terms | 2 hrs | 🔥🔥 |
| 9 | Dog/cat Custom Product Pages + PPO A/B test | 1–2 days | 🔥 |
| 10 | Localize store listing (top 9 languages) | 1 week | 🔥🔥 (compounding) |
| 11 | Social-proof description line once ratings > 1K | later | 🔥 |

---

## 10. Measurement

- Track keyword ranks weekly for: `pet food scanner`, `dog food scanner`, `cat food scanner`, `dog food checker`, `pet food app`, `dog allergy food`.
- App Store Connect: watch **search impressions → product page views → installs** funnel; metadata changes move impressions, screenshot/video/ratings changes move page-view→install conversion.
- Benchmark cadence: re-pull Pawdi + Hapu estimates monthly (Appfigures) — if either starts scaling, inspect what they changed.
- Success gates (90 days): top-5 for `pet food scanner` in US/CA/GB/AU; 100+ ratings ≥4.7; page-view→install conversion >35%.
