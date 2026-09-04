import SwiftUI
import UIKit
import SwiftData

/// Summary of a scored food, surfaced to the parent so it can set Superwall
/// attributes and fire the paywall placement.
struct OnboardingFoodResult {
    let name: String
    let brand: String?
    let verdict: RatingLabel
    let score: Double
    let flagCount: Int
}

/// The AHA payoff: the chosen food scored against the pet profile. Reuses the
/// same leaf components as the real results screen so it reads identically.
///
/// The reveal is deliberately left to land on its own — no coach-mark tour
/// dimming the moment — and the primary CTA is pinned below the scroll so the
/// next step is always one tap away, whatever the verdict.
struct OnboardingFoodResultView: View {
    let product: CatalogProduct
    /// The species picked on the search page. Used rather than `product.species` so the
    /// general verdict, the History row and the personalised result screen all describe the same animal —
    /// search orders rather than filters, so the product may be labelled for the other one.
    let species: Species
    let onBack: () -> Void
    let onScored: (OnboardingFoodResult) -> Void
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var result: OnboardingFoodScorer.Result?
    @State private var selectedIngredient: Ingredient?
    @State private var scoreRevealed = false

    /// Whether this food is worth warning about *in general*.
    ///
    /// There is no pet on this screen, so allergen and avoidance-group flags cannot exist —
    /// the verdict is the only signal, and reading it is what stops a food carrying xylitol
    /// rendering a red "Avoid" badge above the words "in the clear".
    private func hasConcerns(_ breakdown: ScoreBreakdown) -> Bool {
        breakdown.ratingLabel == .caution || breakdown.ratingLabel == .avoid
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
        .task { await computeScore() }
        .sheet(item: $selectedIngredient) { ingredient in
            // `species`, not `product.species`: the score, the verdict and the History row
            // all use the picked species, and the sheet showed cat risk data beside a dog
            // score when the two disagreed.
            IngredientDetailSheet(ingredient: ingredient, species: species, pet: nil)
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.heading3)
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: SpacingTokens.minTouchTarget, height: SpacingTokens.minTouchTarget)
            }
            .accessibilityLabel("Back")
            Spacer()
            // No "Skip" here any more. Under the demo-first order both it and the CTA went
            // to the same next screen, so it was a second button that did exactly what the
            // first one did — the back chevron is the only meaningful alternative left.
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
    }

    @ViewBuilder
    private var content: some View {
        if let result {
            VStack(spacing: 0) {
                resultsScroll(result)
                continueButton(result)
                    .padding(.horizontal, SpacingTokens.screenPadding)
                    .padding(.top, SpacingTokens.sm)
                    .padding(.bottom, SpacingTokens.md)
            }
        } else {
            Spacer()
            VStack(spacing: SpacingTokens.sm) {
                // Replaces the ProgressView rather than sitting beside it. The attend
                // pose turns the animal toward the result and keeps breathing and
                // blinking throughout — a character that freezes while you wait is
                // what a hung app looks like.
                CompanionView(species: species, mood: .attending, height: CompanionSize.prominent.points)
                Text("Checking \(product.name)…")
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private func resultsScroll(_ result: OnboardingFoodScorer.Result) -> some View {
        let breakdown = result.breakdown
        return ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Settle on a clean verdict, wince on a flagged one. The mapping lives
                // in Swift rather than in the rig: it is business logic, and it belongs
                // where it can be tested.
                CompanionView(
                    species: species,
                    mood: .forVerdict(
                        score: Int(breakdown.total.rounded()),
                        hasFlag: hasConcerns(breakdown),
                        allergenHit: false
                    ),
                    height: CompanionSize.prominent.points
                )
                productHeader
                scoreSection(breakdown)
                flagsSection(breakdown)
                ingredientsSection(result)
            }
            .padding(SpacingTokens.screenPadding)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Sections

    private var productHeader: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Text(product.name)
                .font(TypographyTokens.heading2)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            if let brand = product.brand, !brand.isEmpty {
                Text(brand)
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreSection(_ breakdown: ScoreBreakdown) -> some View {
        VStack(spacing: SpacingTokens.sm) {
            // The verdict is the payload — let it pop in rather than appear fully
            // formed, so the biggest moment carries the most motion.
            RatingLabelView(label: breakdown.ratingLabel)
                .scaleEffect(scoreRevealed ? 1 : 0.85)
                .opacity(scoreRevealed ? 1 : 0)
            // Suitability is the *allergen* axis, and on the demo there is no pet to be
            // suitable for: it defaults to 100 and its summary reads "No known allergens
            // detected for your pet." Showing either would be claiming a check we have not
            // run — the worst kind of wrong answer for a safety app, and the exact thing
            // the personalised result screen exists to deliver once there is a profile. Safety and
            // Processing are properties of the food itself and stay.
            VStack(spacing: SpacingTokens.xs) {
                ScoreExplanationCard(title: "Safety", score: breakdown.safety,
                                     explanation: breakdown.safetyExplanation)
                if let processing = breakdown.processing {
                    ScoreExplanationCard(title: "Processing", score: processing,
                                         explanation: breakdown.processingExplanation)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The demo has no pet, so there are no allergen or avoidance-group flags to draw —
    /// those moved to the personalised result screen, which is where a profile exists and where naming the
    /// matched ingredient actually means something. What is left is the general read.
    @ViewBuilder
    private func flagsSection(_ breakdown: ScoreBreakdown) -> some View {
        if !hasConcerns(breakdown) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(ColorTokens.success)
                    Text("Nothing here is a general concern.")
                        .font(TypographyTokens.body)
                        .foregroundColor(ColorTokens.textPrimary)
                }
                Text("That's the general picture. Tell us who's eating it and we'll check it against their own allergies.")
                    .font(TypographyTokens.bodySmall)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(SpacingTokens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .raisedSurface()
        }
    }

    private func ingredientsSection(_ result: OnboardingFoodScorer.Result) -> some View {
        let db = IngredientDatabase.shared
        return VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("What's inside")
                .font(TypographyTokens.heading3)
                .foregroundColor(ColorTokens.textPrimary)
            Text("Tap an ingredient to see what it is")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textSecondary)

            VStack(spacing: 0) {
                ForEach(result.matched) { mi in
                    let ingredient = mi.ingredientId.flatMap { db.ingredients[$0] }
                    Button {
                        if let ingredient { selectedIngredient = ingredient }
                    } label: {
                        ingredientRow(mi, ingredient: ingredient)
                    }
                    .buttonStyle(.plain)
                    .disabled(ingredient == nil)
                    if mi.rank < result.matched.count {
                        Divider()
                    }
                }
            }
            .raisedSurface()
        }
    }

    private func ingredientRow(_ mi: MatchedIngredient, ingredient: Ingredient?) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(ingredient?.commonName ?? mi.labelName)
                .font(TypographyTokens.body)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer()
            if ingredient != nil {
                Image(systemName: "info.circle")
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.brandPrimary)
            }
        }
        .padding(.horizontal, SpacingTokens.cardPadding)
        .padding(.vertical, SpacingTokens.sm)
        .contentShape(Rectangle())
    }

    /// Pinned below the scroll so it's reachable the instant the result renders.
    /// The label is verdict-aware: a flagged food leans into loss aversion, a
    /// clean food points at the rest of the cabinet — both move forward, neither
    /// reads as regret.
    private func continueButton(_ result: OnboardingFoodScorer.Result) -> some View {
        let breakdown = result.breakdown
        let title = hasConcerns(breakdown)
            ? "Check this against your pet"
            : "See what this means for your pet"
        return Button(title, action: onContinue)
            .primaryButtonStyle()
            .accessibilityIdentifier("aha-continue")
    }

    // MARK: - Scoring

    private func computeScore() async {
        guard result == nil else { return }
        // No pet, no allergens, no watch list — this is the general read on the food.
        let scored = await OnboardingFoodScorer.score(
            product: product,
            petName: nil,
            allergens: [],
            groups: [],
            species: species
        )
        result = scored
        // The verdict is the payload of this screen; it should land in the hand as well
        // as on the retina. Warning rather than error on a flag — this is information
        // about a bag of food, not a failure the user caused.
        if !reduceMotion {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(hasConcerns(scored.breakdown) ? .warning : .success)
        }
        saveToHistory(scored)
        onScored(OnboardingFoodResult(
            name: product.name,
            brand: product.brand,
            verdict: scored.breakdown.ratingLabel,
            score: scored.breakdown.total,
            flagCount: scored.breakdown.flags.count
        ))

        // Let the results content mount at the pre-reveal state first, then pop
        // the verdict in. A brief yield ensures SwiftUI has committed the initial
        // frame so the spring actually animates rather than snapping to the end.
        if reduceMotion {
            scoreRevealed = true
        } else {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(AnimationTokens.celebrationBounce) { scoreRevealed = true }
        }

    }

    /// Persist the searched food to History so it's waiting for the user the moment
    /// they land in the app — the demo becomes their first saved scan.
    ///
    /// Replaces any existing row for the same product rather than appending. `computeScore`
    /// only guards against re-running within one appearance of this view, and the pet-setup
    /// page's back button makes the demo re-enterable, so each round trip used to leave
    /// another copy in History.
    private func saveToHistory(_ scored: OnboardingFoodScorer.Result) {
        let gtin = product.gtin
        let existing = try? modelContext.fetch(
            FetchDescriptor<Scan>(predicate: #Predicate<Scan> { $0.barcode == gtin })
        )
        existing?.forEach(modelContext.delete)

        let scan = Scan(
            barcode: product.gtin,
            productName: product.name,
            brand: product.brand,
            imageUrl: product.imageUrl,
            category: product.category,
            targetSpecies: species,
            rawIngredientText: product.ingredients,
            matchedIngredients: scored.matched,
            scoreBreakdown: scored.breakdown
        )
        modelContext.insert(scan)
        try? modelContext.save()
    }
}


/// The personalised result: the last screen before the paywall, and the one that makes
/// leaving mean walking away from an answer about *their* pet rather than skipping ours.
///
/// Deliberately not called a "plan". The app does not produce one — no regimen, no timeline,
/// no numbers to hit. It re-scores one food against a profile and says what it will check
/// from now on, and naming that a plan would promise something the product never delivers.
///
/// It re-scores the food from the demo against the finished profile. That comparison is the
/// point — an allergen match zeroes the score and forces "Avoid", and chicken alone is in
/// 53.9% of dog foods and 77.5% of cat foods, so for most users who name an allergen the
/// verdict visibly moves between the two screens. When it doesn't move, the screen falls
/// back to the receipt: what is now checked on every scan, for whom.
///
/// Lives in this file rather than its own because the Xcode project has no
/// file-system-synchronised groups — a new file needs hand-edited pbxproj entries, and this
/// view shares `OnboardingFoodResult` and the scorer with the screen above it.
struct OnboardingPersonalizedResultView: View {
    let product: CatalogProduct?
    let demoResult: OnboardingFoodResult?
    let petName: String?
    /// The pet's species, not the product's. Search orders rather than filters, so an owner
    /// can legitimately open a food labelled for the other animal — and every scan they run
    /// later is scored against their pet. Scoring this screen off `product.species` would
    /// let it promise a verdict the first real scan contradicts.
    let species: Species
    let allergens: Set<String>
    let groups: Set<AvoidanceGroup>
    let onScored: (OnboardingFoodResult) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @State private var rescored: OnboardingFoodScorer.Result?
    @State private var revealed = false
    @State private var didScore = false
    /// Lowered in a `defer`, so a cancelled or failed re-score still releases the CTA.
    @State private var isScoring = false

    private var petDisplayName: String { petName ?? "your pet" }

    /// True when the profile actually changed the answer — the moment worth animating.
    private var verdictChanged: Bool {
        guard let demoResult, let rescored else { return false }
        return rescored.breakdown.ratingLabel != demoResult.verdict
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SpacingTokens.lg) {
                    header
                    if product != nil {
                        if let rescored {
                            verdictCard(rescored)
                            reasonCards(rescored.breakdown)
                        } else {
                            // The companion in the header is already holding the attend
                            // pose while this runs, so a spinner beneath it would be two
                            // things saying "waiting".
                            Color.clear
                                .frame(height: SpacingTokens.xxl)
                        }
                    }
                    monitoringCard
                }
                .padding(SpacingTokens.screenPadding)
            }

            Button(continueTitle, action: onContinue)
                .primaryButtonStyle()
                // Disabled only while the re-score is actually running. Tapping through the
                // spinner fired `onboarding_complete` with `personalized: false` and the
                // pre-profile verdict, which are the two params audiences read to tell those
                // cohorts apart — but this screen has no back button and no skip, so gating
                // on `rescored == nil` instead would have trapped the user in onboarding
                // for good if the scoring task was ever cancelled.
                .disabled(isScoring)
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.md)
                .accessibilityIdentifier("personalized-continue")
        }
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
        .task { await rescore() }
        // No identifier on this container. An `accessibilityIdentifier` on a SwiftUI
        // parent wins over the ones its children set, which would make `personalized-continue`
        // unaddressable — to XCUITest and to VoiceOver alike.
    }

    /// The mood the re-score earns. An allergen match is the sharpest reaction in the
    /// set, and it is the moment this whole flow is built to reach — the point where a
    /// generic verdict becomes one about *their* animal.
    private var companionMood: CompanionMood {
        guard let rescored else { return .attending }
        return .forVerdict(
            score: Int(rescored.breakdown.total.rounded()),
            hasFlag: rescored.breakdown.ratingLabel == .caution || rescored.breakdown.ratingLabel == .avoid,
            allergenHit: !rescored.breakdown.allergenFlags.isEmpty
        )
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.xs) {
            // A generic shield glyph sat here. The screen's entire job is "this verdict
            // is about *your* animal", and the animal saying so does that better than a
            // checkmark ever could.
            CompanionView(species: species, mood: companionMood, height: CompanionSize.prominent.points)
            Text(petName == nil ? "Now scored for your pet" : "Now scored for \(petDisplayName)")
                .font(TypographyTokens.displayMedium)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.lg)
    }

    /// The before/after.
    ///
    /// Laid out as one centred column rather than a label beside a badge: an `HStack` pair
    /// centres as a unit, which left "In general" and its badge visibly off-axis from the
    /// "For Max" row underneath. Shown as a comparison only when the verdict actually moved,
    /// since an identical pair either side of an arrow reads as a bug.
    @ViewBuilder
    private func verdictCard(_ result: OnboardingFoodScorer.Result) -> some View {
        let breakdown = result.breakdown
        VStack(spacing: SpacingTokens.sm) {
            if let product {
                Text(product.name)
                    .font(TypographyTokens.bodySmall)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if verdictChanged, let demoResult {
                VStack(spacing: SpacingTokens.xxs) {
                    // The discarded answer is a line of text, not a second badge. Two padded
                    // badges stacked pushed the card past the viewport and clipped the watch
                    // list under the CTA — and the general verdict is context, not the point.
                    Text("In general: \(demoResult.verdict.rawValue)")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)

                    Image(systemName: "arrow.down")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                        .padding(.vertical, SpacingTokens.xxs)

                    Text("For \(petDisplayName)")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                    RatingLabelView(label: breakdown.ratingLabel, size: .medium)
                        .scaleEffect(revealed ? 1 : 0.85)
                        .opacity(revealed ? 1 : 0)
                }
            } else {
                VStack(spacing: SpacingTokens.xxs) {
                    Text("For \(petDisplayName)")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                    RatingLabelView(label: breakdown.ratingLabel, size: .medium)
                        .scaleEffect(revealed ? 1 : 0.85)
                        .opacity(revealed ? 1 : 0)
                }
            }

            // Only when nothing below is going to say it better. With allergen flags the
            // banner names the actual ingredients, and this sentence ("Contains 3
            // ingredients Max should avoid. Score set to Avoid.") made the same point a
            // third time, under a badge that had already made it a first.
            if breakdown.allergenFlags.isEmpty,
               !allergens.isEmpty,
               let summary = breakdown.suitabilityExplanation?.summary {
                Text(summary)
                    .font(TypographyTokens.bodySmall)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.cardPadding)
        .raisedSurface()
    }

    /// Names the ingredients that tripped the profile. Its own card, not nested inside the
    /// verdict card — a tinted card inside a tinted card read as a rendering glitch.
    @ViewBuilder
    private func reasonCards(_ breakdown: ScoreBreakdown) -> some View {
        if !breakdown.allergenFlags.isEmpty {
            AllergenAlertBanner(
                petName: petDisplayName,
                allergenFlags: breakdown.allergenFlags,
                allergenNames: breakdown.allergenIngredientNames
            )
        }

        // Avoidance groups cost up to 40 points and can pull the verdict down a tier, so
        // the score moves with no explanation if this is missing.
        let groupFlags = breakdown.flags.filter { $0.type == .avoidanceGroup }
        if !groupFlags.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Label("On your watch list", systemImage: "eye.fill")
                    .font(TypographyTokens.labelLarge)
                    .foregroundColor(ColorTokens.warning)
                ForEach(groupFlags) { flag in
                    HStack(alignment: .top, spacing: SpacingTokens.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(ColorTokens.severityWarning)
                            .font(TypographyTokens.caption)
                            .padding(.top, 2)
                        Text(flag.explain)
                            .font(TypographyTokens.bodySmall)
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }
            .padding(SpacingTokens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .raisedSurface()
        }
    }

    /// The standing promise — what the app will do on every future scan. This is the part
    /// that survives when the verdict didn't move, and it is the thing the user would be
    /// walking away from.
    private var monitoringCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("From now on, every scan checks")
                .font(TypographyTokens.labelLarge)
                .foregroundColor(ColorTokens.textPrimary)

            if allergens.isEmpty && groups.isEmpty {
                planRow(icon: "pawprint.fill",
                        text: "Ingredients that are unsafe for \(petDisplayName)")
            }
            if !allergens.isEmpty {
                planRow(icon: "exclamationmark.triangle.fill",
                        // Allergen ids are stored lowercased ("chicken"); this is the one
                        // place they are shown as prose rather than inside a chip.
                        text: allergens.sorted().map(\.capitalized).joined(separator: ", "))
            }
            if !groups.isEmpty {
                planRow(icon: "eye.fill",
                        text: "\(groups.count) thing\(groups.count == 1 ? "" : "s") on your watch list")
            }
            planRow(icon: "shield.lefthalf.filled",
                    text: "Toxic ingredients and species warnings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.cardPadding)
        .raisedSurface()
    }

    private func planRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.brandPrimary)
                .padding(.top, 2)
            Text(text)
                .font(TypographyTokens.bodySmall)
                .foregroundColor(ColorTokens.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private var continueTitle: String {
        petName == nil ? "Start scanning" : "Start protecting \(petDisplayName)"
    }

    private func rescore() async {
        guard !didScore, let product else { return }
        didScore = true
        isScoring = true
        defer { isScoring = false }
        let scored = await OnboardingFoodScorer.score(
            product: product,
            petName: petName,
            allergens: allergens,
            groups: groups,
            species: species
        )
        rescored = scored
        // The sharpest moment in the flow: a generic verdict has just become one about
        // this specific animal. An allergen match earns the heavier of the two.
        if !reduceMotion {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(
                scored.breakdown.allergenFlags.isEmpty ? .success : .warning
            )
        }
        onScored(OnboardingFoodResult(
            name: product.name,
            brand: product.brand,
            verdict: scored.breakdown.ratingLabel,
            score: scored.breakdown.total,
            flagCount: scored.breakdown.flags.count
        ))

        saveToHistory(scored, product: product)

        if reduceMotion {
            revealed = true
        } else {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(AnimationTokens.celebrationBounce) { revealed = true }
        }
    }

    /// Replaces the row the demo saved with the personalised one.
    ///
    /// The demo screen saves the food as soon as it scores, so a user who leaves before
    /// this screen still lands in an app with something in History. That row carries the
    /// *general* verdict though, and leaving it would mean History disagreed with the last
    /// screen the user saw. `Scan.scoreBreakdown` decodes from JSON behind a transient
    /// cache with no setter, so replacing the row is cleaner than rewriting the string.
    private func saveToHistory(_ scored: OnboardingFoodScorer.Result, product: CatalogProduct) {
        let gtin = product.gtin
        let existing = try? modelContext.fetch(
            FetchDescriptor<Scan>(predicate: #Predicate<Scan> { $0.barcode == gtin })
        )
        existing?.forEach(modelContext.delete)

        let scan = Scan(
            barcode: product.gtin,
            productName: product.name,
            brand: product.brand,
            imageUrl: product.imageUrl,
            category: product.category,
            // The pet's species, matching what this breakdown was scored with. Saving the
            // product's instead badged the row for the wrong animal and hid it behind
            // History's species filter — a dog score, labelled Cat, invisible to its owner.
            targetSpecies: species,
            rawIngredientText: product.ingredients,
            matchedIngredients: scored.matched,
            scoreBreakdown: scored.breakdown
        )
        modelContext.insert(scan)
        try? modelContext.save()
    }
}
