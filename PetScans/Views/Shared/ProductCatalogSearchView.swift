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
    ///
    /// Optional, deliberately. It used to be a non-optional `Species` defaulting to
    /// `.dog`, which meant the species every demo was scored against was an assumption
    /// nobody had made. Unselected is now a real state, and the nil path below already
    /// handled it.
    var speciesSelection: Binding<Species?>? = nil

    /// The species actually in effect for chips and result ordering.
    private var effectiveSpecies: Species? { speciesSelection?.wrappedValue ?? species }
    /// Leading control glyph — a back chevron in onboarding, an "x" when presented
    /// as a sheet from the scanner.
    var leadingIcon: String = "chevron.left"
    let onLeading: () -> Void
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

            if let speciesSelection {
                // The screen has to ask the species question out loud. The headline
                // above only talks about food, so a user could — and did — walk past
                // the control without registering that a choice was on offer.
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Who are we checking for?")
                        .font(TypographyTokens.labelLarge)
                        .foregroundColor(ColorTokens.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CompanionSpeciesPicker(selection: speciesSelection)
                }
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.sm)
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
        // Deliberately does not raise the keyboard on arrival.
        //
        // The brand grid below was added because 17 of 21 users who reached this screen
        // left in a median of 12 seconds without typing a character — and then the view
        // auto-focused the field 350ms in, so the grid that fixed the drop-off rendered
        // underneath a keyboard. The screen was still telling people to type. Focus now
        // moves to the field when someone taps it, which is what "search as a backup"
        // means in practice.
        //
        // The scanner sheet keeps the same behaviour: a sheet that opens with a keyboard
        // already up hides its own suggestions just as effectively.
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
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
    }

    /// The backup path, and it has to *look* like one — an input, not another card.
    ///
    /// Three things were working against that. Every other white rounded rectangle on
    /// this screen is a tappable card, so a white field with grey placeholder text read
    /// as one more of them. Removing the auto-focus fixed the keyboard covering the
    /// brand grid but took away the blinking caret, which was the only unambiguous
    /// signal the row was editable. And only the `TextField` itself accepted a tap, so
    /// most of a 56pt row — the magnifier, the padding — was dead to touch.
    ///
    /// It is now recessed rather than raised and outlined rather than floating: the
    /// tiles sit *on* the page and this sits *in* it. The placeholder names the action
    /// instead of showing an example, because an example does not tell you the row is
    /// a control.
    private var searchField: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFieldFocused ? ColorTokens.brandPrimary : ColorTokens.textSecondary)
            // An explicit prompt rather than the default placeholder: SwiftUI renders
            // the default at tertiary weight, which on a tinted ground reads as a
            // disabled row rather than an empty one.
            TextField("", text: $query,
                      prompt: Text("Search any food or brand")
                        .foregroundColor(ColorTokens.textSecondary))
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
        .insetSurface(fill: ColorTokens.surfaceSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium, style: .continuous)
                .strokeBorder(isFieldFocused ? ColorTokens.brandPrimary
                                             : ColorTokens.textTertiary.opacity(0.45),
                              lineWidth: isFieldFocused ? 2 : 1.5)
        )
        // The whole row is the target, not just the glyphs inside it.
        .contentShape(Rectangle())
        .onTapGesture { isFieldFocused = true }
        .animation(AnimationTokens.springStandard, value: isFieldFocused)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Search the full catalog by name or brand")
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
            // Cards with the same treatment as the brand tiles above, not bare rows
            // with hairline dividers. Both answer the same question — *which food?* —
            // and this screen was answering it in two different visual languages
            // depending on whether the user had tapped a brand or typed into the field.
            ScrollView {
                LazyVStack(spacing: SpacingTokens.xxs) {
                    ForEach(results, id: \.gtin) { product in
                        Button {
                            isFieldFocused = false
                            onSelect(product)
                        } label: {
                            resultRow(product)
                                .raisedSurface(cornerRadius: SpacingTokens.radiusMedium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.md)
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
                    .font(TypographyTokens.labelMedium)
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundColor(ColorTokens.textTertiary)

                // Two even columns of equal-width tiles rather than an adaptive grid of
                // variable-width pills. The pills packed 3/3/2 at three different widths
                // with a ragged right edge and no shared alignment — the layout read as
                // unplaced, which is exactly the impression a first screen cannot afford.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: SpacingTokens.xxs),
                        GridItem(.flexible(), spacing: SpacingTokens.xxs)
                    ],
                    spacing: SpacingTokens.xxs
                ) {
                    ForEach(popularBrandNames, id: \.self) { brand in
                        Button {
                            query = brand
                        } label: {
                            HStack(spacing: SpacingTokens.xxxs) {
                                Text(brand)
                                    .font(TypographyTokens.labelLarge)
                                    .foregroundColor(ColorTokens.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(ColorTokens.textTertiary)
                            }
                            .padding(.horizontal, SpacingTokens.xs)
                            .padding(.vertical, SpacingTokens.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .raisedSurface(cornerRadius: SpacingTokens.radiusMedium)
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
            // Eight, matching the chosen-species lists. This case returned six, which
            // meant making species optional would have quietly handed everyone who
            // skips a shorter grid than the old `.dog` default gave them. Ordered by
            // shelf recognition and spanning both species, since we do not yet know.
            return ["Blue Buffalo", "Purina", "Hill's", "Royal Canin",
                    "Fancy Feast", "Pedigree", "Wellness", "IAMS"]
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
        // Padded for the card it now sits in, not for a full-bleed list. Carrying the
        // old screen padding inside a card stacked to 44pt a side and turned a 72pt row
        // into a 135pt one — three results on screen where there had been five.
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xs)
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
        .insetSurface(cornerRadius: SpacingTokens.radiusSmall,
                      fill: ColorTokens.surfaceSecondary)
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

            // A food genuinely missing from the catalog would otherwise leave the user on
            // a screen whose only forward action is retyping the thing that just failed.
            // This used to be a "Skip for now" that jumped past the demo entirely; with no
            // skip in onboarding any more, the recovery has to keep them inside the flow
            // rather than around it — so it clears the query and puts the brand grid back.
            Button("Browse popular brands") {
                query = ""
                isFieldFocused = false
            }
            .font(TypographyTokens.body)
            .foregroundColor(ColorTokens.brandPrimary)
            .padding(.top, SpacingTokens.sm)
            .accessibilityIdentifier("catalog-empty-browse")

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
