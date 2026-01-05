import SwiftUI

struct FilterChipsView: View {
    @Binding var selectedSpecies: Species?
    @Binding var selectedCategory: Category?
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button - always visible
            Button {
                withSnappyAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter")
                        .labelMedium()
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(ColorTokens.textPrimary)
                .padding(.horizontal)
                .padding(.vertical, SpacingTokens.xs)
            }
            .buttonStyle(.plain)

            // Expandable filter chips
            if isExpanded {
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
                        ForEach(Category.allCases.filter { $0 != .cosmetic }) { category in
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
            }
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
            .padding(.vertical, SpacingTokens.xxs)
            .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.surfaceSecondary)
            .foregroundColor(isSelected ? .white : ColorTokens.textPrimary)
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
