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

    enum Step {
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

    // MARK: - Haptic Feedback

    private let successFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init(
        ingredientMatcher: IngredientMatcher = IngredientMatcher(),
        scoreCalculator: ScoreCalculator = ScoreCalculator(),
        ocrService: OCRServiceProtocol = OCRService(),
        productVisionService: ProductVisionServiceProtocol = ProductVisionService(apiKey: APIKeys.openai)
    ) {
        self.ingredientMatcher = ingredientMatcher
        self.scoreCalculator = scoreCalculator
        self.ocrService = ocrService
        self.productVisionService = productVisionService
        successFeedback.prepare()
    }

    // MARK: - Actions

    func handleBarcodeScan(_ code: String) {
        barcode = code
        currentError = nil
        step = .advancedSearch
    }

    func retryLastScan() {
        guard let code = barcode else {
            step = .scanning
            return
        }
        handleBarcodeScan(code)
    }

    func restartScanning() {
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
            // Get allergens from selected pet, or empty if no pet selected
            let petAllergens = selectedPet?.allergens ?? []

            // Use pet's species if available, otherwise fall back to selectedSpecies
            let species = selectedPet?.speciesEnum ?? selectedSpecies

            // Match ingredients (async - waits for database if needed)
            matchedIngredients = await ingredientMatcher.match(rawIngredients: ingredientsText)

            // Calculate score with allergens, pet name, and score source (async)
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

            Superwall.shared.setUserAttributes([
                "analysis_count": analysisCount
            ])

            Superwall.shared.register(placement: "analysis_complete")

            step = .results
        }
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
