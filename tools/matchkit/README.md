# matchkit

Offline measurement for ingredient matching and scoring. Runs the app's own
`IngredientMatcher` and `ScoreCalculator` across every product in the bundled
`catalog.sqlite`, so coverage and score changes can be reviewed before they reach
a device. It is also where the matching, scoring and persistence tests live —
`swift test`.

```bash
cd tools/matchkit
swift run matchkit coverage        # match rate, and how the matches were made
swift run matchkit misses --top 400
swift run matchkit fuzzy-audit     # how much of the match rate is a guess
swift run matchkit calibration     # why the 0-100 score doesn't discriminate
swift run matchkit baseline --out reports/baseline-<catalog>.json
swift run matchkit score-delta --baseline reports/baseline-<catalog>.json
swift run matchkit doctor          # CI guard: shared-source symlinks intact
```

**Expanding the catalog?** Follow `docs/catalog-expansion.md`. `coverage` and `score-delta`
are steps 5 and 6 of it, and the step they exist for is reading the miss list for allergen
terms: allergen checking only runs on ingredients the matcher resolves, so an unmatched
label spelling is a pet that does not get warned.

## Why it shares the app's source

`Sources/matchkit/Shared/` contains **symlinks** to the app's model and service
files — not copies, and not a port. The numbers this tool prints are only worth
acting on if they come from the code that ships. `IngredientMatcher.normalizeToken`
filters on `CharacterSet.alphanumerics` (Unicode general categories, not `[a-z0-9]`),
so a JavaScript `\w`-based port would quietly disagree on "açaí" and "d-alpha" and
nothing would tell you. Scoring is worse: five penalty paths, rank decay and a
classification threshold, all of which the score-delta audit needs to reproduce
exactly.

Everything lives in one module so the app's `internal` types stay internal.

`matchkit doctor` guards the failure mode this design creates — a file added to the
app's matching core but never symlinked here. It checks the link set against
`Doctor.expected`, that every link resolves, and that nothing in the core imports
SwiftUI/UIKit/SwiftData. Run it in CI.

When you add a core file: add it to `Doctor.expected`, then `ln -s` it into
`Shared/`. If it needs SwiftUI or app state, split it first — see `Models+UI.swift`
and `Matching+SharedDatabase.swift`.

## Baselines

`reports/` holds the committed reference point: the per-product outcome (total,
rating label, processing-classification rate) plus catalog-level totals, keyed by
GTIN.

`baseline-current.json` is the reference the next change is diffed against.
Regenerate it whenever the catalog changes — `petcatalog` edits `catalog.sqlite`
in place without bumping `meta.version`, so the baseline records the row count and
`cleaned_at` too, and `score-delta` warns when they don't match rather than
reporting catalog churn as a code change.

**The rating label is stored, never re-derived from the score.** Deriving it would
apply `RatingLabel.from(score:)` alone and miss `labelOverride` — which is what
actually decides Caution and Avoid — so every overridden product would read as a
regression. That mistake reported 8,231 false transitions the first time this ran.

## What it found (2026-07-30)

**Match rate was 88.5%, but 18% of it was a guess.** Breakdown by how each token
resolved: `exact` 66.8%, `descriptor` 3.7%, `fuzzy` 18.0%, unmatched 11.5%. The
fuzzy path is substring containment against synonym keys.

**A third of those guesses were ambiguous.** 44,159 fuzzy occurrences (32.6%) had
two or more candidate ingredients, and the old code picked by `Dictionary`
iteration order — which depends on a per-process hash seed, so the same token could
resolve differently between launches, with the answer persisted into the scan.
Observed wrong matches: `preserved with mixed tocopherols` → chicken fat (895
occurrences), `potato` → sweet potatoes (456), `fish` → fish oil (625), and a
grouped mineral token collapsing to manganese out of 7 candidates (720).

Fixing it — deterministic longest-key-first, and dropping the reverse-containment
direction — cost 1.9 points of raw match rate (88.5% → 86.6%) and moved 668
products' labels, **659 of them for the better** (Caution → Excellent 390, Avoid →
Excellent 173, Avoid → Caution 96; only 9 got worse). Those were foods flagged as
risky because of a mis-identified ingredient.

**Half the ingredient database was unreachable.** The matcher consulted only
`synonyms.json`, never an ingredient's own name — so **311 of 625 ingredients had
no exact lookup key at all** and could only be found by guessing. Deriving keys
from `commonName` and `scientificName` (curated entries still win) closed that.

Net result: match rate **90.2%**, exact matches **66.8% → 74.3%**, fuzzy guesses
**18.0% → 12.6%**. More of the list is now known rather than inferred. The row
itself no longer marks *how* a match was made — a marker on 90% of rows is
decoration — so that explanation moved into the ingredient detail sheet, which
states the label wording it matched and whether the match was inferred.

**The 0-100 score does not discriminate.** 99.7% of products score at or above the
Excellent threshold of 75; the p1–p99 band spans 16 points of the 100-point scale;
and **zero products rate "Good"**. Every Caution and Avoid comes from
`labelOverride` in `ScoreCalculator`, a boolean on "contains any caution/toxic
ingredient". The number is decorative; the label is a two-way switch.

The structural cause is visible in `matchkit calibration`: rank weight is
`exp(-0.22 * (rank - 1))`, so total penalty weight converges to 5.06 no matter how
long the list is. The median product lists 24 ingredients, but everything past
~rank 15 contributes under 1% of the weight — a long tail of ultra-processed
additives is nearly invisible to the score.
