---
name: ugc-creator-pack
description: Write PetScans UGC video scripts for a specific creator and ship them as a creator-facing .docx pack. Verifies every product claim against the real scorer before a word is written. Use when asked to create UGC scripts, onboard or brief a creator, build a creator pack, or adapt existing scripts to a new creator.
---

# PetScans UGC creator packs

You are writing scripts a real person will read on camera about real products. Every
number, ingredient and warning must be what the shipping app actually renders. A script
that puts a wrong ingredient on screen gets caught in the comments and takes the video
with it.

**Output** — one folder per creator under `PetScans UGC/`:

```
PetScans UGC/
├── ugc_docx.py                        shared layout, do not fork it
└── <Firstname Lastname - Angle>/
    ├── PetScans-UGC-Scripts-<Name>.docx    what the creator gets
    ├── build-<firstname>-pack.py           holds the copy, renders the docx
    └── ugc-scripts-<angle>.md              internal: verification data + reasoning
```

## The one thing that will make you write something false

**The 0–100 score is not where "Avoid" comes from.** Mass-market bags full of BHA, dyes
and menadione still score **87–94 with the label "Caution"** — those ingredients are all
`caution`-level, so they set the label and barely move the number.

**"Avoid" has exactly two sources:** a `toxic` ingredient, or an **allergen match against
the pet's profile**, which forces total to **0** (`PetScans/Services/ScoreCalculator.swift:91`).
Toxicity is per species — garlic is `caution` for dogs and `toxic` for cats — so a bag can
read **"94 · Avoid"** with no profile at all. `check` computes the real label; never infer it
from the number.

So every script follows the same spine: show the general score (Caution), then flip to the
pet's profile and land on **0 · Avoid**. Never write "I scanned it and it scored 14" — it
won't. Read `references/scoring-truth.md` before writing dialogue.

## The app is evidence, not the subject — but branding is what's capped

**The story is never "here is an app."** The video is a person, their animal, and a bag. The
app is what proves the point.

That does **not** mean rushing the app. Distinguish two different things:

| | Budget |
|---|---|
| **App in use** — ingredient panel, warnings, the score, the profile flip | **As long as the story needs.** Hold the panel, let people read and screenshot it. |
| **Branding** — the splash screen, the app name, the logo end card | **2 seconds, maximum.** Once, usually at the close. |

So a script can sit on the ingredient list and the score flip for as long as they earn — those
are the evidence and the payoff, and the pause-frame and screenshot-artifact mechanics in
`references/virality.md` depend on them being readable. What must stay short is the *ad* part:
the branded splash with the name on it gets 2 seconds and no more.

This is the difference between our content and the category's. The landscape study found 30+
scanner apps whose accounts are "a graveyard of feature-shouting brand accounts" — big paid
view counts, near-zero engagement. They lost by leading with branding, not by showing the
product working.

## Pipeline

### 1. Intake the creator

Read their media kit before deciding anything — it tells you species, formats they already
shoot, and what to call them. Canva links need a page-by-page image extraction; the recipe
is in `references/creator-intake.md`, along with the questions to ask and what to flag back
(missing follower stats, competitor seed-network membership).

### 2. Confirm the brief

Ask before writing — these change the scripts structurally, and guessing wastes the work:

- **What animals can they actually put on camera?** Decides the entire product set.
- **Props:** search-only (zero props), shipped bags, or an in-store scan trip.
- **Framing:** how hard to lean on their identity (rescue, farm, mom, vet).

### 3. Pick and verify products — never skip this

```bash
# candidates: mass-market, filler-first, by-product high, preservatives/dyes
.claude/skills/ugc-creator-pack/scripts/verify-products.py find --species cat --min-flags 4

# what the app ACTUALLY renders, and which allergens are safe to name
.claude/skills/ugc-creator-pack/scripts/verify-products.py check <gtin> <gtin> ...
```

`find` only reads label text. **`check` is the authority** — it runs the real matcher and
scorer and prints `SAFE TO NAME ON CAMERA`. Use only allergens on that line. It detects the
two traps that produce false scripts:

- **PHANTOM** — the app displays an ingredient the label never mentions (`Animal Fat (...)`
  renders as **"Chicken fat"**). Naming it on camera is a lie a viewer can catch by pausing.
- **ERASED** — the label says it but the app won't flag it (`Chicken By-Product Meal` is
  stored as **"Meat by products"**, so a chicken allergen never matches). The creator may
  still *read it aloud* — that's the label — but must not say the app flagged it.

Build the pack's product table straight from `check` output. Details and the full trap list:
`references/scoring-truth.md`.

### 4. Write the scripts

Five scripts, each in two lengths: a **30s cut** (shot table) and a **60s cut** (timed
voiceover). Both are organic posts to the creator's own account — neither is an ad, and the
creator doc should never call them one. Anatomy, word counts and honesty rules:
`references/script-craft.md`.

**Assign the emotional driver before writing a single line.** One driver per script, and the
five must span different drivers — five creatives in the same emotional register cannibalise
each other and the test teaches you nothing. **Slot 5 must land on relief** so the pack isn't
five videos of everything being bad. Drivers, construction rules, verbatim proven hooks and
anti-patterns: `references/emotional-hooks.md` — **read it before writing any hook.**

**Then build the spread in — virality is a feature, not an outcome you hope for.** Every
script carries **at least three named viral mechanics**, and mechanic 1 is mandatory in all
five. If you can't name a script's mechanics and say what each makes the viewer *do*, it
isn't finished. Record them in the internal `.md` so they can be checked against results.

Slot drivers, one each, no repeats: **1** betrayal · **2** curiosity gap · **3** fear (the
allergy story — highest ceiling, don't hedge it) · **4** guilt/love or surprise · **5** relief.

| # | Mechanic | Makes the viewer |
|---|---|---|
| 1 | **Verification invitation** (mandatory) | go scan their own bag → comment a score |
| 2 | Argument engine | defend or attack a brand in the comments |
| 3 | Pause frame | pause, screenshot, rewatch |
| 4 | Stitch bait | answer in their own video |
| 5 | Tag trigger | tag someone who "is" that person |
| 6 | Screenshot artifact | repost the still off-platform |
| 7 | Re-skin | (compounding — reuse a hook shape that worked) |

Full definitions, the share/comment/save split, the top-comment seed and the BR / engagement
targets to measure against: `references/virality.md`.

The last script should be the **dual-score hero** — same product, switch the pet profile,
score flips. It needs no props and it is the only thing no competitor can copy.

### 5. Render the pack

Copy an existing `build-*-pack.py`, swap the copy, run it. Layout helpers are shared so
every creator gets an identical-looking document: `references/rendering.md`.

```bash
cd "PetScans UGC/<Creator Folder>"
../../PetScans-Meta-Campaign/venv/bin/python build-<firstname>-pack.py
```

### 6. Pre-flight before you hand it over

Run this list against the finished pack. Every item has been a real mistake at least once.

- [ ] **Every allergen named on camera appears on that product's `SAFE TO NAME ON CAMERA`
      line.** Re-run `check`; do not trust an earlier note in the conversation.
- [ ] **Every score and warning in the doc matches current `check` output**, including the
      label (Caution vs Avoid) — not just the number.
- [ ] **Nothing is attributed to the app that the app didn't say.** The creator can call an
      ingredient whatever they like; they can't say it's "toxic" *per the app* unless `check`
      printed `LABEL: AVOID` for that product and species.
- [ ] **No medical claims** — no diagnosis, treatment, or "this caused / this cured."
- [ ] **The five hooks use five different emotional drivers**, and slot 5 lands on relief.
      At least one allergen script leads with fear and isn't hedged into blandness.
- [ ] **No hook shape is already claimed by another creator.** Check and update
      `PetScans UGC/hook-ledger.md`. Posts go out undisclosed — a matched template across
      accounts is what identifies a seed network. Stagger release windows too.
- [ ] **`scripts/check-duplication.py` is clean.** It parses every pack and compares only the
      *spoken* lines. Rewrite anything with 4+ shared phrases. Overlap on **ingredient lists
      is fine** — both creators are reading real panels that genuinely share ingredients;
      that's fact, not phrasing. Overlap on hooks, closes and the be-fair beat is not.
- [ ] **Branding is ≤2 seconds** — splash screen or logo end card, once. App-in-use screen
      time is unlimited; the ingredient panel is held still long enough to screenshot.
- [ ] **Every script names ≥3 viral mechanics and ends on the verification invitation**,
      with the mechanics and the intended top-comment seed recorded in the internal `.md`.
- [ ] **The creator's median views are on file** — without them breakout ratio can't be
      computed and nothing here is measurable.
- [ ] **Every unverifiable detail is a `[BRACKET]`** — no invented pet names, symptoms,
      histories or counts.
- [ ] **The optional "food I actually feed" beat is written both ways**, good result and bad.
- [ ] **No GTINs, file paths, matchkit commands or matcher talk in the .docx.**
- [ ] **The internal `.md` exists** with the `check` output and guardrail reasoning.
- [ ] **The .docx builds and opens**, and script/table counts look right.

## Rules that go in every pack

The creator-facing doc always carries these, in plain language, before the scripts:

1. **Say it how you feel it.** This isn't medical advice and you're not a vet — you don't
   have to be careful or clinical about your own animal, your own opinion, or how angry this
   makes you. Be as passionate as you actually are.
2. **But never deliberately lie.** Don't invent a pet, a symptom, or a vet visit.
   `[SQUARE BRACKET]` slots are for details only you can supply — fill them with real ones.
3. **Anything you say the app said has to match the screen.** Scores, the Caution/Avoid
   label, warnings, ingredient positions. Call an ingredient whatever you like — just don't
   put words in the app's mouth.
4. **Only name allergens from the `SAFE TO NAME ON CAMERA` line.**
5. **No medical claims.** No diagnosing, no treatment advice, no "this caused it" or "this
   cured it." What happened to your animal is yours to tell; what will happen to theirs isn't.
6. **Record the real app.** If a number differs at shoot time, film what's on screen and tell
   us — we re-verify and fix the script, never the footage.
7. **The profile switch is one unbroken take**, no re-search between the two scores, or the
   comments will say it was two different products.
8. **Branding gets 2 seconds, once.** The app name or logo card at the end, no longer. The
   ingredient list and the score can stay up as long as they're worth looking at.
9. **If your own food scores well, say so.** A clean result is a better video than a bad one.
   Never act disappointed.

## Keep the internal file

`ugc-scripts-<angle>.md` in the creator's folder holds the `check` output, the guardrail
reasoning and the script index. It is what you re-read when scores move or the matcher
changes — the creator's .docx deliberately contains none of it.

## References

- `scripts/check-duplication.py` — cross-creator spoken-phrase overlap; run before shipping
- `references/scoring-truth.md` — how scores and labels really work, every matcher trap
- `references/creator-intake.md` — reading media kits (incl. Canva), questions, red flags
- `references/emotional-hooks.md` — the six drivers, slot mapping, proven hooks, anti-patterns
- `references/virality.md` — the seven mechanics, what to measure, BR and engagement targets
- `references/script-craft.md` — anatomy, timings, the five-slot structure, honesty rules
- `references/rendering.md` — folder convention and the `ugc_docx` API
