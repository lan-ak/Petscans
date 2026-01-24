import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: SpacingTokens.iconOnboarding, height: SpacingTokens.iconOnboarding)
                .cornerRadius(SpacingTokens.radiusXLarge)

            VStack(spacing: SpacingTokens.sm) {
                Text("Welcome to PetScans")
                    .font(TypographyTokens.displayMedium)
                    .foregroundColor(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Let's get started")
                    .font(TypographyTokens.bodyLarge)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
        .accessibilityIdentifier("onboarding-welcome")
    }
}

#Preview {
    OnboardingWelcomePage()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.backgroundPrimary)
}
