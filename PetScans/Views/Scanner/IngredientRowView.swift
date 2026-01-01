import SwiftUI

struct IngredientRowView: View {
    let ingredient: Ingredient
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: SpacingTokens.sm) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: SpacingTokens.iconMedium))
                    .foregroundColor(isSelected ? ColorTokens.brandPrimary : ColorTokens.textSecondary)

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
            }
            .padding(.vertical, SpacingTokens.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var riskIndicator: some View {
        switch ingredient.riskLevel {
        case "caution":
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.warning)
        case "toxic":
            Image(systemName: "xmark.circle.fill")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.error)
        default:
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
            isSelected: false,
            onToggle: {}
        )
    }
}
