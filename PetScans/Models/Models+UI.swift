import SwiftUI

/// SwiftUI colour mappings for the model enums.
///
/// These live apart from the models themselves so `ProcessingLevel`,
/// `RuleSeverity`, `ScoreBreakdown` and friends depend on Foundation alone. The
/// models are compiled into the `matchkit` offline harness, which runs on macOS
/// and has no UI — and `ColorTokens` is built on `UIColor`, so a single colour
/// accessor in a model file would drag UIKit into a command-line tool.
///
/// The rule: a model file describes what something *is*; a `+UI` file describes
/// how it *looks*. Put new colour, icon-tint or font choices here.

extension ProcessingLevel {
    var color: Color {
        switch self {
        case .unprocessed: return ColorTokens.scoreExcellent
        case .culinaryIngredient: return ColorTokens.scoreGood
        case .processed: return ColorTokens.scoreModerate
        case .ultraProcessed: return ColorTokens.scorePoor
        }
    }
}

extension RuleSeverity {
    var color: Color {
        switch self {
        case .info: return ColorTokens.severityInfo
        case .warn: return ColorTokens.severityWarning
        case .high: return ColorTokens.severityHigh
        case .critical: return ColorTokens.severityCritical
        }
    }
}

extension ScoreSource {
    var badgeColor: Color {
        switch self {
        case .databaseVerified: return ColorTokens.success
        case .ocrEstimated: return ColorTokens.info
        case .manualEntry: return ColorTokens.textSecondary
        case .webScraped: return ColorTokens.info
        }
    }
}

extension RatingLabel {
    var color: Color {
        switch self {
        case .excellent: return ColorTokens.scoreExcellent
        case .good: return ColorTokens.scoreGood
        case .caution: return ColorTokens.scoreModerate
        case .avoid: return ColorTokens.scorePoor
        }
    }
}

extension ExplanationFactor.Impact {
    var color: Color {
        switch self {
        case .positive: return ColorTokens.success
        case .negative: return ColorTokens.error
        case .neutral: return ColorTokens.textSecondary
        }
    }
}

extension RiskTier {
    /// `moderation` and `mostlySafe` are deliberately not the warning colour.
    /// They were, before `RiskTier` existed — which put an amber "Caution" badge
    /// on 40 ingredients the scorer barely penalises. Reserving amber for a real
    /// caution is what makes it mean something.
    var color: Color {
        switch self {
        case .toxic: return ColorTokens.error
        case .caution: return ColorTokens.warning
        case .moderation, .mostlySafe: return ColorTokens.info
        case .safe: return ColorTokens.success
        }
    }
}
