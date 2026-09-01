# Script craft

Five scripts per pack, each in two lengths — a **30s cut** and a **60s cut** of the same
story, shot in one session. Both are organic posts to the creator's own account; neither is
an ad, and the creator's document should never call them one.

## The spine

Every script is the same five beats. The order is what makes the payoff land:

1. **Hook (0–8s)** — one emotional driver, no product, no app. Often no phone in frame.
2. **The label read** — the creator reads the ingredient panel out loud. This is the
   credibility beat and the single most repeatable winning format in the study. Show the
   app's ingredient view and **hold it** — long enough to read and screenshot. This beat can
   run; it's evidence, not an interruption.
3. **The general score** — "90, Caution." Deliberately anticlimactic.
4. **The flip** — pick the pet's profile, same product, **0 · Avoid**. This is the video.
   One unbroken take: score, tap the profile, red zero, no cut and no re-search in between.
5. **Close** — one line, then the **verification invitation**: an action the viewer can
   complete in 30 seconds with a bag they already own. "It's free. Go check the one in your
   cupboard." This is a distribution mechanic, not a sign-off — it's what turns watching into
   commenting. Mandatory in all five scripts; see `references/virality.md`.
   Any branded end card — app name, logo — is **2 seconds maximum**.

Beat 3 is not filler. Showing the unremarkable general score first is what makes the flip
mean anything, and it's the only honest way to use the number.

## Timings

- **30s ≈ 75–85 words** of voiceover. Shot table: `Time | What we see | What you say`,
  6–7 rows, with on-screen text called out inline.
- **60s ≈ 150–165 words.** Timed beats with a cue line, written as continuous speech.
- **App-in-use screen time is not capped.** The ingredient panel and the score flip are the
  evidence and the payoff — give them the time they earn. **Branding is capped: any splash
  screen or logo end card is 2 seconds maximum**, once per video. See the framing rule in
  `SKILL.md`.
- Hold the ingredient panel **still** for at least 2 seconds at some point. Viewers pause and
  screenshot; a scrolling list can't be either.
- The flip is one unbroken take: score, tap the profile, red zero, no cut and no re-searching
  between the two numbers — otherwise the comments will say it was two different products.

## The five slots

Vary the product per script so the five don't compete with each other in the creator's own feed.

| Slot | Job | Driver |
|---|---|---|
| 1 | The front-label betrayal — "you bought the salmon/lamb one" | Betrayal |
| 2 | Count the warnings — pick the most-flagged product in the set | Curiosity gap |
| 3 | **The allergy story** — what it did to their animal, and how long they didn't know | **Fear** |
| 4 | The surprising ingredient (garlic, titanium dioxide, sodium nitrite), or "Where's the [protein]?" | Guilt/love or surprise |
| 5 | **Dual-score hero** — same product, switch pet, score flips. Zero props. | Relief |

Five slots, five different drivers — see `references/emotional-hooks.md`.

**Slot 3 has the highest ceiling.** Allergy storytime is the top-performing format in the
landscape study and the only one that maps directly onto the per-pet score. It's also the
easiest to ruin by hedging.

Slot 5 is the one to pin to the profile, and the only one that demonstrates the differentiator
rather than describing it. Never cut it for time.

## Proven formats and hooks

From `PetScans UGC/pet-food-scanner-tiktok-landscape.md` (363 videos, 244 at `organic_hit`):

- **Ingredient exposé / read-the-label** — the #1 repeatable format. 1.94M and 2.13M-view
  examples. This is our app's core loop done by hand; we automate it.
- **Allergy / transformation storytime** — strongest emotional pull, highest breakout in the
  study (6.77M views at BR 11,402× from an 8K-follower account). Maps exactly onto the
  per-pet score.
- **"Worst/toxic brands" listicle** — biggest raw reach (8.5M).
- **Aisle walkthrough** — 738K and 945K. Works as an in-store scan script.
- **Disgust hook (cat-leaning)** — the category's only organic scanner hit, 215K.

**Pick the emotional driver before you write the line, one per script, and make the five
scripts span different drivers.** Which driver belongs in which slot, how to construct the
line, the verbatim proven hooks and the anti-patterns are all in
`references/emotional-hooks.md` — read it before writing any hook.

## Passion is encouraged. Lying is not.

**This is not medical advice and the creator is not a vet.** They do not need to be clinically
precise, cite studies, or hedge their opinions. They should sound like a furious, relieved,
worried pet owner — because that's what they are, and that's what travels.

The line is **deliberate falsehood**, not intensity. Two categories, two standards:

**Theirs to say however they want — no fact-checking needed**
- How they feel. "This makes me so angry." "I felt like an idiot."
- What happened to their animal. "Three years of paw licking." "She groomed herself bald."
- Their opinion of a brand or an ingredient. "I think that's shady." "Why is dog food *red*?"
- What they'll do about it. "I'm not buying this again."

Write these with force. Don't sand the edges off, don't add "in my experience," don't make
them sound like a press release.

**Must match reality exactly — these are checkable on screen**
- The score, the label (Caution vs Avoid), the warnings the app listed.
- Ingredient names and their positions in the panel.
- What the app flagged, and what it flagged it as. Only allergens from the
  `SAFE TO NAME ON CAMERA` line of `verify-products.py check`.

**Never, in either category**
- **Invented specifics.** A pet that doesn't exist, a symptom that never happened, a vet visit
  that wasn't. `[SQUARE BRACKET]` anything you can't verify and let the creator fill it with
  something real.
- **Medical claims.** No diagnosis, no treatment, no "this caused / this cured." They can say
  what happened to their animal; they can't tell the viewer what will happen to theirs.
- **Attributing to the app what the app didn't say.** They can call an ingredient disgusting.
  They can't say the app called it toxic when it says Caution.

### Still worth doing

- **Write the optional beat to work either way.** "I scanned what I actually feed" needs a
  good-result branch and a bad-result branch. A clean score is a *better* video — never ask a
  creator to act disappointed.
- **Be fair on purpose.** A beat like "salmon genuinely is the first ingredient, I'll give
  them that" costs nothing and buys enormous credibility. It also disarms the brand's
  defenders — and those fights are themselves distribution (a 1.31M-view *defence* of Purina
  exists alongside the 2.13M attack).
- **Expect and welcome argument.** Answer with the ingredient list, not an opinion. Don't
  delete comments.

## In-store scripts

If the creator will do a store trip, script 5 becomes a shop-with-me using **barcode
scanning** instead of search. Requirements:

- Profile selected **before leaving the house** — the whole point is the scores are that
  pet's.
- Conduct rules in the doc: don't block the aisle, don't film other customers or staff, stop
  if asked, don't open packaging.
- **Land on a good score at the end.** Scanning five bags and finding the best one is a
  useful video; scanning five and hating all of them is a rant.

## Voice

Write in the creator's register, not ad copy. Contractions, asides, an unfinished sentence.
The best-performing videos in the study are people being irritated or relieved in their own
kitchen. If a line reads like it came from a brand, cut it.
