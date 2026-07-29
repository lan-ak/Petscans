import SwiftUI
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
    let petName: String?
    let allergens: Set<String>
    let groups: Set<AvoidanceGroup>
    let onBack: () -> Void
    let onSkip: () -> Void
    let onScored: (OnboardingFoodResult) -> Void
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var result: OnboardingFoodScorer.Result?
    @State private var selectedIngredient: Ingredient?
    @State private var scoreRevealed = false

    private var petDisplayName: String { petName ?? "your pet" }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
        .task { await computeScore() }
        .sheet(item: $selectedIngredient) { ingredient in
            IngredientDetailSheet(ingredient: ingredient, species: product.species, pet: nil)
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
            // Kept available but deliberately quiet: at the peak-intent moment the
            // Continue CTA should own the screen, not an equal-weight escape hatch.
            Button("Skip", action: onSkip)
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textTertiary)
                .accessibilityIdentifier("aha-result-skip")
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
                ProgressView()
                Text("Checking \(product.name) for \(petDisplayName)…")
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
                productHeader
                scoreSection(breakdown)
                if let summary = checkedSummary {
                    checkedForYouCard(summary)
                }
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
            if let summary = breakdown.suitabilityExplanation?.summary {
                Text(summary)
                    .font(TypographyTokens.body)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: SpacingTokens.xs) {
                ScoreExplanationCard(title: "Suitability", score: breakdown.suitability,
                                     explanation: breakdown.suitabilityExplanation)
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

    /// A receipt of the personalization the user set up — always shown when they
    /// gave us anything to check, so the profile/groups effort visibly pays off
    /// even when the food is clean (nothing tripped a flag below).
    private var checkedSummary: String? {
        var parts: [String] = []
        if !allergens.isEmpty {
            parts.append(allergens.sorted().joined(separator: ", "))
        }
        if !groups.isEmpty {
            let n = groups.count
            parts.append("\(n) thing\(n == 1 ? "" : "s") on your watch list")
        }
        guard !parts.isEmpty else { return nil }
        return "We checked this against \(parts.joined(separator: " and ")) for \(petDisplayName)."
    }

    private func checkedForYouCard(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: "checkmark.shield.fill")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.brandPrimary)
                .padding(.top, 1)
            Text(summary)
                .font(TypographyTokens.bodySmall)
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.cardPadding)
        .background(ColorTokens.surfacePrimary)
        .cornerRadius(SpacingTokens.radiusLarge)
    }

    @ViewBuilder
    private func flagsSection(_ breakdown: ScoreBreakdown) -> some View {
        let allergenFlags = breakdown.allergenFlags
        let groupFlags = breakdown.flags.filter { $0.type == .avoidanceGroup }

        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if !allergenFlags.isEmpty {
                AllergenAlertBanner(
                    petName: petDisplayName,
                    allergenFlags: allergenFlags,
                    allergenNames: allergens.sorted()
                )
            }

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
                .background(ColorTokens.surfacePrimary)
                .cornerRadius(SpacingTokens.radiusLarge)
            }

            // Clean result: reassure, then open a forward loop toward the rest of
            // the cabinet so a good score still points at the next scan.
            if allergenFlags.isEmpty && groupFlags.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(ColorTokens.success)
                        Text("\(petDisplayName) is in the clear on this one.")
                            .font(TypographyTokens.body)
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                    Text("Most cabinets hide at least one surprise, though — worth checking the rest of \(petDisplayName)'s food.")
                        .font(TypographyTokens.bodySmall)
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .padding(SpacingTokens.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.surfacePrimary)
                .cornerRadius(SpacingTokens.radiusLarge)
            }
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
            .background(ColorTokens.surfacePrimary)
            .cornerRadius(SpacingTokens.radiusLarge)
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
        let hasConcerns = !breakdown.allergenFlags.isEmpty
            || breakdown.flags.contains { $0.type == .avoidanceGroup }
        let title = hasConcerns
            ? "See what else could hurt \(petDisplayName)"
            : "Scan the rest of \(petDisplayName)'s food"
        return Button(title, action: onContinue)
            .primaryButtonStyle()
            .accessibilityIdentifier("aha-continue")
    }

    // MARK: - Scoring

    private func computeScore() async {
        guard result == nil else { return }
        let scored = await OnboardingFoodScorer.score(
            product: product,
            petName: petName,
            allergens: allergens,
            groups: groups
        )
        result = scored
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
    /// they land in the app — the AHA becomes their first saved scan. Runs once
    /// (guarded by `computeScore`'s `result == nil` check).
    private func saveToHistory(_ scored: OnboardingFoodScorer.Result) {
        let scan = Scan(
            barcode: product.gtin,
            productName: product.name,
            brand: product.brand,
            imageUrl: product.imageUrl,
            category: product.category,
            targetSpecies: product.species,
            rawIngredientText: product.ingredients,
            matchedIngredients: scored.matched,
            scoreBreakdown: scored.breakdown
        )
        modelContext.insert(scan)
        try? modelContext.save()
    }
}
