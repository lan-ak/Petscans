import SwiftUI

struct OnboardingPetSetupPage: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedAllergens: Set<String>

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                PetFormView(
                    petName: $petName,
                    petSpecies: $petSpecies,
                    selectedAllergens: $selectedAllergens
                )

                // Footer
                Text("You can always update this later\nin Settings")
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, SpacingTokens.sm)
            }
            .padding(.horizontal, SpacingTokens.screenPadding)
            .padding(.top, SpacingTokens.md)
        }
        .accessibilityIdentifier("onboarding-pet-setup")
    }
}

#Preview {
    OnboardingPetSetupPage(
        petName: .constant(""),
        petSpecies: .constant(.dog),
        selectedAllergens: .constant([])
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("With Selections") {
    OnboardingPetSetupPage(
        petName: .constant("Buddy"),
        petSpecies: .constant(.dog),
        selectedAllergens: .constant(["ing_chicken", "ing_beef", "ing_wheat"])
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
