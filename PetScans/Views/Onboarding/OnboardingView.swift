import SwiftUI
import SwiftData
import SuperwallKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var petName = ""
    @State private var petSpecies: Species = .dog
    @State private var selectedAllergens: Set<String> = []

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
                icon: "checkmark.seal.fill",
                headline: "Make confident choices",
                subheadline: "Scan any pet food, treat, or cosmetic. Get instant safety insights backed by veterinary science."
            )
            .transition(.opacity)
        case 2:
            OnboardingBenefitsPage(
                icon: "pawprint.fill",
                headline: "Protection, tailored to your pet",
                subheadline: "Set up allergen alerts and species-specific warnings. Because every pet deserves their own guardian."
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

                Button("Let's go!") {
                    createPetAndComplete()
                }
                .primaryButtonStyle()
                .disabled(!petName.isNotBlank)
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
        guard petName.isNotBlank else { return }

        let pet = Pet(name: petName.trimmed, species: petSpecies, allergens: Array(selectedAllergens))
        modelContext.insert(pet)
        try? modelContext.save()

        completeOnboarding()
    }

    private func completeOnboarding() {
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
