import SwiftUI

/// View displayed when a product is not found in the database
/// Offers options to take a photo of ingredients or enter manually
struct ProductNotFoundView: View {
    let barcode: String?
    var isManualSearch: Bool = false
    let onTakePhoto: () -> Void
    let onManualEntry: () -> Void
    let onRetry: () -> Void

    private var title: String {
        isManualSearch ? "Search by Ingredients" : "Product Not Found"
    }

    private var subtitle: String {
        isManualSearch
            ? "Choose how you'd like to enter ingredients:"
            : "This product isn't in our database yet. You can:"
    }

    private var icon: String {
        isManualSearch ? "magnifyingglass" : "exclamationmark.magnifyingglass"
    }

    private var iconColor: Color {
        isManualSearch ? ColorTokens.brandPrimary : ColorTokens.warning.opacity(0.8)
    }

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(iconColor)

            // Title and message
            VStack(spacing: SpacingTokens.xxs) {
                Text(title)
                    .displaySmall()

                if !isManualSearch, let code = barcode {
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

            // Action buttons
            VStack(spacing: SpacingTokens.xs) {
                // Primary: Take Photo
                Button {
                    onTakePhoto()
                } label: {
                    Label("Take Photo of Ingredients", systemImage: "camera.fill")
                }
                .primaryButtonStyle()

                // Secondary: Manual Entry
                Button {
                    onManualEntry()
                } label: {
                    Label("Enter Ingredients Manually", systemImage: "keyboard")
                }
                .secondaryButtonStyle()

                // Tertiary: Retry (only show if not manual search)
                if !isManualSearch {
                    Button {
                        onRetry()
                    } label: {
                        Label("Try Barcode Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ColorTokens.textSecondary)
                    .padding(.top, SpacingTokens.xs)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

#Preview("With Barcode") {
    ProductNotFoundView(
        barcode: "123456789",
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}

#Preview("Without Barcode") {
    ProductNotFoundView(
        barcode: nil,
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}
