import SwiftUI

/// Shared pet form component used by onboarding and AddPetSheet
struct PetFormView: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedAllergens: Set<String>

    @State private var showingIngredientSearch = false

    /// Common allergens for quick selection (stores lowercased names to match AddAllergenSheet)
    private let commonAllergens: [(id: String, name: String)] = [
        ("chicken", "Chicken"),
        ("beef", "Beef"),
        ("wheat", "Wheat"),
        ("corn", "Corn"),
        ("egg", "Egg"),
        ("lamb", "Lamb")
    ]

    /// Selected allergens that aren't in the common list
    private var otherSelectedAllergens: [String] {
        let commonIds = Set(commonAllergens.map { $0.id })
        return selectedAllergens
            .filter { !commonIds.contains($0) }
            .sorted()
    }

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
            ingredientSection
        }
        .sheet(isPresented: $showingIngredientSearch) {
            IngredientSearchSheet(selectedAllergens: $selectedAllergens)
        }
    }

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            // Section header
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text("What ingredients are you avoiding?")
                    .font(TypographyTokens.heading3)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("(optional)")
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textTertiary)
            }

            // Common allergens quick-pick chips
            commonAllergenChips

            // Search for more button
            Button {
                showingIngredientSearch = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search for more...")
                    Spacer()
                }
            }
            .secondaryButtonStyle()
        }
    }

    private var commonAllergenChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: SpacingTokens.xxs) {
            ForEach(commonAllergens, id: \.id) { allergen in
                let isSelected = selectedAllergens.contains(allergen.id)
                Button {
                    if isSelected {
                        selectedAllergens.remove(allergen.id)
                    } else {
                        selectedAllergens.insert(allergen.id)
                    }
                } label: {
                    Text(allergen.name)
                        .lineLimit(1)
                        .chipStyle(isSelected: isSelected)
                }
                .buttonStyle(.plain)
            }

            // Other selected allergens (not in common list)
            ForEach(otherSelectedAllergens, id: \.self) { allergen in
                Button {
                    selectedAllergens.remove(allergen)
                } label: {
                    Text(allergen.capitalized)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .chipStyle(isSelected: true)
                }
                .buttonStyle(.plain)
            }
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
