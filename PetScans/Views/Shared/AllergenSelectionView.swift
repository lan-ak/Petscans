import SwiftUI

/// The most common food allergens per species, offered as one-tap quick-pick
/// chips. Ranked from Mueller & Olivry, "Critically appraised topic on adverse
/// food reactions of companion animals (2)", BMC Vet Res 2016 — beef/dairy/
/// chicken/wheat dominate dogs; beef/fish/chicken/wheat dominate cats. IDs are
/// lowercased to match how allergens are persisted and how ingredient rows
/// compute their selected state.
enum QuickPickAllergens {
    static func list(for species: Species) -> [(id: String, name: String)] {
        switch species {
        case .dog:
            return [
                ("beef", "Beef"),
                ("dairy", "Dairy"),
                ("chicken", "Chicken"),
                ("wheat", "Wheat"),
                ("soy", "Soy"),
                ("lamb", "Lamb")
            ]
        case .cat:
            return [
                ("beef", "Beef"),
                ("fish", "Fish"),
                ("chicken", "Chicken"),
                ("wheat", "Wheat"),
                ("dairy", "Dairy"),
                ("corn", "Corn")
            ]
        }
    }
}

/// Shared allergen selection component used by PetFormView (add-pet form).
struct AllergenSelectionView: View {
    @Binding var selectedAllergens: Set<String>
    var species: Species = .dog
    var showHeader: Bool = true

    @State private var showingIngredientSearch = false

    private var commonAllergens: [(id: String, name: String)] {
        QuickPickAllergens.list(for: species)
    }

    /// Selected allergens that aren't in the quick-pick list for this species.
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
            IngredientSearchSheet(selectedAllergens: $selectedAllergens, species: species)
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
