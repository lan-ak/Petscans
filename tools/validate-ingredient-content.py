#!/usr/bin/env python3
"""Validate PetScans/Data/ingredient-content.json.

The content in that file is model-authored and is not reviewed by a person before
it ships. This script is what stands in for that review, so it is deliberately
strict and mechanical: it does not judge whether prose is *good*, it checks that
prose cannot be *wrong* in the ways that matter for health-adjacent copy.

The governing rule, which every check below serves:

    An entry may only restate, in plainer words, what the ingredient's record in
    ingredients.json (plus its rules in rules.json) already asserts. It may never
    introduce a new factual claim.

Run from the repo root:

    python3 tools/validate-ingredient-content.py            # validate
    python3 tools/validate-ingredient-content.py --coverage # + per-field counts

Exits non-zero on any violation. Wired into CI next to `matchkit doctor`.
"""

import json
import re
import sys
from pathlib import Path

DATA = Path("PetScans/Data")

# Phrases that assert something the record cannot support, or that read as
# marketing rather than description.
BANNED = [
    # unsupported appeals to evidence
    "studies show", "studies have shown", "research proves", "research shows",
    "clinically proven", "scientifically proven", "experts agree", "vets recommend",
    "veterinarians recommend", "widely regarded",
    # marketing
    "superfood", "super-food", "toxin-free", "all-natural", "all natural",
    "premium quality", "best-in-class", "miracle", "wholesome goodness",
    # medical claims
    "prevents", "cures", "heals", "boosts immunity", "boosts the immune",
    "reduces the risk", "protects against", "guaranteed",
    # hedging filler that says nothing
    "it is important to note", "as always", "at the end of the day",
    "it goes without saying", "needless to say",
]

# A safety verdict is only allowed when the record supports it.
REASSURING = ["completely safe", "perfectly safe", "totally safe", "no risk",
              "harmless", "nothing to worry about", "always safe"]
ALARMING = ["dangerous", "toxic", "poisonous", "avoid entirely", "never feed",
            "harmful", "unsafe"]

# Claims that need context to distinguish from ordinary usage. "treats" as a plain
# substring hit "semi-moist foods and treats" — pet treats are a product category
# here, so the verb sense has to be matched by what follows it.
BANNED_PATTERNS = [
    # The alternation needs its own trailing boundary: without it, `a` matched the
    # "a" in "dog treats and for hiding medication".
    (r"\btreats\s+(a|an|the|your|pain|symptom|disease|condition|illness|infection)\b",
     "reads as a medical claim ('treats <condition>')"),
    (r"\b(should|must)\s+(be\s+)?(given|fed|administered)\b", "reads as an instruction"),
    (r"\bhelps?\s+(prevent|cure|treat|fight)\b", "reads as a medical claim"),
]

LIMITS = {"whatItIs": (40, 260), "whyItsHere": (30, 240), "whatToWatchFor": (30, 300)}


def risk_tier(level: str) -> str:
    """Mirrors RiskTier.init in Swift, including its ordering quirks."""
    r = (level or "").lower()
    if "toxic" in r:
        return "toxic"
    if "caution" in r:
        return "caution"
    if "moderation" in r:
        return "moderation"
    if "safe_for_most" in r:
        return "mostlySafe"
    return "safe"


# Two different questions, and conflating them was wrong in both directions.
# The structural fields are unambiguous and REQUIRE a warning; prose notes only
# PERMIT one. See `permits_watch` for why the distinction is drawn this way.
def requires_watch(ing: dict, rules: list) -> bool:
    """Structural concerns. Omitting a warning here hides something real."""
    tiers = {risk_tier(ing["riskLevel"][s]) for s in ("dog", "cat")} \
        if isinstance(ing.get("riskLevel"), dict) else {risk_tier(ing.get("riskLevel"))}
    if tiers - {"safe"}:
        return True
    allergen = (ing.get("allergenOrSensitizationRisk") or "").lower()
    if any(w in allergen for w in ("medium", "high")):
        return True
    if ing.get("toxicitySymptoms") or ing.get("toxicDose"):
        return True
    return any(r["ingredientId"] == ing["id"] for r in rules)


def permits_watch(ing: dict, rules: list) -> bool:
    """Structural concern, or any note at all.

    Keyword-matching the notes was tried and abandoned: it demanded a warning for
    Vitamin B2 (whose note is reassurance that happens to contain "excess") and
    forbade one for Apples ("Remove seeds - contain amygdalin") and Zinc (breed-
    specific needs). Every list of caveat words missed a real caveat.

    A `notes` value exists because a curator thought something was worth saying, so
    its presence is the signal. Over-permitting is cheap here — the content still
    cannot introduce a number, a species, or an alarming word that is absent from
    the record, and `requires_watch` still guarantees nothing structural is hidden.
    """
    return requires_watch(ing, rules) or bool((ing.get("notes") or "").strip())


def source_text(ing: dict, rules: list) -> str:
    """Everything the entry is permitted to draw on, as one lowercase blob."""
    parts = [
        ing.get("commonName", ""), ing.get("scientificName") or "",
        ing.get("typicalFunction") or "", ing.get("notes") or "",
        ing.get("processingLevelNotes") or "", ing.get("origin") or "",
        ing.get("allergenOrSensitizationRisk") or "",
        " ".join(ing.get("toxicitySymptoms") or []),
        # Keys as well as values: toxicDose is keyed by species, and "cat" appearing
        # only as a key is still the record telling us cats are affected.
        " ".join((ing.get("toxicDose") or {}).keys()),
        " ".join((ing.get("toxicDose") or {}).values()),
        " ".join(ing.get("categories") or []), " ".join(ing.get("species") or []),
    ]
    parts += [r.get("explain", "") + " " + r.get("source", "")
              for r in rules if r["ingredientId"] == ing["id"]]
    return " ".join(parts).lower()


def main() -> int:
    ingredients = {i["id"]: i for i in json.loads((DATA / "ingredients.json").read_text())}
    rules = json.loads((DATA / "rules.json").read_text())
    content = json.loads((DATA / "ingredient-content.json").read_text())

    problems: list[str] = []

    def fail(iid: str, msg: str) -> None:
        problems.append(f"{iid}: {msg}")

    for iid, entry in sorted(content.items()):
        ing = ingredients.get(iid)
        if ing is None:
            fail(iid, "no such ingredient in ingredients.json")
            continue

        allowed = source_text(ing, rules)
        blob = " ".join(filter(None, [entry.get("whatItIs"), entry.get("whyItsHere"),
                                      entry.get("whatToWatchFor")])).lower()

        # 1. Required fields and length bounds.
        for field, (lo, hi) in LIMITS.items():
            value = (entry.get(field) or "").strip()
            if field == "whatToWatchFor" and not value:
                continue
            if not value:
                fail(iid, f"{field} is missing")
            elif not lo <= len(value) <= hi:
                fail(iid, f"{field} is {len(value)} chars, want {lo}-{hi}")

        # 2. Banned phrasing.
        for phrase in BANNED:
            if phrase in blob:
                fail(iid, f"banned phrase {phrase!r}")
        for pattern, why in BANNED_PATTERNS:
            if re.search(pattern, blob):
                fail(iid, why)

        # 3. Safety verdicts must match the record.
        tiers = {risk_tier(ing["riskLevel"][s]) for s in ("dog", "cat")}
        if tiers - {"safe"}:
            for phrase in REASSURING:
                if phrase in blob:
                    fail(iid, f"reassurance {phrase!r} contradicts riskLevel {ing['riskLevel']}")
        if tiers == {"safe"} and not any(r["ingredientId"] == iid for r in rules):
            for phrase in ALARMING:
                # Allowed when the record itself uses the word — restating "toxic in
                # excess" from `notes` is the whole point. Only an *introduced* alarm
                # is a violation. Negations ("not toxic") are fine either way.
                if phrase in allowed:
                    continue
                for m in re.finditer(re.escape(phrase), blob):
                    before = blob[max(0, m.start() - 14):m.start()]
                    if not re.search(r"\b(not|non-?|isn't|aren't|no)\s*$", before):
                        fail(iid, f"alarming word {phrase!r} is not in the source record")

        # 4. No numbers the record doesn't have. Percentages and quantities are the
        #    most dangerous thing a generator can invent in this domain.
        for number in set(re.findall(r"\d+(?:[.,]\d+)?", blob)):
            if number not in allowed:
                fail(iid, f"number {number!r} appears nowhere in the source record")

        # 5. Species mentions must be grounded.
        #
        # `species` means "suitable for", not "relevant to". Propylene glycol is
        # species ["dog"] precisely *because* it is banned in cat food, and its own
        # notes say so — warning a cat owner about it is the single most useful thing
        # the entry can do. So a species may be named when it is in `species` OR when
        # the record itself mentions it. Same restatement rule as everywhere else.
        species = set(ing.get("species") or [])
        for word, key in (("dog", "dog"), ("puppy", "dog"), ("cat", "cat"), ("kitten", "cat")):
            if not re.search(rf"\b{word}s?\b", blob):
                continue
            if key in species or re.search(rf"\b{key}s?\b", allowed):
                continue
            fail(iid, f"mentions {word}, which is neither in species {sorted(species)} nor in the record")

        # 6. whatToWatchFor present exactly when the record asserts a concern.
        has_watch = bool((entry.get("whatToWatchFor") or "").strip())
        if requires_watch(ing, rules) and not has_watch:
            fail(iid, "record asserts a concern (risk/allergen/rule/toxicity) but whatToWatchFor is absent")
        if has_watch and not permits_watch(ing, rules):
            fail(iid, "whatToWatchFor invents a concern the record does not assert")

        # 7. Punctuation artifacts. These come from bulk edits over the whole file —
        #    a substitution that leaves ",," or " ." reads as sloppiness and there is
        #    no legitimate case for any of them.
        for field in ("whatItIs", "whyItsHere", "whatToWatchFor"):
            value = entry.get(field) or ""
            for artifact in (",,", "..", " ,", " .", "  ", " ;"):
                if artifact in value:
                    fail(iid, f"{field} contains {artifact!r}")
            if value and not value.rstrip().endswith((".", "!", "?")):
                fail(iid, f"{field} does not end in a full stop")
            if value and value[0] != value[0].upper():
                fail(iid, f"{field} does not start with a capital")

        # 8. No veterinary instruction.
        if re.search(r"\b(give|feed|administer|dose|dosage)\b.{0,30}\b(if|when|to your)\b", blob):
            fail(iid, "reads as feeding or dosing instruction")

    total = len(ingredients)
    covered = sum(1 for i in ingredients if i in content)
    print(f"ingredient-content.json: {covered}/{total} ingredients "
          f"({100 * covered / total:.0f}%), {len(problems)} problems")

    if "--coverage" in sys.argv:
        watch = sum(1 for e in content.values() if (e.get("whatToWatchFor") or "").strip())
        need = sum(1 for i in ingredients.values() if requires_watch(i, rules))
        allow = sum(1 for i in ingredients.values() if permits_watch(i, rules))
        print(f"  whatToWatchFor: {watch} present; {need} ingredients require one, {allow} may have one")
        missing = [i for i in ingredients if i not in content]
        if missing:
            print(f"  missing {len(missing)}, first 10: {missing[:10]}")

    for p in problems[:60]:
        print("  ✗", p)
    if len(problems) > 60:
        print(f"  … and {len(problems) - 60} more")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
