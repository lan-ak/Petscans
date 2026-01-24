import SwiftUI

/// Shared allergen selection component used by PetFormView and AddAllergenSheet
struct AllergenSelectionView: View {
    @Binding var selectedAllergens: Set<String>
    var showHeader: Bool = true

    @State private var showingIngredientSearch = false

    /// Common allergens for quick selection (stores lowercased names)
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
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if showHeader {
                // Section header
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text("What ingredients are you avoiding?")
                        .font(TypographyTokens.heading3)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("(optional)")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                }
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
        .sheet(isPresented: $showingIngredientSearch) {
            IngredientSearchSheet(selectedAllergens: $selectedAllergens)
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
    AllergenSelectionView(selectedAllergens: .constant(["chicken", "salmon"]))
        .padding()
}
