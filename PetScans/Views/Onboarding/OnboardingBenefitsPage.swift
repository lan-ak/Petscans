import SwiftUI

struct OnboardingBenefitsPage: View {
    let icon: String
    let headline: String
    let subheadline: String

    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            Image(systemName: icon)
                .font(.system(size: SpacingTokens.iconXXLarge, weight: .medium))
                .foregroundColor(ColorTokens.brandPrimary)

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
