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

    func testAllergenMatchingCoversPreparationsOfTheSameIngredient() {
        // An owner avoiding "chicken" is also protected from chicken meal and chicken fat —
        // now via `AllergenFamily`, which matches by ingredient id and falls back to a
        // whole-word name match. It used to be a raw substring test; see
        // `testAllergenDoesNotMatchAWordThatMerelyContainsIt` for why that had to go. Any
        // row tag in the UI must use this same predicate or it will disagree with the score.
        let breakdown = score("Chicken Meal, Rice", allergens: ["chicken"], petName: "Max")
        XCTAssertEqual(breakdown.total, 0)
        XCTAssertFalse(breakdown.allergenFlags.isEmpty)
    }

    func testNoAllergensMeansFullSuitability() {
        let breakdown = score("Brown Rice, Barley", allergens: ["chicken"], petName: "Max")
        XCTAssertEqual(breakdown.suitability, 100)
        XCTAssertTrue(breakdown.allergenFlags.isEmpty)
    }

    // MARK: - Allergen families
    //
    // The allergen check was a substring test on the ingredient's display name. These are
    // the ways that was wrong — the first four each reachable from a default quick-pick
    // chip, the last guarding the narrowing the replacement could have introduced.

    func testDairyAllergenMatchesDairyIngredientsThatDoNotSayDairy() {
        // No ingredient in the database is named "dairy", so this chip previously matched
        // nothing at all and the owner was told their pet was in the clear.
        for label in ["Dried Whey, Rice", "Buttermilk, Barley", "Casein, Oats", "Cheese Powder, Rice"] {
            let breakdown = score(label, allergens: ["dairy"], petName: "Max")
            XCTAssertEqual(breakdown.total, 0, "\(label) should trip a dairy allergy")
            XCTAssertFalse(breakdown.allergenFlags.isEmpty, "\(label) should flag")
        }
    }

    func testFishAllergenMatchesNamedSpecies() {
        // 43 fish ingredients, only 14 with "fish" in the name. Salmon in a cat food is the
        // single most likely way to miss a fish allergy.
        for label in ["Salmon, Rice", "Tuna, Barley", "Herring Meal, Oats", "Sardine, Rice",
                      "Haddock, Rice"] {
            let breakdown = score(label, species: .cat, allergens: ["fish"], petName: "Luna")
            XCTAssertEqual(breakdown.total, 0, "\(label) should trip a fish allergy")
        }
    }

    func testGenericHeadTermsTripTheirAllergy() {
        // The four commonest allergen strings in the catalog had no ingredient at all, so
        // they matched nothing and tripped nothing: "fish broth" alone appears 1,505 times.
        XCTAssertEqual(score("Fish, Rice", species: .cat, allergens: ["fish"]).total, 0)
        XCTAssertEqual(score("Fish Broth, Rice", species: .cat, allergens: ["fish"]).total, 0)
        XCTAssertEqual(score("Natural Fish Flavor, Rice", species: .cat, allergens: ["fish"]).total, 0)
        XCTAssertEqual(score("Milk, Rice", allergens: ["dairy"]).total, 0)
        XCTAssertEqual(score("Poultry, Rice", allergens: ["chicken"]).total, 0)
        XCTAssertEqual(score("Poultry Broth, Rice", allergens: ["chicken"]).total, 0)
        XCTAssertEqual(score("Soy, Rice", allergens: ["soy"]).total, 0)
        XCTAssertEqual(score("Soy Grits, Rice", allergens: ["soy"]).total, 0)
    }

    func testCustomAllergenGetsItsFamilyWhenItNamesOne() {
        // Custom allergens come from the ingredient search and are stored as the
        // ingredient's own name, so they carry no chip family — and whole-word matching
        // cannot reach inside a compound. "milk" names `ing_milk`, which is dairy, so the
        // family applies and Buttermilk is caught.
        XCTAssertEqual(score("Buttermilk, Rice", allergens: ["milk"], petName: "Max").total, 0)
        XCTAssertEqual(score("Dried Whey, Rice", allergens: ["milk"], petName: "Max").total, 0)

        // ...while a *specific* ingredient still means only itself. Widening every custom
        // allergen would make picking Salmon condemn Tuna, Cod and 39 other fish.
        let salmonPicker = score("Tuna, Rice", species: .cat, allergens: ["salmon"], petName: "Luna")
        XCTAssertTrue(salmonPicker.allergenFlags.isEmpty, "salmon is not every fish")
        XCTAssertTrue(score("Beef Tallow, Rice", allergens: ["beef liver"]).allergenFlags.isEmpty,
                      "beef liver is not every beef ingredient")
        XCTAssertEqual(score("Salmon, Rice", species: .cat, allergens: ["salmon"]).total, 0,
                       "...but it still catches itself")

        // And the buckwheat false positive does not come back with any of it.
        XCTAssertTrue(score("Buckwheat, Rice", allergens: ["wheat"], petName: "Max").allergenFlags.isEmpty)
    }

    func testACuratedFamilyIsAuthoritative() {
        // When an allergen resolves to a family, membership is the whole answer — the name
        // fallback must not be able to re-admit what the family deliberately excludes.
        // These all forced score 0 / "Avoid" while the fallback still ran.
        XCTAssertTrue(score("Milk Thistle, Rice", allergens: ["milk"]).allergenFlags.isEmpty,
                      "milk thistle is a plant")
        XCTAssertTrue(score("Peanut Butter, Rice", allergens: ["butter"]).allergenFlags.isEmpty,
                      "peanut butter is not dairy")
        XCTAssertTrue(score("Shea Butter, Rice", allergens: ["butter"]).allergenFlags.isEmpty,
                      "shea butter is not dairy")
        // ...while the family itself still matches.
        XCTAssertEqual(score("Buttermilk, Rice", allergens: ["butter"]).total, 0)
    }

    func testPlantMilksAreNotDairy() {
        // The bare "Milk" ingredient is a 4-char fuzzy key and the matcher resolves by
        // longest-key-first containment, so "oat milk" — 93 products — landed on dairy and
        // condemned a dairy-free food for a dairy-allergic pet.
        for label in ["Oat Milk, Rice", "Soy Milk, Rice", "Coconut Milk, Rice"] {
            XCTAssertTrue(score(label, allergens: ["dairy"]).allergenFlags.isEmpty,
                          "\(label) is not dairy")
        }
        // Soy milk must still carry its soy signal.
        XCTAssertEqual(score("Soy Milk, Rice", allergens: ["soy"]).total, 0)
    }

    func testMilkThistleIsNotDairy() {
        // The hazard created by adding a bare "Milk" ingredient. `fuzzyMatch` is
        // longest-synonym-key-first containment, so without its own entry "milk thistle"
        // would fall through onto "milk", be scored as dairy, and force "Avoid" for a
        // dairy-allergic pet over a liver botanical.
        let breakdown = score("Milk Thistle, Brown Rice", allergens: ["dairy"], petName: "Max")
        XCTAssertTrue(breakdown.allergenFlags.isEmpty, "milk thistle is a plant, not dairy")
        XCTAssertEqual(breakdown.suitability, 100)
    }

    func testShellfishAllergyCoversItsOwnFamily() {
        // "Shellfish" is pickable from the ingredient search. Without a family of its own it
        // whole-word-matched only the literal word, so a shellfish-allergic pet was told
        // "No known allergens detected" over shrimp — the same silent gap Dairy had.
        for label in ["Shrimp, Rice", "Crab Meal, Rice", "Lobster, Rice",
                      "Green-Lipped Mussel, Rice", "Squid, Rice", "Krill Oil, Rice"] {
            XCTAssertEqual(score(label, species: .cat, allergens: ["shellfish"]).total, 0,
                           "\(label) should trip a shellfish allergy")
        }
        // ...and it stays separate from finned fish in both directions.
        XCTAssertTrue(score("Salmon, Rice", species: .cat, allergens: ["shellfish"]).allergenFlags.isEmpty)
        XCTAssertTrue(score("Shrimp, Rice", species: .cat, allergens: ["fish"]).allergenFlags.isEmpty)
    }

    func testAllergenFamiliesStopAtTheEdgeOfTheAllergen() {
        // Shellfish is a different allergen (tropomyosin, not parvalbumin) and bison is the
        // novel protein owners are switched *to* for a beef allergy. Flagging either would
        // condemn exactly the food a vet recommended.
        XCTAssertTrue(score("Shrimp, Rice", species: .cat, allergens: ["fish"]).allergenFlags.isEmpty)
        // Generic "shellfish" too. It has its own ingredient precisely so it resolves
        // exactly instead of falling through fuzzy containment onto the new bare "fish".
        XCTAssertTrue(score("Shellfish, Rice", species: .cat, allergens: ["fish"]).allergenFlags.isEmpty)
        // Krill is a crustacean, not a fish — same rule as shrimp.
        XCTAssertTrue(score("Krill Oil, Rice", species: .cat, allergens: ["fish"]).allergenFlags.isEmpty)
        // ...but refined fish oils DO count as fish. Deliberate and wide: 52.7% of cat foods
        // fail the Fish chip because of this. See the note on `AllergenFamily`.
        XCTAssertEqual(score("Salmon Oil, Rice", species: .cat, allergens: ["fish"]).total, 0)
        XCTAssertEqual(score("Menhaden Oil, Rice", species: .cat, allergens: ["fish"]).total, 0)
        XCTAssertTrue(score("Bison, Rice", allergens: ["beef"]).allergenFlags.isEmpty)
        // Butter is dairy; peanut butter is not.
        XCTAssertEqual(score("Butter, Rice", allergens: ["dairy"]).total, 0)
        XCTAssertTrue(score("Peanut Butter, Rice", allergens: ["dairy"]).allergenFlags.isEmpty)
    }

    func testChickenAllergenMatchesGenericPoultry() {
        // Poultry is overwhelmingly chicken and the owner has declared the allergy, so the
        // family includes it: an over-warning is the cheaper error here.
        for label in ["Poultry Fat, Rice", "Poultry Digest, Barley", "Poultry By-Product, Oats"] {
            let breakdown = score(label, allergens: ["chicken"], petName: "Max")
            XCTAssertEqual(breakdown.total, 0, "\(label) should trip a chicken allergy")
        }

        // Known gap, deliberately not fixed here: `synonyms.json` routes the full phrase
        // "poultry by-product meal" to `ing_meat_by_products`, so the poultry identity is
        // lost during *matching*, before the allergen check ever runs. Repointing that
        // synonym changes what every product containing the phrase scores as, which needs
        // its own coverage/score-delta run rather than riding along with an allergen fix.
        let knownGap = score("Poultry By-Product Meal, Rice", allergens: ["chicken"], petName: "Max")
        XCTAssertTrue(knownGap.allergenFlags.isEmpty,
                      "if this now flags, the synonym was repointed — delete this assertion")
    }

    func testAllergenDoesNotMatchAWordThatMerelyContainsIt() {
        // Buckwheat is not a wheat and Acorn squash is not corn. Both used to force "Avoid".
        let buckwheat = score("Buckwheat, Brown Rice", allergens: ["wheat"], petName: "Max")
        XCTAssertTrue(buckwheat.allergenFlags.isEmpty, "buckwheat is not wheat")
        XCTAssertEqual(buckwheat.suitability, 100)

        let acorn = score("Acorn Squash, Brown Rice", allergens: ["corn"], petName: "Max")
        XCTAssertTrue(acorn.allergenFlags.isEmpty, "acorn squash is not corn")

        // ...while the real thing still trips.
        XCTAssertEqual(score("Wheat Bran, Rice", allergens: ["wheat"]).total, 0)
        XCTAssertEqual(score("Corn Gluten Meal, Rice", allergens: ["corn"]).total, 0)
    }

    func testCustomAllergensStillMatchAcrossSingularAndPlural() {
        // Not covered by the families — these come from the full ingredient search, which
        // stores whatever the ingredient's own name is. The substring test used to catch
        // these by accident; whole-word matching has to keep them on purpose.
        XCTAssertEqual(score("Potatoes, Rice", allergens: ["potato"], petName: "Max").total, 0)
        XCTAssertEqual(score("Sweet Potatoes, Rice", allergens: ["potato"], petName: "Max").total, 0)
        XCTAssertEqual(score("Sardines, Rice", allergens: ["sardine"], petName: "Max").total, 0)
        // ...and the plural must not become a new way to match a different word.
        XCTAssertTrue(score("Buckwheat, Rice", allergens: ["wheat"], petName: "Max").allergenFlags.isEmpty)
    }

    func testOneIngredientRaisesOneAllergenFlag() {
        // Overlapping families would otherwise list and penalise the same row twice.
        let breakdown = score("Salmon Oil, Rice", species: .cat,
                              allergens: ["fish", "salmon"], petName: "Luna")
        XCTAssertEqual(breakdown.allergenFlags.count, 1)
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
