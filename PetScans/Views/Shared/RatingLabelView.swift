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
        // The verdict is the largest single element on the payoff screen, and it was
        // the least finished: a flat 12% wash behind a sharp-cornered rectangle. It now
        // carries the same depth language as every other surface — a gentle vertical
        // fall in the tint, a hairline ring to define the edge against a tinted ground,
        // and a shadow in its own hue rather than a neutral grey.
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [label.color.opacity(0.17), label.color.opacity(0.09)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(label.color.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: label.color.opacity(size == .small ? 0 : 0.16),
                        radius: 14, x: 0, y: 6)
        )
    }

    /// Larger sizes get a proportionally larger radius. One fixed radius across a chip
    /// and a hero block makes the hero look like a scaled-up chip.
    private var cornerRadius: CGFloat {
        switch size {
        case .small:  return SpacingTokens.radiusMedium
        case .medium: return SpacingTokens.radiusLarge
        case .large:  return SpacingTokens.radiusXLarge + 4
        }
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
