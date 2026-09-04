import Foundation
import SwiftUI
import SwiftData
import Combine
import UIKit

/// ViewModel for the scanner workflow, managing state and business logic
@MainActor
final class ScannerViewModel: ObservableObject {
    // MARK: - Types

    enum Step: Equatable {
        case scanning
        case error
        case productNotFound
        case selectOptions
        case results
        // Product photo identification flow
        case productPhotoCapture
        case productIdentification
        case confirmProduct
        case productSearching

        /// Stable string for Superwall params. Spelled out rather than derived
        /// from the case name so a Swift-side rename can't silently rewrite the
        /// value a dashboard audience is keyed on.
        var superwallName: String {
            switch self {
            case .scanning: return "scanning"
            case .error: return "error"
            case .productNotFound: return "product_not_found"
            case .selectOptions: return "select_options"
            case .results: return "results"
            case .productPhotoCapture: return "product_photo_capture"
            case .productIdentification: return "product_identification"
            case .confirmProduct: return "confirm_product"
            case .productSearching: return "product_searching"
            }
        }
    }

    /// Why the "not found" screen is being shown, so it can tailor its copy.
    enum NotFoundReason {
        /// The scanned barcode isn't in the catalog yet.
        case notInCatalog
        /// A photo was taken but the AI couldn't recognise the product.
        case notRecognized
    }

    enum ScanError: LocalizedError {
        case networkError(underlying: Error)
        case productNotFound
        case saveFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .networkError:
                return "Network Error"
            case .productNotFound:
                return "Product Not Found"
            case .saveFailed:
                return "Save Failed"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .networkError:
                return "Please check your internet connection and try again."
            case .productNotFound:
                return "This product isn't in our database yet. Snap a photo and we'll find it."
            case .saveFailed:
                return "Failed to save the scan. Please try again."
            }
        }

        var canRetry: Bool {
            switch self {
            case .networkError:
                return true
            case .productNotFound, .saveFailed:
                return false
            }
        }
    }

    // MARK: - Published Properties

    // Barcode scanning is the default entry point (Yuka/Olive style). The photo/Vision
    // flow — previously the default and the slowest, most expensive path — is now a
    // fallback reached only when there's no readable barcode.
    @Published var step: Step = .scanning
    @Published var barcode: String?
    @Published var productName: String = ""
    @Published var brand: String?
    @Published var imageUrl: String?
    @Published var ingredientsText: String = ""
    @Published var selectedSpecies: Species = .dog
    @Published var selectedCategory: Category = .food
    @Published var selectedPet: Pet?
    @Published var matchedIngredients: [MatchedIngredient] = []
    @Published var scoreBreakdown: ScoreBreakdown?
    @Published var currentError: ScanError?
    @Published var notFoundReason: NotFoundReason = .notInCatalog
    @Published var scoreSource: ScoreSource = .databaseVerified
    @Published var productImage: UIImage?
    @Published var productIdentification: ProductIdentification?
    /// In-flight guard for `performAnalysis` so a double-tap can't run it twice.
    @Published var isAnalyzing: Bool = false

    /// Vision confidence below this routes through an explicit "is this your
    /// product?" confirmation before we spend a scrape and produce a safety score.
    private let confidenceConfirmThreshold: Double = 0.7

    // MARK: - Dependencies

    private let ingredientMatcher: IngredientMatcher
    private let scoreCalculator: ScoreCalculator
    private let productVisionService: ProductVisionServiceProtocol
    private let catalogService: ProductCatalogService

    /// Guards against a barcode held in frame re-triggering a resolve on every camera
    /// frame. Cleared on reset and when a read is ignored as a non-product code.
    private var lastHandledBarcode: String?

    // MARK: - Haptic Feedback

    private let successFeedback = UINotificationFeedbackGenerator()
    private let errorFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init(
        ingredientMatcher: IngredientMatcher = IngredientMatcher(),
        scoreCalculator: ScoreCalculator = ScoreCalculator(),
        productVisionService: ProductVisionServiceProtocol = ProductVisionService(),
        catalogService: ProductCatalogService = ProductCatalogService()
    ) {
        self.ingredientMatcher = ingredientMatcher
        self.scoreCalculator = scoreCalculator
        self.productVisionService = productVisionService
        self.catalogService = catalogService
        successFeedback.prepare()
        errorFeedback.prepare()
    }

    // MARK: - Actions

    /// The instant path. Resolve the barcode against the on-device catalog and, on a hit,
    /// score locally and jump straight to results — no product-identification round trip,
    /// no species/category picker, no "Analyze" tap. A miss surfaces the "not found" screen,
    /// whose single action leads into the AI photo search. Only a code that isn't a retail
    /// product barcode at all is silently ignored so the scanner keeps looking.
    func handleBarcodeScan(_ code: String, pets: [Pet] = [], modelContext: ModelContext? = nil) {
        guard code != lastHandledBarcode else { return }
        lastHandledBarcode = code
        currentError = nil

        Task {
            let started = Date()
            let resolution = await catalogService.resolve(rawBarcode: code)

            switch resolution {
            case .notAProductBarcode:
                // Not something we can act on (QR, coupon, in-store code, bad check digit).
                // Re-arm so a subsequent good read of the same physical label still fires.
                lastHandledBarcode = nil

            case .found(let product):
                barcode = product.gtin
                apply(product, pets: pets)
                await computeScore()
                logResolved(source: "catalog", started: started, gtin: product.gtin)
                showResults()

            case .unknown(let gtin):
                barcode = gtin
                if let context = modelContext, let cached = cachedScan(gtin: gtin, in: context) {
                    apply(cached, pets: pets)
                    await computeScore()
                    logResolved(source: "cache", started: started, gtin: gtin)
                    showResults()
                } else {
                    // New product: surface a "not found" screen that names the barcode and
                    // explains why, so the jump to the photo search isn't a silent, confusing
                    // switch. Its primary action leads into the AI photo search.
                    logResolved(source: "miss", started: started, gtin: gtin)
                    notFoundReason = .notInCatalog
                    errorFeedback.notificationOccurred(.warning)
                    errorFeedback.prepare()
                    step = .productNotFound
                }
            }
        }
    }

    /// Score a product chosen from catalog text search. Routes through the same
    /// path as a barcode hit so it lands on the normal results screen (and can be
    /// saved to history from there), keeping the search and scan experiences identical.
    func selectCatalogProduct(_ product: CatalogProduct, pets: [Pet] = []) {
        currentError = nil
        lastHandledBarcode = nil
        Task {
            let started = Date()
            barcode = product.gtin
            apply(product, pets: pets)
            await computeScore()
            logResolved(source: "search", started: started, gtin: product.gtin)
            showResults()
        }
    }

    /// Populate product fields from a catalog hit, defaulting to a pet of the matching
    /// species so the score is personalised without asking.
    private func apply(_ product: CatalogProduct, pets: [Pet]) {
        productName = product.name
        brand = product.brand
        imageUrl = product.imageUrl
        ingredientsText = product.ingredients
        selectedSpecies = product.species
        selectedCategory = product.category
        scoreSource = .databaseVerified
        selectedPet = pets.first { $0.speciesEnum == product.species } ?? pets.first
    }

    /// Re-hydrate from a product the user already scored once (via OCR or web), so a repeat
    /// scan of a not-yet-catalogued item is still instant.
    private func apply(_ scan: Scan, pets: [Pet]) {
        productName = scan.productName ?? ""
        brand = scan.brand
        imageUrl = scan.imageUrl
        ingredientsText = scan.rawIngredientText
        selectedSpecies = scan.speciesEnum
        selectedCategory = scan.categoryEnum
        scoreSource = .databaseVerified
        selectedPet = pets.first { $0.speciesEnum == scan.speciesEnum } ?? pets.first
    }

    /// Most recent prior scan for this canonical barcode, if any.
    private func cachedScan(gtin: String, in context: ModelContext) -> Scan? {
        var descriptor = FetchDescriptor<Scan>(
            predicate: #Predicate { $0.barcode == gtin },
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// A hard camera/scanner failure surfaced by `BarcodeScannerView`.
    func handleScannerError(_ message: String) {
        failToError(NSError(domain: "Scanner", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
    }

    /// Return to a clean scanner. Full `reset()` so no product/identification state
    /// (name, brand, image, scoreSource…) leaks from an abandoned flow into the next.
    func restartScanning() {
        reset()
    }

    /// Retry after an error — same clean return to the scanner.
    func retryLastScan() {
        reset()
    }

    // MARK: - Product Photo Identification

    func goToProductPhotoCapture() {
        step = .productPhotoCapture
    }

    func handleProductPhotoCapture(_ image: UIImage) {
        productImage = image
        step = .productIdentification

        Task {
            do {
                let identification = try await productVisionService.identifyProduct(from: image)
                // The user can Cancel the identify wait; if they navigated away while the
                // request was in flight, drop the result rather than yanking them back.
                guard step == .productIdentification else { return }
                productIdentification = identification

                guard identification.searchQuery != nil else {
                    throw ProductVisionError.noProductFound
                }

                // A shaky, low-confidence guess would otherwise flow silently into a
                // scrape and a pet-specific safety score. Pause and let the user confirm
                // before we commit to it.
                if identification.confidence < confidenceConfirmThreshold {
                    step = .confirmProduct
                } else {
                    step = .productSearching
                }
            } catch {
                guard step == .productIdentification else { return }
                handleProductIdentificationError(error)
            }
        }
    }

    /// User confirmed a low-confidence identification is correct; proceed to the search.
    func confirmIdentification() {
        step = .productSearching
    }

    private func handleProductIdentificationError(_ error: Error) {
        if let visionError = error as? ProductVisionError {
            switch visionError {
            case .noProductFound:
                // The photo didn't yield a usable product — send the user back to the
                // not-found screen, this time explaining the photo wasn't recognised.
                failToNotRecognized()
            case .networkError, .rateLimited:
                failToError(error)
            default:
                failToNotRecognized()
            }
        } else {
            failToError(error)
        }
    }

    /// Soft failure: product wasn't recognised. Warning haptic (not a hard error).
    private func failToNotRecognized() {
        currentError = .productNotFound
        notFoundReason = .notRecognized
        errorFeedback.notificationOccurred(.warning)
        errorFeedback.prepare()
        step = .productNotFound
    }

    /// Hard failure: something broke (network/rate limit/unexpected). Error haptic.
    private func failToError(_ error: Error) {
        currentError = .networkError(underlying: error)
        errorFeedback.notificationOccurred(.error)
        errorFeedback.prepare()
        step = .error
    }

    func handleProductSearchComplete(ingredientsText: String, productName: String?, brand: String?, matched: [MatchedIngredient], imageUrl: URL?) {
        self.ingredientsText = ingredientsText
        if let productName = productName, !productName.isEmpty {
            self.productName = productName
        }
        if let brand = brand, !brand.isEmpty {
            self.brand = brand
        }
        if let imageUrl = imageUrl {
            self.imageUrl = imageUrl.absoluteString
        }
        self.matchedIngredients = matched
        self.scoreSource = .webScraped
        // Pre-fill the species the vision model already identified, so the picker
        // defaults correctly (e.g. Cat) instead of always starting at Dog.
        if let visionSpecies = productIdentification?.species?.lowercased(),
           let species = Species(rawValue: visionSpecies) {
            selectedSpecies = species
        }
        step = .selectOptions
    }

    func performAnalysis() {
        // Guard against a double-tap on "Analyze": a second run would double-count
        // the analysis, re-register the paywall placement, and re-transition.
        guard !isAnalyzing else { return }
        isAnalyzing = true
        Task {
            let started = Date()
            await computeScore()
            // Non-catalog resolutions land here (OCR, manual, web). Tag the source so the
            // telemetry covers every path, not just instant hits.
            let source: String
            switch scoreSource {
            case .ocrEstimated: source = "ocr"
            case .webScraped: source = "web"
            case .manualEntry: source = "manual"
            case .databaseVerified: source = "catalog"
            }
            logResolved(source: source, started: started, gtin: barcode)
            showResults()
            isAnalyzing = false
        }
    }

    /// The single "results are ready" moment. Every path — instant catalog hit, cached
    /// repeat scan, OCR, manual, web — lands here so the confirmation feels identical
    /// regardless of how the product was resolved.
    private func showResults() {
        successFeedback.notificationOccurred(.success)
        successFeedback.prepare()
        step = .results
    }

    /// Match ingredients and compute the score for the current product against the current
    /// pet, then fire the activation signals. Sets `matchedIngredients` and
    /// `scoreBreakdown` but not `step`, so both the picker flow and the instant catalog
    /// path can call it and decide navigation themselves. Recomputing after a pet change is
    /// just another call.
    func computeScore() async {
        let petAllergens = selectedPet?.allergens ?? []
        let species = selectedPet?.speciesEnum ?? selectedSpecies

        matchedIngredients = await ingredientMatcher.match(rawIngredients: ingredientsText)

        scoreBreakdown = await scoreCalculator.calculate(
            species: species,
            category: selectedCategory,
            matched: matchedIngredients,
            petAllergens: petAllergens,
            petName: selectedPet?.name,
            scoreSource: scoreSource,
            ocrConfidence: nil
        )

        // Update analysis count for Superwall targeting
        let analysisCount = UserDefaults.standard.integer(forKey: "totalAnalysisCount") + 1
        UserDefaults.standard.set(analysisCount, forKey: "totalAnalysisCount")

        SuperwallSafe.setUserAttributes(["analysis_count": analysisCount])

        // Paywall copy names the pet this scan was run for; nil falls back
        // to the roster primary rather than leaving a stale name.
        SuperwallUserAttributes.setFocusedPet(selectedPet)

        // Armed before the register call: `analysis_complete` may present a
        // paywall, and ReviewPrompt re-checks the paywall cooldown when the
        // result screen drains this, so a paywall here cancels the ask.
        if let scoreBreakdown {
            ReviewPrompt.recordScanCompleted(
                breakdown: scoreBreakdown,
                analysisCount: analysisCount
            )
        }

        SuperwallSafe.register(placement: "analysis_complete")

        // Meta ad-campaign signal: the app's core activation moment. No-ops
        // unless Meta credentials are configured (see AttributionService).
        AttributionService.logScanCompleted()

        requestTrackingAuthorizationIfNeeded()
    }

    /// Asks for tracking permission once the user has seen a real result.
    ///
    /// This used to fire 500ms after the tab bar appeared, which put it in a
    /// race with the camera permission alert ScannerView triggers on appear.
    /// iOS silently declines to present the ATT prompt while another system
    /// alert is up, and a prompt that never appears leaves the status
    /// `.notDetermined` forever — Meta attribution then has no IDFA at all.
    /// Here the result screen is showing and nothing else is competing for the
    /// alert slot, and the ask lands right after the app has proven itself.
    ///
    /// Left un-flagged deliberately: every later call is a no-op once iOS has a
    /// stored answer, so a prompt that did get dropped is retried on the next
    /// scan instead of being lost.
    private func requestTrackingAuthorizationIfNeeded() {
        Task {
            // The result view is mid-transition when this runs; presenting into
            // an animating hierarchy is what drops the prompt.
            try? await Task.sleep(for: .milliseconds(800))
            guard UIApplication.shared.applicationState == .active else { return }
            await AttributionService.requestTrackingAuthorization()
        }
    }

    /// Records how a scan resolved and how long it took. `source` is one of
    /// catalog | cache | ocr | web | miss. Proves p50 in production and, for misses,
    /// produces the ranked list of unresolved GTINs that drives catalog growth.
    private func logResolved(source: String, started: Date, gtin: String?) {
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        SuperwallSafe.setUserAttributes([
            "last_scan_source": source,
            "last_scan_elapsed_ms": elapsedMs,
        ])
        #if DEBUG
        print("scan_resolved source=\(source) elapsed_ms=\(elapsedMs) gtin=\(gtin ?? "-")")
        #endif
    }

    func saveToHistory(using modelContext: ModelContext) {
        guard let breakdown = scoreBreakdown else { return }

        let species = selectedPet?.speciesEnum ?? selectedSpecies

        let scan = Scan(
            barcode: barcode,
            productName: productName.isEmpty ? nil : productName,
            brand: brand,
            imageUrl: imageUrl,
            category: selectedCategory,
            targetSpecies: species,
            rawIngredientText: ingredientsText,
            matchedIngredients: matchedIngredients,
            scoreBreakdown: breakdown
        )

        modelContext.insert(scan)

        do {
            try modelContext.save()
            successFeedback.notificationOccurred(.success)

            // Update scan count for Superwall targeting
            let scanCount = UserDefaults.standard.integer(forKey: "totalScanCount") + 1
            UserDefaults.standard.set(scanCount, forKey: "totalScanCount")

            SuperwallSafe.setUserAttributes([
                "scan_count": scanCount
            ])

            reset()
        } catch {
            currentError = .saveFailed(underlying: error)
            // Don't change step - let user see results still
        }
    }

    func reset() {
        step = .scanning
        lastHandledBarcode = nil
        barcode = nil
        productName = ""
        brand = nil
        imageUrl = nil
        ingredientsText = ""
        selectedSpecies = .dog
        selectedCategory = .food
        selectedPet = nil
        matchedIngredients = []
        scoreBreakdown = nil
        currentError = nil
        notFoundReason = .notInCatalog
        scoreSource = .databaseVerified
        productImage = nil
        productIdentification = nil
        isAnalyzing = false
    }

    // MARK: - Share Content

    func generateShareText() -> String {
        guard let breakdown = scoreBreakdown else { return "" }

        return breakdown.generateShareText(
            productName: productName.isEmpty ? nil : productName,
            brand: brand,
            species: selectedSpecies,
            category: selectedCategory
        )
    }
}
