import SwiftUI

struct OnboardingBenefitsPage: View {
    let icon: String
    let headline: String
    let subheadline: String

    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            // Framed in a tinted chip rather than left as a bare glyph, so it
            // reads as an intentional badge (matching the app's icon treatment)
            // and keeps the welcome page's 120pt hero footprint for rhythm.
            Image(systemName: icon)
                .font(.system(size: SpacingTokens.iconXLarge, weight: .medium))
                .foregroundColor(ColorTokens.brandPrimary)
                .frame(width: SpacingTokens.iconOnboarding, height: SpacingTokens.iconOnboarding)
                .background(ColorTokens.brandPrimary.opacity(0.12))
                .clipShape(Circle())

            VStack(spacing: SpacingTokens.sm) {
                Text(headline)
                    .font(TypographyTokens.displayMedium)
                    .foregroundColor(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subheadline)
                    .font(TypographyTokens.bodyLarge)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
    }
}

#Preview("Confident Choices") {
    OnboardingBenefitsPage(
        icon: "checkmark.seal.fill",
        headline: "Make confident choices",
        subheadline: "Scan any pet food or treat. Get instant safety insights backed by veterinary science."
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("Personalized Protection") {
    OnboardingBenefitsPage(
        icon: "pawprint",
        headline: "Protection, tailored to your pet",
        subheadline: "Set up allergen alerts and species-specific warnings. Because every pet deserves their own guardian."
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
