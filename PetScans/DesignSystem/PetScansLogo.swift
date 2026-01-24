import SwiftUI

/// PetScans logo component using the app icon from assets
struct PetScansLogo: View {
    enum Size {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 80
            case .large: return 120
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 28
            case .large: return 40
            }
        }
    }

    let size: Size
    let showText: Bool

    init(size: Size = .medium, showText: Bool = true) {
        self.size = size
        self.showText = showText
    }

    var body: some View {
        VStack(spacing: size.iconSize * 0.2) {
            // App icon from assets
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.iconSize, height: size.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: size.iconSize * 0.22))

            if showText {
                Text("PetScans")
                    .font(.custom("Quicksand", size: size.fontSize).weight(.bold))
                    .foregroundColor(ColorTokens.textPrimary)
            }
        }
    }
}

#Preview {
    VStack(spacing: SpacingTokens.xl) {
        PetScansLogo(size: .small)
        PetScansLogo(size: .medium)
        PetScansLogo(size: .large)
        PetScansLogo(size: .large, showText: false)
    }
    .padding()
}
