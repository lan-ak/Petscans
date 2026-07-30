import XCTest
@testable import matchkit

/// The highest-value tests in the suite: they protect saved scans.
///
/// `Scan.matchedIngredients` and `Scan.scoreBreakdown` decode with `try?` and
/// fall back to `[]` / `.empty`. So a decoder that throws does not surface an
/// error — it silently empties a user's ingredient list, or reports a total of 0,
/// which the UI renders as **"Avoid"**. A schema change that breaks decoding is
/// therefore indistinguishable from telling someone their pet's food is
/// dangerous.
///
/// Every one of these asserts against `legacy-scan-v1.json`, captured from the
/// shape shipped in 1.4.3. Do not edit that fixture to make a test pass.
final class PersistenceDecodeTests: XCTestCase {

    private func legacy() throws -> (ingredients: [MatchedIngredient], breakdown: ScoreBreakdown) {
        let root = try JSONSerialization.jsonObject(with: try TestSupport.fixture("legacy-scan-v1")) as! [String: Any]
        let decoder = JSONDecoder()
        let ingredients = try decoder.decode(
            [MatchedIngredient].self,
            from: try JSONSerialization.data(withJSONObject: root["matchedIngredients"]!))
        let breakdown = try decoder.decode(
            ScoreBreakdown.self,
            from: try JSONSerialization.data(withJSONObject: root["scoreBreakdown"]!))
        return (ingredients, breakdown)
    }

    // MARK: - The shipped shape still decodes, with the right values

    func testLegacyMatchedIngredientsDecodeIntact() throws {
        let (ingredients, _) = try legacy()
        XCTAssertEqual(ingredients.count, 4)
        XCTAssertEqual(ingredients[0].ingredientId, "ing_chicken")
        XCTAssertEqual(ingredients[0].labelName, "Chicken")
        XCTAssertEqual(ingredients[0].rank, 1)
        XCTAssertEqual(ingredients[0].processingLevel, .unprocessed)
        XCTAssertTrue(ingredients[0].isMatched)

        // The unmatched row must survive too — dropping it would renumber the list.
        XCTAssertNil(ingredients[2].ingredientId)
        XCTAssertFalse(ingredients[2].isMatched)
        XCTAssertEqual(ingredients[2].labelName, "Natural Flavoring Blend")
    }

    func testLegacyRowsDefaultToExactConfidence() throws {
        let (ingredients, _) = try legacy()
        // These rows predate `matchConfidence`. `.exact` is the honest default:
        // at the time they were written, the only paths that could produce a match
        // were the exact and descriptor lookups.
        XCTAssertTrue(ingredients.allSatisfy { $0.matchConfidence == .exact })
    }

    func testLegacyScoreBreakdownDecodesIntact() throws {
        let (_, breakdown) = try legacy()
        XCTAssertEqual(breakdown.total, 72.5)
        XCTAssertEqual(breakdown.safety, 80.0)
        XCTAssertEqual(breakdown.suitability, 65.0)
        XCTAssertEqual(breakdown.matchedCount, 3)
        XCTAssertEqual(breakdown.totalCount, 4)
        XCTAssertEqual(breakdown.unmatched, ["Natural Flavoring Blend"])
        XCTAssertFalse(breakdown.scoresAreMissing)
        // `processing` is genuinely absent in this shape, and the legacy `nutrition`
        // key must be ignored rather than mistaken for it.
        XCTAssertNil(breakdown.processing)
    }

    func testLegacyFlagsSurviveWithSeverityAndType() throws {
        let (_, breakdown) = try legacy()
        XCTAssertEqual(breakdown.flags.count, 2)
        XCTAssertEqual(breakdown.allergenFlags.count, 1)
        XCTAssertEqual(breakdown.allergenFlags.first?.severity, .high)
        XCTAssertEqual(breakdown.otherFlags.first?.type, .safety)
        XCTAssertEqual(breakdown.otherFlags.first?.source, "ASPCA")
    }

    func testLegacyLabelOverrideStillDrivesTheRating() throws {
        let (_, breakdown) = try legacy()
        // 72.5 alone would be "Caution" by threshold, but the point is that the
        // override is what's authoritative — losing it silently upgrades a warned
        // product. See ScoreBreakdown.ratingLabel.
        XCTAssertEqual(breakdown.safetyExplanation?.labelOverride, .caution)
        XCTAssertEqual(breakdown.ratingLabel, .caution)
    }

    // MARK: - Forward compatibility: a newer build's data on an older app

    func testUnknownProcessingLevelKeepsTheRow() throws {
        // A future build adding ProcessingLevel 5 must not make its scans
        // undecodable here. Unknown level -> unclassified, row retained.
        let json = #"[{"labelName":"Novel Thing","rank":1,"ingredientId":"ing_x","processingLevel":5}]"#
        let rows = try JSONDecoder().decode([MatchedIngredient].self, from: Data(json.utf8))
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows[0].processingLevel)
        XCTAssertEqual(rows[0].ingredientId, "ing_x")
    }

    func testUnknownMatchConfidenceKeepsTheRow() throws {
        let json = #"[{"labelName":"Thing","rank":1,"matchConfidence":"telepathy"}]"#
        let rows = try JSONDecoder().decode([MatchedIngredient].self, from: Data(json.utf8))
        XCTAssertEqual(rows.first?.matchConfidence, MatchConfidence.none)
    }

    func testUnknownSeverityDoesNotDestroyTheFlagsArray() throws {
        // This is the regression that mattered most: an unknown enum inside one
        // flag used to throw, taking every other flag — including a critical
        // toxicity warning — down with it.
        let json = """
        {"total":40,"safety":40,"suitability":40,
         "flags":[{"severity":"catastrophic","title":"New tier","explain":"x","type":"newType"},
                  {"severity":"critical","title":"Xylitol","explain":"emergency","type":"safety"}],
         "unmatched":[],"matchedCount":1,"totalCount":1,"scoreSource":"quantumOracle"}
        """
        let breakdown = try JSONDecoder().decode(ScoreBreakdown.self, from: Data(json.utf8))
        XCTAssertEqual(breakdown.flags.count, 2)
        XCTAssertEqual(breakdown.flags[0].severity, .warn, "unknown severity stays visible, not demoted to info")
        XCTAssertEqual(breakdown.flags[0].type, .general)
        XCTAssertEqual(breakdown.flags[1].severity, .critical)
        XCTAssertTrue(breakdown.hasCriticalFlags, "the known critical warning must survive its unknown neighbour")
        XCTAssertEqual(breakdown.scoreSource, .databaseVerified)
    }

    func testMissingScoresAreMarkedRatherThanReadingAsZero() throws {
        let json = #"{"flags":[],"unmatched":[],"matchedCount":0,"totalCount":0,"scoreSource":"databaseVerified"}"#
        let breakdown = try JSONDecoder().decode(ScoreBreakdown.self, from: Data(json.utf8))
        XCTAssertTrue(breakdown.scoresAreMissing)
        // The zeros still render as Avoid, which is exactly why the flag exists —
        // ProductScoreView suppresses the score when it is set.
        XCTAssertEqual(breakdown.ratingLabel, .avoid)
    }

    // MARK: - Round trip

    func testFreshBreakdownRoundTripsLosslessly() throws {
        let original = ScoreBreakdown(
            total: 88, safety: 90, suitability: 86, processing: 80,
            flags: [WarningFlag(severity: .warn, title: "T", explain: "E",
                                ingredientId: "ing_x", source: "S", type: .avoidanceGroup)],
            unmatched: ["mystery"], matchedCount: 5, totalCount: 6,
            scoreSource: .ocrEstimated, ocrConfidence: 0.9,
            safetyExplanation: nil, suitabilityExplanation: nil, processingExplanation: nil)

        let decoded = try JSONDecoder().decode(ScoreBreakdown.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.total, 88)
        XCTAssertEqual(decoded.processing, 80)
        XCTAssertEqual(decoded.scoreSource, .ocrEstimated)
        XCTAssertEqual(decoded.ocrConfidence, 0.9)
        XCTAssertEqual(decoded.flags.first?.type, .avoidanceGroup)
        XCTAssertFalse(decoded.scoresAreMissing)
    }

    func testMatchedIngredientRoundTripsIncludingConfidence() throws {
        let original = MatchedIngredient(ingredientId: "ing_x", labelName: "X", rank: 3,
                                         processingLevel: .ultraProcessed, matchConfidence: .fuzzy)
        let decoded = try JSONDecoder().decode(MatchedIngredient.self,
                                               from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.matchConfidence, .fuzzy)
        XCTAssertEqual(decoded.processingLevel, .ultraProcessed)
        XCTAssertEqual(decoded.rank, 3)
    }

    func testIdentifiersStayUniqueEvenWhenRanksCollide() throws {
        // `rank` now has a decode fallback of 0, so malformed rows could share one.
        // If `id` were still just the rank, ForEach would silently drop rows.
        let json = #"[{"labelName":"A"},{"labelName":"B"}]"#
        let rows = try JSONDecoder().decode([MatchedIngredient].self, from: Data(json.utf8))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.id)).count, 2)
    }
}
