import SwiftUI

/// Shows aggregate processing level breakdown for a product
/// Displays as a horizontal stacked bar chart with legend
struct ProcessingSummaryCard: View {
    let ingredients: [MatchedIngredient]
    @State private var showInfoSheet = false

    private var levelCounts: [ProcessingLevel: Int] {
        var counts: [ProcessingLevel: Int] = [:]
        for ingredient in ingredients {
            if let level = ingredient.processingLevel {
                counts[level, default: 0] += 1
            }
        }
        return counts
    }

    private var totalClassified: Int {
        levelCounts.values.reduce(0, +)
    }

    private var classificationRate: Int {
        guard ingredients.count > 0 else { return 0 }
        return Int((Double(totalClassified) / Double(ingredients.count)) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ColorTokens.textSecondary)
                Text("Processing Profile")
                    .heading2()
                Spacer()

                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .accessibilityLabel("Learn about processing levels")
            }

            if totalClassified > 0 {
                // Stacked bar visualization
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(ProcessingLevel.allCases) { level in
                            if let count = levelCounts[level], count > 0 {
                                let percentage = CGFloat(count) / CGFloat(totalClassified)
                                Rectangle()
                                    .fill(level.color)
                                    .frame(width: max(geometry.size.width * percentage, 4))
                            }
                        }
                    }
                    .cornerRadius(SpacingTokens.radiusSmall)
                }
                .frame(height: 12)

                // Legend
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(ProcessingLevel.allCases) { level in
                        if let count = levelCounts[level], count > 0 {
                            legendItem(level: level, count: count)
                        }
                    }
                    Spacer()
                }

                // Classification rate
                if classificationRate < 100 {
                    Text("\(classificationRate)% of ingredients classified")
                        .caption()
                        .foregroundColor(ColorTokens.textTertiary)
                }
            } else {
                Text("Processing data not available for these ingredients")
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Disclaimer
            Text("For informational purposes only")
                .caption()
                .foregroundColor(ColorTokens.textTertiary)
                .italic()
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
        .sheet(isPresented: $showInfoSheet) {
            ProcessingInfoSheet()
        }
    }

    private func legendItem(level: ProcessingLevel, count: Int) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .accessibilityLabel("\(count) \(level.displayName) ingredients")
    }
}

#Preview {
    let sampleIngredients = [
        MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1, processingLevel: .unprocessed),
        MatchedIngredient(ingredientId: "ing_rice", labelName: "Brown Rice", rank: 2, processingLevel: .unprocessed),
        MatchedIngredient(ingredientId: "ing_chicken_fat", labelName: "Chicken Fat", rank: 3, processingLevel: .culinaryIngredient),
        MatchedIngredient(ingredientId: "ing_chicken_meal", labelName: "Chicken Meal", rank: 4, processingLevel: .processed),
        MatchedIngredient(ingredientId: "ing_beet_pulp", labelName: "Dried Beet Pulp", rank: 5, processingLevel: .processed),
        MatchedIngredient(ingredientId: "ing_vitamins", labelName: "Vitamin E Supplement", rank: 6, processingLevel: .ultraProcessed),
        MatchedIngredient(ingredientId: nil, labelName: "Natural Flavors", rank: 7, processingLevel: nil)
    ]

    return ProcessingSummaryCard(ingredients: sampleIngredients)
        .padding()
}
