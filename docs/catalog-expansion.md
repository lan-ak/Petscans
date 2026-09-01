# Expanding the catalog

Follow this every time, in order. It exists because a catalog expansion can silently
**remove allergen protection from pets** without failing a build, changing a score, or
touching a line of Swift.

The failure mode, concretely: allergen checking only runs on ingredients the matcher
*resolves* (`ScoreCalculator.checkAllergenSuitability` skips any token with no
`ingredientId`). New products bring new label spellings. A spelling nothing resolves is
invisible to the allergen check — so the app tells a fish-allergic cat's owner
*"No known allergens detected"* over a food whose label says fish. That is what shipped for
four versions: the Dairy chip matched no ingredient at all, and 43 fish ingredients existed
while only 14 had "fish" in the name.

Nothing below takes long. Steps 4–7 are the ones that catch the silent failure.

---

## 0. Never open the catalog with plain `sqlite3`

```bash
sqlite3 'file:PetScans/Data/catalog.sqlite?mode=ro&immutable=1' "SELECT ..."
```

The bare `sqlite3 catalog.sqlite` — and even `?mode=ro` — **writes to the file** (WAL
checkpoint). It has grown the tracked 23 MB binary by over 1 MB mid-review more than once.
`immutable=1` is the only form that does not.

## 1. Baseline before you change anything

```bash
cd tools/matchkit
swift run -c release matchkit baseline --out reports/baseline-<date>.json
```

Without a baseline taken *before* the harvest, step 6 cannot tell you what moved.

## 2. Harvest, ingest, pack, group

```bash
cd tools/petcatalog && ./harvest.sh all      # or: expand / intl / <single stage>
```

Re-running is safe and never duplicates work — every collector resumes from its `.done`
ledger.

## 3. Regenerate the avoidance groups — only if `ingredients.json` changed

```bash
python3 tools/gen-avoidance-groups.py
python3 tools/validate-ingredient-content.py     # every ingredient needs authored content
```

A new ingredient with no group silently drops out of the owner's watch list. Check the diff:
the generator matches on name tokens, so it will happily group **Milk thistle** (a plant) as
a dairy allergen — add traps like that to `ALLERGEN_EXCLUDE_IDS` with a reason.

## 4. Classify every new ingredient into an allergen family

```bash
cd tools/matchkit && swift test
```

A **curated family is authoritative**: when an allergen resolves to one, membership is the
whole answer and the name fallback is not consulted. That is what stops a string test
overruling a medical exclusion — before it, allergen "milk" matched *Milk thistle* and
"butter" matched *Peanut butter*, each forcing "Avoid".

`DataValidationTests` fails loudly and names the ingredient when:

- a family id in `AllergenFamily` no longer exists;
- an ingredient **looks like** a family member but is neither in the family nor in
  `deliberatelyExcluded` with a reason;
- a quick-pick chip has no family.

**Do not silence these by adding to `deliberatelyExcluded` without a reason.** The exclusions
that are there are medical calls, not conveniences: shellfish is a different allergen from
finned fish (tropomyosin, not parvalbumin); bison is the novel protein owners are switched
*to* for a beef allergy; Buckwheat is not a wheat; Acorn squash is not corn.

## 5. Read the miss list for allergen terms — the step that catches the silent failure

```bash
swift run -c release matchkit coverage
swift run -c release matchkit misses --top 400 > /tmp/misses.txt
grep -iE "milk|whey|cheese|casein|fish|salmon|tuna|cod|herring|sardine|chicken|poultry|beef|lamb|wheat|corn|soy|dairy" /tmp/misses.txt
```

**Every line this prints is a pet that will not be warned.** Each one needs either a synonym
pointing at an existing ingredient, or a new ingredient added to the right family.

Watch **first-5 match rate** more than the overall figure — scoring is rank-weighted, so an
unmatched first ingredient costs far more than an unmatched thirtieth.

For reference, the state this procedure was written in: 93.5% overall, 94.0% first-5,
`dog|treat` the weakest cohort at 85.6%.

## 6. Measure what moved

```bash
swift run -c release matchkit score-delta --baseline reports/baseline-<date>.json
```

The line that matters is **rating-label transitions** — the only change a user actually
feels. Adding the four generic head terms (`fish`, `milk`, `poultry`, `soy`) moved 9.4% of
products by a mean of +0.05 and produced **zero** label transitions. If an expansion moves
labels, understand exactly why before shipping it.

## 7. Run the app suite

```bash
xcodebuild test -project PetScans.xcodeproj -scheme PetScans \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:PetScansUITests
git status --short -- PetScans/Data/catalog.sqlite   # must be clean; see step 0
```

---

## When a new label spelling has no ingredient

Two mechanisms, in order of preference:

**A synonym**, when an existing ingredient already means the same thing. Cheapest — no
content entry, no validation burden. Add to `PetScans/Data/synonyms.json`. Prefer this.

**A new ingredient**, when the term is genuinely its own thing. Needs a record in
`ingredients.json` mirroring the closest existing analogue (copy its risk levels and cite its
AAFCO section — do **not** invent a citation), plus an `ingredient-content.json` entry, plus
family classification in step 4.

Two traps that have already bitten:

- **The matcher's fuzzy fallback is longest-synonym-key-first containment.** A short new key
  swallows longer unmatched strings. Adding a bare `Milk` made "milk thistle" resolve to
  dairy; adding a bare `Fish` made "shellfish" resolve to fish. Both were fixed by giving the
  *trapped* term its own ingredient, so it resolves exactly instead of falling through. After
  adding any short generic term, grep the miss list for strings that contain it.
- **A wrong match is invisible in the miss list.** This is the trap that hides longest. A
  short generic key silently *captures* longer strings instead of leaving them unmatched, so
  step 5 shows nothing at all. Adding the bare `Milk` ingredient made **"oat milk" — 93
  products — resolve to dairy**, condemning a dairy-free food for a dairy-allergic pet, and
  nothing in `misses` said so. After adding any short generic term, grep the *catalog* (not
  the miss list) for strings containing it and check each is really that thing:

  ```bash
  python3 - <<'EOF'
  import sqlite3, zlib, re, collections
  con = sqlite3.connect('file:PetScans/Data/catalog.sqlite?mode=ro&immutable=1', uri=True)
  TERM = "milk"          # the key you just added
  seen = collections.Counter()
  for (b,) in con.execute("SELECT ingredients FROM products"):
      t = zlib.decompress(b, -15).decode("utf-8", "ignore").lower()
      for m in re.findall(r"[a-z ]*\b" + TERM + r"\b[a-z ]*", t):
          seen[m.strip()] += 1
  for phrase, n in seen.most_common(40):
      print(f"{n:6}  {phrase}")
  EOF
  ```

- **Keys of 3 characters or fewer never reach the fuzzy path** (`entry.key.count > 3`), so
  `soy` needed explicit synonyms for `soy grits` and `soy oil` while `poultry` picked up
  `poultry broth` and `poultry giblets` for free.

## The one open decision

Refined fish oils (salmon oil, menhaden oil, cod liver oil) **do** trip a Fish allergy, which
means **52.7% of cat foods** fail the Fish chip — 40.9% name a fish outright, a further 11.8%
only ever name a species oil. That is deliberate: veterinary elimination diets exclude fish
oil when fish is suspected, and an allergen match is all-or-nothing here, so the alternative
is silence. Revisit it if a warn-only allergen tier is ever built. See the note on
`AllergenFamily` in `ScoreCalculator.swift`.
