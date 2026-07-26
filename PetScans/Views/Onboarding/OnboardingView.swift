import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var petName = ""
    @State private var petSpecies: Species = .dog
    @State private var selectedAllergens: Set<String> = []
    @State private var selectedGroups: Set<AvoidanceGroup> = []
    @State private var isSubmitting = false
    @State private var showNameValidation = false
    @FocusState private var isNameFocused: Bool

    let onComplete: () -> Void

    private let totalPages = 5
    private let profilePage = 3
    private let groupsPage = 4

    var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                backButton
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SpacingTokens.screenPadding)

                Spacer()

                pageContent

                Spacer()

                PageIndicator(totalPages: totalPages, currentPage: currentPage)
                    .padding(.bottom, SpacingTokens.lg)

                navigationButtons
                    .padding(.horizontal, SpacingTokens.screenPadding)
                    .padding(.bottom, SpacingTokens.xxl)
                    // The skip link hangs inside the bottom padding instead of
                    // stacking under the CTA, so the primary button lands at the
                    // same height on every page rather than riding up on the
                    // one page that has a secondary action.
                    .overlay(alignment: .bottom) {
                        if currentPage == profilePage || currentPage == groupsPage {
                            skipButton
                                .padding(.bottom, SpacingTokens.xxs)
                        }
                    }
            }
        }
        .onChange(of: petName) { _, _ in
            showNameValidation = false
        }
        .onChange(of: currentPage) { _, page in
            logStep(page)
            focusNameFieldIfNeeded(on: page)
        }
        .onAppear {
            logStep(currentPage)
            focusNameFieldIfNeeded(on: currentPage)
        }
        .task {
            // Automatic preload-all is disabled at configure for launch speed, so
            // preload the end-of-onboarding paywall on demand. Delayed a beat so
            // the WebView spin-up (a WebContent + Networking process) lands after
            // the first paint instead of contending with it — onboarding lasts
            // several seconds, so this still preloads well before the paywall shows.
            try? await Task.sleep(for: .seconds(1))
            SuperwallSafe.preload(placements: ["onboarding_complete", "onboarding_finished"])
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
                icon: "checkmark.shield.fill",
                headline: "Know if it's safe before you buy",
                subheadline: "Every product gets a score for your pet, with the ingredients behind it explained in plain language."
            )
            .transition(.opacity)
        case 2:
            OnboardingBenefitsPage(
                icon: "barcode.viewfinder",
                headline: "Just scan the barcode",
                subheadline: "Point your camera at any pet food or treat. No barcode? Take a photo of the front and we'll find it for you."
            )
            .transition(.opacity)
        case profilePage:
            OnboardingPetSetupPage(
                petName: $petName,
                petSpecies: $petSpecies,
                selectedAllergens: $selectedAllergens,
                nameError: nameError,
                isNameFocused: $isNameFocused,
                // Return dismisses the keyboard and leaves the user on the page.
                // It deliberately does not advance: the ingredient picker sits
                // below the fold, and moving on off a return key press would
                // skip past it.
                onSubmitName: { isNameFocused = false }
            )
            .transition(.opacity)
        case groupsPage:
            OnboardingAvoidanceGroupsPage(selectedGroups: $selectedGroups)
                .transition(.opacity)
        default:
            EmptyView()
        }
    }

    /// Blank until a submit has actually been attempted, so the field is not red
    /// before the user has had a chance to type in it.
    private var nameError: String? {
        (showNameValidation && !petName.isNotBlank) ? "Please enter your pet's name" : nil
    }

    @ViewBuilder
    private var backButton: some View {
        if currentPage > 0 && !isSubmitting {
            Button {
                withStandardAnimation {
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.heading3)
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: SpacingTokens.minTouchTarget, height: SpacingTokens.minTouchTarget)
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("onboarding-back")
        } else {
            // Reserve the row so page content does not shift when back appears.
            Color.clear
                .frame(height: SpacingTokens.minTouchTarget)
        }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        if currentPage == groupsPage {
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
            .disabled(isSubmitting)
        } else if currentPage == profilePage {
            Button("Continue") {
                continueFromProfile()
            }
            .primaryButtonStyle()
        } else {
            Button(currentPage == 0 ? "Get Started" : "Continue") {
                withStandardAnimation {
                    currentPage += 1
                }
            }
            .primaryButtonStyle()
        }
    }

    /// Plain text rather than a second full-width button: as an equal-width
    /// button beside the CTA it read as an equal choice. What skipping means
    /// depends on the page — no pet at all on the profile page, just no
    /// avoidance groups on the (optional) groups page.
    private var skipButton: some View {
        Button("Skip for now") {
            if currentPage == groupsPage {
                // The pet's name, species and ingredients are already entered on
                // the previous page — skipping here only skips the optional
                // groups, so still create the pet.
                createPetAndComplete()
            } else {
                completeOnboarding(createdPet: false)
            }
        }
        .font(TypographyTokens.labelLarge)
        .foregroundColor(ColorTokens.textSecondary)
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.6 : 1)
    }

    /// Gets the keyboard up on arrival at the setup page — the only page asking
    /// for input, and the highest-friction one.
    ///
    /// Deferred rather than assigned inline: focus set while the page is still
    /// transitioning in is dropped, and the field ends up unfocused.
    private func focusNameFieldIfNeeded(on page: Int) {
        guard page == profilePage else {
            isNameFocused = false
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isNameFocused = true
        }
    }

    /// Advances off the profile page once a name is present. Name entry is the
    /// one required answer, so it gates leaving this page rather than the final
    /// submit — by the time the groups page finishes, the name is already valid.
    private func continueFromProfile() {
        if petName.isNotBlank {
            withStandardAnimation {
                currentPage += 1
            }
        } else {
            showNameValidation = true
            isNameFocused = true
        }
    }

    private func createPetAndComplete() {
        guard petName.isNotBlank, !isSubmitting else { return }
        isSubmitting = true

        let pet = Pet(name: petName.trimmed, species: petSpecies, allergens: Array(selectedAllergens))
        modelContext.insert(pet)
        try? modelContext.save()

        completeOnboarding(createdPet: true)
    }

    private func completeOnboarding(createdPet: Bool) {
        isSubmitting = true
        isNameFocused = false

        AvoidancePreferences.groups = selectedGroups

        // Set user attributes for Superwall targeting. Must run before
        // register() so the paywall can address the pet by name.
        SuperwallUserAttributes.syncPets(modelContext: modelContext, fallbackSpecies: petSpecies)
        SuperwallUserAttributes.setAvoidanceGroups(selectedGroups)

        SuperwallSafe.setUserAttributes([
            "onboarding_completed_at": Date()
        ])

        SuperwallSafe.register(
            placement: "onboarding_finished",
            params: ["created_pet": createdPet, "avoid_group_count": selectedGroups.count]
        )

        // Superwall gates the exit from onboarding. The gated register runs the
        // feature block even when the SDK is unavailable, so a paywall that
        // cannot load never strands the user on this page.
        SuperwallSafe.register(placement: "onboarding_complete") {
            onComplete()
        }
    }

    /// Per-page events, so drop-off inside onboarding is visible rather than
    /// showing up only as a gap between installs and `onboarding_complete`.
    /// Without this there is no way to tell paid-traffic quality apart from
    /// friction on a specific screen.
    ///
    /// One placement carrying a `step` param rather than a placement per page:
    /// registering a placement can present a paywall if one is ever attached to
    /// that name on the dashboard, and a single name is far easier to keep out
    /// of campaigns than four.
    private func logStep(_ page: Int) {
        SuperwallSafe.register(
            placement: "onboarding_step",
            params: ["step": page]
        )
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
                    .frame(width: SpacingTokens.indicatorDot, height: SpacingTokens.indicatorDot)
                    .animateSnappy(value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Pet.self, inMemory: true)
}
