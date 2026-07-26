import SwiftUI

/// Shown when a scanned barcode isn't in the catalog, or when an AI photo
/// identification failed. Offers a single clear path forward — search with a
/// photo — plus a way back to the scanner.
struct ProductNotFoundView: View {
    let reason: ScannerViewModel.NotFoundReason
    let barcode: String?
    let onSearchWithPhoto: () -> Void
    let onScanAnother: () -> Void

    private var title: String {
        switch reason {
        case .notInCatalog: return "Product Not Found"
        case .notRecognized: return "We couldn't recognize that"
        }
    }

    private var subtitle: String {
        switch reason {
        case .notInCatalog:
            return "This product isn't in our database yet. Snap a photo of the front of the pack and PetScans AI will find it."
        case .notRecognized:
            return "We couldn't identify the product from that photo. Try again with the front of the pack in clear focus and good light."
        }
    }

    private var icon: String {
        switch reason {
        case .notInCatalog: return "exclamationmark.magnifyingglass"
        case .notRecognized: return "eye.trianglebadge.exclamationmark"
        }
    }

    private var primaryLabel: String {
        switch reason {
        case .notInCatalog: return "Search with PetScans AI"
        case .notRecognized: return "Try Another Photo"
        }
    }

    /// `sparkles` for the first jump into AI search; a camera for a straight
    /// photo-retake, matching the retake action in ProductSearchView.
    private var primaryIcon: String {
        switch reason {
        case .notInCatalog: return "sparkles"
        case .notRecognized: return "camera.fill"
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.warning.opacity(0.8))

            VStack(spacing: SpacingTokens.xxs) {
                Text(title)
                    .displaySmall()

                if reason == .notInCatalog, let code = barcode {
                    Text("Barcode: \(code)")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                        .padding(.bottom, SpacingTokens.xs)
                }

                Text(subtitle)
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: SpacingTokens.xs) {
                // Primary: the one supported way forward — the AI photo search.
                Button {
                    onSearchWithPhoto()
                } label: {
                    Label(primaryLabel, systemImage: primaryIcon)
                }
                .primaryButtonStyle()

                // Secondary: back to the scanner for a different product.
                Button {
                    onScanAnother()
                } label: {
                    Label("Scan Another", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.textSecondary)
                .padding(.top, SpacingTokens.xs)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Not In Catalog") {
    ProductNotFoundView(
        reason: .notInCatalog,
        barcode: "5998749138199",
        onSearchWithPhoto: {},
        onScanAnother: {}
    )
}

#Preview("Not Recognized") {
    ProductNotFoundView(
        reason: .notRecognized,
        barcode: nil,
        onSearchWithPhoto: {},
        onScanAnother: {}
    )
}
