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

            // Progress bar with trailing paw icon
            progressBarSection
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

    // MARK: - Progress Bar Section

    private var progressBarSection: some View {
        StepProgressBar(
            progress: progressValue,
            activeColor: progressColor,
            inactiveColor: ColorTokens.surfaceSecondary,
            height: 6,
            showTrailingIcon: true,
            trailingIcon: "pawprint.fill"
        )
        .padding(.horizontal, SpacingTokens.xl)
    }

    private var progressValue: Double {
        guard currentStep != .failed else { return 0 }
        if currentStep == .complete { return 1.0 }
        return Double(completedSteps.intersection(Set(displaySteps)).count) / Double(displaySteps.count)
    }

    private var progressColor: Color {
        currentStep == .complete ? ColorTokens.success : ColorTokens.brandPrimary
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
