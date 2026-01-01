import SwiftUI

/// View displayed when a product is not found in the database
/// Offers options to take a photo of ingredients or enter manually
struct ProductNotFoundView: View {
    let barcode: String?
    let productName: String?
    let brand: String?
    let imageUrl: String?
    var isManualSearch: Bool = false
    let onTakePhoto: () -> Void
    let onManualEntry: () -> Void
    let onRetry: () -> Void

    /// Check if we have product info to display
    private var hasProductInfo: Bool {
        productName != nil && !productName!.isEmpty
    }

    private var title: String {
        if isManualSearch { return "Search by Ingredients" }
        if hasProductInfo { return "Missing Ingredients" }
        return "Product Not Found"
    }

    private var subtitle: String {
        if isManualSearch {
            return "Choose how you'd like to enter ingredients:"
        }
        if hasProductInfo {
            return "We found this product but don't have its ingredients. You can:"
        }
        return "This product isn't in our database yet. You can:"
    }

    private var icon: String {
        if isManualSearch { return "magnifyingglass" }
        if hasProductInfo { return "doc.text.magnifyingglass" }
        return "exclamationmark.magnifyingglass"
    }

    private var iconColor: Color {
        if isManualSearch { return ColorTokens.brandPrimary }
        if hasProductInfo { return ColorTokens.brandPrimary }
        return ColorTokens.warning.opacity(0.8)
    }

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            // Show product image if available
            if let urlString = imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 100, height: 100)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 120, maxHeight: 120)
                            .cornerRadius(SpacingTokens.radiusMedium)
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Show product info if available
            if hasProductInfo {
                VStack(spacing: SpacingTokens.xxs) {
                    Text(productName!)
                        .heading2()
                        .multilineTextAlignment(.center)
                    if let brand = brand, !brand.isEmpty {
                        Text(brand)
                            .bodySmall()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }

            // Icon (only show if no product image)
            if imageUrl == nil || !hasProductInfo {
                Image(systemName: icon)
                    .font(.system(size: SpacingTokens.iconXLarge))
                    .foregroundColor(iconColor)
            }

            // Title and message
            VStack(spacing: SpacingTokens.xxs) {
                Text(title)
                    .displaySmall()

                if !isManualSearch, let code = barcode, !hasProductInfo {
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
        productName: nil,
        brand: nil,
        imageUrl: nil,
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}

#Preview("With Product Info") {
    ProductNotFoundView(
        barcode: "5998749138199",
        productName: "Whiskas Temptation",
        brand: "Whiskas",
        imageUrl: "https://images.openfoodfacts.org/images/products/599/874/913/8199/front_en.3.400.jpg",
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}

#Preview("Without Barcode") {
    ProductNotFoundView(
        barcode: nil,
        productName: nil,
        brand: nil,
        imageUrl: nil,
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}
