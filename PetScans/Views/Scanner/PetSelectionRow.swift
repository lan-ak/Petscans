import SwiftUI

struct PetSelectionRow: View {
    let pet: Pet
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SpacingTokens.xs) {
                PetIconView(
                    species: pet.speciesEnum,
                    size: .small,
                    foregroundColor: isSelected ? .white : ColorTokens.brandPrimary
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .heading3()
                        .foregroundColor(isSelected ? .white : ColorTokens.textPrimary)

                    if !pet.allergens.isEmpty {
                        Text("\(pet.allergenCountText) tracked")
                            .caption()
                            .foregroundColor(isSelected ? .white.opacity(0.8) : ColorTokens.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(SpacingTokens.xs)
            .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.surfaceSecondary)
            .cornerRadius(SpacingTokens.radiusMedium)
        }
        .buttonStyle(.plain)
    }
}
