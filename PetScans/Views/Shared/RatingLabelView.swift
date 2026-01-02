import SwiftUI

/// Displays a rating label (Excellent/Good/Caution/Avoid) with icon and color
struct RatingLabelView: View {
    let label: RatingLabel
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

            Text(label.rawValue)
                .font(labelFont)
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
}

#Preview {
    VStack(spacing: SpacingTokens.lg) {
        RatingLabelView(label: .excellent)
        RatingLabelView(label: .good)
        RatingLabelView(label: .caution)
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
