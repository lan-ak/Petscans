import SwiftUI

/// View displayed while OCR is processing an image
struct OCRProcessingView: View {
    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            // Icon
            Image(systemName: "text.viewfinder")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            // Title
            Text("Analyzing Ingredients...")
                .heading2()
                .foregroundColor(ColorTokens.textPrimary)

            // Progress indicator
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, SpacingTokens.xs)

            // Description
            Text("Recognizing text from image")
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding()
    }
}

#Preview {
    OCRProcessingView()
}
