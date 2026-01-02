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
    let mode: Mode
    let scannedAt: Date?

    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false

    // For saved scans - need bindable access
    private var scan: Scan? {
        if case .savedScan(let scan, _) = mode {
            return scan
        }
        return nil
    }

    // Computed properties for accurate counts (handles legacy scans)
    private var actualMatchedCount: Int {
        matchedIngredients.filter { $0.isMatched }.count
    }

    private var actualTotalCount: Int {
        matchedIngredients.count
    }

    private var actualMatchRate: Double {
        guard actualTotalCount > 0 else { return 0 }
        return Double(actualMatchedCount) / Double(actualTotalCount)
    }

    private var actualMatchPercentage: Int {
        Int(actualMatchRate * 100)
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
        mode: Mode,
        scannedAt: Date? = nil
    ) {
        self.productName = productName
        self.brand = brand
        self.imageUrl = imageUrl
        self.species = species
        self.category = category
        self.scoreBreakdown = scoreBreakdown
        self.matchedIngredients = matchedIngredients
        self.shareText = shareText
        self.petName = petName
        self.mode = mode
        self.scannedAt = scannedAt
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Product image
                productImageSection

                // Product header
                productHeader

                // Rating label
                RatingLabelView(label: scoreBreakdown.ratingLabel)

                // Score breakdown with explanations
                VStack(spacing: SpacingTokens.xs) {
                    ScoreExplanationCard(
                        title: "Safety",
                        score: scoreBreakdown.safety,
                        explanation: scoreBreakdown.safetyExplanation
                    )

                    ScoreExplanationCard(
                        title: "Suitability",
                        score: scoreBreakdown.suitability,
                        explanation: scoreBreakdown.suitabilityExplanation
                    )
                }

                // OCR info banner (scan results only)
                if scoreBreakdown.scoreSource == .ocrEstimated {
                    ocrInfoBanner
                }

                // Split warnings section
                warningsSection

                // Ingredient recognition section
                ingredientRecognitionSection

                // Ingredients list (saved scans only)
                if case .savedScan = mode {
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
        }
        .onAppear {
            if let scan = scan {
                notes = scan.notes ?? ""
            }
        }
        .confirmationDialog("Delete this scan?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            if case .savedScan(_, let onDelete) = mode {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
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
        if !scoreBreakdown.flags.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                // Allergen warnings subsection
                if !scoreBreakdown.allergenFlags.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        HStack(spacing: SpacingTokens.xxs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ColorTokens.severityHigh)
                            Text("Allergen Details")
                                .heading2()
                                .foregroundColor(ColorTokens.severityHigh)
                        }

                        ForEach(scoreBreakdown.allergenFlags) { flag in
                            WarningFlagView(flag: flag)
                        }
                    }
                }

                // Other warnings subsection
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
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: actualMatchRate)
                        .stroke(matchRateColor, lineWidth: 8)
                        .frame(width: 60, height: 60)
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

                    let unmatchedIngredients = matchedIngredients.filter { !$0.isMatched }.map { $0.labelName }
                    if !unmatchedIngredients.isEmpty {
                        Text("Unrecognized: \(unmatchedIngredients.prefix(3).joined(separator: ", "))\(unmatchedIngredients.count > 3 ? "..." : "")")
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    } else {
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
            Text("Ingredients")
                .heading2()

            ForEach(matchedIngredients) { ingredient in
                HStack {
                    Text("\(ingredient.rank).")
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(width: 24, alignment: .trailing)

                    Text(ingredient.labelName)

                    Spacer()

                    if ingredient.isMatched {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ColorTokens.success)
                    } else {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(ColorTokens.warning)
                    }
                }
                .bodySmall()
            }

            if !scoreBreakdown.unmatched.isEmpty {
                Text("Unrecognized ingredients are marked with a question mark")
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
        .cardStyle(backgroundColor: ColorTokens.surfaceSecondary)
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
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .secondaryButtonStyle()

                Button {
                    onScanAnother()
                } label: {
                    Text("Scan Another")
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
            .frame(width: 120, height: 120)
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
            mode: .savedScan(scan: scan, onDelete: onDelete),
            scannedAt: scan.scannedAt
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
            total: 72.5,
            safety: 85,
            nutrition: 68,
            suitability: 40,
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
                summary: "Contains 1 potential allergen for Max."
            )
        ),
        matchedIngredients: [
            MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1),
            MatchedIngredient(ingredientId: "ing_brown_rice", labelName: "Brown Rice", rank: 2),
            MatchedIngredient(ingredientId: nil, labelName: "Mystery ingredient", rank: 3)
        ],
        shareText: "Test share text",
        petName: "Max",
        mode: .scanResult(onSave: {}, onScanAnother: {})
    )
}
