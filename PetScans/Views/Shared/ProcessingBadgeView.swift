import SwiftUI

/// Displays NOVA-style processing level badge
/// This is purely informational and does NOT affect scores
struct ProcessingBadgeView: View {
    let level: ProcessingLevel
    var size: BadgeSize = .medium
    var showLabel: Bool = true

    enum BadgeSize {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 16
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return SpacingTokens.xxxs
            case .medium: return SpacingTokens.xxs
            case .large: return SpacingTokens.xs
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return SpacingTokens.xxxs
            case .large: return SpacingTokens.xxs
            }
        }

        var font: Font {
            switch self {
            case .small: return TypographyTokens.caption
            case .medium: return TypographyTokens.labelSmall
            case .large: return TypographyTokens.labelMedium
            }
        }
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Image(systemName: level.icon)
                .font(.system(size: size.iconSize, weight: .semibold))

            if showLabel {
                Text(level.shortName)
                    .font(size.font)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(level.color)
        .cornerRadius(SpacingTokens.radiusSmall)
    }
}

#Preview("Badge Sizes") {
    VStack(spacing: SpacingTokens.md) {
        ForEach(ProcessingLevel.allCases) { level in
            HStack(spacing: SpacingTokens.sm) {
                ProcessingBadgeView(level: level, size: .small)
                ProcessingBadgeView(level: level, size: .medium)
                ProcessingBadgeView(level: level, size: .large)
            }
        }
    }
    .padding()
}

#Preview("Icon Only") {
    HStack(spacing: SpacingTokens.xs) {
        ForEach(ProcessingLevel.allCases) { level in
            ProcessingBadgeView(level: level, size: .small, showLabel: false)
        }
    }
    .padding()
}
