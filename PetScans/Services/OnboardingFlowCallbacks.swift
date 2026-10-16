import Foundation
import SuperwallKit
import SwiftUI
import UIKit

/// The custom-callback handler for the onboarding surface.
///
/// This is nothing more than the block handed to
/// `PaywallPresentationHandler.onCustomCallback` — one `switch` over
/// `CustomCallback.name`, returning `CustomCallbackResult`. There is no
/// second transport and no machinery of its own.
///
/// The surface (`superwall/paywalls/onboarding-flow`) renders all six steps;
/// everything
/// it cannot know on its own is a callback rather than a `fetch` for one
/// reason: the product
/// catalogue is `catalog.sqlite` bundled in the app and read through GRDB
/// (`LocalCatalogStore`). There is no endpoint to call, so search, scanning
/// and scoring have to run on device and hand their answers back.
///
/// Wired at the single call site in `OnboardingView.presentFlowIfNeeded`.
@MainActor
enum OnboardingFlowCallbacks {
    /// What the surface reported when it finished. Everything onboarding used
    /// to hold in `@State` now arrives here in one go.
    struct Outcome {
        enum Kind: String {
            /// Reached the end of the flow.
            case completed
            /// Left early. Whatever was gathered before that still arrives.
            case skipped
        }
        let kind: Kind
        let species: Species?
        let petName: String
        let allergens: Set<String>
        let groups: Set<AvoidanceGroup>
        /// Empty for a skip, and for the example path — an example food is not
        /// theirs, so it must not be saved to History or personalised against.
        let gtin: String
        let score: Double
        let verdict: RatingLabel?
        let flagCount: Int
        /// True when the score above is the re-score against the finished
        /// profile rather than the cold demo verdict.
        let isPersonalised: Bool

        var createdPet: Bool { !petName.isEmpty }
    }

    /// Set by the `onboardingDone` callback, drained by `OnboardingView`.
    ///
    /// A stored property rather than a value passed through the dismiss
    /// handler: `onCustomCallback` and `onDismiss` are separate closures on
    /// `PaywallPresentationHandler` with no shared context, and the callback
    /// always lands first — the surface awaits it before calling `close()`.
    private(set) static var lastOutcome: Outcome?

    static func takeOutcome() -> Outcome? {
        defer { lastOutcome = nil }
        return lastOutcome
    }

    static func reset() {
        lastOutcome = nil
    }

    // MARK: - Dispatch

    /// The one entry point handed to `PaywallPresentationHandler.onCustomCallback`.
    ///
    /// Unknown names resolve `.failure` rather than trapping: a surface version
    /// newer than the installed binary can ask for something this build has
    /// never heard of, and every bridge call on the JS side already treats a
    /// failure as an ordinary outcome.
    static func handle(_ callback: CustomCallback) async -> CustomCallbackResult {
        // The surface runs before `onboarding_complete`, so its scan and search
        // would put the user's own food on screen before any paywall had been
        // seen. Refused until `PaywallGate` opens. The surface treats a failure
        // as an ordinary outcome, but it still offers both paths, so it needs a
        // `DemoFoods` step before campaign 111017 is switched back on.
        if ["searchCatalog", "scanBarcode"].contains(callback.name), !PaywallGate.isOpen {
            return .failure()
        }
        switch callback.name {
        case "searchCatalog": return await searchCatalog(callback.variables)
        case "scanBarcode":   return await scanBarcode(callback.variables)
        case "scoreProduct":  return await scoreProduct(callback.variables)
        case "exampleFood":   return await exampleFood(callback.variables)
        case "rescoreForPet": return await rescoreForPet(callback.variables)
        case "onboardingDone": return recordOutcome(callback.variables)
        default:              return .failure()
        }
    }

    // MARK: - Callbacks

    /// Mirrors `ProductCatalogSearchView.runSearch`, including the over-fetch
    /// and species re-rank — a brand often carries more of the other species
    /// than this one, so a 30-row window can come back entirely the wrong
    /// animal with nothing left to reorder.
    private static func searchCatalog(_ variables: [String: Any]?) async -> CustomCallbackResult {
        let query = string(variables, "query").trimmed
        guard query.count >= 2 else { return .success(data: ["rows": []]) }

        let species = species(variables)
        let found = await ProductCatalogService().search(
            query: query,
            limit: species == nil ? 30 : 60
        )
        let ordered = speciesFirst(found, species: species).prefix(30)

        return .success(data: ["rows": ordered.map(row)])
    }

    /// Presents the native scanner over the surface and waits for a read.
    ///
    /// `found: false` with the barcode attached is a real answer, not an
    /// error: the camera worked and the catalogue simply doesn't carry that
    /// product. That distinction is the whole point of instrumenting this
    /// step — if coverage is the problem, scanning fails exactly where typing
    /// does, and we need to be able to tell.
    private static func scanBarcode(_ variables: [String: Any]?) async -> CustomCallbackResult {
        guard let raw = await FoodCheckScannerPresenter.presentAndScan() else {
            // Dismissed without a read. The surface stays where it is.
            return .failure()
        }

        let resolution = await ProductCatalogService().resolve(rawBarcode: raw)
        switch resolution {
        case .found(let product):
            let scored = await score(product, species: species(variables) ?? product.species)
            return .success(data: ["found": true, "barcode": raw, "food": scored])
        case .unknown(let gtin):
            return .success(data: ["found": false, "barcode": gtin])
        case .notAProductBarcode:
            return .success(data: ["found": false, "barcode": raw])
        }
    }

    private static func scoreProduct(_ variables: [String: Any]?) async -> CustomCallbackResult {
        let gtin = string(variables, "gtin")
        guard !gtin.isEmpty,
              let product = await LocalCatalogStore.shared.product(gtin: gtin)
        else { return .failure() }

        let scored = await score(product, species: species(variables) ?? product.species)
        return .success(data: ["food": scored])
    }

    /// The zero-input path: a real, scored row from the bundled catalogue.
    ///
    /// Deliberately not a hardcoded fixture. It runs the same scorer every
    /// other result uses, so the number, the verdict and the flags are the
    /// app's own — an invented example that scored differently from the real
    /// pipeline would be a lie told at the first moment of the funnel.
    private static func exampleFood(_ variables: [String: Any]?) async -> CustomCallbackResult {
        let species = species(variables) ?? .dog
        // Treats, deliberately, and the most recognised brand per species —
        // Milk-Bone is dog-only (147 rows, all `category: treat`), so a cat
        // owner gets Temptations rather than a product for the wrong animal.
        //
        // A treat rather than a kibble because of what the scores look like:
        // the median food in the catalogue scores 93, so a bag of food makes
        // a dull example that answers "is this fine?" with "yes" and gives
        // the user no reason to continue. Treats are where the colours,
        // sugars and by-products actually are.
        //
        // Each list falls through if the bundled catalogue misses the first.
        let seeds = species == .cat
            ? ["Temptations", "Friskies Party Mix", "Fancy Feast"]
            : ["Milk-Bone", "Greenies", "Pedigree"]

        let catalog = ProductCatalogService()
        for seed in seeds {
            let hits = await catalog.search(query: seed, limit: 20)
            guard let product = speciesFirst(hits, species: species).first else { continue }
            let scored = await score(product, species: species)
            return .success(data: ["food": scored])
        }
        return .failure()
    }

    /// Re-scores the chosen food against the finished profile.
    ///
    /// The same `OnboardingFoodScorer` call the native personalised screen
    /// makes, with the allergens and groups the user just picked — so the
    /// before/after the surface shows is the app's own arithmetic, and the
    /// verdict matches what every scan after onboarding will produce.
    private static func rescoreForPet(_ variables: [String: Any]?) async -> CustomCallbackResult {
        let gtin = string(variables, "gtin")
        guard !gtin.isEmpty,
              let product = await LocalCatalogStore.shared.product(gtin: gtin)
        else { return .failure() }

        let name = string(variables, "petName").trimmed
        let scored = await score(
            product,
            species: species(variables) ?? product.species,
            petName: name.isEmpty ? nil : name,
            allergens: idSet(variables, "allergens"),
            groups: groupSet(variables)
        )
        return .success(data: ["food": scored])
    }

    private static func recordOutcome(_ variables: [String: Any]?) -> CustomCallbackResult {
        let kind = Outcome.Kind(rawValue: string(variables, "outcome")) ?? .skipped
        lastOutcome = Outcome(
            kind: kind,
            species: species(variables),
            petName: string(variables, "petName").trimmed,
            allergens: idSet(variables, "allergens"),
            groups: groupSet(variables),
            gtin: string(variables, "gtin"),
            score: double(variables, "score"),
            verdict: RatingLabel(rawValue: string(variables, "verdict")),
            flagCount: Int(double(variables, "flag_count")),
            isPersonalised: string(variables, "personalised") == "true"
        )
        return .success()
    }

    // MARK: - Scoring

    /// Runs `OnboardingFoodScorer` and flattens it for the webview.
    ///
    /// Defaults score with no allergens and no groups — the cold "general
    /// verdict" the demo page shows, before anything is known about the pet.
    /// `rescoreForPet` passes the real profile for step 5.
    private static func score(
        _ product: CatalogProduct,
        species: Species,
        petName: String? = nil,
        allergens: Set<String> = [],
        groups: Set<AvoidanceGroup> = []
    ) async -> [String: Any] {
        let result = await OnboardingFoodScorer.score(
            product: product,
            petName: petName,
            allergens: allergens,
            groups: groups,
            species: species
        )
        let breakdown = result.breakdown

        return [
            "gtin": product.gtin,
            "name": product.name,
            "brand": product.brand?.trimmed ?? "",
            "score": Int(breakdown.total.rounded()),
            "verdict": breakdown.ratingLabel.rawValue,
            // The payoff screen is built around the verdict and the per-axis
            // bars, not a single number — `OnboardingFoodResultView` renders
            // `ScoreExplanationCard` for each. Suitability is the *allergen*
            // axis and means nothing before there is a pet, so it crosses as
            // -1 on the cold demo and the surface hides it.
            "safety": Int(breakdown.safety.rounded()),
            "processing": breakdown.processing.map { Int($0.rounded()) } ?? -1,
            "suitability": allergens.isEmpty && groups.isEmpty
                ? -1
                : Int(breakdown.suitability.rounded()),
            "flags": breakdown.flags.map { flag in
                [
                    "label": flag.title,
                    "severity": severityToken(flag.severity),
                    // One row per flag, so the count the surface renders is
                    // always 1 here. Kept as a field because the surface's
                    // clean/flagged fork reads it, and a future grouped
                    // breakdown would fill it in without a JS change.
                    "count": 1
                ]
            }
        ]
    }

    /// `RuleSeverity` -> the four tokens the surface styles against. `.warn`
    /// is spelled `warning` on the JS side to match the CSS custom property
    /// names lifted from `ColorTokens`.
    private static func severityToken(_ severity: RuleSeverity) -> String {
        switch severity {
        case .critical, .high: return "high"
        case .warn: return "warning"
        case .info: return "info"
        }
    }

    // MARK: - Helpers

    private static func row(_ product: CatalogProduct) -> [String: Any] {
        [
            "gtin": product.gtin,
            "name": product.name,
            "brand": product.brand?.trimmed ?? "",
            "variants": product.variantCount
        ]
    }

    /// Ordering rather than filtering, matching `ProductCatalogSearchView`: a
    /// hard filter would hide a genuinely correct result whenever the catalogue
    /// has the species wrong.
    private static func speciesFirst(_ products: [CatalogProduct], species: Species?) -> [CatalogProduct] {
        guard let species else { return products }
        return products.filter { $0.species == species } + products.filter { $0.species != species }
    }

    /// Values cross the bridge as strings, so an empty species means "not
    /// chosen" — which stays a real state here exactly as it does in the
    /// native picker.
    private static func species(_ variables: [String: Any]?) -> Species? {
        Species(rawValue: string(variables, "species"))
    }

    /// Callback variables cannot carry arrays, so the surface sends these
    /// comma-joined and they are split back here.
    private static func idSet(_ variables: [String: Any]?, _ key: String) -> Set<String> {
        Set(
            string(variables, key)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    /// Unknown group ids are dropped rather than failing the whole hand-off:
    /// a surface newer than the binary can name a group this build predates.
    private static func groupSet(_ variables: [String: Any]?) -> Set<AvoidanceGroup> {
        Set(idSet(variables, "groups").compactMap(AvoidanceGroup.init(rawValue:)))
    }

    private static func string(_ variables: [String: Any]?, _ key: String) -> String {
        guard let value = variables?[key] else { return "" }
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return ""
    }

    private static func double(_ variables: [String: Any]?, _ key: String) -> Double {
        guard let value = variables?[key] else { return 0 }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) ?? 0 }
        return 0
    }
}
