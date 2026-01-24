import SwiftUI

/// Shared pet form component used by onboarding and AddPetSheet
struct PetFormView: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedAllergens: Set<String>

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Heart icon (generic for all pets)
            Image(systemName: "heart.fill")
                .font(.system(size: SpacingTokens.iconXXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            // Title
            Text("Let's meet your pet")
                .font(TypographyTokens.displayMedium)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            // Pet info section
            VStack(spacing: SpacingTokens.sm) {
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

            Divider()
                .padding(.vertical, SpacingTokens.xxs)

            // Ingredients to avoid section
            AllergenSelectionView(selectedAllergens: $selectedAllergens, showHeader: true)
        }
    }
}

#Preview {
    ScrollView {
        PetFormView(
            petName: .constant(""),
            petSpecies: .constant(.dog),
            selectedAllergens: .constant([])
        )
        .padding()
    }
    .background(ColorTokens.backgroundPrimary)
}
