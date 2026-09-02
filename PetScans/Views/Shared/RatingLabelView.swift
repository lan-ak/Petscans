import SwiftUI

/// Displays a rating label (Excellent/Good/Caution/Avoid) with icon and color
struct RatingLabelView: View {
    let label: RatingLabel
    /// The 0-100 total, rendered above the word. Supplied only when the word is the
    /// one this score implies — see `ProductScoreView.heroScore`. A suitability
    /// override can drop the word to "Avoid" while the total stays high, and
    /// "82/100 / Avoid" reads as a bug rather than as a warning.
    var score: Double? = nil
    var showIcon: Bool = true
    var size: RatingSize = .large

    enum RatingSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return SpacingTokens.iconSmall
            case .medium: return SpacingTokens.iconMedium
            case .large: return SpacingTokens.iconXLarge
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return SpacingTokens.xxs
            case .medium: return SpacingTokens.sm
            case .large: return SpacingTokens.md
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return SpacingTokens.sm
            case .medium: return SpacingTokens.md
            case .large: return SpacingTokens.xl
            }
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            if showIcon {
                Image(systemName: label.icon)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(label.color)
            }

            if let score {
                Text("\(Int(score.rounded()))/100")
                    .font(scoreFont)
                    .monospacedDigit()
                    .foregroundColor(label.color)
                    .accessibilityLabel("\(Int(score.rounded())) out of 100")
            }

            Text(label.rawValue)
                .font(score == nil ? labelFont : wordFont)
                .foregroundColor(label.color)
        }
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
        .background(label.color.opacity(0.12))
        .cornerRadius(SpacingTokens.radiusLarge)
    }

    private var labelFont: Font {
        switch size {
        case .small: return TypographyTokens.labelMedium
        case .medium: return TypographyTokens.heading1
        case .large: return TypographyTokens.displayMedium
        }
    }

    /// With a number present the number carries the emphasis, so it takes the size
    /// the word used to have and the word steps down one level rather than
    /// competing with it.
    private var scoreFont: Font {
        switch size {
        case .small: return TypographyTokens.labelLarge
        case .medium: return TypographyTokens.displaySmall
        case .large: return TypographyTokens.displayLarge
        }
    }

    private var wordFont: Font {
        switch size {
        case .small: return TypographyTokens.labelSmall
        case .medium: return TypographyTokens.heading2
        case .large: return TypographyTokens.heading1
        }
    }
}

#Preview {
    VStack(spacing: SpacingTokens.lg) {
        RatingLabelView(label: .excellent, score: 92)
        RatingLabelView(label: .good, score: 68)
        RatingLabelView(label: .caution, score: 34)
        RatingLabelView(label: .avoid)

        HStack(spacing: SpacingTokens.md) {
            RatingLabelView(label: .excellent, size: .small)
            RatingLabelView(label: .good, size: .small)
            RatingLabelView(label: .caution, size: .small)
            RatingLabelView(label: .avoid, size: .small)
        }
    }
    .padding()
}
