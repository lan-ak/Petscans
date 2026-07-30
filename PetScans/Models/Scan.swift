import Foundation
import SwiftData

@Model
final class Scan {
    var barcode: String?
    var productName: String?
    var brand: String?
    var imageUrl: String?

    var category: String
    var targetSpecies: String

    var rawIngredientText: String
    var matchedIngredientsJSON: String
    var scoreBreakdownJSON: String

    var totalScore: Double
    var safetyScore: Double
    var hasCriticalFlags: Bool

    var scannedAt: Date
    var notes: String?
    var isFavorite: Bool

    var createdAt: Date
    var updatedAt: Date

    // Transient cached properties to avoid JSON decoding on every access
    @Transient private var _cachedMatchedIngredients: [MatchedIngredient]?
    @Transient private var _cachedScoreBreakdown: ScoreBreakdown?

    /// Set when either persisted blob could not be decoded at all.
    ///
    /// The decoders in `MatchedIngredient` and `ScoreBreakdown` are deliberately
    /// total — they tolerate missing keys and unknown enum cases — so reaching this
    /// means the stored JSON is genuinely unreadable, not merely from an older
    /// schema. The UI must say so rather than render the fallbacks, because
    /// `ScoreBreakdown.empty` has a total of 0 and a total of 0 displays as "Avoid".
    @Transient private(set) var decodeFailed = false

    init(
        barcode: String? = nil,
        productName: String? = nil,
        brand: String? = nil,
        imageUrl: String? = nil,
        category: Category,
        targetSpecies: Species,
        rawIngredientText: String,
        matchedIngredients: [MatchedIngredient],
        scoreBreakdown: ScoreBreakdown,
        notes: String? = nil,
        isFavorite: Bool = false
    ) {
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageUrl = imageUrl
        self.category = category.rawValue
        self.targetSpecies = targetSpecies.rawValue
        self.rawIngredientText = rawIngredientText

        // Encode matched ingredients to JSON
        let encoder = JSONEncoder()
        self.matchedIngredientsJSON = (try? encoder.encode(matchedIngredients))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.scoreBreakdownJSON = (try? encoder.encode(scoreBreakdown))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        self.totalScore = scoreBreakdown.total
        self.safetyScore = scoreBreakdown.safety
        self.hasCriticalFlags = scoreBreakdown.hasCriticalFlags

        self.scannedAt = Date()
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Replace the frozen match and score with freshly computed ones.
    ///
    /// A scan stores the *result* of matching, not just the label it came from, so a
    /// matcher fix reaches history only by rewriting these blobs — nothing re-derives
    /// them on read. Resetting the transient caches is the part that is easy to miss:
    /// a scan already rendered this launch would otherwise keep serving the rows it
    /// decoded before the rewrite.
    func replaceAnalysis(matchedIngredients: [MatchedIngredient], scoreBreakdown: ScoreBreakdown) {
        let encoder = JSONEncoder()
        guard let matchedJSON = (try? encoder.encode(matchedIngredients))
                .flatMap({ String(data: $0, encoding: .utf8) }),
              let breakdownJSON = (try? encoder.encode(scoreBreakdown))
                .flatMap({ String(data: $0, encoding: .utf8) }) else { return }

        self.matchedIngredientsJSON = matchedJSON
        self.scoreBreakdownJSON = breakdownJSON
        self.totalScore = scoreBreakdown.total
        self.safetyScore = scoreBreakdown.safety
        self.hasCriticalFlags = scoreBreakdown.hasCriticalFlags
        self.updatedAt = Date()

        _cachedMatchedIngredients = matchedIngredients
        _cachedScoreBreakdown = scoreBreakdown
        decodeFailed = false
    }

    // Computed properties with caching to avoid JSON decoding on every access
    var matchedIngredients: [MatchedIngredient] {
        if let cached = _cachedMatchedIngredients {
            return cached
        }
        guard let data = matchedIngredientsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([MatchedIngredient].self, from: data) else {
            decodeFailed = true
            return []
        }
        _cachedMatchedIngredients = decoded
        return decoded
    }

    var scoreBreakdown: ScoreBreakdown {
        if let cached = _cachedScoreBreakdown {
            return cached
        }
        guard let data = scoreBreakdownJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ScoreBreakdown.self, from: data) else {
            decodeFailed = true
            return .empty
        }
        _cachedScoreBreakdown = decoded
        return decoded
    }

    var speciesEnum: Species {
        Species(rawValue: targetSpecies) ?? .dog
    }

    var categoryEnum: Category {
        Category(rawValue: category) ?? .food
    }
}
