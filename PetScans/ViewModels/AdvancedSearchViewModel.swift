import Foundation
import SwiftUI
import UIKit

/// ViewModel managing the multi-step advanced search workflow
/// Orchestrates barcode lookup -> Serper search -> Firecrawl scrape -> ingredient matching
@MainActor
final class AdvancedSearchViewModel: ObservableObject {

    // MARK: - Types

    /// Steps in the advanced search process
    enum SearchStep: Int, CaseIterable, Identifiable {
        case lookingUpBarcode = 0
        case searchingIngredients = 1
        case analyzingIngredients = 2
        case complete = 3
        case failed = 4

        var id: Int { rawValue }

        /// Display title for the current step
        var displayTitle: String {
            switch self {
            case .lookingUpBarcode:
                return "Found it!"
            case .searchingIngredients:
                return "Getting ingredients..."
            case .analyzingIngredients:
                return "Almost there!"
            case .complete:
                return "All done!"
            case .failed:
                return "Hmm, that didn't work"
            }
        }

        /// SF Symbol icon for this step
        var icon: String {
            switch self {
            case .lookingUpBarcode:
                return "barcode"
            case .searchingIngredients:
                return "magnifyingglass"
            case .analyzingIngredients:
                return "waveform.path.ecg"
            case .complete:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.circle.fill"
            }
        }

        /// Description of what's happening at this step
        var activeDescription: String {
            switch self {
            case .lookingUpBarcode:
                return "We found your product"
            case .searchingIngredients:
                return "Searching for the freshest ingredient data"
            case .analyzingIngredients:
                return "Getting the most up-to-date info"
            case .complete:
                return "Ready for you to review"
            case .failed:
                return "Let's try another way"
            }
        }

        /// Whether this is a terminal state
        var isTerminal: Bool {
            self == .complete || self == .failed
        }
    }

    /// Error types for advanced search
    enum AdvancedSearchError: LocalizedError {
        case barcodeNotFound
        case productNotFound
        case ingredientsNotFound
        case networkError(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .barcodeNotFound, .productNotFound:
                return "We couldn't find this product"
            case .ingredientsNotFound:
                return "We couldn't find the ingredients"
            case .networkError:
                return "Network error"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .barcodeNotFound, .productNotFound, .ingredientsNotFound:
                return "Take a photo of the ingredients and we'll analyze it."
            case .networkError:
                return "Please check your internet connection and try again."
            }
        }
    }

    // MARK: - Published Properties

    @Published var currentStep: SearchStep = .lookingUpBarcode
    @Published var completedSteps: Set<SearchStep> = []
    @Published var isSearching: Bool = false
    @Published var error: AdvancedSearchError?

    // Results from search
    @Published var productName: String?
    @Published var brand: String?
    @Published var ingredientsText: String?
    @Published var dataSource: String?
    @Published var matchedIngredients: [MatchedIngredient] = []
    @Published var productImageURL: URL?

    // MARK: - Dependencies

    private let upcService: UPCitemdbServiceProtocol
    private let firecrawlService: FirecrawlServiceProtocol
    private let serperService: SerperServiceProtocol
    private let ingredientMatcher: IngredientMatcher
    private let successFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init(
        upcService: UPCitemdbServiceProtocol = UPCitemdbService(),
        firecrawlService: FirecrawlServiceProtocol,
        serperService: SerperServiceProtocol = SerperService(apiKey: APIKeys.serper),
        ingredientMatcher: IngredientMatcher = IngredientMatcher()
    ) {
        self.upcService = upcService
        self.firecrawlService = firecrawlService
        self.serperService = serperService
        self.ingredientMatcher = ingredientMatcher
        successFeedback.prepare()
    }

    // MARK: - Actions

    /// Start the advanced search process with a barcode
    /// - Parameter barcode: The barcode scanned by the user
    func startSearch(barcode: String) async {
        isSearching = true
        error = nil
        completedSteps = []
        currentStep = .lookingUpBarcode

        do {
            // Step 1: Look up barcode in UPCitemdb
            let upcResult = try await upcService.lookupBarcode(barcode)
            productName = upcResult.displayName
            brand = upcResult.brand
            completedSteps.insert(.lookingUpBarcode)

            guard let searchQuery = upcResult.searchQuery else {
                throw AdvancedSearchError.barcodeNotFound
            }

            // Step 2: Search and extract ingredients via Serper + parallel Scrape
            currentStep = .searchingIngredients
            try await Task.sleep(nanoseconds: 200_000_000)

            // Search across pet retailers (get all matching URLs)
            let searchResults = try await serperService.searchProductURLs(
                query: searchQuery,
                retailers: [.petco, .chewy, .petsmart]
            )
            print("DEBUG: Found \(searchResults.count) URLs via Serper")

            // Scrape all URLs in parallel, return first success
            let (product, winningRetailer) = try await firecrawlService.scrapeFirstSuccessful(
                searchResults: searchResults
            )
            print("DEBUG: First success from \(winningRetailer.displayName), ingredients: \(product.ingredients.count)")

            // Validate ingredients
            guard !product.ingredients.isEmpty else {
                throw AdvancedSearchError.ingredientsNotFound
            }

            // Set data source to winning retailer
            dataSource = winningRetailer.displayName

            // Update product data from result
            ingredientsText = product.ingredients.joined(separator: ", ")

            if !product.name.isEmpty {
                productName = product.name
            }
            if let productBrand = product.brand {
                brand = productBrand
            }
            if let imageURL = product.imageURL {
                productImageURL = imageURL
            }

            completedSteps.insert(.searchingIngredients)

            // Step 3: Match ingredients against database
            currentStep = .analyzingIngredients
            matchedIngredients = await ingredientMatcher.match(rawIngredients: ingredientsText ?? "")
            completedSteps.insert(.analyzingIngredients)

            // Complete!
            currentStep = .complete
            completedSteps.insert(.complete)
            successFeedback.notificationOccurred(.success)

        } catch let upcError as UPCitemdbError {
            print("DEBUG: UPC Error: \(upcError)")
            handleUPCError(upcError)
        } catch let serperError as SerperError {
            print("DEBUG: Serper Error: \(serperError)")
            handleSerperError(serperError)
        } catch let firecrawlError as FirecrawlError {
            print("DEBUG: Firecrawl Error: \(firecrawlError)")
            handleFirecrawlError(firecrawlError)
        } catch let advancedError as AdvancedSearchError {
            print("DEBUG: Advanced Search Error: \(advancedError)")
            error = advancedError
            currentStep = .failed
        } catch {
            print("DEBUG: Unknown Error: \(error)")
            self.error = .networkError(underlying: error)
            currentStep = .failed
        }

        isSearching = false
    }

    /// Reset the view model state
    func reset() {
        currentStep = .lookingUpBarcode
        completedSteps = []
        isSearching = false
        error = nil
        productName = nil
        brand = nil
        ingredientsText = nil
        dataSource = nil
        matchedIngredients = []
        productImageURL = nil
    }

    // MARK: - Private Methods

    private func handleUPCError(_ error: UPCitemdbError) {
        switch error {
        case .productNotFound, .invalidBarcode:
            self.error = .barcodeNotFound
        case .rateLimited, .networkError, .decodingError:
            self.error = .networkError(underlying: error)
        }
        currentStep = .failed
    }

    private func handleFirecrawlError(_ error: FirecrawlError) {
        switch error {
        case .extractionFailed, .scrapeFailed:
            self.error = .ingredientsNotFound
        case .agentJobTimeout, .agentJobFailed, .insufficientCredits, .rateLimited:
            self.error = .productNotFound
        case .invalidAPIKey:
            self.error = .networkError(underlying: error)
        case .networkError, .decodingError:
            self.error = .networkError(underlying: error)
        }
        currentStep = .failed
    }

    private func handleSerperError(_ error: SerperError) {
        switch error {
        case .noResultsFound:
            self.error = .productNotFound
        case .invalidAPIKey, .rateLimited, .networkError, .decodingError:
            self.error = .networkError(underlying: error)
        }
        currentStep = .failed
    }
}

// MARK: - Step Progress Helpers

extension AdvancedSearchViewModel {
    /// Steps to display in the progress indicator (excludes terminal states)
    var displaySteps: [SearchStep] {
        [.lookingUpBarcode, .searchingIngredients, .analyzingIngredients]
    }

    /// Current step index for progress calculation
    var currentStepIndex: Int {
        currentStep.rawValue
    }

    /// Total number of steps (excluding terminal states)
    var totalSteps: Int {
        displaySteps.count
    }

    /// Progress as a percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard currentStep != .failed else { return 0 }
        if currentStep == .complete { return 1.0 }
        return Double(completedSteps.count) / Double(totalSteps)
    }
}
