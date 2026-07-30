import SwiftUI

/// Free-text catalog search over the bundled product database (offline). Shared by
/// the onboarding "check your food" moment and the Identify Product (scanner) flow
/// so the search experience is identical everywhere. The caller decides what to do
/// with the chosen product via `onSelect`.
struct ProductCatalogSearchView: View {
    var title: String = "Find your pet's food"
    /// The onboarding flow uses the larger `displayMedium` so the headline stays
    /// the same size as the pages around it; the scanner sheet keeps the default.
    var titleFont: Font = TypographyTokens.displaySmall
    var subtitle: String = "Search the brand or product name to see what's really inside."
    /// Leading control glyph — a back chevron in onboarding, an "x" when presented
    /// as a sheet from the scanner.
    var leadingIcon: String = "chevron.left"
    let onLeading: () -> Void
    /// Optional trailing "Skip" (onboarding only).
    var onSkip: (() -> Void)? = nil
    let onSelect: (CatalogProduct) -> Void

    @State private var query = ""
    @State private var results: [CatalogProduct] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @FocusState private var isFieldFocused: Bool

    private let catalog = ProductCatalogService()

    var body: some View {
        VStack(spacing: 0) {
            topBar

            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(ColorTokens.textPrimary)
                Text(subtitle)
                    .font(TypographyTokens.body)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpacingTokens.screenPadding)
            .padding(.top, SpacingTokens.sm)

            searchField
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.md)

            resultsList
        }
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
        .task(id: query) { await runSearch() }
        .onAppear {
            // Small delay so focus lands after the presentation transition settles.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                isFieldFocused = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onLeading) {
                Image(systemName: leadingIcon)
                    .font(TypographyTokens.heading3)
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: SpacingTokens.minTouchTarget, height: SpacingTokens.minTouchTarget)
            }
            .accessibilityLabel(leadingIcon == "xmark" ? "Close" : "Back")
            Spacer()
            if let onSkip {
                // Quiet, matching the demoted Skip on the result page — the
                // search + payoff should feel like the main path, not a fork.
                Button("Skip", action: onSkip)
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textTertiary)
                    .accessibilityIdentifier("catalog-search-skip")
            }
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
    }

    private var searchField: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorTokens.textTertiary)
            TextField("e.g. Blue Buffalo salmon", text: $query)
                .font(TypographyTokens.bodyLarge)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($isFieldFocused)
                .submitLabel(.search)
                .accessibilityIdentifier("catalog-search-field")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorTokens.textTertiary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding()
        .background(ColorTokens.surfacePrimary)
        .cornerRadius(SpacingTokens.radiusMedium)
    }

    @ViewBuilder
    private var resultsList: some View {
        if isSearching && results.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if hasSearched && results.isEmpty && query.trimmed.count >= 2 {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results, id: \.gtin) { product in
                        Button {
                            isFieldFocused = false
                            onSelect(product)
                        } label: {
                            resultRow(product)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, SpacingTokens.screenPadding)
                    }
                }
                .padding(.top, SpacingTokens.sm)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func resultRow(_ product: CatalogProduct) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            thumbnail(product.imageUrl)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(TypographyTokens.body)
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                // One row per recipe, so say when it stands for more than one pack size —
                // otherwise the sizes the catalog does carry look missing.
                let brand = product.brand.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                HStack(spacing: 4) {
                    if !brand.isEmpty {
                        Text(brand)
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    if product.variantCount > 1 {
                        Text(brand.isEmpty ? "\(product.variantCount) sizes" : "· \(product.variantCount) sizes")
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textTertiary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textTertiary)
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
        .padding(.vertical, SpacingTokens.sm)
        .contentShape(Rectangle())
    }

    private func thumbnail(_ urlString: String?) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 48, height: 48)
        .background(ColorTokens.surfaceSecondary)
        .cornerRadius(SpacingTokens.radiusSmall)
    }

    private var placeholderIcon: some View {
        Image(systemName: "bag.fill")
            .foregroundColor(ColorTokens.textTertiary)
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.textTertiary)
            Text("No matches for \"\(query.trimmed)\"")
                .font(TypographyTokens.body)
                .foregroundColor(ColorTokens.textPrimary)
            Text("Try just the brand and protein, e.g. \"purina chicken\".")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xxl)

            // A food genuinely missing from the catalog otherwise ends onboarding on a
            // screen with nothing to press but the de-emphasised corner "Skip". Only
            // offered where a skip handler exists — the scanner presents this same view
            // as a sheet and already has its own dismiss.
            if let onSkip {
                Button("Scan the label instead", action: onSkip)
                    .font(TypographyTokens.body)
                    .foregroundColor(ColorTokens.brandPrimary)
                    .padding(.top, SpacingTokens.sm)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func runSearch() async {
        let trimmed = query.trimmed
        guard trimmed.count >= 2 else {
            results = []
            hasSearched = false
            return
        }
        // Debounce so we don't query on every keystroke.
        try? await Task.sleep(for: .milliseconds(220))
        if Task.isCancelled { return }

        isSearching = true
        let found = await catalog.search(query: trimmed, limit: 30)
        if Task.isCancelled { return }
        results = found
        isSearching = false
        hasSearched = true
    }
}
