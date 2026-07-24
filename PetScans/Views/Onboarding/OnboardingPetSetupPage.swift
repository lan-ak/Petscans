import SwiftUI

struct OnboardingPetSetupPage: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedGroups: Set<AvoidanceGroup>

    var nameError: String?
    var isNameFocused: FocusState<Bool>.Binding?
    var onSubmitName: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                PetFormView(
                    petName: $petName,
                    petSpecies: $petSpecies,
                    // Onboarding asks about categories instead — a first-time
                    // user has not seen an ingredient list yet.
                    selectedAllergens: .constant([]),
                    showAllergens: false,
                    showHeaderIcon: false,
                    nameError: nameError,
                    isNameFocused: isNameFocused,
                    onSubmitName: onSubmitName
                )

                Divider()
                    .padding(.vertical, SpacingTokens.xxs)

                AvoidanceGroupPicker(selected: $selectedGroups)

                // Footer
                Text("You can always update this later in Settings")
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
        selectedGroups: .constant([])
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("With Selections") {
    OnboardingPetSetupPage(
        petName: .constant("Buddy"),
        petSpecies: .constant(.dog),
        selectedGroups: .constant([.artificialColours, .ultraProcessed])
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("Name Error") {
    OnboardingPetSetupPage(
        petName: .constant(""),
        petSpecies: .constant(.cat),
        selectedGroups: .constant([]),
        nameError: "Please enter your pet's name"
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
