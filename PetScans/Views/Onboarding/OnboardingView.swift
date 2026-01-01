import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var petName = ""
    @State private var petSpecies: Species = .dog

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
                petSpecies: $petSpecies
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
                .disabled(petName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } else {
            Button(currentPage == 0 ? "Get Started" : "Continue") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage += 1
                }
            }
            .primaryButtonStyle()
        }
    }

    private func createPetAndComplete() {
        let trimmedName = petName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let pet = Pet(name: trimmedName, species: petSpecies)
        modelContext.insert(pet)
        try? modelContext.save()

        completeOnboarding()
    }

    private func completeOnboarding() {
        onComplete()
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
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Pet.self, inMemory: true)
}
