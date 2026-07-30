import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var petName = ""
    @State private var petSpecies: Species = .dog
    @State private var selectedAllergens: Set<String> = []
    @State private var selectedGroups: Set<AvoidanceGroup> = []
    @State private var selectedProduct: CatalogProduct?
    @State private var searchedFood: OnboardingFoodResult?
    @State private var isSubmitting = false
    @State private var showNameValidation = false
    @State private var isForward = true
    @FocusState private var isNameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    // Only the standard-chrome pages (0–3) carry the dot indicator; the search
    // and result pages are full-screen takeovers. `totalPages` counts just the
    // tracked portion so the dots don't promise steps the tracker never shows.
    private let totalPages = 4
    private let profilePage = 2
    private let groupsPage = 3
    private let searchPage = 4
    private let resultPage = 5

    var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            switch currentPage {
            case searchPage:
                ProductCatalogSearchView(
                    title: "Let's check your pet's food",
                    titleFont: TypographyTokens.displayMedium,
                    onLeading: { navigate(to: groupsPage) },
                    onSkip: { completeAfterAHA(presentedResultPaywall: false) },
                    onSelect: { product in
                        selectedProduct = product
                        withStandardAnimation { currentPage = resultPage }
                    }
                )
                .transition(.opacity)
            case resultPage:
                resultPageContent
                    .transition(.opacity)
            default:
                standardChrome
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
            #if DEBUG
            applyDebugStartIfNeeded()
            #endif
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
            SuperwallSafe.preload(placements: ["onboarding_complete", "onboarding_finished", "aha_food_result"])
        }
    }

    /// The shared centered layout used by the welcome/benefit/profile/groups pages.
    private var standardChrome: some View {
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
        // Anchor the CTA to the bottom so the auto-focused name field's keyboard
        // can't lift "Continue" into the thumb zone next to the allergen chips —
        // users were tapping it before adding allergens.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// The AHA payoff page. Recovers to search if the product was somehow lost
    /// (e.g. state reset), so the user is never stranded on a blank screen.
    @ViewBuilder
    private var resultPageContent: some View {
        if let product = selectedProduct {
            OnboardingFoodResultView(
                product: product,
                petName: petName.isNotBlank ? petName.trimmed : nil,
                allergens: selectedAllergens,
                groups: selectedGroups,
                onBack: { withStandardAnimation { currentPage = searchPage } },
                onSkip: { completeAfterAHA(presentedResultPaywall: false) },
                onScored: { summary in
                    searchedFood = summary
                    SuperwallUserAttributes.setSearchedFood(summary)
                },
                onContinue: { completeAfterAHA(presentedResultPaywall: true) }
            )
        } else {
            Color.clear.onAppear { withStandardAnimation { currentPage = searchPage } }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0:
            OnboardingWelcomePage()
                .transition(pageTransition)
        case 1:
            OnboardingBenefitsPage(
                icon: "checkmark.shield.fill",
                headline: "Know if it's safe before you buy",
                subheadline: "Every product gets a score for your pet, with the ingredients behind it explained in plain language."
            )
            .transition(pageTransition)
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
            .transition(pageTransition)
        case groupsPage:
            OnboardingAvoidanceGroupsPage(selectedGroups: $selectedGroups)
                .transition(pageTransition)
        default:
            EmptyView()
        }
    }

    /// Blank until a submit has actually been attempted, so the field is not red
    /// before the user has had a chance to type in it.
    private var nameError: String? {
        (showNameValidation && !petName.isNotBlank) ? "Please enter your pet's name" : nil
    }

    /// Directional push for the setup pages so advancing feels like forward
    /// travel and back feels like retreat, rather than every step crossfading
    /// in place. Falls back to a plain fade when Reduce Motion is on.
    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    /// Single entry point for page changes so the slide direction is inferred
    /// from the target rather than set by hand at each call site.
    private func navigate(to page: Int) {
        isForward = page >= currentPage
        withAnimation(AnimationTokens.springEmphasized) { currentPage = page }
    }

    @ViewBuilder
    private var backButton: some View {
        if currentPage > 0 && !isSubmitting {
            Button {
                navigate(to: currentPage - 1)
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
            Button("Continue") {
                navigate(to: searchPage)
            }
            .primaryButtonStyle()
        } else if currentPage == profilePage {
            Button("Continue") {
                continueFromProfile()
            }
            .primaryButtonStyle()
        } else {
            Button(currentPage == 0 ? "Get Started" : "Continue") {
                navigate(to: currentPage + 1)
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
                // Skipping here only skips the optional groups — the pet is
                // already set up, so continue to the "check your food" moment
                // rather than finishing onboarding early.
                navigate(to: searchPage)
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
            navigate(to: currentPage + 1)
        } else {
            showNameValidation = true
            isNameFocused = true
        }
    }

    /// Persists the pet and pushes every Superwall targeting attribute. Shared by
    /// both exit paths; deliberately does NOT fire the gating placement so each
    /// caller can choose its own paywall trigger.
    private func persistAndSync(createdPet: Bool) {
        if createdPet, petName.isNotBlank {
            let pet = Pet(name: petName.trimmed, species: petSpecies, allergens: Array(selectedAllergens))
            modelContext.insert(pet)
            try? modelContext.save()
        }

        AvoidancePreferences.groups = selectedGroups

        // Must run before any register() so the paywall can address the pet by name.
        SuperwallUserAttributes.syncPets(modelContext: modelContext, fallbackSpecies: petSpecies)
        SuperwallUserAttributes.setAvoidanceGroups(selectedGroups)
        SuperwallSafe.setUserAttributes(["onboarding_completed_at": Date()])

        SuperwallSafe.register(
            placement: "onboarding_finished",
            params: ["created_pet": createdPet, "avoid_group_count": selectedGroups.count]
        )
    }

    /// Exit used when the user skips the AHA search entirely (or skipped the pet
    /// setup). The paywall is gated on `onboarding_complete`, the long-standing
    /// end-of-onboarding trigger.
    private func completeOnboarding(createdPet: Bool) {
        guard !isSubmitting else { return }
        isSubmitting = true
        isNameFocused = false

        persistAndSync(createdPet: createdPet)

        // The gated register runs the feature block even when the SDK is
        // unavailable, so a paywall that cannot load never strands the user.
        SuperwallSafe.register(placement: "onboarding_complete") {
            onComplete()
        }
    }

    /// Exit from the AHA payoff page. When the user taps the result CTA the
    /// paywall fires at the peak-intent moment on `aha_food_result`; when they
    /// skip the payoff it falls back to the standard `onboarding_complete` gate.
    /// Only one of the two campaigns should be active in the dashboard so a user
    /// never sees two paywalls back to back.
    private func completeAfterAHA(presentedResultPaywall: Bool) {
        guard !isSubmitting else { return }
        isSubmitting = true
        isNameFocused = false

        // Name is guaranteed present by the time the AHA is reached (it gates
        // leaving the profile page), so a pet is always created here.
        persistAndSync(createdPet: petName.isNotBlank)

        if presentedResultPaywall {
            SuperwallSafe.register(
                placement: "aha_food_result",
                params: [
                    "verdict": searchedFood?.verdict.rawValue ?? "",
                    "score": Int((searchedFood?.score ?? 0).rounded()),
                    "flag_count": searchedFood?.flagCount ?? 0
                ]
            ) {
                onComplete()
            }
        } else {
            SuperwallSafe.register(placement: "onboarding_complete") {
                onComplete()
            }
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
    #if DEBUG
    /// Debug affordance: `-OnboardingStartPage <n>` jumps straight to a page with
    /// demo profile/allergen/group state seeded, so the AHA screens can be driven
    /// and screenshotted in isolation without walking the whole flow.
    private func applyDebugStartIfNeeded() {
        // `-OnboardingStartPage <n>` is parsed by iOS into the UserDefaults argument
        // domain, so read it there rather than from ProcessInfo.arguments.
        let page = UserDefaults.standard.integer(forKey: "OnboardingStartPage")
        guard page > 0 else { return }
        NSLog("[AHA-DEBUG] jumping onboarding to page \(page)")
        petName = "Max"
        selectedAllergens = ["chicken"]
        selectedGroups = [.artificialColours, .meatByproducts, .commonAllergens]
        if page == resultPage {
            Task {
                if let product = await ProductCatalogService().search(query: "chicken", limit: 1).first {
                    selectedProduct = product
                    currentPage = resultPage
                }
            }
        } else {
            currentPage = page
        }
    }
    #endif

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
