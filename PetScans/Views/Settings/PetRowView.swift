import SwiftUI

struct PetRowView: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            PetIconView(species: pet.speciesEnum, size: .medium)

            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(pet.name)
                    .heading2()

                HStack(spacing: SpacingTokens.xxs) {
                    Text(pet.speciesEnum.displayName)
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)

                    if !pet.allergens.isEmpty {
                        Text("•")
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)

                        Text(pet.allergenCountText)
                            .caption()
                            .foregroundColor(ColorTokens.warning)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, SpacingTokens.xxxs)
    }
}
