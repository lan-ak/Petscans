import SwiftUI

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
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
    }
}

/// Modifier for outlined card styling with border
struct OutlinedCardModifier: ViewModifier {
    let backgroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat
    let padding: CGFloat

    init(
        backgroundColor: Color = ColorTokens.surfacePrimary,
        borderColor: Color = ColorTokens.border,
        cornerRadius: CGFloat = SpacingTokens.radiusLarge,
        padding: CGFloat = SpacingTokens.cardPadding
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
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
            .background(isDestructive ? ColorTokens.error : ColorTokens.brandPrimary)
            .foregroundColor(.white)
            .cornerRadius(SpacingTokens.radiusMedium)
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

/// Outlined button style - Transparent background with brand color border
struct OutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypographyTokens.labelLarge)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.clear)
            .foregroundColor(ColorTokens.brandPrimary)
            .cornerRadius(SpacingTokens.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium)
                    .stroke(ColorTokens.brandPrimary, lineWidth: 2)
            )
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

    /// Apply outlined card styling with border
    /// - Parameters:
    ///   - backgroundColor: Background color (default: surfacePrimary)
    ///   - borderColor: Border color (default: border)
    ///   - cornerRadius: Corner radius (default: 16pt)
    ///   - padding: Internal padding (default: 16pt)
    func outlinedCardStyle(
        backgroundColor: Color = ColorTokens.surfacePrimary,
        borderColor: Color = ColorTokens.border,
        cornerRadius: CGFloat = SpacingTokens.radiusLarge,
        padding: CGFloat = SpacingTokens.cardPadding
    ) -> some View {
        self.modifier(OutlinedCardModifier(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
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

    /// Apply outlined button style (brand color border)
    func outlinedButtonStyle() -> some View {
        self.buttonStyle(OutlinedButtonStyle())
    }
}
