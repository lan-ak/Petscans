import Foundation
import SwiftUI

struct ScoreBreakdown: Codable {
    let total: Double
    let safety: Double
    let suitability: Double
    let processing: Double?
    let flags: [WarningFlag]
    let unmatched: [String]
    let matchedCount: Int
    let totalCount: Int
    let scoreSource: ScoreSource
    let ocrConfidence: Float?
    let safetyExplanation: ScoreExplanation?
    let suitabilityExplanation: ScoreExplanation?
    let processingExplanation: ScoreExplanation?

    // Custom decoder to handle old saved scans missing processing field
    private enum CodingKeys: String, CodingKey {
        case total, safety, suitability, processing, flags, unmatched
        case matchedCount, totalCount, scoreSource, ocrConfidence
        case safetyExplanation, suitabilityExplanation, processingExplanation
        // Legacy key for backward compatibility
        case nutrition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decode(Double.self, forKey: .total)
        safety = try container.decode(Double.self, forKey: .safety)
        suitability = try container.decode(Double.self, forKey: .suitability)
        processing = try container.decodeIfPresent(Double.self, forKey: .processing)
        flags = try container.decode([WarningFlag].self, forKey: .flags)
        unmatched = try container.decode([String].self, forKey: .unmatched)
        matchedCount = try container.decode(Int.self, forKey: .matchedCount)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        scoreSource = try container.decode(ScoreSource.self, forKey: .scoreSource)
        ocrConfidence = try container.decodeIfPresent(Float.self, forKey: .ocrConfidence)
        safetyExplanation = try container.decodeIfPresent(ScoreExplanation.self, forKey: .safetyExplanation)
        suitabilityExplanation = try container.decodeIfPresent(ScoreExplanation.self, forKey: .suitabilityExplanation)
        processingExplanation = try container.decodeIfPresent(ScoreExplanation.self, forKey: .processingExplanation)
        // Note: nutrition is ignored during decode (legacy field)
    }

    init(
        total: Double,
        safety: Double,
        suitability: Double,
        processing: Double?,
        flags: [WarningFlag],
        unmatched: [String],
        matchedCount: Int,
        totalCount: Int,
        scoreSource: ScoreSource,
        ocrConfidence: Float?,
        safetyExplanation: ScoreExplanation?,
        suitabilityExplanation: ScoreExplanation?,
        processingExplanation: ScoreExplanation?
    ) {
        self.total = total
        self.safety = safety
        self.suitability = suitability
        self.processing = processing
        self.flags = flags
        self.unmatched = unmatched
        self.matchedCount = matchedCount
        self.totalCount = totalCount
        self.scoreSource = scoreSource
        self.ocrConfidence = ocrConfidence
        self.safetyExplanation = safetyExplanation
        self.suitabilityExplanation = suitabilityExplanation
        self.processingExplanation = processingExplanation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(total, forKey: .total)
        try container.encode(safety, forKey: .safety)
        try container.encode(suitability, forKey: .suitability)
        try container.encodeIfPresent(processing, forKey: .processing)
        try container.encode(flags, forKey: .flags)
        try container.encode(unmatched, forKey: .unmatched)
        try container.encode(matchedCount, forKey: .matchedCount)
        try container.encode(totalCount, forKey: .totalCount)
        try container.encode(scoreSource, forKey: .scoreSource)
        try container.encodeIfPresent(ocrConfidence, forKey: .ocrConfidence)
        try container.encodeIfPresent(safetyExplanation, forKey: .safetyExplanation)
        try container.encodeIfPresent(suitabilityExplanation, forKey: .suitabilityExplanation)
        try container.encodeIfPresent(processingExplanation, forKey: .processingExplanation)
    }

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
        // Get the score-based label
        let scoreLabel = RatingLabel.from(score: total)

        // Collect all label overrides from sub-categories
        let overrides = [
            safetyExplanation?.labelOverride,
            suitabilityExplanation?.labelOverride,
            processingExplanation?.labelOverride
        ].compactMap { $0 }

        // If no overrides, use score-based label
        guard !overrides.isEmpty else { return scoreLabel }

        // Return the worst label (avoid > caution > good > excellent)
        let allLabels = overrides + [scoreLabel]
        return allLabels.min(by: { $0.severity > $1.severity }) ?? scoreLabel
    }

    var allergenFlags: [WarningFlag] {
        flags.filter { $0.type == .allergen }
    }

    var otherFlags: [WarningFlag] {
        flags.filter { $0.type != .allergen }
    }

    /// Empty breakdown for fallback cases
    static let empty = ScoreBreakdown(
        total: 0,
        safety: 0,
        suitability: 0,
        processing: nil,
        flags: [],
        unmatched: [],
        matchedCount: 0,
        totalCount: 0,
        scoreSource: .databaseVerified,
        ocrConfidence: nil,
        safetyExplanation: nil,
        suitabilityExplanation: nil,
        processingExplanation: nil
    )
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

    /// Lower number = worse rating (for comparison)
    var severity: Int {
        switch self {
        case .avoid: return 0
        case .caution: return 1
        case .good: return 2
        case .excellent: return 3
        }
    }

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
    let labelOverride: RatingLabel?

    init(factors: [ExplanationFactor], summary: String, labelOverride: RatingLabel? = nil) {
        self.factors = factors
        self.summary = summary
        self.labelOverride = labelOverride
    }
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

        var icon: String {
            switch self {
            case .positive: return "plus.circle.fill"
            case .negative: return "minus.circle.fill"
            case .neutral: return "circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .positive: return ColorTokens.success
            case .negative: return ColorTokens.error
            case .neutral: return ColorTokens.textSecondary
            }
        }
    }
}
