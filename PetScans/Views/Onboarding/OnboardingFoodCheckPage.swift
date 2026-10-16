import SwiftUI

/// Onboarding step 1: pick one of three popular foods and see it scored.
///
/// This used to offer Scan, Search and See an example. In the week to
/// 2026-10-08 that step was where installs were lost. Barcodes from Canada,
/// Australia and the UK missed the catalogue, half-typed searches fired
/// `search_no_results` on every keystroke, and US users whose scans worked
/// kept scanning (one read eight bags) instead of moving on. A pick cannot
/// fail and takes one tap.
///
/// It is also what puts the paywall first. Scanning your own food now starts
/// in the Scan tab, behind `PaywallGate`, which nobody reaches before
/// `onboarding_complete` has shown its paywall.
///
/// A pick is an *example* to `OnboardingView`. It is not saved to History and
/// does not set `searched_food*`, because the aha paywall's copy ("You caught
/// N things in Max's bowl") would be a claim about a food the pet may never
/// have eaten. These users get the "What you'll see" paywall instead.
struct OnboardingFoodCheckPage: View {
    @Binding var species: Species?
    /// A `DemoFoods` row the user tapped. Not theirs.
    let onSample: (CatalogProduct) -> Void
    /// Back to the promise page.
    let onBack: () -> Void

    @State private var samples: [CatalogProduct] = []
    @State private var busy = false

    /// What the cards are for while the picker is unanswered. Matches
    /// `OnboardingView.petSpecies`, which scores against `.dog` in that case.
    private var effectiveSpecies: Species { species ?? .dog }

    /// One centred group (headline, the two questions, the footnote) with
    /// the same gap between each. The picker no longer stretches to fill the
    /// screen, which left a void between it and the foods.
    var body: some View {
        VStack(spacing: 0) {
            navBar

            Spacer(minLength: SpacingTokens.xs)

            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Let's see what's really in pet food")
                        .font(TypographyTokens.displayMedium)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("Pick a popular one. We'll score it out of 100, the same way we'll score yours.")
                        .font(TypographyTokens.body)
                        .foregroundColor(ColorTokens.textSecondary)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Who are we checking for?")
                        .font(TypographyTokens.heading3)
                        .foregroundColor(ColorTokens.textPrimary)
                    CompanionSpeciesPicker(
                        selection: $species,
                        rigHeight: CompanionSize.prominent.points
                    )
                }
                .accessibilityIdentifier("food-check-species")

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Pick a food")
                        .font(TypographyTokens.heading3)
                        .foregroundColor(ColorTokens.textPrimary)
                    VStack(spacing: SpacingTokens.xxs) {
                        ForEach(samples, id: \.gtin) { product in
                            sampleRow(product)
                        }
                    }
                    Text("You'll scan your own bag right after setup.")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, SpacingTokens.xxxs)
                }
            }
            .padding(.horizontal, SpacingTokens.screenPadding)

            Spacer(minLength: SpacingTokens.md)
            // Optical centre, as in `OnboardingView.standardChrome`: a little
            // more room below than above.
            Spacer(minLength: 0).frame(maxHeight: SpacingTokens.xxl)
        }
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
        .task(id: effectiveSpecies) {
            samples = await DemoFoods.products(for: effectiveSpecies)
        }
        .animation(AnimationTokens.springStandard, value: samples.map(\.gtin))
    }

    private func sampleRow(_ product: CatalogProduct) -> some View {
        let label = DemoFoods.label(for: product)
        return Button {
            pick(product)
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                ProductImageView(
                    url: product.imageUrl.flatMap(URL.init(string:)),
                    size: SpacingTokens.minTouchTarget,
                    maxSize: SpacingTokens.minTouchTarget
                )
                .frame(width: SpacingTokens.minTouchTarget, height: SpacingTokens.minTouchTarget)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label.brand)
                        .font(TypographyTokens.labelMedium)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text(label.detail)
                        .font(TypographyTokens.bodySmall)
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.labelSmall)
                    .foregroundColor(ColorTokens.textTertiary)
            }
            .padding(SpacingTokens.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .insetSurface(fill: ColorTokens.surfaceSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel("\(label.brand), \(label.detail)")
        .accessibilityIdentifier("food-check-sample-\(product.gtin)")
    }

    private var navBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.heading3)
                    .foregroundColor(ColorTokens.textSecondary)
                    .frame(width: SpacingTokens.minTouchTarget,
                           height: SpacingTokens.minTouchTarget)
            }
            .accessibilityLabel("Back")
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.screenPadding)
    }

    private func pick(_ product: CatalogProduct) {
        guard !busy else { return }
        busy = true
        track("path_chosen", ["path": "sample"])
        track("result_shown", ["path": "sample", "gtin": product.gtin])
        onSample(product)
        busy = false
    }

    /// One placement name carrying an `event` param, matching both
    /// `OnboardingView.logStep` and the surface's `useTrack`. A single name
    /// is far easier to keep out of campaigns than eight.
    private func track(_ event: String, _ extra: [String: Any] = [:]) {
        var params: [String: Any] = ["event": event, "source": "native"]
        params.merge(extra) { _, new in new }
        SuperwallSafe.register(placement: "onboarding_flow_event", params: params)
    }
}

/// The three foods onboarding demos against, per species.
///
/// Real catalogue rows scored by the real pipeline. An invented example that
/// scored differently from the scanner would be a lie told at the first moment
/// of the funnel. Chosen to be:
///
/// - **Sold everywhere PetScans is.** Royal Canin, Purina Pro Plan, Pedigree
///   and Whiskas are on shelves in the US, Canada, the UK, Australia and the
///   EU, so nobody is shown a brand they have never seen.
/// - **Different from each other.** Scored 2026-10-08 (cold, no pet): Pedigree
///   flags 6 ingredients, Pro Plan 1, Royal Canin none; Whiskas 2, Pro Plan
///   Indoor 1, Royal Canin Indoor none. Three results that look the same would
///   teach nothing about what a score means.
///
/// Rows missing from the bundled catalogue are dropped, and the search seeds
/// fill in after them, so a catalogue rebuild that loses a GTIN shrinks the
/// list rather than emptying the screen.
enum DemoFoods {
    struct Label {
        let brand: String
        let detail: String
    }

    private struct Entry {
        let gtin: String
        let label: Label
    }

    private static let dog: [Entry] = [
        Entry(gtin: "00023100143408", label: Label(brand: "Pedigree", detail: "Complete Nutrition, Roasted Chicken")),
        Entry(gtin: "00038100100757", label: Label(brand: "Purina Pro Plan", detail: "Sensitive Skin & Stomach, Salmon")),
        Entry(gtin: "00030111174550", label: Label(brand: "Royal Canin", detail: "Medium Adult")),
    ]

    private static let cat: [Entry] = [
        Entry(gtin: "00058496701246", label: Label(brand: "Whiskas", detail: "Meaty Selections, Chicken")),
        Entry(gtin: "00038100103949", label: Label(brand: "Purina Pro Plan", detail: "Indoor, Chicken & Rice")),
        Entry(gtin: "00030111430403", label: Label(brand: "Royal Canin", detail: "Indoor Adult")),
    ]

    /// Fallbacks, the same seeds the old "See an example" used.
    private static func seeds(for species: Species) -> [String] {
        species == .cat
            ? ["Temptations", "Friskies Party Mix", "Fancy Feast"]
            : ["Milk-Bone", "Greenies", "Pedigree"]
    }

    private static let count = 3

    static func products(for species: Species) async -> [CatalogProduct] {
        var found: [CatalogProduct] = []
        for entry in species == .cat ? cat : dog {
            if let product = await LocalCatalogStore.shared.product(gtin: entry.gtin) {
                found.append(product)
            }
        }
        guard found.count < count else { return found }

        let catalog = ProductCatalogService()
        for seed in seeds(for: species) where found.count < count {
            let hits = await catalog.search(query: seed, limit: 20)
            if let product = hits.first(where: { hit in
                hit.species == species && !found.contains { $0.gtin == hit.gtin }
            }) {
                found.append(product)
            }
        }
        return found
    }

    /// The short name for a card. Catalogue names run to a hundred characters
    /// ("Pedigree Complete Nutrition Roasted Chicken & Vegetable Flavor Dog
    /// Kibble Adult Dry Dog Food, 1…"), which no row can hold.
    static func label(for product: CatalogProduct) -> Label {
        if let entry = (dog + cat).first(where: { $0.gtin == product.gtin }) {
            return entry.label
        }
        let brand = product.brand?.trimmed ?? ""
        var detail = product.name
        if !brand.isEmpty, detail.lowercased().hasPrefix(brand.lowercased()) {
            detail = String(detail.dropFirst(brand.count)).trimmed
        }
        return Label(brand: brand.isEmpty ? product.name : brand, detail: detail)
    }
}
