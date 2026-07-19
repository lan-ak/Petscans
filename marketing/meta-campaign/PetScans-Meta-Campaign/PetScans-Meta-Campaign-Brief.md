# PetScans — Meta Creative Test Kit

**Objective:** find the winning message for PetScans (iOS) by testing **5 diverging angles** — each isolating a
different reason a pet parent would install — plus a **5-card carousel**. Scope: **food & treats only**.

**App in one line:** scan any pet-food or treat barcode/label → instant **0–100 safety score** backed by
veterinary science (AAFCO, FDA, ASPCA Poison Control, Merck Vet Manual), with **allergen alerts**,
**toxic-ingredient flags**, and a **NOVA processing** breakdown. Master tagline: *"Every ingredient revealed."*
App Store: https://apps.apple.com/ca/app/petscans/id6757314496

**Why 5 distinct angles (not 5 variations):** the fastest way to lower cost-per-install is to find the
*message* that resonates, then iterate on the winner. Each angle below targets a different buyer motivation,
so the test reads cleanly. Keep 5–10 active variations live and refresh every 3–6 weeks to fight fatigue.

---

## Deliverables

- **5 static angles** — each rendered in **1:1 (1080×1080)**, **4:5 (1080×1350)**, **9:16 (1080×1920)**.
  Files in `output/1x1|4x5|9x16/`.
- **1 carousel** — 5 cards at **1:1**, `output/carousel/card-1…5.png`.
- Source HTML in `templates/`; regenerate anytime with `npm install && node render.mjs` (see `README.md`).
- Every pixel uses the app's real design tokens (Quicksand, brand green `#34C759`, mint `#F0F9F4`,
  traffic-light score circles, the real app icon, paw-print motif).

**Format guidance:** upload the **4:5** as the primary feed asset (most feed real estate), the **1:1** as the
universal fallback, and the **9:16** for Stories/Reels. Let Advantage+ placements use all three per ad.

---

## The 5 angles

Copy fields map to Meta: **Primary text** (~125 char sweet spot), **Headline** (~40 char), **Description**
(~30 char), **CTA button**. Two primary-text options per angle so you can A/B the hook without new art.

### 1 · Toxic Reveal — *loss aversion*
The strongest driver in pet safety: fear of unknowingly feeding something harmful.
- **Who:** dog & cat owners; broad prospecting.
- **Visual:** a scanned treat scoring **15 · Poor** with red/amber ingredient flags (BHA/BHT, artificial color, by-product).
- **Primary A:** "That 'premium' treat could be hiding synthetic preservatives, dyes and by-products. Scan it in 3 seconds and see the real score."
- **Primary B:** "Would you still buy it if you saw the ingredients? Scan any pet food or treat and get an instant safety score."
- **Headline:** Is your pet's food hiding something?
- **Description:** Scan. Score. Know.
- **CTA:** Download
- **File:** `01-toxic-reveal`

### 2 · Instant Demo — *curiosity / ease*
Shows the core mechanic — the "aha" of scan → instant score.
- **Who:** broad; strong top-of-funnel introducer.
- **Visual:** camera scan frame resolving to **85 · Excellent**, 3-step Scan → Score → Choose.
- **Primary A:** "Point your camera at any pet-food label and get an instant 0–100 safety score, backed by veterinary science. No jargon, no guessing."
- **Primary B:** "Scanning your pet's food takes 3 seconds. Understanding it takes zero effort. Get an instant, science-backed safety score."
- **Headline:** Scan any pet food in seconds
- **Description:** Free on the App Store
- **CTA:** Download
- **File:** `02-instant-demo`

### 3 · Vet-Science Authority — *credibility / trust*
Reduces perceived risk with authoritative sourcing — best for skeptics and retargeting.
- **Who:** research-minded owners; warm/retargeting audiences.
- **Visual:** trust-badge grid (AAFCO / FDA / ASPCA / Merck) + evidence tiers (Strong/Medium/Weak).
- **Primary A:** "Every PetScans rating is built on AAFCO, FDA, ASPCA Poison Control and the Merck Veterinary Manual — each rule graded by evidence strength."
- **Primary B:** "Not opinions — evidence. Pet-food safety ratings sourced from the same authorities vets rely on."
- **Headline:** Pet food safety, backed by science
- **Description:** Trusted by pet parents
- **CTA:** Learn More
- **File:** `03-vet-science`

### 4 · Allergen Personalization — *relevance*
Speaks directly to owners of pets with allergies/sensitivities — a high-intent segment.
- **Who:** interest targeting — pet allergies, grain-free, sensitive stomach, limited-ingredient diets.
- **Visual:** pet profile (Max · Golden Retriever · allergies: Chicken, Wheat) + a **HIGH** allergen alert.
- **Primary A:** "Chicken allergy? Sensitive stomach? Add your pet's profile once and PetScans flags every ingredient they should avoid — on every scan."
- **Primary B:** "Your pet's food shouldn't fight their allergies. Set their profile and get instant alerts for ingredients that conflict."
- **Headline:** Protection tailored to your pet
- **Description:** Allergen alerts built in
- **CTA:** Download
- **File:** `04-allergen`

### 5 · Ultra-Processed / What's Inside — *health-conscious / clean-label*
Bridges the human clean-eating mindset (the Yuka crossover audience) to pets.
- **Who:** health-conscious millennials/Gen-Z; clean-label, human-grade, organic interests.
- **Visual:** NOVA processing bar (green→red) + Minimally-processed vs Ultra-processed examples.
- **Primary A:** "You read your own labels — why not your pet's? See how ultra-processed their food really is with a clear NOVA breakdown."
- **Primary B:** "Whole food or industrial formulation? See exactly how processed your pet's food is, ingredient by ingredient."
- **Headline:** How processed is their food, really?
- **Description:** See what's really inside
- **CTA:** Download
- **File:** `05-ultra-processed`

---

## Carousel — "Do you know what's in your pet's bowl?"

Best-practice app-install structure: **hook → steps → CTA**. One idea per card so each swipe advances the story.
Suggested primary text: *"Most pet-food labels are impossible to decode. Here's how PetScans reveals what's
really inside — in 3 seconds. 🐾"*  Headline: *Every ingredient revealed.*  CTA: **Download**.

| Card | Message | File |
|------|---------|------|
| 1 | **Hook** — "Do you really know what's in your pet's bowl?" (app icon, paw motif) | `carousel/card-1` |
| 2 | **Step 1** — Scan any label or barcode (scan frame) | `carousel/card-2` |
| 3 | **Step 2** — Get an instant 0–100 safety score (traffic-light circles) | `carousel/card-3` |
| 4 | **Step 3** — Instant allergen & toxic-ingredient alerts (HIGH / CAUTION cards) | `carousel/card-4` |
| 5 | **CTA** — Backed by vet science. Download free. (trust badges + App Store) | `carousel/card-5` |

---

## Suggested campaign setup

- **Objective:** App promotion (installs), or App Install with a value/trial event if the Superwall paywall passes
  a purchase signal to the SDK/MMP.
- **Structure:** 1 campaign → 1–2 ad sets (broad + a "pet allergy/health" interest stack) → **6 ads**
  (5 statics + 1 carousel). Keep creative the variable; hold audience/placement constant so the test is clean.
- **Placements:** Advantage+ placements ON, supplying 4:5 + 1:1 + 9:16 per ad.
- **Budget:** even split or Advantage+ campaign budget; give each ad enough to exit learning (~50 optimization
  events/week) before judging.
- **Read the winners on:** cost per install and (if tracked) trial/subscribe rate — not CTR alone. Angle CTR
  ranking often differs from install-cost ranking.
- **Iterate:** once a message wins, spin 3–4 fresh executions of *that* angle (new hook line, reordered proof)
  and retire the laggards. Refresh the pack every 3–6 weeks.

## Measurement notes

- Angle 2 (Demo) and the Carousel usually win top-of-funnel volume; Angle 3 (Authority) and Angle 4 (Allergen)
  usually win efficiency on warm/interest audiences. Expect Angle 1 (Toxic Reveal) to have the highest CTR but
  watch its install-to-value rate.
- Because the two primary-text options per angle share the same image, you can test hooks cheaply by duplicating
  the ad and swapping only the primary text.

## Compliance guardrails (keep copy clean)

PetScans is **educational, not veterinary advice**, and Meta restricts health claims. The copy above stays
factual: "safety score", "flags ingredients to avoid", "backed by vet science". **Do not** add
disease/cure/longevity claims, "guaranteed", implied medical outcomes, or "before/after health" framing.
Avoid implying you know a user's or pet's personal health condition. Keep the ASPCA/FDA/AAFCO/Merck references
as *sourcing of rules*, not endorsements of the app.

## Assets & brand

- Real app icon: `assets/icon.png` (green shield · dog+cat face · leaf · checkmark).
- Font: Quicksand (self-hosted in `assets/fonts/`). Palette + components: `styles/creative.css`.
- Statics leave subtle room to drop in a pet/product photo later (swap a `.photo-zone` block) without a redesign.

## Sources (research grounding)

- [Meta Ads best practices 2026 — LeadsBridge](https://leadsbridge.com/blog/meta-ads-best-practices/)
- [Meta Ads for App Install Campaigns: 2026 Field Guide — adlibrary.com](https://adlibrary.com/posts/meta-ads-for-app-install-campaigns)
- [App Install Ad Creative Specs by Platform: 2026 — SEM Nexus](https://semnexus.com/app-install-ad-creative-specs-by-platform-2026)
- [Facebook Carousel Ads: 2026 Setup, Specs, and Tactics — ecomparkour](https://ecomparkour.com/blog/facebook-carousel-ads-guide)
- [Carousel vs. Single Image Facebook Ads — Foreplay](https://www.foreplay.co/post/carousel-vs-single-image-facebook-ads)
- [Meta Ads for Pet Product Brands — MHI Growth Engine](https://mhigrowthengine.com/blog/meta-ads-for-pet-product-brands/)
- [Ad ideas for Pet Food on Meta, 2026 — Atria](https://www.tryatria.com/ads/meta/pet-food-ads)
- [Yuka — Food & Cosmetic Scanner (category reference)](https://yuka.io/en/)
