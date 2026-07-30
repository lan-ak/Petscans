import XCTest
@testable import matchkit

/// Pins the behaviour of `ScoreCalculator` that users actually experience.
///
/// These are behavioural invariants, not magic numbers: they assert the rules the
/// scoring is *supposed* to enforce (an allergen always wins, a toxic ingredient
/// always forces Avoid, rank matters) rather than that a particular product scores
/// 87.3. Numeric pins would break on every deliberate tuning change and teach
/// people to update the expectation without reading it.
///
/// Whole-catalog score movement is audited separately by `matchkit score-delta`.
final class ScoringTests: XCTestCase {
    private let matcher = IngredientMatcher()
    private let calculator = ScoreCalculator()
    private var data: IngredientData { TestSupport.liveData }

    // `Category` is qualified: XCTest also exposes a `Category`, and the bare name
    // is ambiguous inside a test target.
    private func score(_ label: String,
                       species: Species = .dog,
                       category: matchkit.Category = .food,
                       allergens: [String] = [],
                       petName: String? = nil,
                       groups: Set<AvoidanceGroup> = []) -> ScoreBreakdown {
        calculator.calculate(
            species: species, category: category,
            matched: matcher.match(rawIngredients: label, data: data),
            data: data, petAllergens: allergens, petName: petName, avoidanceGroups: groups)
    }

    // MARK: - The invariants users depend on

    func testAllergenMatchAlwaysForcesZeroAndAvoid() {
        // Documented as the one absolute in ScoreCalculator: any allergen match is
        // total 0 regardless of how good the rest of the food is.
        let breakdown = score("Chicken, Brown Rice, Salmon Oil, Blueberries",
                              allergens: ["chicken"], petName: "Max")
        XCTAssertEqual(breakdown.total, 0)
        XCTAssertEqual(breakdown.suitability, 0)
        XCTAssertEqual(breakdown.ratingLabel, .avoid)
        XCTAssertFalse(breakdown.allergenFlags.isEmpty)
    }

    func testAllergenMatchingIsSubstringBased() {
        // `checkAllergenSuitability` matches on substrings of commonName, so an
        // owner avoiding "chicken" is also protected from chicken meal and chicken
        // fat. Any row tag in the UI must use this same predicate or it will
        // disagree with the score.
        let breakdown = score("Chicken Meal, Rice", allergens: ["chicken"], petName: "Max")
        XCTAssertEqual(breakdown.total, 0)
        XCTAssertFalse(breakdown.allergenFlags.isEmpty)
    }

    func testNoAllergensMeansFullSuitability() {
        let breakdown = score("Brown Rice, Barley", allergens: ["chicken"], petName: "Max")
        XCTAssertEqual(breakdown.suitability, 100)
        XCTAssertTrue(breakdown.allergenFlags.isEmpty)
    }

    func testToxicIngredientForcesAvoidRegardlessOfScore() {
        // Xylitol is the emergency case. A food that is otherwise excellent must
        // still be labelled Avoid.
        let breakdown = score("Chicken, Brown Rice, Xylitol")
        XCTAssertEqual(breakdown.ratingLabel, .avoid,
                       "a toxic ingredient must override the numeric score")
    }

    func testCautionIngredientDowngradesTheLabel() {
        let breakdown = score("Chicken, Brown Rice, Garlic")
        XCTAssertNotEqual(breakdown.ratingLabel, .excellent)
    }

    func testCleanFoodIsNotDowngraded() {
        let breakdown = score("Chicken, Brown Rice, Carrots, Blueberries")
        XCTAssertTrue(breakdown.allergenFlags.isEmpty)
        XCTAssertNil(breakdown.safetyExplanation?.labelOverride)
    }

    // MARK: - Rank weighting

    func testEarlierIngredientsCarryMoreWeight() {
        // Rank weight is exp(-0.22 * (rank - 1)); a concerning ingredient first
        // must cost more than the same ingredient last.
        let early = score("Garlic, Chicken, Brown Rice, Carrots, Barley, Peas")
        let late = score("Chicken, Brown Rice, Carrots, Barley, Peas, Garlic")
        XCTAssertLessThan(early.safety, late.safety)
    }

    func testUnknownIngredientsCostSafety() {
        let known = score("Chicken, Brown Rice, Carrots")
        let unknown = score("Zzqx Nonsense, Wibble Compound, Flurb Extract")
        XCTAssertLessThan(unknown.safety, known.safety)
        XCTAssertEqual(unknown.unmatched.count, 3)
        XCTAssertEqual(unknown.matchedCount, 0)
    }

    // MARK: - Species-specific risk

    func testPropyleneGlycolIsScoredPerSpecies() {
        // FDA-banned in cat food (Heinz body anaemia), permitted for dogs. This is
        // the case the per-species RiskLevel exists for; collapsing it to one value
        // would either over-warn dog owners or under-warn cat owners.
        let forDog = score("Chicken, Propylene Glycol", species: .dog)
        let forCat = score("Chicken, Propylene Glycol", species: .cat)
        XCTAssertLessThanOrEqual(forCat.safety, forDog.safety)
    }

    // MARK: - Avoidance groups

    func testAvoidanceGroupsLowerTheScoreButNeverForceAvoid() {
        // Documented intent: owner-selected groups are a soft signal — they nudge
        // the rating down and raise a warning, but only allergens and toxics force
        // Avoid. If this ever inverts, an owner ticking a preference box would be
        // told their food is dangerous.
        let label = "Chicken, Corn Syrup, Artificial Colors, BHA, Xanthan Gum"
        let without = score(label)
        let with = score(label, groups: Set(AvoidanceGroup.allCases))

        XCTAssertLessThanOrEqual(with.total, without.total)
        if without.ratingLabel != .avoid {
            XCTAssertNotEqual(with.ratingLabel, .avoid,
                              "avoidance groups must not be able to force Avoid on their own")
        }
        XCTAssertTrue(with.flags.contains { $0.type == .avoidanceGroup })
    }

    // MARK: - Structural guarantees

    func testScoresAlwaysStayInRange() {
        for label in ["Chicken, Rice",
                      "Xylitol, Garlic, Onion, Chocolate, Grapes",
                      "Zzqx, Wibble, Flurb",
                      ""] {
            let breakdown = score(label)
            XCTAssertTrue((0...100).contains(breakdown.total), "total \(breakdown.total) for '\(label)'")
            XCTAssertTrue((0...100).contains(breakdown.safety), "safety \(breakdown.safety) for '\(label)'")
            XCTAssertTrue((0...100).contains(breakdown.suitability))
            if let processing = breakdown.processing {
                XCTAssertTrue((0...100).contains(processing))
            }
        }
    }

    func testCountsAreConsistent() {
        let breakdown = score("Chicken, Brown Rice, Zzqx Nonsense")
        XCTAssertEqual(breakdown.totalCount, 3)
        XCTAssertEqual(breakdown.matchedCount + breakdown.unmatched.count, breakdown.totalCount)
        XCTAssertLessThanOrEqual(breakdown.matchRate, 1.0)
    }

    func testEmptyLabelDoesNotCrashOrFabricateConfidence() {
        let breakdown = score("")
        XCTAssertEqual(breakdown.totalCount, 0)
        XCTAssertEqual(breakdown.matchRate, 0)
        XCTAssertFalse(breakdown.scoresAreMissing, "a real calculation is never 'missing'")
    }

    func testScoringIsDeterministic() {
        let label = "Chicken, Brown Rice, Garlic, Xanthan Gum, Vitamin B12 Supplement, Potato"
        let first = score(label)
        for _ in 0..<20 {
            let again = score(label)
            XCTAssertEqual(again.total, first.total)
            XCTAssertEqual(again.safety, first.safety)
            XCTAssertEqual(again.ratingLabel, first.ratingLabel)
        }
    }

    func testFreshlyCalculatedBreakdownSurvivesPersistence() {
        // The whole scan round trip: score, encode as Scan would, decode back.
        let original = score("Chicken, Brown Rice, Garlic", allergens: [], petName: nil)
        let decoded = try! JSONDecoder().decode(ScoreBreakdown.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.total, original.total)
        XCTAssertEqual(decoded.ratingLabel, original.ratingLabel)
        XCTAssertEqual(decoded.flags.count, original.flags.count)
        XCTAssertFalse(decoded.scoresAreMissing)
    }
}

/// `RiskTier` replaced three separate `contains(...)` ladders — in
/// `ScoreCalculator.basePenalty`, the detail-sheet badge and the ingredient row —
/// that had already drifted apart. The extraction must not move a single score,
/// so the old ladder's exact behaviour is pinned here, quirks included.
final class RiskTierTests: XCTestCase {
    /// The original `ScoreCalculator.basePenalty`, verbatim, as the oracle.
    private func legacyPenalty(_ riskLevel: String) -> Double {
        let r = riskLevel.lowercased()
        if r.contains("toxic") { return 40 }
        if r.contains("caution") { return 15 }
        if r.contains("moderation") { return 6 }
        if r.contains("safe_for_most") { return 2 }
        return 0
    }

    func testMatchesTheLadderItReplacedOnEveryValueInTheData() {
        // Not a hand-written list — every risk level actually present in
        // ingredients.json, for both species.
        var values = Set<String>()
        for ingredient in TestSupport.liveData.ingredients.values {
            values.insert(ingredient.riskLevel.dog)
            values.insert(ingredient.riskLevel.cat)
        }
        XCTAssertFalse(values.isEmpty)

        for value in values.sorted() {
            XCTAssertEqual(RiskTier(value).basePenalty, legacyPenalty(value),
                           "penalty changed for risk level '\(value)'")
        }
    }

    func testOrderingQuirksArePreserved() {
        // "safe_in_moderation" contains both "safe" and "moderation"; checking in
        // the wrong order would score it as safe.
        XCTAssertEqual(RiskTier("safe_in_moderation"), .moderation)
        XCTAssertEqual(RiskTier("safe_for_most"), .mostlySafe)
        // Deliberately preserved quirk: this fell through the old ladder entirely.
        XCTAssertEqual(RiskTier("safe_in_small_amounts"), .safe)
        XCTAssertEqual(RiskTier("safe"), .safe)
        XCTAssertEqual(RiskTier("toxic"), .toxic)
        XCTAssertEqual(RiskTier("caution"), .caution)
    }

    func testOnlyToxicAndCautionAreSurfacedOnARow() {
        // What the row indicator keys off. If `moderation` ever became concerning,
        // markers would reappear on a large share of rows — the clutter this removed.
        XCTAssertTrue(RiskTier.toxic.isConcerning)
        XCTAssertTrue(RiskTier.caution.isConcerning)
        XCTAssertFalse(RiskTier.moderation.isConcerning)
        XCTAssertFalse(RiskTier.mostlySafe.isConcerning)
        XCTAssertFalse(RiskTier.safe.isConcerning)
    }
}
