import SwiftUI

/// A selectable row for choosing what a scan is scored against: a specific pet, or a
/// general species-level scan. Both options share one component so the layout, the
/// selected styling and the selection animation are defined in a single place.
struct ScanTargetRow: View {
    enum Target {
        case pet(Pet)
        case general
    }

    let target: Target
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SpacingTokens.xs) {
                leadingIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .heading3()
                        .foregroundColor(isSelected ? .white : ColorTokens.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .caption()
                            .foregroundColor(isSelected ? .white.opacity(0.8) : ColorTokens.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(TypographyTokens.heading1)
                    .foregroundColor(isSelected ? .white : ColorTokens.textSecondary)
            }
            .padding(SpacingTokens.xs)
            .background(isSelected ? ColorTokens.brandPrimary : ColorTokens.surfaceSecondary)
            .cornerRadius(SpacingTokens.radiusMedium)
        }
        .buttonStyle(.plain)
        .animateSnappy(value: isSelected)
    }

    // MARK: - Content

    @ViewBuilder
    private var leadingIcon: some View {
        switch target {
        case .pet(let pet):
            PetIconView(
                species: pet.speciesEnum,
                size: .small,
                foregroundColor: tintColor
            )
        case .general:
            Image(systemName: "magnifyingglass")
                .font(PetIconSize.small.font)
                .foregroundColor(tintColor)
                .frame(width: PetIconSize.small.frameSize, height: PetIconSize.small.frameSize)
        }
    }

    private var tintColor: Color {
        isSelected ? .white : ColorTokens.brandPrimary
    }

    private var title: String {
        switch target {
        case .pet(let pet): return pet.name
        case .general: return "General scan"
        }
    }

    private var subtitle: String? {
        switch target {
        case .pet(let pet):
            return pet.allergens.isEmpty ? nil : "\(pet.allergenCountText) tracked"
        case .general:
            return "Select species below"
        }
    }
}
