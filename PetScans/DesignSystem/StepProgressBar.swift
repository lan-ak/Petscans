import SwiftUI

/// A reusable horizontal step progress bar with animated fill.
/// Shows progress through a multi-step process.
///
/// Usage:
/// ```swift
/// StepProgressBar(currentStep: 2, totalSteps: 5)
/// StepProgressBar(progress: 0.6)
/// ```
struct StepProgressBar: View {

    // MARK: - Configuration

    let progress: Double
    let activeColor: Color
    let inactiveColor: Color
    let height: CGFloat
    let showTrailingIcon: Bool
    let trailingIcon: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    private let iconSize: CGFloat = 20

    // MARK: - Init (Progress-based)

    /// Create a progress bar with a progress value (0.0 to 1.0)
    init(
        progress: Double,
        activeColor: Color = ColorTokens.brandPrimary,
        inactiveColor: Color = ColorTokens.surfaceSecondary,
        height: CGFloat = 4,
        showTrailingIcon: Bool = false,
        trailingIcon: String = "pawprint.fill"
    ) {
        self.progress = min(max(progress, 0), 1) // Clamp to 0-1
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.height = height
        self.showTrailingIcon = showTrailingIcon
        self.trailingIcon = trailingIcon
    }

    /// Create a progress bar with current step and total steps
    init(
        currentStep: Int,
        totalSteps: Int,
        activeColor: Color = ColorTokens.brandPrimary,
        inactiveColor: Color = ColorTokens.surfaceSecondary,
        height: CGFloat = 4,
        showTrailingIcon: Bool = false,
        trailingIcon: String = "pawprint.fill"
    ) {
        let calculatedProgress = totalSteps > 0
            ? Double(currentStep) / Double(totalSteps)
            : 0
        self.init(
            progress: calculatedProgress,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            height: height,
            showTrailingIcon: showTrailingIcon,
            trailingIcon: trailingIcon
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(inactiveColor)
                    .frame(height: height)

                // Active fill
                Capsule()
                    .fill(activeColor)
                    .frame(
                        width: geometry.size.width * progress,
                        height: height
                    )
                    .animation(
                        reduceMotion ? nil : AnimationTokens.springStandard,
                        value: progress
                    )

                // Trailing paw icon - positioned ON the bar
                if showTrailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(activeColor)
                                .frame(width: iconSize + 8, height: iconSize + 8)
                        )
                        .offset(x: max(0, (geometry.size.width * progress) - (iconSize / 2)))
                        .animation(
                            reduceMotion ? nil : AnimationTokens.springStandard,
                            value: progress
                        )
                }
            }
        }
        .frame(height: showTrailingIcon ? iconSize + 8 : height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Previews

#Preview("Progress Bar - 25%") {
    VStack(spacing: SpacingTokens.md) {
        StepProgressBar(progress: 0.25)
        StepProgressBar(progress: 0.5)
        StepProgressBar(progress: 0.75)
        StepProgressBar(progress: 1.0)
    }
    .padding()
}

#Preview("Step Progress - 2 of 4") {
    StepProgressBar(currentStep: 2, totalSteps: 4)
        .padding()
}
