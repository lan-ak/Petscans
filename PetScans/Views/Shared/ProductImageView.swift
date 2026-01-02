import SwiftUI

/// Reusable async product image loader with loading and error states.
/// Used in ProductScoreView and ProductNotFoundView.
struct ProductImageView: View {
    let url: URL?
    var size: CGFloat = 120
    var maxSize: CGFloat? = nil
    var showPlaceholder: Bool = true

    private var effectiveMaxSize: CGFloat {
        maxSize ?? size * 1.25
    }

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: effectiveMaxSize, maxHeight: effectiveMaxSize)
                        .cornerRadius(SpacingTokens.radiusMedium)
                case .failure:
                    if showPlaceholder {
                        placeholder
                    } else {
                        EmptyView()
                    }
                @unknown default:
                    if showPlaceholder {
                        placeholder
                    } else {
                        EmptyView()
                    }
                }
            }
        } else if showPlaceholder {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: SpacingTokens.iconXLarge * 0.67))
            .foregroundColor(ColorTokens.textSecondary)
            .frame(width: size, height: size)
            .background(ColorTokens.surfacePrimary)
            .cornerRadius(SpacingTokens.radiusMedium)
    }
}

#Preview("Loading") {
    ProductImageView(
        url: URL(string: "https://example.com/loading.jpg"),
        size: 120
    )
}

#Preview("Placeholder") {
    ProductImageView(
        url: nil,
        size: 120,
        showPlaceholder: true
    )
}
