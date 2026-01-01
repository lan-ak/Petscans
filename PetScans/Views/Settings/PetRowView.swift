import SwiftUI

struct PetRowView: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: pet.speciesEnum.icon)
                .font(.title2)
                .foregroundColor(ColorTokens.brandPrimary)
                .frame(width: 32, height: 32)

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

                        Text("\(pet.allergens.count) allergen\(pet.allergens.count == 1 ? "" : "s")")
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
