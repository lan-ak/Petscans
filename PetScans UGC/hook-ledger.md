# Hook ledger

**Every hook shape in use, and who owns it.** Check this before writing any pack; add your
rows when the pack ships.

**The rule:** no two creators run the same hook shape. Posts go out undisclosed, so a matched
template across several accounts is the exact fingerprint of a paid seed network — it's how
we identified a competitor's network in `competitor-scanner-apps.md` (~10 accounts, all
running *"Most TOXIC [dog/cat] food you NEED to AVOID"*). Same product across creators is
fine. Same *shape* is not.

Re-skinning a shape onto a **new product, weeks later, for the same creator** is encouraged —
that's how a proven hook compounds. See mechanic 7 in the skill's `virality.md`.

## Shapes in use

| Shape | Owned by | Slot | Driver | Example line |
|---|---|---|---|---|
| **"You bought the [protein] one"** — the front-label protein chosen *because* of the sensitivity | **Ellie Hofstedt** | 1 | Betrayal + late discovery | "If your cat can't do chicken, you have bought the salmon one. Everybody buys the salmon one." |
| **"[N] separate warnings on one bag"** — hard number, withheld answer | **Ellie Hofstedt** | 2 | Curiosity gap | "I found a cat food with six separate warnings on it. Six." |
| **"The sound she makes"** — a sensory detail only sufferers recognise | **Ellie Hofstedt** | 3 | **Fear** | "There's a sound a cat makes when she's been licking the same patch of skin for months." |
| **"The donated bag with no story"** — gratitude plus duty | **Ellie Hofstedt** | 4 | Guilt/love, inverted | "People drop food off for the rescue constantly and it is genuinely kind. I still check every tin." |
| **"Every app thinks they're the same animal"** — multi-pet, one score | **Ellie Hofstedt** | 5 | Relief | "I've got [N] cats and every app I've ever tried thinks they're the same animal." |
| **"Everything here eats what it should — except the dog"** — farm animals vs. the bagged one | **Kara Robinson** | 1 | Betrayal + late discovery | "Everything on this farm eats exactly what it's meant to eat. Except the dog." |
| **"Who is the colour for?"** — dyes for a colourblind animal | **Kara Robinson** | 2 | Curiosity gap | "There are four dyes in this dog food. Dogs are colourblind. So who's the colour for?" |
| **"Two in the morning"** — the hour the symptom owns | **Kara Robinson** | 3 | **Fear** | "I have listened to my dog scratch himself awake at two in the morning for [N] years." |
| **"I had to stop reading"** — the one ingredient that broke the scroll | **Kara Robinson** | 4 | Surprise, bounded | "I was reading a dog food label and I had to stop. There is garlic in it." |
| **"Scan the whole aisle with my animal's allergies loaded"** — in-store sweep | **Kara Robinson** | 5 | Relief / utility | "I'm going to scan every dog food on this shelf with my dog's actual allergies loaded in." |


## Open pools (many creators, one brief)

Noise playbooks are the exception to the one-creator-one-shape rule — dozens of creators run
the same brief, which is the fingerprint problem by construction. They are only safe when the
brief specifies a **structure** and forces the **hook** to come from the creator's own animal.
A playbook that ships a scripted opening line is a seed network with extra steps.

| Pool | Platform | Spine | Hook source | Status |
|---|---|---|---|---|
| **Same bag, two scores** (Noise playbook `18676`, campaign `3988` PetScans) | Noise | The dual-score profile flip — general score · Caution → pet's profile → 0 · Avoid, one unbroken take | Creator's own pet, name + real sensitivity. Four registers offered (late discovery, betrayal, fear, relief), one per video | **LIVE** 2026-08-07 |
| **Bone marrow treats, mostly wheat** (Noise playbook `18677`, campaign `3988`) | Noise | 2 slides, ~30s. One fixed product (MaroSnacks `00079100902071`). Panel read — wheat #1, sugar #3 — then wheat profile → 0 · Avoid | Creator's own dog; "I've never read this bag" | **LIVE** 2026-08-07 |
| **A cat food that's mostly corn** (Noise playbook `18675`, campaign `3988`) | Noise | Cat mirror of 18677. Meow Mix Original Choice `00829274513760`. Corn #1 and #4 → corn profile → 0 · Avoid | Creator's own cat; obligate-carnivore framing | **LIVE** 2026-08-07 |

**Campaign 3988 went live 2026-08-07** — niche, static, **$1,000 budget over 2026-08-07 →
2026-09-06**, flat $4 CPM in US and CA (≈250K views). All three pools run simultaneously, so the
release-window staggering below does not separate them — they are differentiated by shape and
species instead. Ellie's and Kara's packs must still be staggered against each other, and
should not ship into the same weeks as this campaign.

> **`18673` and `18674` are dead — delete them.** Both accumulated undeletable duplicate slides
> (12 and 4). Slide deletion fails silently over MCP *and* in the dashboard, so they were
> replaced by fresh playbooks rather than repaired. Both are confirmed inactive. Do not activate.

**No pool claims a shape from the table above or from the unclaimed list.** The flip beat is the
one thing both existing packs already state in common, and `check-duplication.py` explicitly
tolerates it. 18676's slide 1 *bans* all five of Ellie's and both of Kara's most distinctive
openers by name so a Noise creator can't wander into a claimed shape.

18674 and 18675 use the **"filler is ingredient #1"** shape, which nobody had claimed. 18675
explicitly *bans* Kara's dye opener ("who is the colour for?") in its slide 1, because its
product genuinely does surface four dye warnings and a creator would otherwise wander into it.

**18675 reuses Ellie's slot-3 product** (Meow Mix Original Choice) with the same corn trigger.
That is permitted — the ledger rule is same *shape*, not same product — but her slot 3 is a
fear storytime and this is a flat carnivore/panel read. Keep them that far apart.

Consequence for future packs: **Ellie's and Kara's slot-5 relief scripts are now adjacent to an
open pool.** Their hooks are still theirs, but if 18673 goes live, a third creator pack should
not build its slot 5 on the bare flip — differentiate on props or species instead.

### Chicken by-product: what the pool may and may not say

Verified `verify-products.py check`, 2026-08-07 — 7 dog products, all `SAFE TO NAME: NONE`.

| Species | Verdict | What a creator may say |
|---|---|---|
| **Dog** | `Chicken By-Product Meal` is **ERASED** — stored generically, so a chicken profile never matches | Read it off the panel. **Never** "the app flagged chicken." |
| **Cat** — Purina ONE Tender Selects Salmon, 9Lives Meaty Paté | `OK` — plain `Chicken` token at #13 / #3 | Full profile flip to Avoid is honest here |
| **Any Pedigree** | **PHANTOM** — `Animal Fat (...)` renders as "Chicken fat," not on the bag | Banned from this pool entirely |

### ⚠️ The App Store "BHA warning" screen is not reproducible

`Screenshots/6.9-framed/02_UnsafeIngredients.png` shows MaroSnacks with a **"Controversial
preservative — BHA and BHT … Source: FDA 21 CFR 582.3169"** warning and an **"Allergen detected:
Chicken"**. Both come from `PetScans/Services/ScreenshotDataSeeder.swift` — hand-authored demo
data for a fictional dog called Luna.

The real catalog row (`verify-products.py check 00079100902071`, 2026-08-07) returns
**`GENERAL: 87.1 · FLAGS SHOWN: none`**. BHA sits inside a parenthetical on the real label,
`Beef Fat (Preserved with BHA/BHT)`, so it never tokenises into a flag — the same trap as
ethoxyquin in Ellie's Script 3. Chicken is not matchable on it either.

**No playbook may promise the BHA screen.** The reproducible Avoid on this product comes from
**wheat** (ingredient #1) or **beef**, via the pet's profile. Worth a separate look at whether
a shipped App Store screenshot should depict a warning the app won't produce.

## Retired / burned

None yet. Move a shape here when it has been used twice by the same creator, or when it
underperformed badly enough not to re-run (BR < 1× or engagement < 3% — see `virality.md`).

## Unclaimed shapes worth trying

Free for the next pack:

- **The defence that turns** — open by defending the brand for ten seconds, then stop.
- **The price inversion** — the expensive bag that scores worse than the cheap one.
- **The receipt** — read the panel in reverse, from the vitamins back up to the corn.
- **The substitution** — "here's what I switched to and what it scored," relief-led.
- **The bystander** — someone else's bag (a friend's, a comment request) scanned on request.
- **The count-up** — "I scanned nine bags before I found one I'd buy."
- **"Tell me when we hit the [protein]"** — participatory countdown through the panel. Was Kara's slot 4; freed when slot 4 became the garlic script. Betrayal driver, so it can only run as somebody's slot 1.

## Release windows

Stagger creators. Two packs landing in the same week reads as coordinated even when the
hooks differ.

| Creator | Pack | Window |
|---|---|---|
| Ellie Hofstedt | Cat rescue, 5 scripts | *TBD* |
| Kara Robinson | Farm & dog, 5 scripts | *TBD — do not overlap with Ellie's* |
