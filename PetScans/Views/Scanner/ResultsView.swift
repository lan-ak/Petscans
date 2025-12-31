import SwiftUI

struct ResultsView: View {
    let productName: String?
    let brand: String?
    let imageUrl: String?
    let species: Species
    let category: Category
    let scoreBreakdown: ScoreBreakdown
    let matchedIngredients: [MatchedIngredient]
    let shareText: String
    let onSave: () -> Void
    let onScanAnother: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Product image
                if let urlString = imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 150, maxHeight: 150)
                                .cornerRadius(SpacingTokens.radiusMedium)
                        case .failure:
                            productPlaceholder
                        @unknown default:
                            productPlaceholder
                        }
                    }
                }

                // Product header
                VStack(spacing: SpacingTokens.xxs) {
                    if let name = productName {
                        Text(name)
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

                    // Score source badge
                    HStack(spacing: SpacingTokens.xxxs) {
                        Image(systemName: scoreBreakdown.scoreSource.icon)
                        Text(scoreBreakdown.scoreSource.badge)
                    }
                    .labelSmall()
                    .badgeStyle(color: scoreBreakdown.scoreSource.badgeColor)
                }

                // Main score
                ScoreCircleView(score: scoreBreakdown.total, size: 120)

                // Score breakdown
                VStack(spacing: SpacingTokens.xs) {
                    ScoreBarView(label: "Safety", score: scoreBreakdown.safety)

                    if let nutrition = scoreBreakdown.nutrition {
                        ScoreBarView(label: "Nutrition", score: nutrition)
                    }

                    ScoreBarView(label: "Suitability", score: scoreBreakdown.suitability)
                }
                .cardStyle(backgroundColor: ColorTokens.surfaceSecondary)

                // OCR info banner
                if scoreBreakdown.scoreSource == .ocrEstimated {
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

                // Warning flags
                if !scoreBreakdown.flags.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Warnings")
                            .heading2()

                        ForEach(scoreBreakdown.flags) { flag in
                            WarningFlagView(flag: flag)
                        }
                    }
                }

                // Ingredient match rate - prominent display
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
                                .trim(from: 0, to: scoreBreakdown.matchRate)
                                .stroke(matchRateColor, lineWidth: 8)
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))

                            Text("\(scoreBreakdown.matchPercentage)%")
                                .labelMedium()
                        }

                        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                            HStack {
                                Text("\(scoreBreakdown.matchedCount) of \(scoreBreakdown.totalCount) ingredients recognized")
                                    .bodyText()
                                Spacer()
                            }

                            if !scoreBreakdown.unmatched.isEmpty {
                                Text("Unrecognized: \(scoreBreakdown.unmatched.prefix(3).joined(separator: ", "))\(scoreBreakdown.unmatched.count > 3 ? "..." : "")")
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
                .cardStyle(backgroundColor: ColorTokens.surfaceSecondary)

                // Action buttons
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
            .padding()
        }
    }

    private var productPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 40))
            .foregroundColor(ColorTokens.textSecondary)
            .frame(width: 120, height: 120)
            .background(ColorTokens.surfacePrimary)
            .cornerRadius(SpacingTokens.radiusMedium)
    }

    private var matchRateColor: Color {
        let percentage = scoreBreakdown.matchPercentage
        if percentage >= 80 {
            return ColorTokens.success
        } else if percentage >= 50 {
            return ColorTokens.warning
        } else {
            return ColorTokens.error
        }
    }
}

#Preview {
    ResultsView(
        productName: "Premium Dog Food",
        brand: "Acme Pet Foods",
        imageUrl: nil,
        species: .dog,
        category: .food,
        scoreBreakdown: ScoreBreakdown(
            total: 72.5,
            safety: 85,
            nutrition: 68,
            suitability: 90,
            flags: [
                WarningFlag(severity: .warn, title: "Use with caution", explain: "Garlic in large quantities may be harmful.", ingredientId: "ing_garlic")
            ],
            unmatched: ["mystery ingredient", "natural flavoring blend"],
            matchedCount: 8,
            totalCount: 10,
            scoreSource: .databaseVerified,
            ocrConfidence: nil
        ),
        matchedIngredients: [
            MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1),
            MatchedIngredient(ingredientId: "ing_brown_rice", labelName: "Brown Rice", rank: 2),
            MatchedIngredient(ingredientId: nil, labelName: "Mystery ingredient", rank: 3)
        ],
        shareText: "Test share text",
        onSave: {},
        onScanAnother: {}
    )
}
