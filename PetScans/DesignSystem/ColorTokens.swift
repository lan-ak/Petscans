import SwiftUI

/// Color extension for light/dark mode support
extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

/// Color tokens for the PetScans design system
/// Inspired by Yuka's clean, trust-building color palette
struct ColorTokens {

    // MARK: - Brand Colors

    /// Primary brand color - Used for primary actions, selected states
    /// Yuka uses green to convey health and trust
    /// Light mode: #34C759, Dark mode: #32D74B
    static let brandPrimary = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)

    /// Secondary brand color - For accents and highlights
    /// Light Green for positive but secondary elements
    static let brandSecondary = Color(red: 0x52/255, green: 0xC4/255, blue: 0x1A/255)

    // MARK: - Score Colors (Traffic Light System - Yuka 4-tier)

    /// Excellent score (75-100) - Deep, trustworthy green
    /// Light mode: #2DA44E, Dark mode: #3FB950
    static let scoreExcellent = Color(red: 0x2D/255, green: 0xA4/255, blue: 0x4E/255)

    /// Good score (50-74) - Light green, positive but room for improvement
    /// Light mode: #52C41A, Dark mode: #73D13D
    static let scoreGood = Color(red: 0x52/255, green: 0xC4/255, blue: 0x1A/255)

    /// Moderate score (25-49) - Orange, concerning
    /// Light mode: #FF9500, Dark mode: #FF9F0A
    static let scoreModerate = Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255)

    /// Poor score (0-24) - Red, alarming
    /// Light mode: #FF3B30, Dark mode: #FF453A
    static let scorePoor = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)

    // MARK: - Severity Colors (for Warning Flags)

    /// Info severity - Blue, informational
    /// Light mode: #007AFF, Dark mode: #0A84FF
    static let severityInfo = Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255)

    /// Warning severity - Orange, caution
    /// Light mode: #FF9500, Dark mode: #FF9F0A
    static let severityWarning = Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255)

    /// High severity - Red, danger
    /// Light mode: #FF3B30, Dark mode: #FF453A
    static let severityHigh = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)

    /// Critical severity - Purple, critical danger
    /// Light mode: #AF52DE, Dark mode: #BF5AF2
    static let severityCritical = Color(red: 0xAF/255, green: 0x52/255, blue: 0xDE/255)

    // MARK: - Semantic Colors

    /// Success state - green
    static let success = scoreGood

    /// Error state - red
    static let error = severityHigh

    /// Warning state - orange
    static let warning = severityWarning

    /// Information state - blue
    static let info = severityInfo

    /// Favorite/star state - yellow
    static let favorite = Color(red: 0xFF/255, green: 0xCC/255, blue: 0x00/255)

    // MARK: - Neutral Colors

    /// App-wide background with subtle green tint to reinforce Yuka branding
    /// Light mode: #F0F9F4 (very pale green), Dark mode: #1A1F1C (very dark with subtle green tint)
    static let backgroundPrimary = Color(light: Color(red: 0xF0/255, green: 0xF9/255, blue: 0xF4/255),
                                          dark: Color(red: 0x1A/255, green: 0x1F/255, blue: 0x1C/255))

    /// Background for cards and containers
    static let surfacePrimary = Color(.systemGray6)

    /// Subtle background for nested content
    static let surfaceSecondary = Color(.systemGray5)

    /// Dividers and borders
    static let border = Color(.systemGray4)

    // MARK: - Text Colors (Semantic)

    /// Primary text color
    static let textPrimary = Color.primary

    /// Secondary, de-emphasized text
    static let textSecondary = Color.secondary

    /// Tertiary, very subtle text
    static let textTertiary = Color(.systemGray)
}

// MARK: - Score Color Helper

extension ColorTokens {
    /// Returns the appropriate color for a given score (0-100)
    /// Uses Yuka's 4-tier traffic light system with 75/50/25 thresholds
    ///
    /// - 75-100: Excellent (dark green)
    /// - 50-74: Good (light green)
    /// - 25-49: Moderate (orange)
    /// - 0-24: Poor (red)
    static func colorForScore(_ score: Double) -> Color {
        switch score {
        case 75...100:
            return scoreExcellent
        case 50..<75:
            return scoreGood
        case 25..<50:
            return scoreModerate
        default:
            return scorePoor
        }
    }

    /// Returns background opacity color for a score
    /// Used for subtle score-based backgrounds
    static func backgroundForScore(_ score: Double) -> Color {
        colorForScore(score).opacity(0.15)
    }

    /// Returns the appropriate color for a match rate percentage (0-100)
    /// Uses 80/50 thresholds for high/medium/low recognition quality
    ///
    /// - 80-100: High match rate (success/green)
    /// - 50-79: Medium match rate (warning/orange)
    /// - 0-49: Low match rate (error/red)
    static func colorForMatchRate(_ percentage: Int) -> Color {
        if percentage >= 80 {
            return success
        } else if percentage >= 50 {
            return warning
        } else {
            return error
        }
    }
}
