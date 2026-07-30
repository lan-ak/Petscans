import SwiftUI
import SwiftData

/// Unified view for displaying product scores - used for both scan results and saved scan details
struct ProductScoreView: View {
    enum Mode {
        case scanResult(onSave: () -> Void, onScanAnother: () -> Void)
        case savedScan(scan: Scan, onDelete: () -> Void)
    }

    let productName: String
    let brand: String?
    let imageUrl: String?
    let species: Species
    let category: Category
    let scoreBreakdown: ScoreBreakdown
    let matchedIngredients: [MatchedIngredient]
    let shareText: String
    let petName: String?
    let selectedPet: Pet?
    let mode: Mode
    let scannedAt: Date?

    /// This scan's stored JSON could not be read, so `scoreBreakdown` is the zeroed
    /// fallback rather than a real result. Suppresses the rating and score cards —
    /// a total of 0 renders as "Avoid", and telling someone their food is dangerous
    /// because we failed to parse our own file is worse than telling them nothing.
    let dataUnavailable: Bool

    @Environment(\.requestReview) private var requestReview

    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false
    @State private var selectedIngredient: Ingredient?
    @State private var showAllIngredients = false
    @State private var renderedShareCard: ShareCard?
    /// Drives the one-time result-reveal bounce on a fresh scan (not on saved scans).
    @State private var ratingRevealed = false

    // Pre-computed values (calculated once in init, not on every render)
    private let actualMatchedCount: Int
    private let actualTotalCount: Int
    private let actualMatchRate: Double
    private let actualMatchPercentage: Int
    private let unmatchedIngredientNames: [String]
    /// Matched, but by inference rather than a dictionary lookup.
    private let inferredMatchCount: Int

    // For saved scans - need bindable access
    private var scan: Scan? {
        if case .savedScan(let scan, _) = mode {
            return scan
        }
        return nil
    }

    init(
        productName: String,
        brand: String?,
        imageUrl: String?,
        species: Species,
        category: Category,
        scoreBreakdown: ScoreBreakdown,
        matchedIngredients: [MatchedIngredient],
        shareText: String,
        petName: String?,
        selectedPet: Pet? = nil,
        mode: Mode,
        scannedAt: Date? = nil,
        dataUnavailable: Bool = false
    ) {
        self.dataUnavailable = dataUnavailable
        self.productName = productName
        self.brand = brand
        self.imageUrl = imageUrl
        self.species = species
        self.category = category
        self.scoreBreakdown = scoreBreakdown
        self.matchedIngredients = matchedIngredients
        self.shareText = shareText
        self.petName = petName
        self.selectedPet = selectedPet
        self.mode = mode
        self.scannedAt = scannedAt

        // Pre-compute values once instead of on every render
        self.actualTotalCount = matchedIngredients.count
        self.actualMatchedCount = matchedIngredients.filter { $0.isMatched }.count
        self.actualMatchRate = actualTotalCount > 0 ? Double(actualMatchedCount) / Double(actualTotalCount) : 0
        self.actualMatchPercentage = Int(actualMatchRate * 100)
        self.unmatchedIngredientNames = matchedIngredients.filter { !$0.isMatched }.map { $0.labelName }
        self.inferredMatchCount = matchedIngredients.filter {
            $0.matchConfidence.isDatabaseMatch && !$0.matchConfidence.isCertain
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Product image
                productImageSection

                // Product header
                productHeader

                if dataUnavailable {
                    unreadableScanBanner
                } else {
                    // Allergen alert banner (only shown when allergens found)
                    allergenAlertBanner

                    // Rating label — bounces in once when a fresh result appears.
                    RatingLabelView(label: scoreBreakdown.ratingLabel)
                        .scaleEffect(ratingRevealed ? 1 : 0.85)
                        .opacity(ratingRevealed ? 1 : 0)

                    // Score breakdown with explanations
                    VStack(spacing: SpacingTokens.xs) {
                        // Suitability first - highest priority (allergen matching)
                        ScoreExplanationCard(
                            title: "Suitability",
                            score: scoreBreakdown.suitability,
                            explanation: scoreBreakdown.suitabilityExplanation
                        )

                        ScoreExplanationCard(
                            title: "Safety",
                            score: scoreBreakdown.safety,
                            explanation: scoreBreakdown.safetyExplanation
                        )

                        // Processing score (only shown for food/treats)
                        if let processingScore = scoreBreakdown.processing {
                            ScoreExplanationCard(
                                title: "Processing",
                                score: processingScore,
                                explanation: scoreBreakdown.processingExplanation
                            )
                        }
                    }
                }

                if !dataUnavailable {
                    // OCR info banner (scan results only)
                    if scoreBreakdown.scoreSource == .ocrEstimated {
                        ocrInfoBanner
                    }

                    // Split warnings section
                    warningsSection

                    // Ingredient recognition section
                    ingredientRecognitionSection

                    // Processing profile section (NOVA-style classification)
                    if matchedIngredients.contains(where: { $0.processingLevel != nil }) {
                        ProcessingSummaryCard(ingredients: matchedIngredients)
                    }

                    // Ingredients list
                    ingredientsListSection
                }

                // Mode-specific sections
                switch mode {
                case .scanResult(let onSave, let onScanAnother):
                    scanResultActions(onSave: onSave, onScanAnother: onScanAnother)

                case .savedScan(let scan, let onDelete):
                    savedScanSections(scan: scan, onDelete: onDelete)
                }
            }
            .padding()
            // Pin the content to exactly the viewport width. Without this, an
            // occasional oversized child — a long unbroken ingredient name,
            // product title, or unrecognized-ingredient string — widens the
            // stack past the screen and unlocks horizontal scrolling, letting
            // the user drag the whole view sideways into blank space. Locking
            // the width forces that content to wrap instead of overflow.
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onAppear {
            if let scan = scan {
                notes = scan.notes ?? ""
            }
            // Celebrate a fresh scan result; saved scans appear already-revealed.
            if case .scanResult = mode {
                withAnimation(AnimationTokens.celebrationBounce.delay(0.15)) {
                    ratingRevealed = true
                }
            } else {
                ratingRevealed = true
            }
        }
        .task { renderShareCard() }
        .task { await askForReviewIfEarned() }
        .confirmationDialog("Delete this scan?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            if case .savedScan(_, let onDelete) = mode {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityIdentifier("product-score-view")
        .toolbar {
            if case .scanResult(_, let onScanAnother) = mode {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onScanAnother()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("scan-result-close")
                }
            }
        }
        .sheet(item: $selectedIngredient) { ingredient in
            IngredientDetailSheet(ingredient: ingredient, species: species, pet: selectedPet)
        }
    }

    // MARK: - Share

    /// Shares a rendered score card, falling back to the plain text block until
    /// the card exists — and permanently, if rendering fails. `ImageRenderer` is
    /// a synchronous rasterize of a 1080pt view, so it runs once off `.task`
    /// into `renderedShareCard` rather than on every body evaluation.
    @ViewBuilder
    private var shareButton: some View {
        if let card = renderedShareCard {
            ShareLink(
                item: card,
                preview: SharePreview(productName, image: Image(uiImage: card.image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .secondaryButtonStyle()
        } else {
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .secondaryButtonStyle()
        }
    }

    private func renderShareCard() {
        guard renderedShareCard == nil else { return }
        // Never let a fabricated 0 escape the device as a shareable "Avoid" card.
        guard !dataUnavailable else { return }
        guard let image = ShareCardRenderer.render(
            productName: productName,
            brand: brand,
            breakdown: scoreBreakdown,
            petName: petName
        ) else { return }

        renderedShareCard = ShareCard(image: image, text: shareText)
    }

    // MARK: - Rating Prompt

    /// Presents the App Store rating sheet when `ReviewPrompt` armed one for
    /// this scan. Only from a fresh result — re-opening a saved scan from
    /// history is not the moment, and shouldn't be able to drain the flag.
    ///
    /// The delay is not cosmetic. `ScannerViewModel` schedules the ATT prompt
    /// 800ms after this screen appears, and iOS drops a review request made
    /// while another system alert owns the slot — silently, and it still counts
    /// against the three-per-year budget. Waiting past that window means the
    /// ask either lands or is never made.
    private func askForReviewIfEarned() async {
        guard case .scanResult = mode else { return }

        try? await Task.sleep(for: .seconds(2.5))
        guard !Task.isCancelled else { return }
        guard ReviewPrompt.consumePending() else { return }

        requestReview()
    }

    // MARK: - Unreadable Scan Banner

    private var unreadableScanBanner: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ColorTokens.warning)
                Text("This scan couldn't be loaded")
                    .heading2()
                Spacer()
            }

            Text("Its saved results are unreadable, so we can't show a score for it. Scanning the product again will give you a fresh result.")
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(backgroundColor: ColorTokens.warning.opacity(0.1))
    }

    // MARK: - Allergen Alert Banner

    @ViewBuilder
    private var allergenAlertBanner: some View {
        let allergenFlags = scoreBreakdown.allergenFlags
        if !allergenFlags.isEmpty, let petDisplayName = petName {
            let allergenNames = scoreBreakdown.suitabilityExplanation?.factors
                .filter { $0.impact == .negative }
                .compactMap { $0.ingredientName } ?? []

            AllergenAlertBanner(
                petName: petDisplayName,
                allergenFlags: allergenFlags,
                allergenNames: allergenNames
            )
        }
    }

    // MARK: - Product Image

    @ViewBuilder
    private var productImageSection: some View {
        if let urlString = imageUrl {
            ProductImageView(
                url: URL(string: urlString),
                size: 120,
                maxSize: 150,
                showPlaceholder: true
            )
        }
    }

    // MARK: - Product Header

    private var productHeader: some View {
        VStack(spacing: SpacingTokens.xxs) {
            if !productName.isEmpty {
                Text(productName)
                    .displaySmall()
                    .multilineTextAlignment(.center)
            }

            if let brand = brand {
                Text(brand)
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            HStack(spacing: SpacingTokens.xxs) {
                Label(species.displayName, systemImage: species.icon)
                Text("•")
                Label(category.displayName, systemImage: category.icon)
            }
            .caption()
            .foregroundColor(ColorTokens.textSecondary)

            // Show date for saved scans
            if let date = scannedAt {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Score source badge
            HStack(spacing: SpacingTokens.xxxs) {
                Image(systemName: scoreBreakdown.scoreSource.icon)
                Text(scoreBreakdown.scoreSource.badge)
            }
            .labelSmall()
            .badgeStyle(color: scoreBreakdown.scoreSource.badgeColor)
        }
    }

    // MARK: - OCR Info Banner

    private var ocrInfoBanner: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(ColorTokens.info)
                .font(TypographyTokens.heading3)

            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text("Estimated Score")
                    .heading3()
                Text("Based on ingredients from photo. Match rate: \(scoreBreakdown.matchPercentage)%")
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }
            Spacer()
        }
        .cardStyle(
            backgroundColor: ColorTokens.info.opacity(0.1),
            cornerRadius: SpacingTokens.radiusMedium
        )
    }

    // MARK: - Warnings Section

    @ViewBuilder
    private var warningsSection: some View {
        // Only show other warnings here - allergen warnings are shown in the hero banner
        if !scoreBreakdown.otherFlags.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Other Warnings")
                    .heading2()

                ForEach(scoreBreakdown.otherFlags) { flag in
                    WarningFlagView(flag: flag)
                }
            }
        }
    }

    // MARK: - Ingredient Recognition

    private var ingredientRecognitionSection: some View {
        VStack(spacing: SpacingTokens.xs) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(ColorTokens.textSecondary)
                Text("Ingredient Recognition")
                    .heading2()
                Spacer()
            }

            HStack(spacing: SpacingTokens.md) {
                // Match percentage circle
                ZStack {
                    Circle()
                        .stroke(ColorTokens.surfaceSecondary, lineWidth: 8)
                        .frame(width: SpacingTokens.iconXLarge, height: SpacingTokens.iconXLarge)

                    Circle()
                        .trim(from: 0, to: actualMatchRate)
                        .stroke(matchRateColor, lineWidth: 8)
                        .frame(width: SpacingTokens.iconXLarge, height: SpacingTokens.iconXLarge)
                        .rotationEffect(.degrees(-90))

                    Text("\(actualMatchPercentage)%")
                        .labelMedium()
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    HStack {
                        Text("\(actualMatchedCount) of \(actualTotalCount) ingredients recognized")
                            .bodyText()
                        Spacer()
                    }

                    // Break out the ones we inferred rather than looked up. The
                    // headline figure counts both, so without this line a product
                    // held together by guesses reads exactly like one we know cold.
                    if inferredMatchCount > 0 {
                        Text("\(inferredMatchCount) identified by closest match")
                            .caption()
                            .foregroundColor(ColorTokens.info)
                    }

                    if !unmatchedIngredientNames.isEmpty {
                        Text("Unrecognized: \(unmatchedIngredientNames.prefix(3).joined(separator: ", "))\(unmatchedIngredientNames.count > 3 ? "..." : "")")
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    } else if inferredMatchCount == 0 {
                        Text("All ingredients in our database")
                            .caption()
                            .foregroundColor(ColorTokens.success)
                    }
                }
            }
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
    }

    // MARK: - Ingredients List (Saved Scans)

    private var ingredientsListSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("Ingredients")
                    .heading2()
                Spacer()
                Text("Tap for details")
                    .caption()
                    .foregroundColor(ColorTokens.textTertiary)
            }

            let displayedIngredients = showAllIngredients
                ? matchedIngredients
                : Array(matchedIngredients.prefix(10))

            ForEach(displayedIngredients) { matchedIngredient in
                ingredientRow(matchedIngredient)
            }

            if matchedIngredients.count > 10 {
                Button {
                    withAnimation {
                        showAllIngredients.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllIngredients
                            ? "Show less"
                            : "Show \(matchedIngredients.count - 10) more ingredients")
                        Image(systemName: showAllIngredients ? "chevron.up" : "chevron.down")
                    }
                    .bodySmall()
                    .foregroundColor(ColorTokens.brandPrimary)
                }
                .padding(.top, SpacingTokens.xxs)
            }

        }
        .cardStyle(backgroundColor: ColorTokens.surfaceSecondary)
    }

    /// The only row marker: an ingredient we could not identify at all.
    ///
    /// There used to be a marker for every state, including a solid green check on
    /// every recognised ingredient. That check appeared on ~90% of rows, so it
    /// carried no information — it was a decoration that made the genuinely useful
    /// markers harder to spot. What's left is the exception: a token we don't know.
    ///
    /// *How* a known ingredient was matched still matters, but it belongs in the
    /// detail sheet next to the evidence, not as an icon the user has to decode.
    @ViewBuilder
    private func unknownIndicator(for matchedIngredient: MatchedIngredient) -> some View {
        if !matchedIngredient.isMatched {
            Image(systemName: "questionmark.circle")
                .foregroundColor(ColorTokens.warning)
                .accessibilityLabel("Not in our database yet")
        }
    }

    /// Species-specific risk, shown inline so a concerning ingredient is visible
    /// without tapping every row in a 27-item list.
    ///
    /// Uses `RiskTier`, the same classification `ScoreCalculator` scores against,
    /// so the row and the score can't disagree.
    @ViewBuilder
    private func riskIndicator(for ingredient: Ingredient) -> some View {
        // Symbol and colour come from the tier rather than being restated here. Restating
        // them is exactly what made this row draw a purple `severityCritical` octagon for
        // an ingredient the detail sheet, one tap away, badges red via `tier.color` —
        // while the comment above claimed the two could not disagree. Purple is otherwise
        // reserved for `RuleSeverity.critical`.
        //
        // Only the concerning tiers draw; a marker on a fine ingredient is the clutter
        // this replaced.
        let tier = RiskTier(ingredient.riskLevel(for: species))
        if tier.isConcerning {
            Image(systemName: tier.icon)
                .foregroundColor(tier.color)
                .accessibilityLabel(tier.displayName)
        }
    }

    private func ingredientRow(_ matchedIngredient: MatchedIngredient) -> some View {
        let fullIngredient = matchedIngredient.ingredientId.flatMap { IngredientDatabase.shared.ingredients[$0] }

        return Button {
            if let ingredient = fullIngredient {
                selectedIngredient = ingredient
            }
        } label: {
            HStack {
                Text("\(matchedIngredient.rank).")
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: 24, alignment: .trailing)

                Text(matchedIngredient.labelName)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                // Processing level badge (if available). Resolved live rather than
                // read from the snapshot, so a database update improves old scans.
                if let level = matchedIngredient.resolvedProcessingLevel(IngredientDatabase.shared.ingredients) {
                    ProcessingBadgeView(level: level, size: .small, showLabel: false)
                }

                if let ingredient = fullIngredient {
                    riskIndicator(for: ingredient)
                }

                unknownIndicator(for: matchedIngredient)

                // Show chevron for tappable ingredients
                if fullIngredient != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                }
            }
            .bodySmall()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(fullIngredient == nil)
    }

    // MARK: - Scan Result Actions

    private func scanResultActions(onSave: @escaping () -> Void, onScanAnother: @escaping () -> Void) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Button {
                onSave()
            } label: {
                Label("Save to History", systemImage: "square.and.arrow.down")
            }
            .primaryButtonStyle()

            HStack(spacing: SpacingTokens.xs) {
                shareButton

                Button {
                    onScanAnother()
                } label: {
                    Label("Scan Another", systemImage: "barcode.viewfinder")
                }
                .secondaryButtonStyle()
            }
        }
    }

    // MARK: - Saved Scan Sections

    @ViewBuilder
    private func savedScanSections(scan: Scan, onDelete: @escaping () -> Void) -> some View {
        // Notes
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Notes")
                .heading2()

            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(SpacingTokens.xxs)
                .background(ColorTokens.surfaceSecondary)
                .cornerRadius(SpacingTokens.radiusSmall)
                .onChange(of: notes) { _, newValue in
                    scan.notes = newValue.isEmpty ? nil : newValue
                    scan.updatedAt = Date()
                }
        }

        // Delete button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete Scan", systemImage: "trash")
        }
        .primaryButtonStyle(isDestructive: true)
    }

    // MARK: - Helper Views

    private var productPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: SpacingTokens.iconXLarge * 0.67))
            .foregroundColor(ColorTokens.textSecondary)
            .frame(width: SpacingTokens.iconOnboarding, height: SpacingTokens.iconOnboarding)
            .background(ColorTokens.surfacePrimary)
            .cornerRadius(SpacingTokens.radiusMedium)
    }

    private var matchRateColor: Color {
        ColorTokens.colorForMatchRate(actualMatchPercentage)
    }
}

// MARK: - Convenience initializer for Scan objects

extension ProductScoreView {
    init(scan: Scan, shareText: String, onDelete: @escaping () -> Void) {
        self.init(
            productName: scan.productName ?? "",
            brand: scan.brand,
            imageUrl: scan.imageUrl,
            species: scan.speciesEnum,
            category: scan.categoryEnum,
            scoreBreakdown: scan.scoreBreakdown,
            matchedIngredients: scan.matchedIngredients,
            shareText: shareText,
            petName: nil,
            selectedPet: nil,
            mode: .savedScan(scan: scan, onDelete: onDelete),
            scannedAt: scan.scannedAt,
            // Read after the two accessors above, which is what sets the flag.
            dataUnavailable: scan.decodeFailed
        )
    }
}

#Preview("Scan Result") {
    ProductScoreView(
        productName: "Premium Dog Food",
        brand: "Acme Pet Foods",
        imageUrl: nil,
        species: .dog,
        category: .food,
        scoreBreakdown: ScoreBreakdown(
            total: 0,
            safety: 85,
            suitability: 0,
            processing: 75,
            flags: [
                WarningFlag(severity: .high, title: "Possible allergen", explain: "Chicken may conflict with Max's allergen profile.", ingredientId: "ing_chicken", source: nil, type: .allergen),
                WarningFlag(severity: .warn, title: "Ingredient warning", explain: "Garlic in large quantities may be harmful.", ingredientId: "ing_garlic", source: "ASPCA", type: .safety)
            ],
            unmatched: ["mystery ingredient", "natural flavoring blend"],
            matchedCount: 8,
            totalCount: 10,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Safe ingredient", impact: .positive, ingredientName: "Brown Rice"),
                    ExplanationFactor(id: "2", description: "Use with caution", impact: .negative, ingredientName: "Garlic")
                ],
                summary: "One ingredient requires attention."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Matches Max's allergen profile", impact: .negative, ingredientName: "Chicken")
                ],
                summary: "Contains an ingredient Max should avoid. Score set to Avoid."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Majority minimally processed", impact: .positive, ingredientName: nil)
                ],
                summary: "Mostly minimally processed ingredients."
            )
        ),
        matchedIngredients: [
            MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1, processingLevel: .unprocessed),
            MatchedIngredient(ingredientId: "ing_brown_rice", labelName: "Brown Rice", rank: 2, processingLevel: .unprocessed),
            MatchedIngredient(ingredientId: nil, labelName: "Mystery ingredient", rank: 3, processingLevel: nil)
        ],
        shareText: "Test share text",
        petName: "Max",
        mode: .scanResult(onSave: {}, onScanAnother: {})
    )
}
