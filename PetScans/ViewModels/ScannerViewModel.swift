import Foundation
import SwiftUI
import SwiftData
import Combine
import UIKit

/// ViewModel for the scanner workflow, managing state and business logic
@MainActor
final class ScannerViewModel: ObservableObject {
    // MARK: - Types

    enum Step {
        case scanning
        case loading
        case error
        case productNotFound
        case ocrCapture
        case ocrProcessing
        case selectOptions
        case manualEntry
        case results
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
    @Published var productName: String?
    @Published var brand: String?
    @Published var imageUrl: String?
    @Published var ingredientsText: String = ""
    @Published var selectedSpecies: Species = .dog
    @Published var selectedCategory: Category = .food
    @Published var matchedIngredients: [MatchedIngredient] = []
    @Published var scoreBreakdown: ScoreBreakdown?
    @Published var currentError: ScanError?
    @Published var ocrImage: UIImage?
    @Published var ocrConfidence: Float?
    @Published var scoreSource: ScoreSource = .databaseVerified

    // MARK: - Dependencies

    private let apiService: PetFoodAPIServiceProtocol
    private let ingredientMatcher: IngredientMatcher
    private let scoreCalculator: ScoreCalculator
    private let ocrService: OCRServiceProtocol

    // MARK: - Haptic Feedback

    private let successFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init(
        apiService: PetFoodAPIServiceProtocol = PetFoodAPIService(),
        ingredientMatcher: IngredientMatcher = IngredientMatcher(),
        scoreCalculator: ScoreCalculator = ScoreCalculator(),
        ocrService: OCRServiceProtocol = OCRService()
    ) {
        self.apiService = apiService
        self.ingredientMatcher = ingredientMatcher
        self.scoreCalculator = scoreCalculator
        self.ocrService = ocrService
        successFeedback.prepare()
    }

    // MARK: - Actions

    func handleBarcodeScan(_ code: String) {
        barcode = code
        step = .loading
        currentError = nil

        Task {
            do {
                let result = try await apiService.lookupProduct(barcode: code)

                productName = result.productName
                brand = result.brand
                imageUrl = result.imageUrl
                scoreSource = .databaseVerified

                if let ingredients = result.ingredientsText, !ingredients.isEmpty {
                    ingredientsText = ingredients
                    step = .selectOptions
                } else {
                    // Product found but no ingredients
                    step = .productNotFound
                }
            } catch let error as APIError {
                switch error {
                case .productNotFound:
                    // Not an error - show options for OCR or manual entry
                    step = .productNotFound
                case .networkError(let underlying):
                    currentError = .networkError(underlying: underlying)
                    step = .error
                case .decodingError, .invalidResponse:
                    currentError = .networkError(underlying: error)
                    step = .error
                }
            } catch {
                currentError = .networkError(underlying: error)
                step = .error
            }
        }
    }

    func retryLastScan() {
        guard let code = barcode else {
            step = .scanning
            return
        }
        handleBarcodeScan(code)
    }

    func handleManualEntry(name: String?, brandName: String?, ingredients: String) {
        productName = name
        brand = brandName
        ingredientsText = ingredients
        scoreSource = .manualEntry
        step = .selectOptions
    }

    func goToManualEntry() {
        scoreSource = .manualEntry
        step = .manualEntry
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

    func performAnalysis(petAllergens: [String] = []) {
        // Match ingredients
        matchedIngredients = ingredientMatcher.match(rawIngredients: ingredientsText)

        // Calculate score with allergens and score source
        scoreBreakdown = scoreCalculator.calculate(
            species: selectedSpecies,
            category: selectedCategory,
            matched: matchedIngredients,
            petAllergens: petAllergens,
            scoreSource: scoreSource,
            ocrConfidence: ocrConfidence
        )

        step = .results
    }

    func saveToHistory(using modelContext: ModelContext) {
        guard let breakdown = scoreBreakdown else { return }

        let scan = Scan(
            barcode: barcode,
            productName: productName,
            brand: brand,
            imageUrl: imageUrl,
            category: selectedCategory,
            targetSpecies: selectedSpecies,
            rawIngredientText: ingredientsText,
            matchedIngredients: matchedIngredients,
            scoreBreakdown: breakdown
        )

        modelContext.insert(scan)

        do {
            try modelContext.save()
            successFeedback.notificationOccurred(.success)
            reset()
        } catch {
            currentError = .saveFailed(underlying: error)
            // Don't change step - let user see results still
        }
    }

    func reset() {
        step = .scanning
        barcode = nil
        productName = nil
        brand = nil
        imageUrl = nil
        ingredientsText = ""
        selectedSpecies = .dog
        selectedCategory = .food
        matchedIngredients = []
        scoreBreakdown = nil
        currentError = nil
        ocrImage = nil
        ocrConfidence = nil
        scoreSource = .databaseVerified
    }

    // MARK: - Share Content

    func generateShareText() -> String {
        guard let breakdown = scoreBreakdown else { return "" }

        return breakdown.generateShareText(
            productName: productName,
            brand: brand,
            species: selectedSpecies,
            category: selectedCategory
        )
    }
}
