import Foundation
import SwiftUI
import SwiftData
import Combine
import UIKit
import SuperwallKit

/// ViewModel for the scanner workflow, managing state and business logic
@MainActor
final class ScannerViewModel: ObservableObject {
    // MARK: - Types

    enum Step: Equatable {
        case scanning
        case error
        case productNotFound
        case advancedSearch
        case ocrCapture
        case ocrProcessing
        case selectOptions
        case manualEntry
        case results
        // Product photo identification flow
        case productPhotoCapture
        case productIdentification
        case productSearching
    }

    enum ScanError: LocalizedError {
        case networkError(underlying: Error)
        case productNotFound
        case noIngredients
        case saveFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .networkError:
                return "Network Error"
            case .productNotFound:
                return "Product Not Found"
            case .noIngredients:
                return "No Ingredients"
            case .saveFailed:
                return "Save Failed"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .networkError:
                return "Please check your internet connection and try again."
            case .productNotFound:
                return "This product wasn't found in our database. You can enter the details manually."
            case .noIngredients:
                return "No ingredient information available. Please enter ingredients manually."
            case .saveFailed:
                return "Failed to save the scan. Please try again."
            }
        }

        var canRetry: Bool {
            switch self {
            case .networkError:
                return true
            case .productNotFound, .noIngredients, .saveFailed:
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
    @Published var ocrImage: UIImage?
    @Published var ocrConfidence: Float?
    @Published var scoreSource: ScoreSource = .databaseVerified
    @Published var isManualSearch: Bool = false
    @Published var productImage: UIImage?
    @Published var productIdentification: ProductIdentification?

    // MARK: - Dependencies

    private let ingredientMatcher: IngredientMatcher
    private let scoreCalculator: ScoreCalculator
    private let ocrService: OCRServiceProtocol
    private let productVisionService: ProductVisionServiceProtocol
    private let catalogService: ProductCatalogService

    /// Guards against a barcode held in frame re-triggering a resolve on every camera
    /// frame. Cleared on reset and when a read is ignored as a non-product code.
    private var lastHandledBarcode: String?

    // MARK: - Haptic Feedback

    private let successFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init(
        ingredientMatcher: IngredientMatcher = IngredientMatcher(),
        scoreCalculator: ScoreCalculator = ScoreCalculator(),
        ocrService: OCRServiceProtocol = OCRService(),
        productVisionService: ProductVisionServiceProtocol = ProductVisionService(),
        catalogService: ProductCatalogService = ProductCatalogService()
    ) {
        self.ingredientMatcher = ingredientMatcher
        self.scoreCalculator = scoreCalculator
        self.ocrService = ocrService
        self.productVisionService = productVisionService
        self.catalogService = catalogService
        successFeedback.prepare()
    }

    // MARK: - Actions

    /// The instant path. Resolve the barcode against the on-device catalog and, on a hit,
    /// score locally and jump straight to results — no product-identification round trip,
    /// no species/category picker, no "Analyze" tap. A miss goes straight to the OCR label
    /// capture, which is on-device and sub-second. Only a code that isn't a retail product
    /// barcode at all is silently ignored so the scanner keeps looking.
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
                successFeedback.notificationOccurred(.success)
                step = .results

            case .unknown(let gtin):
                barcode = gtin
                if let context = modelContext, let cached = cachedScan(gtin: gtin, in: context) {
                    apply(cached, pets: pets)
                    await computeScore()
                    logResolved(source: "cache", started: started, gtin: gtin)
                    successFeedback.notificationOccurred(.success)
                    step = .results
                } else {
                    // New product: surface a "not found" screen that names the barcode and
                    // explains why, so the jump to the label camera isn't a silent, confusing
                    // switch. Its primary action leads to the on-device OCR capture.
                    logResolved(source: "miss", started: started, gtin: gtin)
                    isManualSearch = false
                    step = .productNotFound
                }
            }
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

    func retryLastScan() {
        lastHandledBarcode = nil
        barcode = nil
        step = .scanning
        currentError = nil
    }

    func restartScanning() {
        lastHandledBarcode = nil
        barcode = nil
        step = .scanning
        currentError = nil
    }

    func handleManualEntry(name: String?, brandName: String?, ingredients: String) {
        productName = name ?? ""
        brand = brandName
        ingredientsText = ingredients
        scoreSource = .manualEntry
        step = .selectOptions
    }

    func goToManualEntry() {
        isManualSearch = true
        step = .productNotFound
    }

    func goToIngredientSelection() {
        step = .manualEntry
    }

    func startAdvancedSearch() {
        guard barcode != nil else { return }
        step = .advancedSearch
    }

    func handleAdvancedSearchComplete(ingredientsText: String, productName: String?, brand: String?, matched: [MatchedIngredient], imageUrl: URL?) {
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
        step = .selectOptions
    }

    func handleOCRCapture(_ image: UIImage) {
        ocrImage = image
        step = .ocrProcessing

        Task {
            do {
                let result = try await ocrService.extractText(from: image)
                ingredientsText = result.text
                ocrConfidence = result.confidence
                scoreSource = .ocrEstimated
                step = .selectOptions
            } catch let error as OCRService.OCRError {
                handleOCRError(error)
            } catch {
                currentError = .networkError(underlying: error)
                step = .error
            }
        }
    }

    private func handleOCRError(_ error: OCRService.OCRError) {
        // Convert OCR errors to scan errors
        switch error {
        case .noTextDetected, .lowConfidence, .imageTooSmall:
            currentError = .noIngredients
        case .processingFailed(let underlying):
            currentError = .networkError(underlying: underlying)
        }
        step = .error
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
                productIdentification = identification

                guard identification.searchQuery != nil else {
                    throw ProductVisionError.noProductFound
                }

                // Transition to searching with the identified product
                step = .productSearching
            } catch {
                handleProductIdentificationError(error)
            }
        }
    }

    private func handleProductIdentificationError(_ error: Error) {
        if let visionError = error as? ProductVisionError {
            switch visionError {
            case .noProductFound, .lowConfidence:
                // Allow fallback to ingredient photo or retry
                currentError = .productNotFound
                step = .productNotFound
            case .networkError, .rateLimited:
                currentError = .networkError(underlying: error)
                step = .error
            default:
                currentError = .productNotFound
                step = .productNotFound
            }
        } else {
            currentError = .networkError(underlying: error)
            step = .error
        }
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
        step = .selectOptions
    }

    func performAnalysis() {
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
            step = .results
        }
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
            ocrConfidence: ocrConfidence
        )

        // Update analysis count for Superwall targeting
        let analysisCount = UserDefaults.standard.integer(forKey: "totalAnalysisCount") + 1
        UserDefaults.standard.set(analysisCount, forKey: "totalAnalysisCount")

        Superwall.shared.setUserAttributes(["analysis_count": analysisCount])

        // Paywall copy names the pet this scan was run for; nil falls back
        // to the roster primary rather than leaving a stale name.
        SuperwallUserAttributes.setFocusedPet(selectedPet)

        Superwall.shared.register(placement: "analysis_complete")

        // Meta ad-campaign signal: the app's core activation moment. No-ops
        // unless Meta credentials are configured (see AttributionService).
        AttributionService.logScanCompleted()
    }

    /// Records how a scan resolved and how long it took. `source` is one of
    /// catalog | cache | ocr | web | miss. Proves p50 in production and, for misses,
    /// produces the ranked list of unresolved GTINs that drives catalog growth.
    private func logResolved(source: String, started: Date, gtin: String?) {
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        Superwall.shared.setUserAttributes([
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

            Superwall.shared.setUserAttributes([
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
        ocrImage = nil
        ocrConfidence = nil
        scoreSource = .databaseVerified
        isManualSearch = false
        productImage = nil
        productIdentification = nil
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
