import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            // The highest-attention slot in the product used to hold our own app icon,
            // which promised nothing. The pair carries the promise instead — and says
            // this app is about an animal before the headline says anything at all.
            //
            // Both animals, deliberately. The species question belongs on the search
            // screen where it costs no extra step; asking it here would put a decision
            // ahead of the demo, which is the ordering the funnel rebuild removed.
            // Anchored on a soft brand-tinted halo rather than floating in the middle
            // of an empty screen. The first pass centred a 120pt pair in roughly 600pt
            // of nothing, which is what a VStack with two Spacers gives you if nobody
            // composes the page — the hero has to hold the top half of the screen.
            CompanionPair(height: CompanionSize.hero.points)
                .background(
                    RadialGradient(
                        colors: [ColorTokens.brandPrimary.opacity(0.14), .clear],
                        center: .center, startRadius: 8, endRadius: 168
                    )
                    .frame(width: 340, height: 340)
                    .blur(radius: 8)
                )

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
