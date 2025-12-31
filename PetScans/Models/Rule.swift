import Foundation

struct Rule: Codable, Identifiable {
    let id: String
    let ingredientId: String
    let appliesTo: AppliesTo
    let severity: RuleSeverity
    let scoreImpact: Int
    let explain: String
    let evidence: String

    struct AppliesTo: Codable {
        let species: [Species]
        let categories: [Category]
    }
}
