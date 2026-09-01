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
    /// The pet's species, when the caller already knows it (the scanner reads it off the
    /// roster). Drives the popular-brand chips and pushes that species to the top.
    var species: Species? = nil
    /// Onboarding passes a binding instead: the flow now runs the demo before asking
    /// anything, so this screen is where species gets chosen. One tap, no keyboard — it
    /// costs far less than a form page and it keeps the demo from showing a dog owner a
    /// page of cat food that then gets scored as cat food.
    var speciesPicker: Binding<Species>? = nil

    /// The species actually in effect for chips and result ordering.
    private var effectiveSpecies: Species? { speciesPicker?.wrappedValue ?? species }
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

            if let speciesPicker {
                Picker("Species", selection: speciesPicker) {
                    ForEach(Species.allCases) { species in
                        Text(species.displayName).tag(species)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.md)
                .accessibilityIdentifier("catalog-species-picker")
            }

            searchField
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.md)

            resultsList
        }
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
        // Keyed on the species too: flipping Dog/Cat has to re-rank the results that are
        // already on screen, not just the next query.
        .task(id: "\(query)|\(effectiveSpecies?.rawValue ?? "")") { await runSearch() }
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
        } else if query.trimmed.count < 2 {
            popularBrands
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

    /// Shown instead of a blank page before the user has typed anything.
    ///
    /// This screen used to render an empty scroll view under the search field, and it was
    /// the single largest measured drop in the funnel: 17 of 21 users who reached it left
    /// in a median of 12 seconds without typing a character. Recalling and spelling a brand
    /// cold is real work; tapping one is not.
    private var popularBrands: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Popular brands")
                    .font(TypographyTokens.labelLarge)
                    .foregroundColor(ColorTokens.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: SpacingTokens.xxs) {
                    ForEach(popularBrandNames, id: \.self) { brand in
                        Button {
                            query = brand
                        } label: {
                            Text(brand)
                                .lineLimit(1)
                                .chipStyle()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("catalog-brand-chip")
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenPadding)
            .padding(.top, SpacingTokens.md)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// Counted off the bundled catalog by group, so every chip returns a full page of
    /// results (the smallest here, "IAMS" for a cat, still matches 108 groups).
    ///
    /// Kept to the recognisable brand token rather than the full line name: a chip has one
    /// line to work with, and "Purina Pro Plan" truncates to "Purina Pro…" at this width
    /// while matching fewer products than plain "Purina" does. Apostrophes are safe —
    /// `foldForSearch` strips them, so "Hill's" matches the folded `search_text`.
    private var popularBrandNames: [String] {
        switch effectiveSpecies {
        case .dog:
            return ["Blue Buffalo", "Purina", "Pedigree", "Hill's",
                    "Royal Canin", "Merrick", "Wellness", "IAMS"]
        case .cat:
            return ["Fancy Feast", "Friskies", "Blue Buffalo", "Temptations",
                    "Purina", "Hill's", "Wellness", "Royal Canin"]
        case .none:
            return ["Blue Buffalo", "Purina", "Hill's",
                    "Royal Canin", "Wellness", "IAMS"]
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

            // A food genuinely missing from the catalog otherwise leaves the user on a
            // screen with nothing to press but the de-emphasised corner "Skip". Only
            // offered where a skip handler exists — the scanner presents this same view
            // as a sheet and already has its own dismiss.
            //
            // The label says what the button now does. It used to read "Scan the label
            // instead", which was true when skipping dropped the user into the scanner;
            // under the demo-first flow the same handler moves them on to pet setup, and
            // the scanner is several screens away.
            if let onSkip {
                Button("Skip for now", action: onSkip)
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
            // Clearing the field mid-search cancels the in-flight task, which never got to
            // lower this flag — the view then sat on a spinner forever with the popular-
            // brand grid hidden behind it.
            isSearching = false
            return
        }
        // Raised before the debounce, not after. Tapping a brand chip fills the field in
        // one go, and with the flag still false the view fell through to the results branch
        // and rendered an empty list for 220 ms — a blank screen produced by the very
        // control that exists to stop the screen being blank.
        isSearching = true

        // Debounce so we don't query on every keystroke.
        try? await Task.sleep(for: .milliseconds(220))
        if Task.isCancelled { return }
        // Over-fetch when the species is known so the re-rank has something to promote.
        // A brand often carries more of the other species than this one — "Purina Pro
        // Plan" is 310 cat groups against 238 dog — so a 30-row window can legitimately
        // come back entirely the wrong animal, leaving nothing to reorder.
        let found = await catalog.search(query: trimmed, limit: effectiveSpecies == nil ? 30 : 60)
        if Task.isCancelled { return }
        results = Array(speciesFirst(found).prefix(30))
        isSearching = false
        hasSearched = true
    }

    /// Puts the owner's own species first, preserving relevance order within each half.
    ///
    /// Ordering rather than filtering, deliberately: a dog owner searching "Purina Pro
    /// Plan" was getting a page of cat food that then got *scored as cat food*, but a
    /// hard filter would hide a genuinely correct result whenever the catalog has the
    /// species wrong. This keeps the fallback and still fixes the common case.
    private func speciesFirst(_ products: [CatalogProduct]) -> [CatalogProduct] {
        guard let species = effectiveSpecies else { return products }
        return products.filter { $0.species == species } + products.filter { $0.species != species }
    }
}
