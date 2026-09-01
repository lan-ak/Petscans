# Ellie Hofstedt — cat pack (internal)

Creator-facing dialogue lives in `build-ellie-pack.py`, which renders
`PetScans-UGC-Scripts-Ellie-Hofstedt.docx`. This file holds verification data, guardrail
reasoning, and the mechanics recorded per script.

**Brief:** runs a small cat rescue, multiple cats. Rescue mentioned once, lightly. Generic
intake scenarios with `[FILL]` slots. Search-only — zero props. **Organic posts to her own
account; nothing here is an ad.**

---

## Verified product data

`verify-products.py check`, re-run 2026-08-05. Rank = position in the panel.

| Slot | Product | GTIN | Score · Label | Flags shown | Safe to name |
|---|---|---|---|---|---|
| 1 | Purina ONE Tender Selects Salmon | `00017800474900` | **91.5 · Caution** | menadione | **chicken**, corn, soy, wheat, salmon, rice |
| 2 | Meow Mix Tender Centers | `00829274515993` | **89.7 · Caution** | BHA, menadione, titanium dioxide, Red 40, Yellow 5, Yellow 6 | corn, soy, wheat, salmon |
| 3 | Meow Mix Original Choice | `00829274513760` | **93.5 · Caution** | Red 40, Yellow 5, Yellow 6, Blue 2 | beef, **corn**, soy, fish, salmon, turkey |
| 4 | 9Lives Meaty Paté w/ Real Chicken | `00079100003617` | **89.9 · Caution** | menadione, sodium nitrite, titanium dioxide | **chicken**, rice |
| 5 | Friskies Gravy Swirl'd | `00050000168620` | **93.0 · Caution** | menadione, Red 40, Yellow 5 | **corn**, soy, wheat, fish, salmon |

**Panel facts used on camera**

- **#1** — Salmon, Rice Flour, Corn Gluten Meal, **Chicken By-Product Meal (#4)** … plain
  **Chicken at #13**. Salmon genuinely is first; say so.
- **#2** — Whole Ground Corn, **Chicken By-Product Meal (#2)**, Corn Gluten Meal, Soybean Meal…
- **#3** — Ground Corn, **Chicken By-Product Meal (#2)**, Soybean Meal, Corn Protein Meal…
- **#4** — **Meat By-Products (#1)**, Water, **Chicken (#3)** — front of the can says "with real
  chicken."
- **#5** — Ground Yellow Corn, Corn Protein Meal, **Chicken By-Product Meal (#3)**…

## Guardrails specific to this pack

- **Chicken is only nameable on Scripts 1 and 4** (literal `Chicken` tokens at #13 and #3).
  On 2, 3 and 5 `Chicken By-Product Meal` resolves to `ing_meat_by_products` → displayed
  "Meat by products," so a chicken allergen never matches. She may read the phrase aloud
  anywhere; she may not attribute it to the app.
- **Never a chicken profile against Script 2** — Meow Mix Tender Centers' `Animal Fat (...)`
  fuzzy-matches to `ing_chicken_fat`, which would put "Chicken fat" on screen. Not on that label.
- **Ethoxyquin on Script 3's label does not tokenise** (it sits inside a parenthetical), so it
  never appears in the flags. Only the four dyes are shown. Don't script it as a flag.
- All five are `caution`-level. Nothing here is toxic; no script claims otherwise.

## Slot plan — five drivers, no repeats

| Slot | Script | Driver | Trigger |
|---|---|---|---|
| 1 | The bag says salmon | Betrayal + late discovery | chicken |
| 2 | Six warnings on one bag | Curiosity gap | corn |
| 3 | **Four months of her chewing herself** | **Fear** | corn |
| 4 | The donation bin | Guilt/love, inverted | chicken |
| 5 | Same tin. Four cats. Four answers. | Relief | corn |

**Script 3 is the highest-ceiling video in the pack** — allergy storytime is the top-performing
format in the landscape study and the only one that maps onto the per-pet score. It carries a
callout telling her explicitly not to soften it.

## Viral mechanics per script

Mechanic 1 (verification invitation) is in all five, as required.

| Slot | Mechanics | Intended top comment |
|---|---|---|
| 1 | verification invitation · pause frame (#4/#13 held) · screenshot artifact · tag trigger ("anyone with a cat that can't do chicken") | "so what do I buy instead?" |
| 2 | verification invitation · curiosity gap · pause frame (warnings stamp in) · argument engine · screenshot artifact | "what's the worst one you've found?" |
| 3 | verification invitation · tag trigger (owners who know the sound) · screenshot artifact | others telling their own version — reply to these first |
| 4 | verification invitation · tag trigger (rescue/donor circles) · pause frame · stitch bait | "is [brand] any better?" |
| 5 | verification invitation · tag trigger (multi-pet households) · screenshot artifact · stitch bait | "what does [my food] score?" |

**Hook shapes are registered in `../hook-ledger.md`.** None are shared with Kara Robinson —
`check-duplication.py` reports max 3 shared phrases, all ingredient lists and the flip beat,
which both packs must state.

## Rebuild

```
cd "PetScans UGC/Ellie Hofstedt - Cat Rescue"
../../PetScans-Meta-Campaign/venv/bin/python build-ellie-pack.py
```

## Outstanding

- **Median views per post not yet on file.** Without it breakout ratio can't be computed and
  none of this is measurable. Requested in the creator brief.
- Release window not set — must not overlap Kara's.
