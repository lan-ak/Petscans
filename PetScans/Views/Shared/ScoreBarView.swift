import SwiftUI

struct ScoreBarView: View {
    let label: String
    let score: Double
    var showValue: Bool = true

    private var color: Color {
        ColorTokens.colorForScore(score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack {
                Text(label)
                    .font(TypographyTokens.bodySmall)
                    .foregroundColor(ColorTokens.textSecondary)

                Spacer()

                if showValue {
                    Text("\(Int(score))")
                        .font(TypographyTokens.scoreValue)
                        .foregroundColor(color)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: SpacingTokens.radiusSmall / 2)
                        .fill(ColorTokens.surfaceSecondary)

                    RoundedRectangle(cornerRadius: SpacingTokens.radiusSmall / 2)
                        .fill(color)
                        .frame(width: geometry.size.width * (score / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    VStack(spacing: SpacingTokens.sm) {
        ScoreBarView(label: "Safety", score: 90)        // Excellent
        ScoreBarView(label: "Nutrition", score: 65)     // Good
        ScoreBarView(label: "Suitability", score: 35)   // Moderate
        ScoreBarView(label: "Quality", score: 15)       // Poor
    }
    .padding()
}
