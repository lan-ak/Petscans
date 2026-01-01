import SwiftUI

struct OnboardingPetSetupPage: View {
    @Binding var petName: String
    @Binding var petSpecies: Species

    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            Text("Let's meet your pet")
                .font(TypographyTokens.displayMedium)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: SpacingTokens.lg) {
                TextField("Pet Name", text: $petName)
                    .font(TypographyTokens.bodyLarge)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(ColorTokens.surfacePrimary)
                    .cornerRadius(SpacingTokens.radiusMedium)

                Picker("Species", selection: $petSpecies) {
                    ForEach(Species.allCases) { species in
                        Label(species.displayName, systemImage: species.icon)
                            .tag(species)
                    }
                }
                .pickerStyle(.segmented)
            }

            Text("You can add more pets and manage allergens in Settings")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
    }
}

#Preview {
    OnboardingPetSetupPage(
        petName: .constant(""),
        petSpecies: .constant(.dog)
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
