import Foundation

/// One token from a product's ingredient label, with whatever the matcher could
/// resolve it to.
///
/// **This type is persisted**, JSON-encoded into `Scan.matchedIngredientsJSON`.
/// That makes its decoder load-bearing: `Scan.matchedIngredients` decodes with
/// `try?` and falls back to `[]`, so a single throw silently empties the
/// ingredient list of *every* saved scan rather than failing loudly. The
/// hand-written `init(from:)` below therefore uses `decodeIfPresent` for every
/// key including the existing ones — adding a field must never be able to throw.
///
/// **Snapshot vs. resolve.** Fields here record *the match event* and are frozen
/// at scan time. Properties of the ingredient itself (risk level, notes, sources,
/// rules) are deliberately NOT stored — they are looked up live from
/// `IngredientDatabase` at render time, so improving the database improves every
/// historical scan for free. When adding a field, ask which one it is:
///
/// - *What we scored with* → snapshot it here, and scoring code reads the stored value.
/// - *What we know now* → leave it out, resolve it live.
///
/// `processingLevel` predates that rule and sits awkwardly on both sides: scoring
/// needs the stored value for reproducibility, but rendering it stale means a saved
/// scan shows the badge as it was on scan day, forever. Render paths should use
/// `resolvedProcessingLevel(_:)`; scoring paths keep reading `processingLevel`.
struct MatchedIngredient: Codable, Identifiable {
    let ingredientId: String?
    let labelName: String
    let rank: Int

    // Processing level cached from Ingredient for UI display (informational only)
    let processingLevel: ProcessingLevel?

    /// How `ingredientId` was arrived at. A property of the match event, so it is
    /// snapshotted rather than recomputed. Legacy scans decode as `.exact`: they
    /// predate the distinction, and every match they could have made came from the
    /// exact or descriptor path.
    let matchConfidence: MatchConfidence

    /// Composite rather than `rank` alone: `rank` now has a decode fallback, and a
    /// corrupt row defaulting several entries to the same rank would collide in
    /// `ForEach` and drop rows from the list.
    var id: String { "\(rank)-\(labelName)" }

    var isMatched: Bool {
        ingredientId != nil
    }

    /// The processing level as we understand it *today*, preferring the live
    /// database over the value snapshotted at scan time. Use this for display.
    /// Scoring must keep using `processingLevel` so a saved score stays reproducible.
    func resolvedProcessingLevel(_ ingredients: [String: Ingredient]) -> ProcessingLevel? {
        if let id = ingredientId, let level = ingredients[id]?.processingLevel {
            return level
        }
        return processingLevel
    }

    init(
        ingredientId: String?,
        labelName: String,
        rank: Int,
        processingLevel: ProcessingLevel? = nil,
        matchConfidence: MatchConfidence = .exact
    ) {
        self.ingredientId = ingredientId
        self.labelName = labelName
        self.rank = rank
        self.processingLevel = processingLevel
        self.matchConfidence = matchConfidence
    }

    private enum CodingKeys: String, CodingKey {
        case ingredientId, labelName, rank, processingLevel, matchConfidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ingredientId = try container.decodeIfPresent(String.self, forKey: .ingredientId)
        labelName = try container.decodeIfPresent(String.self, forKey: .labelName) ?? ""
        rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        // `try?` rather than `try`: `ProcessingLevel` is an Int-raw enum, so a future
        // build introducing a level 5 would make every scan saved by that build
        // undecodable by this one. Unknown level → unclassified, which is honest;
        // giving the enum a custom decoder that mapped unknowns onto an existing
        // case would fabricate a classification instead.
        processingLevel = try? container.decodeIfPresent(ProcessingLevel.self, forKey: .processingLevel)
        matchConfidence = (try? container.decodeIfPresent(MatchConfidence.self, forKey: .matchConfidence)) ?? .exact
    }
}
