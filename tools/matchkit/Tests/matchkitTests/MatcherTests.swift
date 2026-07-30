import XCTest
@testable import matchkit

/// Tests for `IngredientMatcher`, run against the real shipped database.
///
/// The specific cases below are not invented — they are the wrong matches
/// `matchkit fuzzy-audit` found in production, with their observed occurrence
/// counts across the shipped catalog. Each one fed a wrong ingredient id into
/// scoring, which reads risk level, processing level, rules and allergens from it.
final class MatcherTests: XCTestCase {
    private let matcher = IngredientMatcher()
    private var data: IngredientData { TestSupport.liveData }

    func testDatabaseActuallyLoaded() {
        XCTAssertGreaterThan(data.ingredients.count, 500, "ingredients.json failed to load")
        XCTAssertGreaterThan(data.synonyms.count, 500, "synonyms.json failed to load")
    }

    // MARK: - Determinism

    func testResolutionIsStableAcrossRepeatedRuns() {
        // The original fuzzy fallback iterated the synonyms Dictionary and took the
        // first containment hit. Swift's Dictionary order depends on a per-process
        // hash seed, so the same token could resolve differently between launches —
        // and the answer was persisted into the saved scan. Within one process the
        // order is at least stable, so this catches a regression to any
        // order-dependent structure introduced later.
        let label = "chicken fat preserved with mixed tocopherols, pearled barley, potato"
        let first = matcher.match(rawIngredients: label, data: data).map { $0.ingredientId ?? "-" }
        for _ in 0..<25 {
            XCTAssertEqual(matcher.match(rawIngredients: label, data: data).map { $0.ingredientId ?? "-" }, first)
        }
    }

    func testSynonymOrderingIsTotalAndDeterministic() {
        // `synonymsByLengthDescending` is what makes fuzzy matching reproducible.
        // Length alone is not a total order — without the secondary key, equal-length
        // keys would still fall back to hash order.
        let ordering = data.synonymsByLengthDescending
        XCTAssertEqual(ordering.count, data.synonyms.count)
        for (a, b) in zip(ordering, ordering.dropFirst()) {
            XCTAssertTrue((a.key.count, a.key) > (b.key.count, b.key),
                          "ordering must be strict: \(a.key) then \(b.key)")
        }
        // Rebuilding from the same input must give the identical sequence.
        let rebuilt = IngredientData(ingredients: data.ingredients, rules: data.rules,
                                     synonyms: data.synonyms, avoidanceGroups: data.avoidanceGroups)
        XCTAssertEqual(rebuilt.synonymsByLengthDescending.map(\.key), ordering.map(\.key))
    }

    // MARK: - The wrong matches that shipped

    func testPreservedWithMixedTocopherolsIsNotChickenFat() {
        // Observed 895 times. The synonym key "chicken fat preserved with mixed
        // tocopherols" *contained* the token, and the old reverse-containment
        // direction accepted that — so a preservative was scored as a fat.
        let resolved = matcher.resolve("preserved with mixed tocopherols", data: data)
        XCTAssertNotEqual(resolved.id, "ing_chicken_fat")
    }

    func testPotatoIsNotSweetPotato() {
        // Observed 456 times. Different ingredient, different processing level.
        let resolved = matcher.resolve("potato", data: data)
        XCTAssertNotEqual(resolved.id, "ing_sweet_potatoes")
    }

    func testFishIsNotFishOil() {
        // Observed 625 times. A protein scored as an added fat.
        let resolved = matcher.resolve("fish", data: data)
        XCTAssertNotEqual(resolved.id, "ing_fish_oil")
    }

    func testPearledBarleyResolvesToBarleyNotPear() {
        // Longest-key-first is what fixes this: "barley" beats "pear".
        let resolved = matcher.resolve("pearled barley", data: data)
        XCTAssertNotEqual(resolved.id, "ing_pear")
    }

    func testShortTokensDoNotFuzzyMatch() {
        // The length floor stops two- and three-letter fragments matching anything.
        for token in ["oil", "gum", "ash", "b12"] {
            let resolved = matcher.resolve(token, data: data)
            if resolved.confidence == .fuzzy {
                XCTFail("'\(token)' should be too short to fuzzy match, got \(resolved.id ?? "nil")")
            }
        }
    }

    // MARK: - Confidence attribution

    func testExactSynonymHitIsReportedAsExact() throws {
        let (key, expectedId) = try XCTUnwrap(data.synonyms.first { $0.key.count > 6 })
        let resolved = matcher.resolve(key, data: data)
        XCTAssertEqual(resolved.id, expectedId)
        XCTAssertEqual(resolved.confidence, .exact)
    }

    func testUnresolvableTokenIsReportedAsNone() {
        let resolved = matcher.resolve("zzqx unobtainium phlogiston", data: data)
        XCTAssertNil(resolved.id)
        XCTAssertEqual(resolved.confidence, MatchConfidence.none)
    }

    func testConfidenceAlwaysAgreesWithWhetherAnIdWasFound() {
        // An id without a confidence, or a confidence without an id, would make the
        // recognition figure and the row badges disagree.
        let sample = "Chicken, Brown Rice, Vitamin B12 Supplement, Xanthan Gum, Zzqx Nonsense"
        for mi in matcher.match(rawIngredients: sample, data: data) {
            XCTAssertEqual(mi.isMatched, mi.matchConfidence.isDatabaseMatch,
                           "'\(mi.labelName)' -> id \(mi.ingredientId ?? "nil"), confidence \(mi.matchConfidence.rawValue)")
        }
    }

    func testClassOnlyNeverCountsAsADatabaseMatch() {
        // Knowing a token is "some vitamin" is not knowing what it is. If this ever
        // becomes true, the recognition percentage starts overstating what we know.
        XCTAssertFalse(MatchConfidence.classOnly.isDatabaseMatch)
        XCTAssertFalse(MatchConfidence.classOnly.isCertain)
        XCTAssertFalse(MatchConfidence.fuzzy.isCertain)
        XCTAssertTrue(MatchConfidence.exact.isCertain)
        XCTAssertTrue(MatchConfidence.descriptor.isCertain)
    }

    // MARK: - Tokenizing

    func testCategoryGroupsAreExpandedIntoTheirMembers() {
        // "Vitamins (…)" is a heading, not an ingredient. Held together it becomes one
        // row that fuzzy-matches to whichever member has the longest synonym key, so
        // the rest are invisible to rules, allergens and avoidance groups.
        let raw = "Chicken, Vitamins (Vitamin E Supplement, Thiamine Mononitrate, Vitamin D3 Supplement), Salt"
        let matched = matcher.match(rawIngredients: raw, data: data)
        let names = matched.map(\.labelName)

        XCTAssertFalse(names.contains { $0.hasPrefix("Vitamins (") },
                       "the category header survived as a row: \(names)")
        XCTAssertTrue(names.contains("Vitamin E Supplement"), "members not expanded: \(names)")
        XCTAssertTrue(names.contains("Thiamine Mononitrate"), "members not expanded: \(names)")
        XCTAssertEqual(names.first, "Chicken")
        XCTAssertEqual(names.last, "Salt")
        XCTAssertEqual(matched.map(\.rank), Array(1...matched.count), "ranks must stay contiguous after expansion")
    }

    func testIngredientHeadersAreNotExpanded() {
        // The opposite case: "Fish Oil (source of DHA, EPA)" — the header *is* the
        // ingredient. Expanding it would delete the fish oil and leave two fragments
        // that mean nothing on their own.
        let matched = matcher.match(rawIngredients: "Fish Oil (source of DHA, EPA), Salt", data: data)
        XCTAssertEqual(matched.count, 2, "an ingredient header was torn apart: \(matched.map(\.labelName))")
        XCTAssertTrue(matched[0].labelName.lowercased().hasPrefix("fish oil"))
    }

    func testUnresolvableGroupsAreLeftIntactRatherThanShattered() {
        // Neither the header nor any member resolves, so there is nothing to gain by
        // splitting — and splitting freeform text on its commas produces nonsense rows.
        let raw = "Zzqx Blend (wibble compound, flurb extract), Chicken"
        let matched = matcher.match(rawIngredients: raw, data: data)
        XCTAssertEqual(matched.count, 2, "an unresolvable group was shattered: \(matched.map(\.labelName))")
    }

    func testStrayCloserInsideAGroupDoesNotEndIt() {
        // Straight off a scan: OCR dropped the "(" before "Vitamin B-2". A depth counter
        // lets that ")" close the vitamin pack, so everything after it splits as though
        // it were top-level and the pack's real "]" ends up glued to the last row —
        // "Menadione Sodium Bisulphite Complex (Vitamin K)]".
        let raw = "Chicken, Vitamins [Vitamin E Supplement, Thiamine Mononitrate (Vitamin B-1), "
            + "Riboflavin Supplement Vitamin B-2), Biotin (Vitamin B-7)], Taurine"
        let names = matcher.match(rawIngredients: raw, data: data).map(\.labelName)

        XCTAssertEqual(names.first, "Chicken")
        XCTAssertEqual(names.last, "Taurine")
        XCTAssertTrue(names.contains("Biotin (Vitamin B-7)"), "group did not expand: \(names)")
        XCTAssertFalse(names.contains { $0.contains("]") },
                       "a stray bracket survived onto an ingredient row: \(names)")
    }

    func testGroupClosedByTheWrongBracketStillEndsThere() {
        // The opposite malformation, and the reason the rule above needs a lookahead
        // rather than "ignore every unmatched closer": this pack opens with "[" and
        // closes with ")", and its "]" never arrives. Ignoring that ")" holds the group
        // open and swallows the whole rest of the label into one row.
        let raw = "Chicken, Vitamins [Vitamin E Supplement, Thiamine Mononitrate), Salt, Taurine"
        let names = matcher.match(rawIngredients: raw, data: data).map(\.labelName)
        XCTAssertEqual(names.suffix(2), ["Salt", "Taurine"], "the label was swallowed: \(names)")
    }

    func testRecipesSeparatedByPeriodsAreNotOneToken() {
        // Variety packs print one recipe per sentence. Without a sentence break the tail
        // of one recipe and the head of the next share a row, and a group sitting on that
        // boundary can never expand because it no longer ends at its own bracket.
        let names = matcher.match(rawIngredients: "Chicken, Salt. Beef Dinner: Beef, Rice", data: data)
            .map(\.labelName)
        XCTAssertEqual(names, ["Chicken", "Salt", "Beef", "Rice"])
    }

    func testDecimalsAndInitialismsAreNotSentenceBreaks() {
        let names = matcher.match(rawIngredients: "Chicken 12.5%, B.H.A., Salt", data: data).map(\.labelName)
        XCTAssertEqual(names, ["Chicken 12.5%", "B.H.A.", "Salt"])
    }

    func testLotCodesAreDropped() {
        // Promoted to a row of their own by the sentence break; "J453018C — unknown
        // ingredient" is worse than no row at all.
        let names = matcher.match(rawIngredients: "Chicken, Potassium Chloride. J453018C", data: data)
            .map(\.labelName)
        XCTAssertEqual(names, ["Chicken", "Potassium Chloride"])
    }

    func testRanksAreSequentialFromOne() {
        let matched = matcher.match(rawIngredients: "A, B, C, D", data: data)
        XCTAssertEqual(matched.map(\.rank), [1, 2, 3, 4])
    }

    func testEmptyAndWhitespaceTokensAreDropped() {
        let matched = matcher.match(rawIngredients: "Chicken,, ,  , Rice", data: data)
        XCTAssertEqual(matched.count, 2)
        XCTAssertEqual(matched.map(\.rank), [1, 2])
    }

    func testUnicodeIngredientNamesSurviveNormalization() {
        // `normalizeToken` filters on CharacterSet.alphanumerics — Unicode general
        // categories, not [a-z0-9]. This is precisely why the offline harness shares
        // the app's Swift source instead of porting the matcher to another language.
        let matched = matcher.match(rawIngredients: "Açaí Berry, D-Alpha Tocopherol", data: data)
        XCTAssertEqual(matched.count, 2)
        XCTAssertEqual(matched[0].labelName, "Açaí Berry")
    }
}
