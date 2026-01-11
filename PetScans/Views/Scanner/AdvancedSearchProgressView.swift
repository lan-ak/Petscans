import SwiftUI

/// Animated step-by-step progress indicator for advanced search
/// Shows current step with animated icon, status text, and dot indicators
struct AdvancedSearchProgressView: View {
    let currentStep: AdvancedSearchViewModel.SearchStep
    let completedSteps: Set<AdvancedSearchViewModel.SearchStep>

    // MARK: - Animation State

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5
    @State private var iconScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    private let iconCircleSize: CGFloat = 80
    private let pulseRingSize: CGFloat = 100

    private var displaySteps: [AdvancedSearchViewModel.SearchStep] {
        [.lookingUpBarcode, .searchingProduct, .extractingIngredients, .analyzingIngredients]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: SpacingTokens.xl) {
            // Main animated icon
            iconSection

            // Status text (hidden on failure - shown in errorSection instead)
            if currentStep != .failed {
                statusTextSection
            }

            // Step dots
            stepDotsSection
        }
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: currentStep) { _, _ in
            triggerStepChangeAnimation()
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        ZStack {
            // Pulse ring (only for active, non-terminal states)
            if !currentStep.isTerminal && !reduceMotion {
                Circle()
                    .stroke(iconColor.opacity(0.3), lineWidth: 4)
                    .frame(width: pulseRingSize, height: pulseRingSize)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }

            // Background circle
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: iconCircleSize, height: iconCircleSize)

            // Icon
            Image(systemName: currentStep.icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(iconColor)
                .scaleEffect(iconScale)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentStep.displayTitle)
        .accessibilityValue(currentStep.activeDescription)
    }

    // MARK: - Status Text Section

    private var statusTextSection: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Text(currentStep.displayTitle)
                .heading1()
                .foregroundColor(ColorTokens.textPrimary)

            Text(currentStep.activeDescription)
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .animateStandard(value: currentStep)
    }

    // MARK: - Step Dots Section

    private var stepDotsSection: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(displaySteps) { step in
                StepDot(
                    step: step,
                    currentStep: currentStep,
                    isCompleted: completedSteps.contains(step)
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var iconBackgroundColor: Color {
        switch currentStep {
        case .complete:
            return ColorTokens.success.opacity(0.15)
        case .failed:
            return ColorTokens.error.opacity(0.15)
        default:
            return ColorTokens.brandPrimary.opacity(0.15)
        }
    }

    private var iconColor: Color {
        switch currentStep {
        case .complete:
            return ColorTokens.success
        case .failed:
            return ColorTokens.error
        default:
            return ColorTokens.brandPrimary
        }
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        guard !reduceMotion else { return }

        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.2
            pulseOpacity = 0.0
        }
    }

    private func triggerStepChangeAnimation() {
        guard !reduceMotion else { return }

        // Bounce effect on step change
        withAnimation(AnimationTokens.springSnappy) {
            iconScale = 0.85
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(AnimationTokens.springStandard) {
                iconScale = 1.0
            }
        }
    }
}

// MARK: - Step Dot

/// Individual step indicator dot
private struct StepDot: View {
    let step: AdvancedSearchViewModel.SearchStep
    let currentStep: AdvancedSearchViewModel.SearchStep
    let isCompleted: Bool

    private var isActive: Bool {
        step.rawValue == currentStep.rawValue
    }

    private var isPending: Bool {
        step.rawValue > currentStep.rawValue
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
        .animation(AnimationTokens.springSnappy, value: isActive)
        .animation(AnimationTokens.springSnappy, value: isCompleted)
        .accessibilityHidden(true)
    }

    private var dotSize: CGFloat {
        isActive ? 12 : 8
    }

    private var dotColor: Color {
        if isCompleted {
            return ColorTokens.success
        } else if isActive {
            return ColorTokens.brandPrimary
        } else {
            return ColorTokens.surfaceSecondary
        }
    }
}

// MARK: - Preview

#Preview("In Progress") {
    VStack {
        AdvancedSearchProgressView(
            currentStep: .searchingProduct,
            completedSteps: [.lookingUpBarcode]
        )
    }
    .padding()
}

#Preview("Complete") {
    VStack {
        AdvancedSearchProgressView(
            currentStep: .complete,
            completedSteps: [.lookingUpBarcode, .searchingProduct, .extractingIngredients, .analyzingIngredients, .complete]
        )
    }
    .padding()
}

#Preview("Failed") {
    VStack {
        AdvancedSearchProgressView(
            currentStep: .failed,
            completedSteps: [.lookingUpBarcode]
        )
    }
    .padding()
}
