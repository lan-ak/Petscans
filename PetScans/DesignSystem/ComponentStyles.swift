import SwiftUI

// MARK: - Surfaces
//
// The app has exactly two filled-surface roles, and every filled surface in it should
// be one of them. Before this existed, six views used `cardStyle()` while roughly
// twenty hand-rolled `.background(surfacePrimary).cornerRadius(...)` — so the app ran
// two visual languages at once: elevated, continuous-cornered cards in a handful of
// places and flat, circular-cornered panels everywhere else. That inconsistency reads
// as carelessness long before anyone can name what is wrong.

extension View {
    /// A panel that sits **above** the page: cards, sheets' content blocks, tiles.
    /// Continuous corners and two shadows — a tight contact shade plus a wider ambient
    /// one. A single mid-blur shadow is the look of a default.
    /// - Parameter glow: when a surface is *selected*, its ambient shade takes the
    ///   accent hue and lifts further, so choosing reads as the card rising rather than
    ///   as a rule appearing around it. Passing nil gives the resting elevation.
    func raisedSurface(
        cornerRadius: CGFloat = SpacingTokens.radiusLarge,
        fill: Color = ColorTokens.surfacePrimary,
        glow: Color? = nil
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
                .shadow(color: ColorTokens.elevationShadow, radius: 1, x: 0, y: 1)
                .shadow(color: glow ?? ColorTokens.elevationShadow.opacity(0.55),
                        radius: glow == nil ? 10 : 16,
                        x: 0, y: glow == nil ? 4 : 7)
        )
    }

    /// A surface that sits **in** the page: text fields, image wells, chips. Same corner
    /// geometry, no elevation — a drop shadow on a text field says the field is floating
    /// above the card it is written on, which is never what is meant.
    func insetSurface(
        cornerRadius: CGFloat = SpacingTokens.radiusMedium,
        fill: Color = ColorTokens.surfacePrimary
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(fill)
        )
    }
}

// MARK: - Card Styles

/// Modifier for standard card styling with background and corner radius
struct CardModifier: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let padding: CGFloat

    init(
        backgroundColor: Color = ColorTokens.surfacePrimary,
        cornerRadius: CGFloat = SpacingTokens.radiusLarge,
        padding: CGFloat = SpacingTokens.cardPadding
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .raisedSurface(cornerRadius: cornerRadius, fill: backgroundColor)
    }
}

// MARK: - Button Styles

/// Primary button style - Solid green background with white text
struct PrimaryButtonStyle: ButtonStyle {
    let isDestructive: Bool

    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypographyTokens.labelLarge)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium, style: .continuous)
                    .fill(isDestructive ? ColorTokens.error : ColorTokens.brandPrimary)
                    // Restrained on purpose. At 0.28/12 this read as a neon bloom on a
                    // white ground rather than as a button with weight — the tell of a
                    // shadow chosen for effect instead of for elevation.
                    .shadow(color: (isDestructive ? ColorTokens.error : ColorTokens.brandPrimary).opacity(0.20),
                            radius: 8, x: 0, y: 4)
            )
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AnimationTokens.buttonTap, value: configuration.isPressed)
    }
}

/// Secondary button style - Subtle gray background
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypographyTokens.labelLarge)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ColorTokens.surfaceSecondary)
            .foregroundColor(ColorTokens.textPrimary)
            .cornerRadius(SpacingTokens.radiusMedium)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AnimationTokens.buttonTap, value: configuration.isPressed)
    }
}

// MARK: - Chip Style

/// Modifier for filter chip styling (pill-shaped with selection state)
struct ChipModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(TypographyTokens.labelMedium)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs)
            .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.surfaceSecondary)
            .foregroundColor(isSelected ? .white : ColorTokens.textPrimary)
            .cornerRadius(SpacingTokens.radiusCircular)
    }
}

// MARK: - Badge Style

/// Modifier for small badge styling
struct BadgeModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(TypographyTokens.labelSmall)
            .foregroundColor(.white)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(color)
            .cornerRadius(SpacingTokens.radiusSmall)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card styling
    /// - Parameters:
    ///   - backgroundColor: Background color (default: surfacePrimary)
    ///   - cornerRadius: Corner radius (default: 16pt)
    ///   - padding: Internal padding (default: 16pt)
    func cardStyle(
        backgroundColor: Color = ColorTokens.surfacePrimary,
        cornerRadius: CGFloat = SpacingTokens.radiusLarge,
        padding: CGFloat = SpacingTokens.cardPadding
    ) -> some View {
        self.modifier(CardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            padding: padding
        ))
    }

    /// Apply chip styling
    /// - Parameter isSelected: Whether the chip is in selected state
    func chipStyle(isSelected: Bool = false) -> some View {
        self.modifier(ChipModifier(isSelected: isSelected))
    }

    /// Apply badge styling
    /// - Parameter color: Badge background color
    func badgeStyle(color: Color) -> some View {
        self.modifier(BadgeModifier(color: color))
    }
}

// MARK: - Button Style Extensions

extension View {
    /// Apply primary button style (solid green background)
    /// - Parameter isDestructive: Whether this is a destructive action (uses red color)
    func primaryButtonStyle(isDestructive: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isDestructive: isDestructive))
    }

    /// Apply secondary button style (subtle gray background)
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
}
