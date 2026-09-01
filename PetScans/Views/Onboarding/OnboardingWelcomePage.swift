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
                // The first screen gets one job: name the outcome the user came for.
                //
                // This used to read "Welcome to PetScans", which spent the highest-
                // attention slot in the funnel on our own name and promised nothing. The
                // allergen / personalized-protection angle is the one that actually won
                // the Meta concept test (6.26% CTR, the best of five), so the app now
                // opens on the same promise the ad made rather than resetting to a
                // generic greeting.
                Text("Find out what's really in your pet's food")
                    .font(TypographyTokens.displayMedium)
                    .foregroundColor(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Most bags hide something. Scan any food and see what your pet should be avoiding — in seconds.")
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
