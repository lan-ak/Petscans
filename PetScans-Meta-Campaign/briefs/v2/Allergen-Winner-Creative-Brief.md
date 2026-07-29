# PetScans — Allergen Winner Creative Brief (Round 2)

**Purpose:** generate 3 static images + 1 UGC video that iterate on the **winning angle** from the
July test. Produce the files, drop them at the exact paths in the table below, and the campaign
(already staged & validated) launches with one command.

---

## Why this angle won

In the July install test (4 ad sets, ~$340 spend), the **Allergen / personalized-protection** angle
was the clear winner on the only trustworthy metric at this volume — **CTR / hook resonance**:

| Ad set | CTR | Clicks |
|---|---|---|
| **04 Allergen** 🏆 | **6.26%** | 141 |
| 01 Toxic Reveal | 5.13% | 115 |
| 05 Ultra-Processed | 4.77% | 93 |
| 06 Carousel | 1.63% | 31 |

(Installs/CPI ignored — 13 total installs is statistical noise.) The winning insight: **specific +
personal** beats generic fear. A named problem ("my dog's chicken allergy") plus the app's genuinely
unique feature (per-pet allergen flagging on every scan) is what pulled clicks. All 3 statics and the
video below extend that one idea.

---

## Global spec (applies to everything)

- **Brand tokens:** font **Quicksand**; brand green `#34C759`; mint background `#F0F9F4`; traffic-light
  score rings (green/amber/red); real PetScans app icon; subtle paw-print motif. Master tagline:
  *"Every ingredient revealed."*
- **Look:** clean, bright, app-native. Mirror the winning `04-allergen` creative — a **pet profile card**
  (name · breed · allergies) alongside a **HIGH allergen alert** on a scanned product.
- **Legibility:** headline readable at thumbnail size; keep key elements out of the outer 10% (platform
  UI safe zone), especially for 9:16.
- **No text-heavy images** — Meta suppresses reach on dense text. Short on-image words only.

### Compliance guardrails (hard rules — one ad was disapproved last round)
- ✅ Allowed: "allergen alerts", "flags ingredients to avoid", "safety score", "backed by vet science".
- ❌ Forbidden: disease/cure/treatment/longevity claims, "guaranteed", implied medical outcomes,
  before/after health framing, and drug/pharma imagery or logos (FDA/Merck/Poison-Control badges →
  triggers Meta's "Drugs & Pharmaceuticals" false-positive). Keep it about *ingredients*, not *health outcomes*.

---

## Static 1 — "A · Chicken Allergy" (hyper-specific)

- **Concept:** Lead with the single most common allergen. The sharpened version of the winner.
- **Visual:** A pet profile card (e.g. *Max · Golden Retriever · Avoids: Chicken, Wheat*) beside a
  scanned kibble bag showing a red **"⚠ Contains chicken"** allergen flag and an amber/low score ring.
- **On-image text (minimal):** "Chicken allergy? Check every bowl."
- **Copy (locked — matches campaign spec):**
  - Primary: *Chicken is the most common food allergy in dogs and cats — and it hides in 'premium' recipes under names you'd never catch. Add your pet's profile once and PetScans flags it on every label you scan, in about 3 seconds. 🐾*
  - Headline: **Chicken allergy? Check every bowl.**
  - Description: Allergen alerts, built in.
  - CTA: Download (Install)
- **Deliver:** `1080 × 1080` PNG → `creatives/v2/a-chicken__1x1.png`

## Static 2 — "B · Symptoms" (symptom-led)

- **Concept:** Hook people who don't yet know food is the cause. Symptom → ingredient culprit.
- **Visual:** Three small symptom icons (scratching / ear / stomach) resolving into a scan that reveals a
  flagged ingredient with a red allergen alert. Keep it clean, not clinical (no medical imagery).
- **On-image text:** "It could be one ingredient."
- **Copy (locked):**
  - Primary: *Constant scratching? Recurring ear infections? A stomach that's never quite settled? It's often one ingredient in the bowl. Add your pet's sensitivities to PetScans and see them flagged on every food you scan.*
  - Headline: **Itching, ear infections, upset tummy?**
  - Description: It could be one ingredient.
  - CTA: Download (Install)
- **Deliver:** `1080 × 1080` PNG → `creatives/v2/b-symptoms__1x1.png`

## Static 3 — "C · Flip" (relatable analogy)

- **Concept:** Empathy hook — you'd never eat your own allergen; your pet can't read the label.
- **Visual:** Split/parallel composition — a human food label with an allergen warning on one side, the
  PetScans scan doing the same for a pet food on the other. Warm, human, brand-green accents.
- **On-image text:** "You'd never eat your allergen. Why should they?"
- **Copy (locked):**
  - Primary: *You'd never eat something you're allergic to. Your pet can't read the label — so PetScans reads it for them. Set their profile once, then scan any food to see every ingredient they should avoid.*
  - Headline: **You'd never eat your allergen. Why should they?**
  - Description: Personalized allergen protection.
  - CTA: Download (Install)
- **Deliver:** `1080 × 1080` PNG → `creatives/v2/c-flip__1x1.png`

> **Production tip for statics:** these match the existing render pipeline (`templates/` + `render.mjs`,
> Quicksand + real design tokens). Reusing it keeps them visually identical to the winner. AI image-gen
> also works if you feed it the tokens above — but the app-native mock look is what performed.

---

## Video 1 — "V1 · UGC Testimonial" (the format test)

- **Format:** **9:16 vertical, 1080 × 1920**, **12–15 seconds**, MP4 (H.264). Reels/Stories-native.
- **Style:** Authentic, hand-held, real pet parent — NOT polished/agency. Feels like a friend's Story.
  This is the format we haven't tested (carousel underperformed), so keep production cheap and real.
- **Hook (first 1s is everything):** open mid-sentence on the person + their dog, no logo intro.
- **Script / shot list:**

  | Time | Visual | Voiceover (natural, unscripted feel) | On-screen text |
  |---|---|---|---|
  | 0–3s | Person with their dog, handheld selfie or close-up of the dog scratching | "Max itched for *months* — we tried everything." | "Max. Itchy for months. 🐾" |
  | 3–7s | Cut to phone: **screen-recording** of a PetScans scan of a kibble bag → score ring resolves | "Turns out it was chicken. In his food the whole time." | — |
  | 7–11s | Screen-record continues → red **"ALLERGEN: Chicken"** alert on the product | "Now I just scan the bag before it goes in the cart." | "Scan → instant allergen alert" |
  | 11–15s | Back to happy dog; end card with app icon + tagline | "Takes like 3 seconds." | "PetScans — Every ingredient revealed." + **Download free** |

- **Audio:** real voiceover (the pet parent), light upbeat bed under it. Add **burned-in captions** the
  whole way (most view muted).
- **Copy (locked — matches campaign spec):**
  - Primary: *Max itched for months before we realized it was chicken. Now I scan every bag before it hits the cart. PetScans flags your pet's allergens in about 3 seconds. 🐾*
  - Headline: **Turned out it was his food.**
  - Description: Scan. Score. Know.
  - CTA: Download (Install)
- **Deliver:**
  - Video → `creatives/v2/v1-ugc__9x16.mp4`
  - Thumbnail/cover `1080 × 1920` PNG → `creatives/v2/v1-ugc__thumb.png` (a strong frame: the dog + "ALLERGEN: Chicken" alert)

> **Screen-recording note:** the mid-video scan should be a real capture from the app (a product that
> actually flags chicken) so the demo is genuine. If you can't film a real dog, a licensed UGC clip +
> the real app screen-record still works — the screen-record is the essential part.

---

## Drop-in file map (must match exactly — the campaign spec points here)

| Ad set | File to produce | Size |
|---|---|---|
| A Chicken Allergy | `creatives/v2/a-chicken__1x1.png` | 1080×1080 |
| B Symptoms | `creatives/v2/b-symptoms__1x1.png` | 1080×1080 |
| C Flip | `creatives/v2/c-flip__1x1.png` | 1080×1080 |
| V1 UGC Video | `creatives/v2/v1-ugc__9x16.mp4` | 1080×1920 |
| V1 thumbnail | `creatives/v2/v1-ugc__thumb.png` | 1080×1920 |

All paths are relative to `PetScans-Meta-Campaign/`. Folder is already created and waiting.

Once these five files exist, tell me and I'll validate against Meta and create the campaign **PAUSED**
(4 ad sets · CA+US · CAD $13.75/ad set = **$55/day**), then hand you the campaign id to activate. I won't launch it.
