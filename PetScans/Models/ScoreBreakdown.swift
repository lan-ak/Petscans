import Foundation
import SwiftUI

struct ScoreBreakdown: Codable {
    let total: Double
    let safety: Double
    let nutrition: Double?
    let suitability: Double
    let flags: [WarningFlag]
    let unmatched: [String]
    let matchedCount: Int
    let totalCount: Int
    let scoreSource: ScoreSource
    let ocrConfidence: Float?

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

// MARK: - Score Source

enum ScoreSource: String, Codable {
    case databaseVerified   // Product from API/database
    case ocrEstimated       // OCR-extracted ingredients
    case manualEntry        // User-typed ingredients

    var badge: String {
        switch self {
        case .databaseVerified: return "Verified"
        case .ocrEstimated: return "Estimated"
        case .manualEntry: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .databaseVerified: return "checkmark.seal.fill"
        case .ocrEstimated: return "camera.fill"
        case .manualEntry: return "keyboard.fill"
        }
    }

    var badgeColor: Color {
        switch self {
        case .databaseVerified: return ColorTokens.success
        case .ocrEstimated: return ColorTokens.info
        case .manualEntry: return ColorTokens.textSecondary
        }
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
