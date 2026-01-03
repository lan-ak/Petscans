import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            if let appIcon = UIImage(named: "AppIcon") {
                Image(uiImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(SpacingTokens.radiusXLarge)
            }

            VStack(spacing: SpacingTokens.sm) {
                Text("Know what's really in your pet's products")
                    .font(TypographyTokens.displayMedium)
                    .foregroundColor(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Every ingredient. Every product. Total peace of mind.")
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
