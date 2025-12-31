import Foundation

struct MatchedIngredient: Codable, Identifiable {
    let ingredientId: String?
    let labelName: String
    let rank: Int

    var id: Int { rank }

    var isMatched: Bool {
        ingredientId != nil
    }
}
