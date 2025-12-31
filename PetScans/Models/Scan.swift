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

    // Computed properties to decode JSON
    var matchedIngredients: [MatchedIngredient] {
        guard let data = matchedIngredientsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([MatchedIngredient].self, from: data)) ?? []
    }

    var scoreBreakdown: ScoreBreakdown {
        guard let data = scoreBreakdownJSON.data(using: .utf8) else {
            return ScoreBreakdown(total: 0, safety: 0, nutrition: nil, suitability: 0, flags: [], unmatched: [], matchedCount: 0, totalCount: 0, scoreSource: .databaseVerified, ocrConfidence: nil)
        }
        return (try? JSONDecoder().decode(ScoreBreakdown.self, from: data)) ?? ScoreBreakdown(total: 0, safety: 0, nutrition: nil, suitability: 0, flags: [], unmatched: [], matchedCount: 0, totalCount: 0, scoreSource: .databaseVerified, ocrConfidence: nil)
    }

    var speciesEnum: Species {
        Species(rawValue: targetSpecies) ?? .dog
    }

    var categoryEnum: Category {
        Category(rawValue: category) ?? .food
    }
}
