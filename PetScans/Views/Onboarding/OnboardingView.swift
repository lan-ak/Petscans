import SwiftUI
import SwiftData
import SuperwallKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var petName = ""
    /// Nil until the owner actually taps one of the two animals on the search screen.
    ///
    /// This was `Species = .dog`. A default is not an answer: a dog owner never noticed
    /// the control and a cat owner had to correct it, so the species every demo was
    /// scored against was an assumption. Downstream still needs a concrete value, which
    /// `petSpecies` supplies — but the picker, the brand grid and the result ordering
    /// can now tell "chose dog" from "has not chosen".
    @State private var chosenSpecies: Species?

    /// The species to score and persist against. Falls back to `.dog` for the user who
    /// skips the question entirely, which is exactly what shipped before.
    private var petSpecies: Species { chosenSpecies ?? .dog }

    /// For the profile page, which asks the question again as a plain form control.
    private var petSpeciesBinding: Binding<Species> {
        Binding(get: { chosenSpecies ?? .dog }, set: { chosenSpecies = $0 })
    }
    @State private var selectedAllergens: Set<String> = []
    @State private var selectedGroups: Set<AvoidanceGroup> = []
    @State private var selectedProduct: CatalogProduct?
    /// The demo verdict, scored before we know anything about the pet. Kept so the
    /// personalised result can show what changed once the profile is in.
    @State private var demoFood: OnboardingFoodResult?
    /// The same food re-scored against the finished profile.
    @State private var personalizedFood: OnboardingFoodResult?
    @State private var isSubmitting = false
    /// Whether the surface or the SwiftUI flow is serving onboarding.
    @State private var flowMode: FlowMode = .idle
    /// True when `selectedProduct` came from "See an example" rather than the
    /// owner's own pick. Gates History, the targeting attributes and the
    /// personalised re-score — none of which should describe a food they do
    /// not feed.
    @State private var isExampleFood = false
    @State private var showNameValidation = false
    @State private var isForward = true
    @FocusState private var isNameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    // Demo first. The measured funnel said everything placed ahead of the food search is
    // paid for at a brutal rate — the old pet-setup page alone lost 48% of arrivals, and
    // only 21% of users ever reached the payoff screen at all. Questions now sit *after*
    // the moment that earns them, and the profile is played back on the personalised result screen.
    private let searchPage = 1
    private let resultPage = 2
    private let profilePage = 3
    private let groupsPage = 4
    private let personalizedPage = 5

    /// The dots cover the question block only (profile → groups). The promise, the demo and
    /// its payoff are discovery, not a form, and a tracker over them read as paperwork; a
    /// bounded "2 steps" after the payoff is a promise that can actually be kept.
    private var questionStepCount: Int { 2 }

    var body: some View {
        switch flowMode {
        case .idle, .surface:
            // The ground the surface presents over, and what the user sees for
            // the few frames before it does — so it is the app background, not
            // a spinner. `ConfigReadyGate` has already waited for config.
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()
                .onAppear(perform: presentFlowIfNeeded)
        case .native:
            nativeFlow
        }
    }

    /// The 1.4.6 flow, unchanged, kept as the fallback.
    ///
    /// Not deleted, deliberately. If the placement has no campaign, the
    /// audience doesn't match, config never landed or the webview fails,
    /// `onSkip` fires and the user gets this instead of a blank screen. A
    /// brand new user is the worst possible person to strand.
    private var nativeFlow: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            switch currentPage {
            case searchPage:
                nativeFoodSearch
                    .transition(.opacity)
            case resultPage:
                resultPageContent
                    .transition(.opacity)
            case personalizedPage:
                personalizedPageContent
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
            SuperwallSafe.preload(placements: ["onboarding_complete", "onboarding_finished"])
        }
    }

    // MARK: - The onboarding surface

    /// Whether onboarding is being served by the Superwall surface or the
    /// SwiftUI flow it replaces.
    private enum FlowMode {
        /// Nothing attempted yet.
        case idle
        /// `register` fired; the surface is presenting or about to.
        case surface
        /// No surface available — the 1.4.6 flow, page for page.
        case native
    }

    /// Step 1 of the fallback flow: a pick from `DemoFoods`. There is no
    /// scan or search here. Their own food waits behind `PaywallGate`, in the
    /// Scan tab, after `onboarding_complete`.
    private var nativeFoodSearch: some View {
        OnboardingFoodCheckPage(
            species: $chosenSpecies,
            onSample: { product in
                // A sample is not their food. It gets the same scored payoff
                // and personalised re-score, but it is not written to History
                // and does not set the `searched_food*` targeting attributes.
                isExampleFood = true
                selectedProduct = product
                withStandardAnimation { currentPage = resultPage }
            },
            onBack: { navigate(to: 0) }
        )
    }

    /// Fires the placement once, on arrival.
    ///
    /// The surface covers every onboarding step, so a finished run ends
    /// onboarding outright rather than returning to a page here.
    private func presentFlowIfNeeded() {
        guard flowMode == .idle else { return }
        flowMode = .surface
        OnboardingFlowCallbacks.reset()

        var didPresent = false
        let handler = PaywallPresentationHandler()
        handler.onPresent { _ in didPresent = true }
        handler.onSkip { _ in
            Task { @MainActor in withStandardAnimation { flowMode = .native } }
        }
        handler.onError { _ in
            Task { @MainActor in withStandardAnimation { flowMode = .native } }
        }
        handler.onCustomCallback { callback in
            await OnboardingFlowCallbacks.handle(callback)
        }

        SuperwallSafe.register(
            placement: "onboarding_flow",
            handler: handler
        ) {
            // Non-gated, so this runs on dismissal — and immediately when the
            // SDK isn't ready at all.
            Task { @MainActor in
                if let outcome = OnboardingFlowCallbacks.takeOutcome() {
                    await applyFlowOutcome(outcome)
                } else if didPresent {
                    // Presented, then dismissed without reporting. Nothing was
                    // gathered, so finish onboarding rather than re-showing the
                    // flow they just left — the app is gated behind it.
                    finishFromSurface(createdPet: false)
                } else {
                    withStandardAnimation { flowMode = .native }
                }
            }
        }
    }

    /// Replays everything the surface gathered into the state the rest of
    /// onboarding's exit path already expects, then finishes.
    private func applyFlowOutcome(_ outcome: OnboardingFlowCallbacks.Outcome) async {
        petName = outcome.petName
        chosenSpecies = outcome.species
        selectedAllergens = outcome.allergens
        selectedGroups = outcome.groups

        // An empty gtin means skipped, or an example food — neither is theirs,
        // so neither gets saved to History or carried into targeting.
        if !outcome.gtin.isEmpty,
           let product = await LocalCatalogStore.shared.product(gtin: outcome.gtin) {
            selectedProduct = product
            if chosenSpecies == nil { chosenSpecies = product.species }

            let summary = OnboardingFoodResult(
                name: product.name,
                brand: product.brand,
                verdict: outcome.verdict ?? .good,
                score: outcome.score,
                flagCount: outcome.flagCount
            )
            // Both are set so `finishOnboarding`'s `personalizedFood ?? demoFood`
            // reports the verdict the user was actually left looking at.
            demoFood = summary
            if outcome.isPersonalised { personalizedFood = summary }
        }

        finishFromSurface(createdPet: outcome.createdPet)
    }

    /// The surface's exit. Routes into the same `finishOnboarding` the native
    /// flow uses, so persistence, attributes, the review arm and
    /// `onboarding_complete` all behave identically on both paths.
    private func finishFromSurface(createdPet: Bool) {
        ReviewPrompt.recordOnboardingCompleted(sawPersonalizedResult: personalizedFood != nil)
        finishOnboarding(createdPet: createdPet)
    }

    /// The shared centered layout used by the welcome/profile/groups pages.
    private var standardChrome: some View {
        VStack(spacing: 0) {
            backButton
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SpacingTokens.screenPadding)

            Spacer(minLength: 0)

            pageContent

            Spacer(minLength: 0)
            // A hair more room below than above. Content centred on the true vertical
            // midpoint reads as sitting low, because the eye weights the top of a
            // screen more heavily — this is the optical centre, not the arithmetic one.
            Spacer(minLength: 0).frame(maxHeight: SpacingTokens.xxl)

            if currentPage == profilePage || currentPage == groupsPage {
                PageIndicator(
                    totalPages: questionStepCount,
                    currentPage: currentPage - profilePage
                )
                .padding(.bottom, SpacingTokens.lg)
            }

            navigationButtons
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.bottom, SpacingTokens.ctaBottomInset)
        }
        // Anchor the CTA to the bottom so the auto-focused name field's keyboard
        // can't lift "Continue" into the thumb zone next to the allergen chips —
        // users were tapping it before adding allergens.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// The demo payoff — scored before there is a pet, so it carries the general verdict
    /// and points forward at personalisation. Recovers to search if the product was lost.
    @ViewBuilder
    private var resultPageContent: some View {
        if let product = selectedProduct {
            OnboardingFoodResultView(
                product: product,
                species: petSpecies,
                savesToHistory: !isExampleFood,
                onBack: { withStandardAnimation { currentPage = searchPage } },
                onScored: { summary in
                    demoFood = summary
                    // Set now as well as after the re-score: a user who drops out between
                    // here and the personalised result screen still reaches the paywall with a verdict
                    // attached for targeting.
                    //
                    // Not for an example, though: `searched_food` is what audience
                    // 166983 ("Got Aha Moment") targets on, and a food the owner
                    // does not feed is not an aha moment. Those users fall through
                    // to the unconditional audience, which is correct.
                    if !isExampleFood {
                        SuperwallUserAttributes.setSearchedFood(summary)
                    }
                },
                onContinue: { navigate(to: profilePage) }
            )
        } else {
            Color.clear.onAppear { withStandardAnimation { currentPage = searchPage } }
        }
    }

    /// The same food re-scored against the finished profile, so the last thing before the
    /// paywall is an answer about the user's own pet rather than a generic offer.
    private var personalizedPageContent: some View {
        OnboardingPersonalizedResultView(
            product: selectedProduct,
            demoResult: demoFood,
            petName: petName.isNotBlank ? petName.trimmed : nil,
            species: petSpecies,
            allergens: selectedAllergens,
            groups: selectedGroups,
            savesToHistory: !isExampleFood,
            onScored: { summary in
                personalizedFood = summary
                // Same rule as the demo screen: the aha paywall reads these
                // as "your pet's bowl", which a sample is not.
                if !isExampleFood {
                    SuperwallUserAttributes.setSearchedFood(summary)
                }
            },
            onContinue: { finishOnboarding(createdPet: petName.isNotBlank) }
        )
    }

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0:
            OnboardingWelcomePage()
                .transition(pageTransition)
                .accessibilityIdentifier("onboarding-welcome-page")
        case profilePage:
            OnboardingPetSetupPage(
                petName: $petName,
                petSpecies: petSpeciesBinding,
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
                navigate(to: personalizedPage)
            }
            .primaryButtonStyle()
        } else if currentPage == profilePage {
            Button("Continue") {
                continueFromProfile()
            }
            .primaryButtonStyle()
        } else {
            Button("Continue") {
                navigate(to: currentPage + 1)
            }
            .primaryButtonStyle()
            .accessibilityIdentifier(currentPage == 0 ? "onboarding-start" : "onboarding-continue")
        }
    }

    /// There is no skip. Onboarding is now a single path: pick a food, see the verdict,
    /// name the pet, and get the personalised answer.
    ///
    /// The exits that used to be here were load-bearing in both directions. The profile
    /// page's "Not now — finish setup" ended onboarding outright, and 39% of finishers
    /// took it; the groups page's "Skip for now" jumped straight to the personalised
    /// result. Removing them means the pet's name is now genuinely required, and since
    /// onboarding gates the app, a user who will not enter one cannot get in. That is the
    /// intended trade — but it is the reason `continueFromProfile` has to keep surfacing
    /// a clear validation message rather than silently refusing to advance.
    ///
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
            navigate(to: groupsPage)
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

    /// The single exit. Everyone leaves through `onboarding_complete` — off the personalised
    /// result, or off the profile page's "Not now". Which paywall they see is a campaign
    /// audience decision on the persisted `user.searched_food*` attributes, not a
    /// placement decision: gating on a separate placement name could only ever reach users
    /// whose downloaded config already carried it, silently excluding everyone else.
    private func finishOnboarding(createdPet: Bool) {
        guard !isSubmitting else { return }
        isSubmitting = true
        isNameFocused = false

        persistAndSync(createdPet: createdPet)

        // The searched food reported here is the personalised score when there is one, so
        // audiences and paywall copy see the verdict the user was actually left looking at.
        let food = personalizedFood ?? demoFood

        // Armed, not presented. `onboarding_complete` below is the gated placement that
        // shows the paywall, and iOS drops a review request while another sheet owns the
        // slot — silently, still spending one of three per year. `MainTabView` drains this
        // once the user has actually landed in the app, and defers past the paywall.
        ReviewPrompt.recordOnboardingCompleted(sawPersonalizedResult: personalizedFood != nil)

        // The gated register runs the feature block even when the SDK is
        // unavailable, so a paywall that cannot load never strands the user.
        SuperwallSafe.register(
            placement: "onboarding_complete",
            params: [
                "viewed_food_result": demoFood != nil,
                "personalized": personalizedFood != nil,
                "verdict": food?.verdict.rawValue ?? "",
                "score": Int((food?.score ?? 0).rounded()),
                "flag_count": food?.flagCount ?? 0
            ]
        ) {
            onComplete()
        }
    }

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
        if page == resultPage || page == personalizedPage {
            Task {
                if let product = await ProductCatalogService().search(query: "chicken", limit: 1).first {
                    selectedProduct = product
                    chosenSpecies = product.species
                    // The personalised result screen's whole point is the before/after, and that needs the
                    // demo's *general* verdict to compare against. Jumping straight here
                    // would otherwise always render the single-verdict fallback, which is
                    // the one case the screen isn't built to show off.
                    if page == personalizedPage {
                        let cold = await OnboardingFoodScorer.score(
                            product: product, petName: nil, allergens: [], groups: []
                        )
                        demoFood = OnboardingFoodResult(
                            name: product.name,
                            brand: product.brand,
                            verdict: cold.breakdown.ratingLabel,
                            score: cold.breakdown.total,
                            flagCount: cold.breakdown.flags.count
                        )
                    }
                    currentPage = page
                }
            }
        } else {
            currentPage = page
        }
    }
    #endif

    /// Per-page events, so drop-off inside onboarding is visible rather than
    /// showing up only as a gap between installs and `onboarding_complete`.
    ///
    /// One placement carrying a `step` param rather than a placement per page:
    /// registering a placement can present a paywall if one is ever attached to
    /// that name on the dashboard, and a single name is far easier to keep out
    /// of campaigns than four.
    ///
    /// `step_name` travels alongside the index because the index is not stable — this
    /// release reorders the flow, so any funnel keyed on `step` alone silently changes
    /// meaning at the cutover. Query on the name.
    private func logStep(_ page: Int) {
        SuperwallSafe.register(
            placement: "onboarding_step",
            params: ["step": page, "step_name": Self.stepName(page)]
        )
    }

    private static func stepName(_ page: Int) -> String {
        switch page {
        case 0: return "promise"
        case 1: return "search"
        case 2: return "demo_result"
        case 3: return "pet_setup"
        case 4: return "watch_list"
        case 5: return "personalized_result"
        default: return "unknown_\(page)"
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
                    .frame(width: SpacingTokens.indicatorDot, height: SpacingTokens.indicatorDot)
                    .animateSnappy(value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentPage + 1) of \(totalPages)")
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Pet.self, inMemory: true)
}
