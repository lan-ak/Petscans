import SwiftUI

/// PetScans logo component combining search icon with app name
/// Follows the design system's Yuka-inspired clean aesthetic
struct PetScansLogo: View {
    enum Size {
        case small
        case medium
        case large
        case custom(iconSize: CGFloat, fontSize: CGFloat)

        var iconSize: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 40
            case .large: return 60
            case .custom(let size, _): return size
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 28
            case .large: return 40
            case .custom(_, let size): return size
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
        HStack(spacing: size.iconSize * 0.25) {
            // Search icon with custom styling
            ZStack {
                // Outer circle (magnifying glass lens)
                Circle()
                    .strokeBorder(ColorTokens.brandPrimary, lineWidth: size.iconSize * 0.12)
                    .frame(width: size.iconSize * 0.65, height: size.iconSize * 0.65)
                    .offset(x: -size.iconSize * 0.08, y: -size.iconSize * 0.08)

                // Magnifying glass handle
                RoundedRectangle(cornerRadius: size.iconSize * 0.06)
                    .fill(ColorTokens.brandPrimary)
                    .frame(width: size.iconSize * 0.12, height: size.iconSize * 0.4)
                    .rotationEffect(.degrees(45))
                    .offset(x: size.iconSize * 0.25, y: size.iconSize * 0.25)

                // Small paw print inside the lens for pet theme
                PawPrintIcon(size: size.iconSize * 0.28)
                    .foregroundColor(ColorTokens.brandSecondary)
                    .offset(x: -size.iconSize * 0.08, y: -size.iconSize * 0.08)
            }
            .frame(width: size.iconSize, height: size.iconSize)

            if showText {
                // App name with Quicksand font
                Text("PetScans")
                    .font(.custom("Quicksand", size: size.fontSize).weight(.bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .kerning(size.fontSize * 0.02)
            }
        }
    }
}

/// Simple paw print icon for the logo
private struct PawPrintIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Main pad (larger oval at bottom)
            Ellipse()
                .frame(width: size * 0.55, height: size * 0.65)
                .offset(y: size * 0.18)

            // Top left toe
            Circle()
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(x: -size * 0.25, y: -size * 0.15)

            // Top middle toe
            Circle()
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(y: -size * 0.25)

            // Top right toe
            Circle()
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(x: size * 0.25, y: -size * 0.15)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Logo Variations

extension PetScansLogo {
    /// Logo with inverted colors for dark backgrounds
    func inverted() -> some View {
        self.colorScheme(.dark)
    }

    /// Monochrome version of the logo
    func monochrome(color: Color = .primary) -> some View {
        self.foregroundColor(color)
    }
}

// MARK: - Previews

#Preview("Logo Sizes") {
    VStack(spacing: 32) {
        PetScansLogo(size: .small)
        PetScansLogo(size: .medium)
        PetScansLogo(size: .large)
    }
    .padding()
}

#Preview("Icon Only") {
    HStack(spacing: 24) {
        PetScansLogo(size: .small, showText: false)
        PetScansLogo(size: .medium, showText: false)
        PetScansLogo(size: .large, showText: false)
    }
    .padding()
}

#Preview("On Colored Backgrounds") {
    VStack(spacing: 0) {
        // Light background
        PetScansLogo(size: .large)
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(ColorTokens.backgroundPrimary)

        // Dark background
        PetScansLogo(size: .large)
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(Color.black)
            .colorScheme(.dark)

        // Brand color background
        PetScansLogo(size: .large, showText: false)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(ColorTokens.brandPrimary)
    }
}

#Preview("Custom Sizes") {
    VStack(spacing: 24) {
        PetScansLogo(size: .custom(iconSize: 30, fontSize: 24))
        PetScansLogo(size: .custom(iconSize: 50, fontSize: 36))
        PetScansLogo(size: .custom(iconSize: 80, fontSize: 56))
    }
    .padding()
}
