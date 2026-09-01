# Kara Robinson — dog pack (internal)

Creator-facing dialogue lives in `build-kara-pack.py`, which renders
`PetScans-UGC-Scripts-Kara-Robinson.docx`. This file holds verification data, guardrail
reasoning, and the mechanics recorded per script.

## Creator profile

From her media kit (Canva, 9 pages, read 2026-08-05):

- **Kara Robinson** · `@crazykararoo` · North Carolina · `KaraWaltonUGC@gmail.com`
- *"Content creator | UGC | Social media management — MOM & Farm life"*
- TikTok, Instagram, Facebook, YouTube. Corporate-leadership background; kit sells
  professionalism, deadlines, analytics.
- **Named formats she shoots:** talking-head **app promotion**, talking-head nutrition,
  voice-over pet product, digital-edit pet product, time-lapse review, farm-animals product
  feature, unboxing, text overlay, viral hook, YouTube podcast
- **Pet work:** PetArmor flea & tick (voice-over, large dog) + a dedicated Pet Videos page
- **Brand partners:** Chewy · VetPets+ · Academy Sports · Visit North Carolina · Anixwell ·
  Primal Queen · Wiingy · FutureClinic · TrimRx

> ⚠️ **No follower or engagement numbers anywhere in the 9 pages.** Get median views per post
> before any paid deal — and it's required for breakout ratio regardless.

**Brief:** dog. Search-only baseline plus an optional in-store scan (Script 5). Farm/mom
identity is an asset, woven into hooks. **Organic posts to her own account; nothing is an ad.**

---

## Verified product data

`verify-products.py check`, re-run 2026-08-05.

| Slot | Product | GTIN | Score · Label | Flags shown | Safe to name |
|---|---|---|---|---|---|
| 1 | Purina ONE Lamb & Rice | `00763979668717` | **93.3 · Caution** | menadione | **corn**, soy, **wheat**, lamb, rice |
| 2 | Pedigree Adult Beef & Lamb | `00023100143330` | **89.9 · Caution** | BHA, BHT, Red 40, Yellow 5, Yellow 6, Blue 2 | beef, **corn**, soy, wheat, lamb |
| 3 | Purina Dog Chow Lamb Flavor | `00601957853895` | **90.7 · Caution** | menadione, Red 40, Yellow 5, Yellow 6, Blue 2 | **corn**, soy, lamb, rice |
| 4 | Purina Dog Chow Complete Adult | `00017800419918` | **87.6 · Caution** | **garlic**, menadione, Red 40, Yellow 5, Yellow 6, Blue 2 | **corn**, soy, wheat |
| 5 | In-store — whatever's on the shelf | — | varies | varies | her dog's real trigger |

**Panel facts used on camera**

- **#1** — Lamb, Rice Flour, **Whole Grain Corn (#3)**, **Whole Grain Wheat (#4)**,
  **Chicken By-Product Meal (#5)**. Lamb genuinely is first; say so.
- **#2** — Ground Whole Grain Corn, Meat and Bone Meal, Corn Protein Meal, Soybean Meal,
  **Chicken By-Product Meal (#5)**, Animal Fat *(preserved with BHA)*.
- **#3** — Whole Grain Corn, **Chicken By-Product Meal (#2)**, Corn Gluten Meal … **Lamb Meal
  at #12, behind the salt.**
- **#4** — Whole Grain Corn, Meat and Bone Meal, Corn Gluten Meal … **Chicken By-Product Meal
  (#6)**; garlic flagged.

## Guardrails specific to this pack

- **Never name chicken as the trigger on any of the five.** `Chicken By-Product Meal` resolves
  to `ing_meat_by_products` ("Meat by products"), and on Pedigree the `Animal Fat (...)` line
  fuzzy-matches to `ing_chicken_fat` — which would display "Chicken fat," a phrase not on that
  label. Reading "chicken by-product meal" off the panel is fine; attributing it isn't.
- **Garlic (Script 4) is `caution` for dogs, `toxic` for cats.** The label here stays Caution,
  so the script carries a callout: "the app flagged garlic and I didn't expect that" is the
  ceiling. No poisoning claims.
- All five are `caution`-level. Nothing here is toxic.

## Slot plan — five drivers, no repeats

| Slot | Script | Driver | Trigger |
|---|---|---|---|
| 1 | Everything here eats what it should. Except the dog. | Betrayal + late discovery | wheat/corn |
| 2 | Who is the colour for? | Curiosity gap | corn |
| 3 | **Two in the morning, every night** | **Fear** | corn |
| 4 | Hang on — there's garlic in it | Surprise, bounded | corn |
| 5 | I scanned the whole dog food aisle | Relief / utility | her dog's real one |

**Script 3 is the highest-ceiling video** and carries a callout telling her not to soften it.
The "lamb is #12, behind the salt" fact now lives inside Script 3 as evidence rather than as
its own hook — that shape is betrayal, which slot 1 already owns.

**Script 5 is the only one using barcode scanning**, and carries in-store conduct rules. It is
deliberately written to land on a **good** score so the pack doesn't read as five rants.

## Viral mechanics per script

Mechanic 1 (verification invitation) is in all five, as required.

| Slot | Mechanics | Intended top comment |
|---|---|---|
| 1 | verification invitation · tag trigger (farm & dog owners) · pause frame (#3/#4 held) · screenshot artifact | "what should he be eating instead?" |
| 2 | verification invitation · argument engine · pause frame (white plate) · stitch bait ("tip yours out") · screenshot artifact | "mine's not even that colour" / brand defenders |
| 3 | verification invitation · tag trigger (anyone with a 2am scratcher) · screenshot artifact | others telling their own version — reply first |
| 4 | verification invitation · curiosity gap · argument engine (garlic debate) · pause frame | "garlic is fine in small amounts actually" — answer with the panel |
| 5 | verification invitation · save-driver (aisle reference) · stitch bait · screenshot artifact | "do [store] next" |

**Hook shapes are registered in `../hook-ledger.md`.** None are shared with Ellie Hofstedt —
`check-duplication.py` reports max 3 shared phrases, all ingredient lists and the flip beat.

## Rebuild

```
cd "PetScans UGC/Kara Robinson - Farm and Dog"
../../PetScans-Meta-Campaign/venv/bin/python build-kara-pack.py
```

## Outstanding

- **Median views per post not on file** — her kit has no stats at all. Blocks breakout-ratio
  measurement. Requested in the creator brief.
- Release window not set — must not overlap Ellie's.
