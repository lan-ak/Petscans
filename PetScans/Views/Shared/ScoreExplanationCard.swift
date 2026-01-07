import SwiftUI

/// Expandable card showing a score component with detailed explanation
struct ScoreExplanationCard: View {
    let title: String
    let score: Double
    let explanation: ScoreExplanation?
    @State private var isExpanded: Bool = false

    private var ratingLabel: RatingLabel {
        explanation?.labelOverride ?? RatingLabel.from(score: score)
    }

    /// When a label override exists, use a score that visually matches the label
    private var effectiveScore: Double {
        if let override = explanation?.labelOverride {
            switch override {
            case .avoid: return 0
            case .caution: return 35
            case .good: return 60
            case .excellent: return score
            }
        }
        return score
    }

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

                            Text(ratingLabel.rawValue)
                                .labelSmall()
                                .foregroundColor(ratingLabel.color)
                        }

                        // Score bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: SpacingTokens.xxxs)
                                    .fill(ColorTokens.surfaceSecondary)

                                RoundedRectangle(cornerRadius: SpacingTokens.xxxs)
                                    .fill(ratingLabel.color)
                                    .frame(width: geometry.size.width * (effectiveScore / 100))
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

        // Label override to "Avoid" - bar should be empty
        ScoreExplanationCard(
            title: "Suitability",
            score: 100, // High score but overridden to Avoid
            explanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Contains known allergen", impact: .negative, ingredientName: "Chicken")
                ],
                summary: "Contains an ingredient Max should avoid. Score set to Avoid.",
                labelOverride: .avoid
            )
        )
    }
    .padding()
}
