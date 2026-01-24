import SwiftUI

/// Standardized sizes for pet icons across the app.
enum PetIconSize {
    case small   // PetSelectionRow
    case medium  // PetRowView
    case large   // PetDetailView

    var font: Font {
        switch self {
        case .small: return .title3
        case .medium: return .title2
        case .large: return .largeTitle
        }
    }

    var frameSize: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 32
        case .large: return 44
        }
    }
}

/// Reusable pet species icon with consistent styling.
/// Used in PetRowView, PetSelectionRow, and PetDetailView.
struct PetIconView: View {
    let species: Species
    var size: PetIconSize = .medium
    var foregroundColor: Color = ColorTokens.brandPrimary

    var body: some View {
        Image(systemName: species.icon)
            .font(size.font)
            .foregroundColor(foregroundColor)
            .frame(width: size.frameSize, height: size.frameSize)
    }
}

#Preview("All Sizes") {
    VStack(spacing: SpacingTokens.md) {
        HStack(spacing: SpacingTokens.md) {
            PetIconView(species: .dog, size: .small)
            PetIconView(species: .dog, size: .medium)
            PetIconView(species: .dog, size: .large)
        }
        HStack(spacing: SpacingTokens.md) {
            PetIconView(species: .cat, size: .small)
            PetIconView(species: .cat, size: .medium)
            PetIconView(species: .cat, size: .large)
        }
    }
}
