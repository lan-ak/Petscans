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
    let safetyExplanation: ScoreExplanation?
    let suitabilityExplanation: ScoreExplanation?

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

    var ratingLabel: RatingLabel {
        RatingLabel.from(score: total)
    }

    var allergenFlags: [WarningFlag] {
        flags.filter { $0.type == .allergen }
    }

    var otherFlags: [WarningFlag] {
        flags.filter { $0.type != .allergen }
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

// MARK: - Warning Type

enum WarningType: String, Codable {
    case allergen   // Pet-specific allergen conflicts
    case safety     // Ingredient safety rules
    case general    // Other warnings
}

struct WarningFlag: Codable, Identifiable {
    let severity: RuleSeverity
    let title: String
    let explain: String
    let ingredientId: String?
    let source: String?
    let type: WarningType

    var id: String {
        "\(severity.rawValue)-\(type.rawValue)-\(ingredientId ?? title)"
    }

    init(severity: RuleSeverity, title: String, explain: String, ingredientId: String?, source: String?, type: WarningType = .general) {
        self.severity = severity
        self.title = title
        self.explain = explain
        self.ingredientId = ingredientId
        self.source = source
        self.type = type
    }
}

// MARK: - Rating Label

enum RatingLabel: String, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case caution = "Caution"
    case avoid = "Avoid"

    static func from(score: Double) -> RatingLabel {
        switch score {
        case 75...100: return .excellent
        case 50..<75: return .good
        case 25..<50: return .caution
        default: return .avoid
        }
    }

    var color: Color {
        switch self {
        case .excellent: return ColorTokens.scoreExcellent
        case .good: return ColorTokens.scoreGood
        case .caution: return ColorTokens.scoreModerate
        case .avoid: return ColorTokens.scorePoor
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.seal.fill"
        case .good: return "hand.thumbsup.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .avoid: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Score Explanation

struct ScoreExplanation: Codable {
    let factors: [ExplanationFactor]
    let summary: String
}

struct ExplanationFactor: Codable, Identifiable {
    let id: String
    let description: String
    let impact: Impact
    let ingredientName: String?

    enum Impact: String, Codable {
        case positive
        case negative
        case neutral
    }
}
