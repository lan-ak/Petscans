import SwiftUI

/// Progress view shown while identifying product from photo
struct ProductIdentificationProgressView: View {
    let image: UIImage?
    let identification: ProductIdentification?
    let isProcessing: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            // Show captured image thumbnail
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(SpacingTokens.radiusMedium)
                    .shadow(radius: 8)
            }

            // Processing indicator or result
            if isProcessing {
                VStack(spacing: SpacingTokens.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(ColorTokens.brandPrimary)

                    Text("Identifying product...")
                        .heading3()

                    Text("Looking for brand and product name")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                }
            } else if let identification = identification {
                // Show identified brand/product
                VStack(spacing: SpacingTokens.xs) {
                    if let brand = identification.brand {
                        Text(brand)
                            .heading2()
                    }
                    if let productName = identification.productName {
                        Text(productName)
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Confidence indicator
                    HStack(spacing: SpacingTokens.xxs) {
                        Image(systemName: confidenceIcon(for: identification.confidence))
                            .foregroundColor(confidenceColor(for: identification.confidence))
                        Text("\(Int(identification.confidence * 100))% confident")
                            .caption()
                            .foregroundColor(ColorTokens.textTertiary)
                    }
                    .padding(.top, SpacingTokens.xs)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func confidenceIcon(for confidence: Double) -> String {
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.5 {
            return "checkmark.circle"
        } else {
            return "questionmark.circle"
        }
    }

    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 {
            return ColorTokens.success
        } else if confidence >= 0.5 {
            return ColorTokens.warning
        } else {
            return ColorTokens.textTertiary
        }
    }
}

#Preview("Processing") {
    ProductIdentificationProgressView(
        image: nil,
        identification: nil,
        isProcessing: true
    )
}

#Preview("Identified") {
    ProductIdentificationProgressView(
        image: nil,
        identification: ProductIdentification(
            brand: "Blue Buffalo",
            productName: "Wilderness Chicken Recipe",
            species: "dog",
            confidence: 0.92,
            primaryProtein: "Chicken",
            primaryCarb: "Rice"
        ),
        isProcessing: false
    )
}
