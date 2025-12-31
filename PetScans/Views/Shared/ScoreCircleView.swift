import SwiftUI

struct ScoreCircleView: View {
    let score: Double
    var size: CGFloat = 80

    private var color: Color {
        ColorTokens.colorForScore(score)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: size * 0.1)

            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(score))")
                .font(TypographyTokens.scoreDisplay(size: size))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: SpacingTokens.md) {
        ScoreCircleView(score: 90)  // Excellent (75-100)
        ScoreCircleView(score: 65)  // Good (50-74)
        ScoreCircleView(score: 35)  // Moderate (25-49)
        ScoreCircleView(score: 15)  // Poor (0-24)
        ScoreCircleView(score: 78, size: 120)
    }
}
