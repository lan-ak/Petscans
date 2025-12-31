import Foundation

struct ScoreBreakdown: Codable {
    let total: Double
    let safety: Double
    let nutrition: Double?
    let suitability: Double
    let flags: [WarningFlag]
    let unmatched: [String]
    let matchedCount: Int
    let totalCount: Int

    var hasCriticalFlags: Bool {
        flags.contains { $0.severity == .critical }
    }

    var matchRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(matchedCount) / Double(totalCount)
    }

    var matchPercentage: Int {
        Int(matchRate * 100)
    }
}

struct WarningFlag: Codable, Identifiable {
    let severity: RuleSeverity
    let title: String
    let explain: String
    let ingredientId: String?

    var id: String {
        "\(severity.rawValue)-\(ingredientId ?? title)"
    }
}
