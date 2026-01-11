import SwiftUI

/// View displayed when a product is not found in the database
/// Offers options to take a photo of ingredients or enter manually
struct ProductNotFoundView: View {
    let barcode: String?
    let productName: String?
    let brand: String?
    let imageUrl: String?
    var isManualSearch: Bool = false
    let onAdvancedSearch: (() -> Void)?
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
            if let urlString = imageUrl {
                ProductImageView(
                    url: URL(string: urlString),
                    size: 100,
                    maxSize: 120,
                    showPlaceholder: false
                )
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
                // Primary: Advanced Search (only if barcode exists and not manual search)
                if let advancedSearch = onAdvancedSearch, barcode != nil, !isManualSearch {
                    Button {
                        advancedSearch()
                    } label: {
                        HStack(spacing: SpacingTokens.xxs) {
                            Image(systemName: "sparkles")
                            Text("Use PetScans AI")
                            Image(systemName: "sparkles")
                        }
                    }
                    .primaryButtonStyle()
                }

                // Take Photo (primary if no advanced search, secondary otherwise)
                Button {
                    onTakePhoto()
                } label: {
                    Label("Take Photo of Ingredients", systemImage: "camera.fill")
                }
                .modifier(ConditionalButtonStyle(
                    isPrimary: onAdvancedSearch == nil || barcode == nil || isManualSearch
                ))

                // Tertiary: Manual Entry
                Button {
                    onManualEntry()
                } label: {
                    Label("Enter Ingredients Manually", systemImage: "keyboard")
                }
                .secondaryButtonStyle()

                // Tertiary: Switch mode
                Button {
                    onRetry()
                } label: {
                    Label(
                        isManualSearch ? "Scan Barcode Instead" : "Try Barcode Again",
                        systemImage: isManualSearch ? "barcode.viewfinder" : "arrow.clockwise"
                    )
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

// MARK: - Conditional Button Style

/// Helper to apply primary or secondary button style conditionally
private struct ConditionalButtonStyle: ViewModifier {
    let isPrimary: Bool

    func body(content: Content) -> some View {
        if isPrimary {
            content.primaryButtonStyle()
        } else {
            content.secondaryButtonStyle()
        }
    }
}

// MARK: - Previews

#Preview("With Barcode") {
    ProductNotFoundView(
        barcode: "123456789",
        productName: nil,
        brand: nil,
        imageUrl: nil,
        onAdvancedSearch: { print("Advanced search") },
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
        onAdvancedSearch: { print("Advanced search") },
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}

#Preview("Without Barcode (Manual Search)") {
    ProductNotFoundView(
        barcode: nil,
        productName: nil,
        brand: nil,
        imageUrl: nil,
        onAdvancedSearch: nil,
        onTakePhoto: {},
        onManualEntry: {},
        onRetry: {}
    )
}
