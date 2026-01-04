import SwiftUI

/// Shared pet form component used by onboarding and AddPetSheet
struct PetFormView: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedAllergens: Set<String>

    @State private var showingIngredientSearch = false

    /// Common allergens for quick selection (maps to ingredient IDs)
    private let commonAllergens: [(id: String, name: String)] = [
        ("ing_chicken", "Chicken"),
        ("ing_beef", "Beef"),
        ("ing_wheat", "Wheat"),
        ("ing_corn", "Corn"),
        ("ing_egg", "Egg"),
        ("ing_lamb", "Lamb")
    ]

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

            // Ingredients to avoid section
            ingredientSection
        }
        .sheet(isPresented: $showingIngredientSearch) {
            IngredientSearchSheet(selectedIngredientIds: $selectedAllergens)
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
                        .foregroundColor(ColorTokens.textTertiary)

                    Text("Search for more...")
                        .font(TypographyTokens.body)
                        .foregroundColor(ColorTokens.textTertiary)

                    Spacer()
                }
                .padding()
                .background(ColorTokens.surfacePrimary)
                .cornerRadius(SpacingTokens.radiusMedium)
            }
            .buttonStyle(.plain)
        }
    }

    private var commonAllergenChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: SpacingTokens.xxs) {
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
                        .labelSmall()
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                        .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.brandPrimary.opacity(0.1))
                        .foregroundColor(isSelected ? .white : ColorTokens.brandPrimary)
                        .cornerRadius(SpacingTokens.radiusSmall)
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
