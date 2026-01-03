import SwiftUI

/// Expandable card showing a score component with detailed explanation
struct ScoreExplanationCard: View {
    let title: String
    let score: Double
    let explanation: ScoreExplanation?
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            // Header with score bar
            Button {
                withSnappyAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        HStack {
                            Text(title)
                                .heading3()
                                .foregroundColor(ColorTokens.textPrimary)

                            Spacer()

                            Text(RatingLabel.from(score: score).rawValue)
                                .labelSmall()
                                .foregroundColor(ColorTokens.colorForScore(score))
                        }

                        // Score bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: SpacingTokens.xxxs)
                                    .fill(ColorTokens.surfaceSecondary)

                                RoundedRectangle(cornerRadius: SpacingTokens.xxxs)
                                    .fill(ColorTokens.colorForScore(score))
                                    .frame(width: geometry.size.width * (score / 100))
                            }
                        }
                        .frame(height: 8)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ColorTokens.textSecondary)
                        .font(.caption)
                        .padding(.leading, SpacingTokens.xs)
                }
            }
            .buttonStyle(.plain)

            // Expandable explanation
            if isExpanded, let explanation = explanation {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(explanation.summary)
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)

                    if !explanation.factors.isEmpty {
                        Divider()
                            .padding(.vertical, SpacingTokens.xxxs)

                        ForEach(explanation.factors) { factor in
                            HStack(alignment: .top, spacing: SpacingTokens.xxs) {
                                Image(systemName: factor.impact.icon)
                                    .foregroundColor(factor.impact.color)
                                    .font(.caption)
                                    .frame(width: SpacingTokens.iconSmall)

                                VStack(alignment: .leading, spacing: 2) {
                                    if let ingredientName = factor.ingredientName {
                                        Text(ingredientName)
                                            .labelSmall()
                                            .foregroundColor(ColorTokens.textPrimary)
                                    }
                                    Text(factor.description)
                                        .caption()
                                        .foregroundColor(ColorTokens.textSecondary)
                                }

                                Spacer()
                            }
                        }
                    }
                }
                .padding(.top, SpacingTokens.xxs)
            }
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
    }
}

#Preview {
    VStack(spacing: SpacingTokens.md) {
        ScoreExplanationCard(
            title: "Safety",
            score: 85,
            explanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Safe ingredient", impact: .positive, ingredientName: "Chicken"),
                    ExplanationFactor(id: "2", description: "Use with caution", impact: .negative, ingredientName: "Garlic")
                ],
                summary: "Most ingredients appear safe."
            )
        )

        ScoreExplanationCard(
            title: "Suitability",
            score: 40,
            explanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Matches Max's allergen profile", impact: .negative, ingredientName: "Beef"),
                    ExplanationFactor(id: "2", description: "Matches Max's allergen profile", impact: .negative, ingredientName: "Dairy")
                ],
                summary: "Contains 2 potential allergens for Max."
            )
        )
    }
    .padding()
}
