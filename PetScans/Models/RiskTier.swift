import Foundation

/// The one place a `riskLevel` string is turned into a decision.
///
/// `Ingredient.riskLevel` is free text from `ingredients.json` — "safe",
/// "safe_in_moderation", "safe_for_most", "safe_in_small_amounts", "caution",
/// "toxic". Three separate places used to classify it with their own
/// `contains(...)` ladders: `ScoreCalculator.basePenalty`, the badge in
/// `IngredientDetailSheet`, and the ingredient picker row. They already disagreed
/// — the detail sheet treated "safe_in_moderation" as a caution while the scorer
/// gave it a much smaller penalty than a real caution, so a row could show a
/// warning badge the score didn't reflect.
///
/// Ordering matters: "safe_in_moderation" contains both "safe" and "moderation",
/// so the checks have to run most-severe-first. That subtlety is exactly why this
/// should exist once.
///
/// `DataValidationTests.testRiskLevelsUseKnownVocabulary` fails the build if
/// `ingredients.json` grows a value outside the vocabulary below, so an unknown
/// string silently scoring as safe can't reach a device.
enum RiskTier {
    /// Not recommended for this species at any amount.
    case toxic
    /// Known concerns; the score is penalised meaningfully.
    case caution
    /// "safe_in_moderation" — fine in normal amounts.
    case moderation
    /// "safe_for_most" — a small penalty for individual sensitivities.
    case mostlySafe
    /// No known concerns.
    case safe

    /// Mirrors the old `ScoreCalculator.basePenalty` ladder exactly, including its
    /// quirks: "safe_in_small_amounts" fell through every check and scored as fully
    /// safe. Preserved deliberately — this extraction must not move a single score.
    /// Changing it is a scoring decision, to be made and audited on its own.
    init(_ riskLevel: String) {
        let r = riskLevel.lowercased()
        if r.contains("toxic") { self = .toxic }
        else if r.contains("caution") { self = .caution }
        else if r.contains("moderation") { self = .moderation }
        else if r.contains("safe_for_most") { self = .mostlySafe }
        else { self = .safe }
    }

    /// Points deducted from safety, before rank weighting.
    var basePenalty: Double {
        switch self {
        case .toxic: return 40
        case .caution: return 15
        case .moderation: return 6
        case .mostlySafe: return 2
        case .safe: return 0
        }
    }

    /// Short label for a badge.
    var displayName: String {
        switch self {
        case .toxic: return "Avoid"
        case .caution: return "Caution"
        case .moderation: return "In moderation"
        case .mostlySafe: return "Safe for most"
        case .safe: return "Safe"
        }
    }

    /// SF Symbol for a badge or row marker.
    var icon: String {
        switch self {
        case .toxic: return "xmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .moderation, .mostlySafe: return "checkmark.circle.fill"
        case .safe: return "checkmark.circle.fill"
        }
    }

    /// Whether this is worth surfacing without the user tapping in.
    var isConcerning: Bool {
        self == .toxic || self == .caution
    }
}
