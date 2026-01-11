import Foundation
import SwiftUI

/// ViewModel managing the multi-step advanced search workflow
/// Orchestrates barcode lookup -> Serper search -> Firecrawl scraping -> ingredient matching
@MainActor
final class AdvancedSearchViewModel: ObservableObject {

    // MARK: - Types

    /// Steps in the advanced search process
    enum SearchStep: Int, CaseIterable, Identifiable {
        case lookingUpBarcode = 0
        case searchingProduct = 1
        case extractingIngredients = 2
        case analyzingIngredients = 3
        case complete = 4
        case failed = 5

        var id: Int { rawValue }

        /// Display title for the current step
        var displayTitle: String {
            switch self {
            case .lookingUpBarcode:
                return "Looking up barcode..."
            case .searchingProduct:
                return "Searching for product..."
            case .extractingIngredients:
                return "Finding ingredients..."
            case .analyzingIngredients:
                return "Analyzing ingredients..."
            case .complete:
                return "Complete!"
            case .failed:
                return "Search failed"
            }
        }

        /// SF Symbol icon for this step
        var icon: String {
            switch self {
            case .lookingUpBarcode:
                return "barcode"
            case .searchingProduct:
                return "magnifyingglass"
            case .extractingIngredients:
                return "doc.text.magnifyingglass"
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
                return "Identifying product from barcode"
            case .searchingProduct:
                return "Searching pet food databases"
            case .extractingIngredients:
                return "Extracting ingredient information"
            case .analyzingIngredients:
                return "Matching against known ingredients"
            case .complete:
                return "Analysis complete"
            case .failed:
                return "Unable to find ingredients"
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
            case .barcodeNotFound:
                return "Barcode not recognized"
            case .productNotFound:
                return "Product not found online"
            case .ingredientsNotFound:
                return "Couldn't find ingredients"
            case .networkError:
                return "Network error"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .barcodeNotFound:
                return "This barcode isn't in our product database. Try taking a photo of the ingredients instead."
            case .productNotFound:
                return "We couldn't find this product on pet food websites. Try taking a photo of the ingredients."
            case .ingredientsNotFound:
                return "We found the product but couldn't extract ingredients. Try taking a photo instead."
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
    private let serperService: SerperServiceProtocol
    private let firecrawlService: FirecrawlServiceProtocol
    private let ingredientMatcher: IngredientMatcher

    // MARK: - Init

    init(
        upcService: UPCitemdbServiceProtocol = UPCitemdbService(),
        serperService: SerperServiceProtocol,
        firecrawlService: FirecrawlServiceProtocol,
        ingredientMatcher: IngredientMatcher = IngredientMatcher()
    ) {
        self.upcService = upcService
        self.serperService = serperService
        self.firecrawlService = firecrawlService
        self.ingredientMatcher = ingredientMatcher
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

            // Step 2: Search across retailers (Chewy -> Petco -> PetSmart)
            currentStep = .searchingProduct
            try await Task.sleep(nanoseconds: 300_000_000)

            let searchResult = try await serperService.searchProduct(
                query: searchQuery,
                retailers: [.chewy, .petco, .petsmart]
            )
            print("DEBUG: Found product on \(searchResult.retailer.displayName): \(searchResult.url.absoluteString)")
            completedSteps.insert(.searchingProduct)

            // Step 3: Extract ingredients (method depends on retailer)
            currentStep = .extractingIngredients
            try await Task.sleep(nanoseconds: 200_000_000)

            try await extractIngredients(from: searchResult)
            completedSteps.insert(.extractingIngredients)

            // Step 4: Match ingredients against database
            currentStep = .analyzingIngredients
            matchedIngredients = await ingredientMatcher.match(rawIngredients: ingredientsText ?? "")
            completedSteps.insert(.analyzingIngredients)

            // Complete!
            currentStep = .complete
            completedSteps.insert(.complete)

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

    /// Extract ingredients from the found product URL using Firecrawl
    /// Works for all retailers (Chewy, Petco, PetSmart) with AI-powered extraction
    private func extractIngredients(from searchResult: SerperSearchResult) async throws {
        print("DEBUG: Using Firecrawl for \(searchResult.retailer.displayName) URL: \(searchResult.url.absoluteString)")

        let product = try await firecrawlService.scrapeProduct(url: searchResult.url)
        print("DEBUG: Firecrawl got product: \(product.name), ingredients count: \(product.ingredients.count)")

        ingredientsText = product.ingredients.joined(separator: ", ")
        dataSource = searchResult.retailer.displayName

        if !product.name.isEmpty {
            productName = product.name
        }
        if let productBrand = product.brand {
            brand = productBrand
        }
        if let imageURL = product.imageURL {
            productImageURL = imageURL
        }
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

    private func handleSerperError(_ error: SerperError) {
        switch error {
        case .noResultsFound:
            self.error = .productNotFound
        case .invalidAPIKey, .rateLimited:
            self.error = .networkError(underlying: error)
        case .networkError, .decodingError:
            self.error = .networkError(underlying: error)
        }
        currentStep = .failed
    }

    private func handleFirecrawlError(_ error: FirecrawlError) {
        switch error {
        case .extractionFailed, .scrapeFailed:
            self.error = .ingredientsNotFound
        case .invalidAPIKey, .rateLimited:
            self.error = .networkError(underlying: error)
        case .networkError, .decodingError:
            self.error = .networkError(underlying: error)
        }
        currentStep = .failed
    }
}

// MARK: - Step Progress Helpers

extension AdvancedSearchViewModel {
    /// Steps to display in the progress indicator (excludes terminal states)
    var displaySteps: [SearchStep] {
        [.lookingUpBarcode, .searchingProduct, .extractingIngredients, .analyzingIngredients]
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
