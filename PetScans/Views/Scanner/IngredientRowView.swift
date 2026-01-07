import SwiftUI

struct IngredientRowView: View {
    let ingredient: Ingredient
    let species: Species
    let isSelected: Bool
    let onToggle: () -> Void

    /// Convenience initializer that defaults to dog
    init(ingredient: Ingredient, species: Species = .dog, isSelected: Bool, onToggle: @escaping () -> Void) {
        self.ingredient = ingredient
        self.species = species
        self.isSelected = isSelected
        self.onToggle = onToggle
    }

    /// The risk level for the current species
    private var currentRiskLevel: String {
        ingredient.riskLevel(for: species)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: SpacingTokens.sm) {
                // Ingredient info
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(ingredient.commonName)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)

                    if let function = ingredient.typicalFunction {
                        Text(function)
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }

                Spacer()

                // Risk level indicator
                riskIndicator

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: SpacingTokens.iconMedium))
                    .foregroundColor(isSelected ? ColorTokens.brandPrimary : ColorTokens.textSecondary)
            }
            .padding(.vertical, SpacingTokens.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var riskIndicator: some View {
        let risk = currentRiskLevel.lowercased()
        if risk.contains("caution") || risk.contains("moderation") {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.warning)
        } else if risk.contains("toxic") || risk.contains("avoid") {
            Image(systemName: "xmark.circle.fill")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.error)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    List {
        IngredientRowView(
            ingredient: Ingredient(
                id: "ing_chicken",
                commonName: "Chicken",
                scientificName: "Gallus domesticus",
                species: [.dog, .cat],
                categories: [.food],
                origin: "natural",
                riskLevel: "safe",
                allergenOrSensitizationRisk: nil,
                typicalFunction: "Primary protein source",
                notes: nil
            ),
            species: .dog,
            isSelected: true,
            onToggle: {}
        )

        IngredientRowView(
            ingredient: Ingredient(
                id: "ing_garlic",
                commonName: "Garlic",
                scientificName: nil,
                species: [.dog],
                categories: [.food],
                origin: "natural",
                riskLevel: "caution",
                allergenOrSensitizationRisk: nil,
                typicalFunction: "Flavoring",
                notes: nil
            ),
            species: .dog,
            isSelected: false,
            onToggle: {}
        )
    }
}
