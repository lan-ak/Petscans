import Foundation

struct Rule: Codable, Identifiable {
    let id: String
    let ingredientId: String
    let appliesTo: AppliesTo
    let severity: RuleSeverity
    let scoreImpact: Int
    let explain: String
    let evidence: String

    // V2 fields (optional for backward compatibility)
    let type: String?
    let action: String?
    let penalty: Int?
    let source: String?
    let createdAt: String?
    let schemaVersion: String?

    struct AppliesTo: Codable {
        let species: [Species]
        let categories: [Category]
    }
}
