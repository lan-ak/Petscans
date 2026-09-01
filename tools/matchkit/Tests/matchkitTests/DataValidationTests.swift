import XCTest
@testable import matchkit

/// Integrity checks on the four hand-maintained data files.
///
/// `ingredients.json` (625 entries), `synonyms.json` (826 pairs) and `rules.json`
/// (47 rules) have no generator, no schema and no CI validation — they are edited
/// by hand and shipped as bundled resources. A synonym pointing at a deleted
/// ingredient id, or a rule referencing one, fails silently at runtime: the
/// matcher just returns an id that resolves to nothing, and the ingredient is
/// treated as unknown.
///
/// `tools/gen-avoidance-groups.py` already hard-fails on a vanished id for its own
/// file. This is the equivalent guard for everything else.
final class DataValidationTests: XCTestCase {
    private var data: IngredientData { TestSupport.liveData }

    func testEverySynonymResolvesToARealIngredient() {
        let dangling = data.synonyms
            .filter { data.ingredients[$0.value] == nil }
            .sorted { $0.key < $1.key }
        XCTAssertTrue(dangling.isEmpty,
            "\(dangling.count) synonyms point at ingredient ids that do not exist. "
          + "The matcher will resolve these tokens to nothing and score them as unknown: "
          + dangling.prefix(10).map { "\($0.key) -> \($0.value)" }.joined(separator: ", "))
    }

    // MARK: - Allergen families
    //
    // `AllergenFamily` is a hand-maintained snapshot of `ingredients.json`, and the failure
    // mode when it drifts is silent and safety-relevant: an ingredient that belongs to a
    // family but isn't listed falls back to a whole-word name match, so a newly added
    // "Ricotta" or "Barramundi" would simply never trip a dairy or fish allergy. That is
    // exactly the bug these families were introduced to fix, and adding ingredients is the
    // one thing guaranteed to reintroduce it. These two tests make growth fail loudly.

    func testEveryAllergenFamilyIdStillExists() {
        let dangling = AllergenFamily.ingredientIds
            .flatMap { family, ids in ids.filter { data.ingredients[$0] == nil }.map { (family, $0) } }
            .sorted { $0.1 < $1.1 }
        XCTAssertTrue(dangling.isEmpty,
            "\(dangling.count) allergen-family ids no longer exist in ingredients.json. "
          + "Those ingredients silently drop out of the family and stop tripping the allergy: "
          + dangling.prefix(10).map { "\($0.0) -> \($0.1)" }.joined(separator: ", "))
    }

    func testNoIngredientLooksLikeAFamilyMemberWithoutBeingClassified() {
        // Names that read like a family member. Anything matching has to be either in the
        // family or in `deliberatelyExcluded` below, with a reason.
        let looksLike: [String: String] = [
            "dairy": "milk|whey|cheese|casein|lactose|yogurt|kefir|curd|ghee|butter|cream",
            "fish":  "fish|salmon|tuna|herring|anchov|sardine|menhaden|mackerel|trout|pollock|tilapia|haddock|cod|capelin|smelt|whiting|halibut",
            // \b on the short words: bare "hen" also matches p-hen-ylalanine, pant-hen-ol,
            // pantot-hen-ic and p-hen-oxyethanol.
            "chicken": "chicken|poultry|\\bhen\\b|\\bbroiler\\b",
            "beef":  "beef|\\bveal\\b|tallow",
            "lamb":  "lamb|mutton",
            "wheat": "wheat|spelt|semolina|durum|farina",
            "corn":  "\\bcorn|maize|hominy",
            "soy":   "soy|tofu|edamame",
            "shellfish": "shellfish|shrimp|prawn|crab|lobster|crayfish|clam|mussel|oyster|scallop|squid|octopus|krill",
        ]
        // Each of these reads like a family member and is deliberately not one.
        let deliberatelyExcluded: Set<String> = [
            "ing_buckwheat",        // a seed, not a wheat, and gluten-free
            "ing_acorn_squash",     // not corn
            "ing_butternut_squash", // not dairy
            "ing_peanut_butter",    // not dairy
            "ing_shea_butter",      // not dairy
            // Excluded from `fish` only — its *name* contains "fish" but shellfish allergy is
            // a different allergen. It is a full member of the `shellfish` family, and
            // membership is checked before this set, so listing it here does not weaken it.
            "ing_shellfish",
            // Krill needs no entry: it is in the `shellfish` family and its name never
            // matches the fish pattern.
            "ing_milk_thistle",     // a plant; shares only the word
        ]

        var unclassified: [String] = []
        for (family, pattern) in looksLike {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let listed = AllergenFamily.ingredientIds[family] ?? []
            for (id, ingredient) in data.ingredients {
                guard !listed.contains(id), !deliberatelyExcluded.contains(id) else { continue }
                let name = ingredient.commonName
                let range = NSRange(name.startIndex..., in: name)
                guard regex.firstMatch(in: name, range: range) != nil else { continue }
                // The name fallback still protects these, so only flag the ones it cannot
                // reach — where the family word does not appear as a whole word.
                guard !AllergenFamily.containsWholeWord(family, in: name) else { continue }
                unclassified.append("\(family): \(id) (\(name))")
            }
        }

        XCTAssertTrue(unclassified.isEmpty,
            "\(unclassified.count) ingredient(s) look like an allergen family member but are "
          + "neither in the family nor deliberately excluded. Left alone they will never trip "
          + "that allergy. Add them to `AllergenFamily`, or to `deliberatelyExcluded` here "
          + "with a reason: " + unclassified.sorted().joined(separator: ", "))
    }

    func testEveryQuickPickChipHasAFamily() {
        // A chip with no family falls back to bare name matching — which is how "dairy",
        // matching nothing at all, shipped for four versions.
        for species in [Species.dog, .cat] {
            for chip in QuickPickAllergens.list(for: species) {
                XCTAssertNotNil(AllergenFamily.ingredientIds[chip.id],
                                "quick-pick '\(chip.id)' has no ingredient family")
            }
        }
    }

    func testEveryRuleTargetsARealIngredient() {
        let dangling = data.rules
            .filter { data.ingredients[$0.ingredientId] == nil }
            .map(\.id)
        XCTAssertTrue(dangling.isEmpty,
            "\(dangling.count) rules target missing ingredients, so they can never fire: "
          + dangling.prefix(10).joined(separator: ", "))
    }

    func testEveryAvoidanceGroupEntryTargetsARealIngredient() {
        let dangling = data.avoidanceGroups.keys
            .filter { data.ingredients[$0] == nil }
            .sorted()
        XCTAssertTrue(dangling.isEmpty,
            "\(dangling.count) avoidance-group entries reference missing ingredients — "
          + "re-run tools/gen-avoidance-groups.py: " + dangling.prefix(10).joined(separator: ", "))
    }

    func testIngredientIdsAreUnique() throws {
        // `IngredientData` de-duplicates last-wins so a duplicate can't trap at launch;
        // this is what surfaces it instead of letting one entry silently win.
        let raw = try Data(contentsOf: TestSupport.dataDirectory.appendingPathComponent("ingredients.json"))
        let list = try JSONDecoder().decode([Ingredient].self, from: raw)
        var seen = Set<String>()
        let duplicates = list.map(\.id).filter { !seen.insert($0).inserted }.sorted()
        XCTAssertTrue(duplicates.isEmpty, "duplicate ingredient ids: \(duplicates.joined(separator: ", "))")
        XCTAssertEqual(list.count, data.ingredients.count)
    }

    func testRuleIdsAreUnique() {
        var seen = Set<String>()
        let duplicates = data.rules.map(\.id).filter { !seen.insert($0).inserted }.sorted()
        XCTAssertTrue(duplicates.isEmpty, "duplicate rule ids: \(duplicates.joined(separator: ", "))")
    }

    /// Every ingredient must be reachable by an exact lookup, or be knowingly
    /// shadowed by a curated synonym that maps its name somewhere else.
    ///
    /// Anything neither of those can only be found by the fuzzy fallback — a guess —
    /// so its risk level, rules and notes are effectively unreachable. Before
    /// `IngredientData` began deriving keys from ingredient names, 311 of 625 were
    /// in that state.
    func testEveryIngredientIsReachableByAnExactLookup() {
        let reachable = Set(data.synonyms.values)
        let unreachable = data.ingredients.values
            .filter { !reachable.contains($0.id) }
            // Shadowed = the name *does* produce a key, but a curated synonym owns it.
            // That's a curation decision, covered by the test below, not a hole.
            .filter { data.synonyms[IngredientMatcher.normalizeToken($0.commonName)] == nil }
            .map(\.id).sorted()

        XCTAssertTrue(unreachable.isEmpty,
            "\(unreachable.count) ingredients cannot be reached by any exact lookup — the matcher "
          + "can only find them by guessing: " + unreachable.prefix(15).joined(separator: ", "))
    }

    /// Reports ingredients whose own name is claimed by a curated synonym pointing
    /// at a *different* ingredient — usually a more generic one.
    ///
    /// Not a failure: some of these generalizations are deliberate, because rules
    /// and avoidance groups hang off the generic entry. But each is a specific
    /// ingredient that can never be matched, so the list is worth keeping visible.
    /// Letting names win instead was measured and moved 92% of products' scores —
    /// too broad to adopt blindly. See `IngredientData.synonymsIncludingIngredientNames`.
    func testIngredientsShadowedByCuratedSynonyms() {
        let shadowed = data.ingredients.values.compactMap { ingredient -> String? in
            let key = IngredientMatcher.normalizeToken(ingredient.commonName)
            guard let owner = data.synonyms[key], owner != ingredient.id else { return nil }
            return "\(ingredient.id) (\"\(ingredient.commonName)\") -> \(owner)"
        }.sorted()

        // Pinned at the count measured on 2026-07-30 so the list can only shrink
        // deliberately. Raising it means another specific ingredient just became
        // unmatchable by its own name.
        XCTAssertLessThanOrEqual(shadowed.count, 142,
            "more ingredients are now shadowed than before:\n" + shadowed.joined(separator: "\n"))
        if !shadowed.isEmpty {
            print("[data] \(shadowed.count) ingredients shadowed by curated synonyms:")
            shadowed.forEach { print("  \($0)") }
        }
    }

    func testNoIngredientHasABlankName() {
        let blank = data.ingredients.values
            .filter { $0.commonName.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(\.id)
        XCTAssertTrue(blank.isEmpty, "ingredients with no commonName: \(blank.joined(separator: ", "))")
    }

    func testRiskLevelsUseKnownVocabulary() {
        // `ScoreCalculator.basePenalty` and the UI both switch on substrings of this
        // string. A value outside the known set silently scores as safe.
        let known = ["safe", "safe_in_moderation", "safe_for_most", "safe_in_small_amounts", "caution", "toxic"]
        var unknown: Set<String> = []
        for ingredient in data.ingredients.values {
            for level in [ingredient.riskLevel.dog, ingredient.riskLevel.cat] where !known.contains(level) {
                unknown.insert(level)
            }
        }
        XCTAssertTrue(unknown.isEmpty,
            "risk levels outside the vocabulary ScoreCalculator understands — these score as safe: "
          + unknown.sorted().joined(separator: ", "))
    }

    func testEveryIngredientDeclaresASpeciesAndCategory() {
        let bad = data.ingredients.values
            .filter { $0.species.isEmpty || $0.categories.isEmpty }
            .map(\.id).sorted()
        XCTAssertTrue(bad.isEmpty, "ingredients with no species or category: \(bad.prefix(10).joined(separator: ", "))")
    }

    func testSynonymKeysAreAlreadyNormalized() {
        // Lookup is `synonyms[normalizeToken(token)]`. A key that isn't in normalized
        // form — uppercase, padded, double-spaced — can never be hit by the exact
        // path and quietly degrades to the fuzzy fallback.
        let offenders = data.synonyms.keys.filter { key in
            key != key.lowercased()
                || key != key.trimmingCharacters(in: .whitespaces)
                || key.contains("  ")
        }.sorted()
        XCTAssertTrue(offenders.isEmpty,
            "\(offenders.count) synonym keys are not in normalized form and can never match exactly: "
          + offenders.prefix(10).joined(separator: " | "))
    }
}

/// `allergenOrSensitizationRisk` is mostly a plain level but 12 entries encode a
/// per-species split as `"Medium dog|High cat"`. The detail sheet used to render
/// that raw.
final class AllergenRiskTests: XCTestCase {
    private var data: IngredientData { TestSupport.liveData }

    func testPerSpeciesRiskIsSplitCorrectly() throws {
        let ingredient = try XCTUnwrap(
            data.ingredients.values.first { $0.allergenOrSensitizationRisk?.contains("|") == true },
            "no piped allergen-risk value in the data any more — this test can go")

        for species in [Species.dog, .cat] {
            let value = try XCTUnwrap(ingredient.allergenRisk(for: species))
            XCTAssertFalse(value.contains("|"), "raw piped value leaked to the UI: \(value)")
            XCTAssertFalse(value.lowercased().hasSuffix(species.rawValue),
                           "species name left in the displayed level: \(value)")
        }
    }

    func testPlainValuesArePassedThroughUnchanged() {
        let plain = data.ingredients.values.filter {
            guard let r = $0.allergenOrSensitizationRisk else { return false }
            return !r.contains("|")
        }
        XCTAssertFalse(plain.isEmpty)
        for ingredient in plain.prefix(50) {
            XCTAssertEqual(ingredient.allergenRisk(for: .dog), ingredient.allergenOrSensitizationRisk)
        }
    }

    func testNoRawPipedValueCanReachTheUIForEitherSpecies() {
        for ingredient in data.ingredients.values {
            for species in [Species.dog, .cat] {
                if let value = ingredient.allergenRisk(for: species) {
                    XCTAssertFalse(value.contains("|"), "\(ingredient.id) renders '\(value)'")
                }
            }
        }
    }
}
