import Foundation

struct MatchedIngredient: Codable, Identifiable {
    let ingredientId: String?
    let labelName: String
    let rank: Int

    // Processing level cached from Ingredient for UI display (informational only)
    let processingLevel: ProcessingLevel?

    var id: Int { rank }

    var isMatched: Bool {
        ingredientId != nil
    }

    init(ingredientId: String?, labelName: String, rank: Int, processingLevel: ProcessingLevel? = nil) {
        self.ingredientId = ingredientId
        self.labelName = labelName
        self.rank = rank
        self.processingLevel = processingLevel
    }
}
