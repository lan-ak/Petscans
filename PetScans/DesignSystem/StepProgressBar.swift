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

// MARK: - Step Progress Bar with Dots

/// A progress bar with connected step dots below
struct StepProgressBarWithDots: View {

    let currentStep: Int
    let totalSteps: Int
    let completedSteps: Set<Int>
    let activeColor: Color
    let completedColor: Color
    let inactiveColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        currentStep: Int,
        totalSteps: Int,
        completedSteps: Set<Int> = [],
        activeColor: Color = ColorTokens.brandPrimary,
        completedColor: Color = ColorTokens.success,
        inactiveColor: Color = ColorTokens.surfaceSecondary
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.activeColor = activeColor
        self.completedColor = completedColor
        self.inactiveColor = inactiveColor
    }

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            // Progress bar
            StepProgressBar(
                currentStep: completedSteps.count,
                totalSteps: totalSteps,
                activeColor: activeColor,
                inactiveColor: inactiveColor
            )
            .padding(.horizontal, SpacingTokens.lg)

            // Step dots with connecting lines
            HStack(spacing: 0) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    if step > 0 {
                        // Connecting line
                        Rectangle()
                            .fill(lineColor(for: step))
                            .frame(height: 2)
                            .animation(
                                reduceMotion ? nil : AnimationTokens.springSnappy,
                                value: completedSteps.contains(step)
                            )
                    }

                    // Step dot
                    StepDotView(
                        step: step,
                        isActive: step == currentStep,
                        isCompleted: completedSteps.contains(step),
                        activeColor: activeColor,
                        completedColor: completedColor,
                        inactiveColor: inactiveColor
                    )
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
        }
    }

    private func lineColor(for step: Int) -> Color {
        // Line is filled if the previous step is completed
        completedSteps.contains(step - 1) ? completedColor : inactiveColor
    }
}

// MARK: - Step Dot View

private struct StepDotView: View {
    let step: Int
    let isActive: Bool
    let isCompleted: Bool
    let activeColor: Color
    let completedColor: Color
    let inactiveColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dotSize: CGFloat {
        isActive ? 12 : 8
    }

    private var dotColor: Color {
        if isCompleted {
            return completedColor
        } else if isActive {
            return activeColor
        }
        return inactiveColor
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .animation(
            reduceMotion ? nil : AnimationTokens.springSnappy,
            value: isActive
        )
        .animation(
            reduceMotion ? nil : AnimationTokens.springSnappy,
            value: isCompleted
        )
        .accessibilityHidden(true)
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

#Preview("With Dots - In Progress") {
    StepProgressBarWithDots(
        currentStep: 2,
        totalSteps: 4,
        completedSteps: [0, 1]
    )
    .padding()
}

#Preview("With Dots - Complete") {
    StepProgressBarWithDots(
        currentStep: 4,
        totalSteps: 4,
        completedSteps: [0, 1, 2, 3]
    )
    .padding()
}
