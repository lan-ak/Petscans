import SwiftUI

struct PetSelectionRow: View {
    let pet: Pet
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: pet.speciesEnum.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : ColorTokens.brandPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .heading3()
                        .foregroundColor(isSelected ? .white : ColorTokens.textPrimary)

                    if !pet.allergens.isEmpty {
                        Text("\(pet.allergens.count) allergen\(pet.allergens.count == 1 ? "" : "s") tracked")
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
