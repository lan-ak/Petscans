import Foundation

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

    /// True when a decode found none of `total`/`safety`/`suitability`, i.e. this
    /// breakdown's zeros are absence of data rather than a real score of zero.
    /// Derived, never encoded. Always false for a freshly calculated breakdown.
    let scoresAreMissing: Bool

    // Custom decoder to handle old saved scans missing processing field
    private enum CodingKeys: String, CodingKey {
        case total, safety, suitability, processing, flags, unmatched
        case matchedCount, totalCount, scoreSource, ocrConfidence
        case safetyExplanation, suitabilityExplanation, processingExplanation
        // Legacy key for backward compatibility
        case nutrition
    }

    /// Every key decodes with `decodeIfPresent`, including the ones that are
    /// logically required.
    ///
    /// The reason is the call site: `Scan.scoreBreakdown` decodes with `try?` and
    /// falls back to `.empty`, which is a total of 0 — and a total of 0 renders as
    /// **"Avoid"**, indistinguishable from a genuinely dangerous product. A decoder
    /// that throws on one missing key therefore doesn't produce an error state, it
    /// produces a confident lie about a product's safety. Partial data is strictly
    /// better than that, so nothing here is allowed to throw.
    ///
    /// A scan that decodes with no scores at all is still wrong, just not silently:
    /// `scoresAreMissing` marks it so the UI can say so.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTotal = try container.decodeIfPresent(Double.self, forKey: .total)
        let decodedSafety = try container.decodeIfPresent(Double.self, forKey: .safety)
        let decodedSuitability = try container.decodeIfPresent(Double.self, forKey: .suitability)

        total = decodedTotal ?? 0
        safety = decodedSafety ?? 0
        suitability = decodedSuitability ?? 0
        scoresAreMissing = decodedTotal == nil && decodedSafety == nil && decodedSuitability == nil

        processing = try container.decodeIfPresent(Double.self, forKey: .processing)
        flags = (try? container.decodeIfPresent([WarningFlag].self, forKey: .flags)) ?? []
        unmatched = (try? container.decodeIfPresent([String].self, forKey: .unmatched)) ?? []
        matchedCount = try container.decodeIfPresent(Int.self, forKey: .matchedCount) ?? 0
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        scoreSource = try container.decodeIfPresent(ScoreSource.self, forKey: .scoreSource) ?? .databaseVerified
        ocrConfidence = try container.decodeIfPresent(Float.self, forKey: .ocrConfidence)
        // `try?`: the explanations are presentational. A malformed one should cost
        // the narration, not the scores it narrates.
        safetyExplanation = try? container.decodeIfPresent(ScoreExplanation.self, forKey: .safetyExplanation)
        suitabilityExplanation = try? container.decodeIfPresent(ScoreExplanation.self, forKey: .suitabilityExplanation)
        processingExplanation = try? container.decodeIfPresent(ScoreExplanation.self, forKey: .processingExplanation)
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
        processingExplanation: ScoreExplanation?,
        scoresAreMissing: Bool = false
    ) {
        self.scoresAreMissing = scoresAreMissing
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

        // Return the worst label (avoid > caution > good > excellent). Lower
        // `severity` == worse, so the worst label is the minimum severity.
        let allLabels = overrides + [scoreLabel]
        return allLabels.min(by: { $0.severity < $1.severity }) ?? scoreLabel
    }

    var allergenFlags: [WarningFlag] {
        flags.filter { $0.type == .allergen }
    }

    var otherFlags: [WarningFlag] {
        flags.filter { $0.type != .allergen }
    }

    /// The ingredients that tripped the pet's allergen profile, named once each.
    ///
    /// Lives here rather than in a view because two screens need it — the scan result
    /// and the onboarding demo — and when it was derived independently in both, only
    /// one of them got de-duplicated. Every real scan lands on the other one.
    ///
    /// `ScoreCalculator` already collapses repeated spellings of the same ingredient,
    /// so this guards the remaining case: two genuinely different ingredient rows that
    /// share a display name (`ing_chicken` and `ing_chicken_fresh` are both "Chicken").
    /// "Chicken, Chicken" reads as a bug whatever produced it.
    var allergenIngredientNames: [String] {
        var seen = Set<String>()
        return (suitabilityExplanation?.factors ?? [])
            .filter { $0.impact == .negative }
            .compactMap(\.ingredientName)
            .filter { seen.insert($0.lowercased()).inserted }
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
    case webScraped         // Ingredients from web scraping

    /// Unknown raw values decode to `.databaseVerified`. Persisted inside
    /// `ScoreBreakdown`, so throwing would cost the whole breakdown; the badge is
    /// cosmetic, the scores are not. See `RuleSeverity.init(from:)`.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ScoreSource(rawValue: raw) ?? .databaseVerified
    }

    var badge: String {
        switch self {
        case .databaseVerified: return "Verified"
        case .ocrEstimated: return "Estimated"
        case .manualEntry: return "Custom"
        case .webScraped: return "PetScans AI"
        }
    }

    var icon: String {
        switch self {
        case .databaseVerified: return "checkmark.seal.fill"
        case .ocrEstimated: return "camera.fill"
        case .manualEntry: return "keyboard.fill"
        case .webScraped: return "sparkles"
        }
    }
}

// MARK: - Warning Type

enum WarningType: String, Codable {
    case allergen        // Pet-specific allergen conflicts
    case safety          // Ingredient safety rules
    case avoidanceGroup  // Matches an owner-selected avoidance group (warning, never forces Avoid)
    case general         // Other warnings

    /// Old saved scans predate `avoidanceGroup`; any unrecognised value decodes as `.general`
    /// so a stored WarningFlag from a prior build never fails to decode.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WarningType(rawValue: raw) ?? .general
    }
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

    private enum CodingKeys: String, CodingKey {
        case severity, title, explain, ingredientId, source, type
    }

    /// Nothing here throws, for the same reason as `ScoreBreakdown.init(from:)`:
    /// these live in an array inside a blob decoded with `try?`, so one malformed
    /// flag would take every *other* flag — allergen and toxicity warnings included —
    /// down with it. A flag with a blank title still shows its severity and text.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        severity = try container.decodeIfPresent(RuleSeverity.self, forKey: .severity) ?? .warn
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        explain = try container.decodeIfPresent(String.self, forKey: .explain) ?? ""
        ingredientId = try container.decodeIfPresent(String.self, forKey: .ingredientId)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        type = try container.decodeIfPresent(WarningType.self, forKey: .type) ?? .general
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
    }
}
