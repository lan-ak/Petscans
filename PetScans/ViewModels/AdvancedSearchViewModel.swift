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

        /// Display title for the current step (shown while in progress)
        var displayTitle: String {
            switch self {
            case .lookingUpBarcode:
                return "Looking up product..."
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
        case productNotFound
        case ingredientsNotFound
        case networkError(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "We couldn't find this product"
            case .ingredientsNotFound:
                return "We couldn't find the ingredients"
            case .networkError:
                return "Network error"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .productNotFound:
                return "Try another photo of the front of the pack, or scan a different product."
            case .ingredientsNotFound:
                return "We found the product but couldn't pull its ingredient list online. Try scanning a different product."
            case .networkError:
                return "Please check your internet connection and try again."
            }
        }

        /// True when a better photo can't change the outcome (product was located,
        /// but its ingredients aren't available online) — so the UI shouldn't lead
        /// with "try another photo."
        var retakeWontHelp: Bool {
            if case .ingredientsNotFound = self { return true }
            return false
        }

        /// A soft "we couldn't find it" outcome (vs a hard error that broke). Drives
        /// warning-amber vs error-red treatment and the haptic class, matching the
        /// vision stage's split.
        var isNotFound: Bool {
            switch self {
            case .productNotFound, .ingredientsNotFound: return true
            case .networkError: return false
            }
        }
    }

    // MARK: - Published Properties

    @Published var currentStep: SearchStep = .lookingUpBarcode
    @Published var completedSteps: Set<SearchStep> = []
    @Published var error: AdvancedSearchError?

    // Results from search
    @Published var productName: String?
    @Published var brand: String?
    @Published var ingredientsText: String?
    @Published var matchedIngredients: [MatchedIngredient] = []
    @Published var productImageURL: URL?

    // MARK: - Dependencies

    private let firecrawlService: FirecrawlServiceProtocol
    private let serperService: SerperServiceProtocol
    private let ingredientMatcher: IngredientMatcher
    private let errorFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init(
        firecrawlService: FirecrawlServiceProtocol,
        serperService: SerperServiceProtocol = SerperService(),
        ingredientMatcher: IngredientMatcher = IngredientMatcher()
    ) {
        self.firecrawlService = firecrawlService
        self.serperService = serperService
        self.ingredientMatcher = ingredientMatcher
        errorFeedback.prepare()
    }

    // MARK: - Actions

    /// Start search from product identification (bypasses barcode lookup)
    /// - Parameter identification: Product identification from vision API
    func startSearchFromImage(identification: ProductIdentification) async {
        error = nil
        completedSteps = []

        // Use identification data as our starting point (skip barcode lookup)
        productName = identification.productName
        brand = identification.brand

        // Mark barcode lookup as complete since we already have product info
        completedSteps.insert(.lookingUpBarcode)
        currentStep = .searchingIngredients

        guard let searchQuery = identification.searchQuery else {
            markFailed(.productNotFound)
            return
        }

        do {
            // Step 2: Search and extract ingredients via Serper + parallel Scrape
            try await Task.sleep(nanoseconds: 200_000_000)

            // Search across pet retailers
            let searchResults = try await serperService.searchProductURLs(
                query: searchQuery,
                brand: identification.brand,
                retailers: [.petco, .chewy, .petsmart]
            )
            print("DEBUG: Found \(searchResults.count) URLs via Serper (from image)")

            // Prioritize URLs that contain the identified protein/carb
            var sortedResults = searchResults
            let protein = identification.primaryProtein?.lowercased() ?? ""
            let carb = identification.primaryCarb?.lowercased().replacingOccurrences(of: " ", with: "-") ?? ""

            if !protein.isEmpty || !carb.isEmpty {
                sortedResults.sort { result1, result2 in
                    let url1 = result1.url.absoluteString.lowercased()
                    let url2 = result2.url.absoluteString.lowercased()

                    // Score based on protein and carb matches
                    var score1 = 0
                    var score2 = 0
                    if !protein.isEmpty {
                        if url1.contains(protein) { score1 += 2 }
                        if url2.contains(protein) { score2 += 2 }
                    }
                    if !carb.isEmpty {
                        if url1.contains(carb) { score1 += 1 }
                        if url2.contains(carb) { score2 += 1 }
                    }

                    return score1 > score2
                }
                print("DEBUG: Prioritized URLs by protein='\(protein)' carb='\(carb)'")
            }

            // Scrape all URLs in parallel, return first success
            let (product, winningSource) = try await firecrawlService.scrapeFirstSuccessful(
                searchResults: sortedResults
            )
            print("DEBUG: First success from \(winningSource.displayName), ingredients: \(product.ingredients.count)")

            // Validate ingredients
            guard !product.ingredients.isEmpty else {
                throw AdvancedSearchError.ingredientsNotFound
            }
            print("DEBUG: Winning source \(winningSource.displayName)")

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

            // Complete! The single success haptic fires later at the result screen
            // (ScannerViewModel.showResults), so it isn't double-tapped here.
            currentStep = .complete
            completedSteps.insert(.complete)

        } catch let serperError as SerperError {
            print("DEBUG: Serper Error: \(serperError)")
            handleSerperError(serperError)
        } catch let firecrawlError as FirecrawlError {
            print("DEBUG: Firecrawl Error: \(firecrawlError)")
            handleFirecrawlError(firecrawlError)
        } catch let advancedError as AdvancedSearchError {
            print("DEBUG: Advanced Search Error: \(advancedError)")
            markFailed(advancedError)
        } catch {
            print("DEBUG: Unknown Error: \(error)")
            markFailed(.networkError(underlying: error))
        }
    }

    /// Reset the view model state
    func reset() {
        currentStep = .lookingUpBarcode
        completedSteps = []
        error = nil
        productName = nil
        brand = nil
        ingredientsText = nil
        matchedIngredients = []
        productImageURL = nil
    }

    // MARK: - Private Methods

    /// Whether the current failure is a soft "not found" (vs a hard error).
    var failureIsSoft: Bool { error?.isNotFound ?? false }

    /// Single failure path: record the error, move to the failed step, and fire a
    /// haptic that matches severity — `.warning` for not-found, `.error` for a hard
    /// failure — mirroring the vision stage's split.
    private func markFailed(_ error: AdvancedSearchError) {
        self.error = error
        currentStep = .failed
        errorFeedback.notificationOccurred(error.isNotFound ? .warning : .error)
        errorFeedback.prepare()
    }

    private func handleFirecrawlError(_ error: FirecrawlError) {
        switch error {
        case .extractionFailed, .scrapeFailed:
            markFailed(.ingredientsNotFound)
        case .agentJobTimeout, .agentJobFailed, .insufficientCredits, .rateLimited:
            markFailed(.productNotFound)
        case .invalidAPIKey:
            markFailed(.networkError(underlying: error))
        case .networkError, .decodingError:
            markFailed(.networkError(underlying: error))
        }
    }

    private func handleSerperError(_ error: SerperError) {
        switch error {
        case .noResultsFound:
            markFailed(.productNotFound)
        case .invalidAPIKey, .rateLimited, .networkError, .decodingError:
            markFailed(.networkError(underlying: error))
        }
    }
}
