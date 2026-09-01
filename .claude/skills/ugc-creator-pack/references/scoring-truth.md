# What the app actually renders

Everything here was measured, not assumed. Re-measure with
`scripts/verify-products.py check <gtin>` — it runs the shipping matcher and scorer.

## The score does not discriminate; the label does

- Mass-market bags stuffed with BHA, BHT, dyes and menadione land at **87–94 / 100**.
- Across the whole catalog, **99.7% of products score ≥75** and the p1–p99 band spans
  **16 points**. Structural cause: rank weight `exp(-0.22 * (rank - 1))` makes total penalty
  weight converge to ~5.06 regardless of list length, so everything past rank ~15 is nearly
  invisible.
- **No product ever rates "Good."** That label is unreachable in practice.

So the number is decorative. **The label is a switch**, set in `generateSafetyExplanation`:

| Condition | Label |
|---|---|
| any ingredient whose species risk level is `toxic` | **Avoid** |
| else any `caution` ingredient | **Caution** |
| else | (score band) |

And separately, in `calculate`:

> **Any allergen match at all forces total score to 0 and the rating to "Avoid"**
> — `ScoreCalculator.swift:91`, `hasAllergenMatch = !allergenFlags.isEmpty`

**This is the entire creative engine.** The general score is a flat "Caution ~90" on every
mass-market bag; the drama comes from the pet profile flipping it to a red 0.

## How allergen matching works — and why it misfires

`checkAllergenSuitability` compares the owner's allergen string against
`ing.commonName.lowercased()` with `==` or `.contains()`. It never looks at the raw label
text. So what matters is **the ingredient the matcher resolved to**, not what the bag says.

That produces two failure modes. `verify-products.py check` detects both.

### PHANTOM — the app shows what the label doesn't say

| Label text | Resolves to | Displays as |
|---|---|---|
| `Animal Fat (Source of Omega 6 ... [Preserved with BHA...])` | `ing_chicken_fat` | **"Chicken fat"** |

On Pedigree Adult Beef & Lamb and Pedigree Puppy, a chicken-allergic dog gets a real
**0 · Avoid** — attributed to "Chicken fat," a phrase nowhere on that label. A viewer who
pauses on the panel catches it. **Never script this.**

### ERASED — the label says it but the app won't flag it

| Label text | Resolves to | Displays as |
|---|---|---|
| `Chicken By-Product Meal` | `ing_meat_by_products` | **"Meat by products"** |
| `Turkey By-Product Meal` | `ing_turkey` | "Turkey" |

The chicken identity is erased; turkey's is kept. A chicken allergen therefore does **not**
match "chicken by-product meal" on any product. The creator may still read the phrase aloud —
that's the printed label, and it's true — but must never say the app flagged chicken.

> **Worth fixing.** Making `Chicken By-Product Meal` resolve to a chicken-bearing ingredient
> (as turkey already does) would unlock the strongest angle in this whole campaign: a bag
> whose front says salmon/lamb/beef, scored **Avoid** for a chicken-sensitive pet because of
> a by-product buried at #4. Until then, route around it.

### Where chicken *is* safe to name

Only where a literal `Chicken` token exists in the panel — e.g. Purina ONE Tender Selects
Salmon (`Chicken` at #13) and 9Lives Meaty Paté with Real Chicken (`Chicken` at #3). `check`
will show these as `OK chicken`.

## Species-dependent risk

`riskLevel` is per species, so the same ingredient changes the label:

| Ingredient | Dog | Cat |
|---|---|---|
| Garlic | `caution` | **`toxic`** |
| Propylene glycol | `safe` | **`toxic`** |
| BHA / BHT / ethoxyquin / menadione / titanium dioxide / dyes | `caution` | `caution` |

**Garlic in a dog script needs careful wording.** It renders a high-severity flag but the
label stays *Caution*, not Avoid. "The app flagged garlic and I didn't expect that" is true
and sufficient. Claiming it poisons the dog invites a correction pile-on.

**The same ingredient in a cat food is `toxic` and does force Avoid** — a different script
entirely, and a much stronger one. `check` computes the real label per species and prints it,
so never infer it from the number.

### The high-score Avoid — the rarest and best premise

A toxic-for-species ingredient sets the label independently of the score, which produces
bags that read **"94 / 100 · Avoid"** with no pet profile at all. Example: Lotus Oven-Baked
Duck (cat) scores **94.4** and labels **AVOID**, because garlic is toxic for cats.

This is the only honest way to open on a scary label without a pet profile, and it inverts
the usual spine — the hook is the contradiction itself ("it scored ninety-four out of a
hundred and it still says avoid"). It also lands on a premium brand rather than a cheap one,
which is a different and less-expected story than corn-first supermarket kibble.

`check` prints `LABEL: AVOID` plus the responsible ingredient whenever this happens. Go
looking for it deliberately when a pack needs a slot-3 surprise.

## Tokenisation gotchas

- Preservatives named inside parentheses may not tokenise. Meow Mix Original Choice lists
  `Ocean Fish Meal (Ethoxyquin Used As A Preservative)` but **ethoxyquin never appears in the
  flags**. Only script warnings that `check` prints under `FLAGS SHOWN`.
- Many catalog rows contain the ingredient list **twice** (multi-pack listings), so ranks
  above ~40 are duplicates of earlier ones. `check` collapses these to the first occurrence,
  but if you read raw `matchkit explain` output yourself, ignore the second pass.
- Flag severities (`info` / `warn` / `high`) are display-only. They do **not** drive the
  label — only the `toxic` / `caution` risk level does.

## The honest framing that results

Truthful, verifiable, and still dramatic:

> "The general score is 90 — 'Caution.' That's the score for dogs in general, and it's
> useless to me, because I don't have dogs in general. I pick my dog's profile and the same
> bag goes to **zero. Avoid.**"

Never: "I scanned it and it scored 14/100." It won't, and the creator will be filming a
screen that says 90.
