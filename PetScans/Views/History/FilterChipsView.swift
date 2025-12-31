import SwiftUI

struct FilterChipsView: View {
    @Binding var selectedSpecies: Species?
    @Binding var selectedCategory: Category?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.xxs) {
                // Species filters
                ForEach(Species.allCases) { species in
                    FilterChip(
                        label: species.displayName,
                        icon: species.icon,
                        isSelected: selectedSpecies == species
                    ) {
                        if selectedSpecies == species {
                            selectedSpecies = nil
                        } else {
                            selectedSpecies = species
                        }
                    }
                }

                Divider()
                    .frame(height: 24)

                // Category filters
                ForEach(Category.allCases) { category in
                    FilterChip(
                        label: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        if selectedCategory == category {
                            selectedCategory = nil
                        } else {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, SpacingTokens.xxs)
        }
        .background(ColorTokens.surfacePrimary)
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xxxs) {
                Image(systemName: icon)
                    .labelSmall()
                Text(label)
                    .labelMedium()
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs + 2)
            .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.surfaceSecondary)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(SpacingTokens.radiusLarge)
        }
    }
}

#Preview {
    FilterChipsView(
        selectedSpecies: .constant(.dog),
        selectedCategory: .constant(nil)
    )
}
