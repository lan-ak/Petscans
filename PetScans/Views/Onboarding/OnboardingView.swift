import SwiftUI
import SwiftData
import SuperwallKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var petName = ""
    @State private var petSpecies: Species = .dog
    @State private var selectedAllergens: Set<String> = []
    @State private var isSubmitting = false

    let onComplete: () -> Void

    private let totalPages = 4

    var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                pageContent

                Spacer()

                PageIndicator(totalPages: totalPages, currentPage: currentPage)
                    .padding(.bottom, SpacingTokens.lg)

                navigationButtons
                    .padding(.horizontal, SpacingTokens.screenPadding)
                    .padding(.bottom, SpacingTokens.xxl)
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0:
            OnboardingWelcomePage()
                .transition(.opacity)
        case 1:
            OnboardingBenefitsPage(
                icon: "magnifyingglass.circle.fill",
                headline: "Know what's in every product",
                subheadline: "Every ingredient revealed. Instant alerts for anything your pet should avoid."
            )
            .transition(.opacity)
        case 2:
            OnboardingBenefitsPage(
                icon: "text.viewfinder",
                headline: "The world's largest database",
                subheadline: "Scan any product label or type ingredients manually. We'll analyze them all instantly."
            )
            .transition(.opacity)
        case 3:
            OnboardingPetSetupPage(
                petName: $petName,
                petSpecies: $petSpecies,
                selectedAllergens: $selectedAllergens
            )
            .transition(.opacity)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        if currentPage == 3 {
            HStack(spacing: SpacingTokens.sm) {
                Button("Skip for now") {
                    completeOnboarding()
                }
                .secondaryButtonStyle()
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.6 : 1)

                Button {
                    createPetAndComplete()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Let's go!")
                    }
                }
                .primaryButtonStyle()
                .disabled(!petName.isNotBlank || isSubmitting)
            }
        } else {
            Button(currentPage == 0 ? "Get Started" : "Continue") {
                withStandardAnimation {
                    currentPage += 1
                }
            }
            .primaryButtonStyle()
        }
    }

    private func createPetAndComplete() {
        guard petName.isNotBlank, !isSubmitting else { return }
        isSubmitting = true

        let pet = Pet(name: petName.trimmed, species: petSpecies, allergens: Array(selectedAllergens))
        modelContext.insert(pet)
        try? modelContext.save()

        completeOnboarding()
    }

    private func completeOnboarding() {
        isSubmitting = true

        // Set user attributes for Superwall targeting
        Superwall.shared.setUserAttributes([
            "pet_species": petSpecies.rawValue,
            "pet_count": 1,
            "onboarding_completed_at": Date()
        ])

        Superwall.shared.register(placement: "onboarding_complete") {
            onComplete()
        }
    }
}

struct PageIndicator: View {
    let totalPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? ColorTokens.brandPrimary : ColorTokens.border)
                    .frame(width: SpacingTokens.xxs, height: SpacingTokens.xxs)
                    .animateSnappy(value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Pet.self, inMemory: true)
}
