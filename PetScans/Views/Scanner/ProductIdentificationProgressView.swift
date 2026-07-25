import SwiftUI

/// Progress view shown while identifying product from photo
struct ProductIdentificationProgressView: View {
    let image: UIImage?
    let identification: ProductIdentification?
    let isProcessing: Bool
    /// Optional escape hatch while identifying (vision can take up to 30s).
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Matches the paw background of the next screen (ProductSearchView) so the
            // two waiting states read as one continuous flow.
            FloatingElementsView.paws(opacity: 0.45)
                .ignoresSafeArea()

            content
        }
    }

    private var content: some View {
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
                    ZStack {
                        Circle()
                            .fill(ColorTokens.brandPrimary.opacity(0.15))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(ColorTokens.brandPrimary)
                    }

                    Text("Identifying product...")
                        .heading3()

                    Text("This can take up to 30 seconds — reading the brand and product name")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundColor(ColorTokens.textSecondary)
                        .padding(.top, SpacingTokens.xs)
                    }
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

// MARK: - Confirmation Gate

/// Shown when the vision identification came back with low confidence. Asks the
/// user to confirm the guess before we spend a scrape and produce a safety score,
/// so a mis-identified product can't silently drive a wrong result.
struct ProductIdentificationConfirmView: View {
    let image: UIImage?
    let identification: ProductIdentification?
    let onConfirm: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(SpacingTokens.radiusMedium)
                    .shadow(radius: 8)
            }

            VStack(spacing: SpacingTokens.xs) {
                Text("Is this your product?")
                    .heading2()
                    .multilineTextAlignment(.center)

                if let brand = identification?.brand {
                    Text(brand)
                        .bodyText()
                        .foregroundColor(ColorTokens.textPrimary)
                }
                if let productName = identification?.productName {
                    Text(productName)
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("We're not fully sure — please confirm so we score the right food.")
                    .caption()
                    .foregroundColor(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, SpacingTokens.xxs)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: SpacingTokens.xs) {
                Button {
                    onConfirm()
                } label: {
                    Label("Yes, that's it", systemImage: "checkmark")
                }
                .primaryButtonStyle()

                Button {
                    onRetake()
                } label: {
                    Label("Retake Photo", systemImage: "camera.fill")
                }
                .secondaryButtonStyle()

                Button("Back to Scanner") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.textSecondary)
                .padding(.top, SpacingTokens.xxs)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview("Processing") {
    ProductIdentificationProgressView(
        image: nil,
        identification: nil,
        isProcessing: true
    )
}

#Preview("Confirm") {
    ProductIdentificationConfirmView(
        image: nil,
        identification: ProductIdentification(
            brand: "Blue Buffalo",
            productName: "Wilderness Chicken Recipe",
            species: "dog",
            confidence: 0.55,
            primaryProtein: "Chicken",
            primaryCarb: "Rice"
        ),
        onConfirm: {},
        onRetake: {},
        onCancel: {}
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
