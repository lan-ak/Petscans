import XCTest
@testable import matchkit

/// Guards `ingredient-content.json`.
///
/// That file is model-authored and ships without human review, so these checks
/// are the review. They enforce the one rule the content is written under: **an
/// entry may only restate, in plainer words, what the ingredient's record already
/// asserts.**
///
/// `tools/validate-ingredient-content.py` runs the full rule set during authoring
/// and in CI. This suite covers the subset that must hold at the point the app
/// actually reads the data — including the loader path, which the Python script
/// cannot exercise.
final class ContentValidationTests: XCTestCase {
    private var data: IngredientData { TestSupport.liveData }

    func testEveryIngredientHasContent() {
        let missing = data.ingredients.keys.filter { data.content[$0] == nil }.sorted()
        XCTAssertTrue(missing.isEmpty,
            "\(missing.count) of \(data.ingredients.count) ingredients have no authored content: "
          + missing.prefix(10).joined(separator: ", "))
    }

    func testNoContentEntryIsOrphaned() {
        let orphans = data.content.keys.filter { data.ingredients[$0] == nil }.sorted()
        XCTAssertTrue(orphans.isEmpty,
            "content exists for ingredients that no longer exist: " + orphans.joined(separator: ", "))
    }

    func testNoEntryIsEmpty() {
        let empty = data.content.filter { $0.value.isEmpty }.keys.sorted()
        XCTAssertTrue(empty.isEmpty, "entries with no prose: " + empty.joined(separator: ", "))
    }

    /// The check that matters most. A reassuring line on a toxic ingredient is the
    /// one failure that could actually hurt an animal.
    func testNothingReassuringIsSaidAboutANonSafeIngredient() {
        let reassuring = ["completely safe", "perfectly safe", "totally safe",
                          "no risk", "harmless", "nothing to worry about"]
        for (id, entry) in data.content {
            guard let ingredient = data.ingredients[id] else { continue }
            let tiers = [ingredient.riskLevel.dog, ingredient.riskLevel.cat].map(RiskTier.init)
            guard tiers.contains(where: { $0 != .safe }) else { continue }

            let blob = [entry.whatItIs, entry.whyItsHere, entry.whatToWatchFor ?? ""]
                .joined(separator: " ").lowercased()
            for phrase in reassuring {
                XCTAssertFalse(blob.contains(phrase),
                    "\(id) is rated \(ingredient.riskLevel.dog)/\(ingredient.riskLevel.cat) "
                  + "but its content says '\(phrase)'")
            }
        }
    }

    /// Anything the record flags as a structural concern must carry a warning.
    /// Silence on a toxic ingredient is worse than saying nothing at all elsewhere.
    func testEveryStructuralConcernCarriesAWarning() {
        var missing: [String] = []
        for (id, ingredient) in data.ingredients {
            let tiers = [ingredient.riskLevel.dog, ingredient.riskLevel.cat].map(RiskTier.init)
            let allergen = (ingredient.allergenOrSensitizationRisk ?? "").lowercased()
            let concerning = tiers.contains { $0 != .safe }
                || allergen.contains("medium") || allergen.contains("high")
                || ingredient.toxicitySymptoms?.isEmpty == false
                || data.rulesByIngredient[id]?.isEmpty == false
            guard concerning else { continue }

            let watch = data.content[id]?.whatToWatchFor?.trimmingCharacters(in: .whitespaces) ?? ""
            if watch.isEmpty { missing.append(id) }
        }
        XCTAssertTrue(missing.isEmpty,
            "\(missing.count) ingredients the record flags as concerning have no whatToWatchFor: "
          + missing.sorted().prefix(10).joined(separator: ", "))
    }

    /// Every toxic ingredient must name its risk plainly rather than gesturing at it.
    func testToxicIngredientsSaySo() {
        for (id, ingredient) in data.ingredients {
            let tiers = [ingredient.riskLevel.dog, ingredient.riskLevel.cat].map(RiskTier.init)
            guard tiers.contains(.toxic) else { continue }
            let watch = (data.content[id]?.whatToWatchFor ?? "").lowercased()
            XCTAssertTrue(watch.contains("toxic") || watch.contains("critical")
                          || watch.contains("fatal") || watch.contains("emergency"),
                "\(id) is rated toxic but its warning does not say so: \(watch)")
        }
    }

    /// Content is display-only. If it ever reached the scorer, a generated sentence
    /// would start moving scores — the boundary this whole design rests on.
    func testContentIsNotReadByScoring() throws {
        let matcher = IngredientMatcher()
        let calculator = ScoreCalculator()
        let matched = matcher.match(rawIngredients: "Chicken, Brown Rice, Garlic", data: data)

        let withContent = calculator.calculate(species: .dog, category: .food, matched: matched,
                                               data: data, avoidanceGroups: [])
        let stripped = IngredientData(ingredients: data.ingredients, rules: data.rules,
                                      synonyms: data.synonyms, avoidanceGroups: data.avoidanceGroups,
                                      content: [:])
        let withoutContent = calculator.calculate(species: .dog, category: .food, matched: matched,
                                                  data: stripped, avoidanceGroups: [])

        XCTAssertEqual(withContent.total, withoutContent.total)
        XCTAssertEqual(withContent.safety, withoutContent.safety)
        XCTAssertEqual(withContent.ratingLabel, withoutContent.ratingLabel)
    }

    /// The fallback has to hold for every record, because it is what shows whenever
    /// authored content is absent — including for any ingredient added later.
    func testComposedSummaryIsWellFormedForEveryIngredient() {
        for ingredient in data.sortedIngredients {
            guard let summary = ingredient.composedSummary() else {
                XCTFail("\(ingredient.id) produces no composed summary")
                continue
            }
            XCTAssertFalse(summary.contains("  "), "\(ingredient.id): doubled space in '\(summary)'")
            XCTAssertFalse(summary.contains(".."), "\(ingredient.id): doubled period in '\(summary)'")
            XCTAssertFalse(summary.contains(" ."), "\(ingredient.id): space before period in '\(summary)'")
            XCTAssertFalse(summary.lowercased().contains(" a a "), "\(ingredient.id): 'a a' in '\(summary)'")
            XCTAssertTrue(summary.hasSuffix("."), "\(ingredient.id): no terminal period in '\(summary)'")
            XCTAssertGreaterThan(summary.count, 20, "\(ingredient.id): summary too short")
        }
    }

    /// Copy-paste across 620 hand-written entries is the likeliest authoring error,
    /// and the one a reader would notice immediately.
    func testNoTwoIngredientsShareTheSameDescription() {
        var seen: [String: String] = [:]
        var collisions: [String] = []
        for (id, entry) in data.content.sorted(by: { $0.key < $1.key }) {
            let key = entry.whatItIs.lowercased()
            if let other = seen[key] { collisions.append("\(id) == \(other)") }
            seen[key] = id
        }
        XCTAssertTrue(collisions.isEmpty,
            "duplicate whatItIs text: " + collisions.prefix(10).joined(separator: ", "))
    }

    func testNoEntryMentionsASpeciesTheIngredientAndRecordBothExclude() {
        for (id, entry) in data.content {
            guard let ingredient = data.ingredients[id] else { continue }
            let blob = [entry.whatItIs, entry.whyItsHere, entry.whatToWatchFor ?? ""]
                .joined(separator: " ").lowercased()
            // The record's own text counts as grounding: propylene glycol is species
            // ["dog"] precisely because its notes explain it is banned in cat food.
            let record = [ingredient.notes ?? "", ingredient.toxicDose?.keys.joined(separator: " ") ?? "",
                          ingredient.toxicDose?.values.joined(separator: " ") ?? ""]
                .joined(separator: " ").lowercased()
            let declared = Set(ingredient.species.map(\.rawValue))

            // Word boundaries, not substrings: "medicated" contains "cat" and
            // "medication" contains "cat", which flagged two correct entries.
            for (word, key) in [("cat", "cat"), ("dog", "dog")] {
                let pattern = "\\b\(word)s?\\b"
                guard blob.range(of: pattern, options: .regularExpression) != nil else { continue }
                XCTAssertTrue(declared.contains(key) || record.contains(key),
                    "\(id) mentions \(word) but it is neither in species \(declared.sorted()) nor in the record")
            }
        }
    }
}
