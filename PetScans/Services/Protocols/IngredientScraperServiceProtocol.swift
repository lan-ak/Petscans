import Foundation

// MARK: - Scraping Models

/// Source where ingredients were scraped from
enum ScrapingSource: String, CaseIterable {
    // Retailers
    case chewy = "Chewy"
    case petco = "Petco"
    case petsmart = "PetSmart"
    // Manufacturer sites (most reliable for their own products)
    case purina = "Purina"
    case hillspet = "Hill's"
    case royalcanin = "Royal Canin"
    case bluebuffalo = "Blue Buffalo"
    case iams = "Iams"
    case nutro = "Nutro"

    /// Search URL pattern for this source
    var searchURLPattern: String {
        switch self {
        case .chewy:
            return "https://www.chewy.com/s?query=%@"
        case .petco:
            return "https://www.petco.com/shop/en/petcostore/search?query=%@"
        case .petsmart:
            return "https://www.petsmart.com/search/?q=%@"
        case .purina:
            return "https://www.purina.com/search?query=%@"
        case .hillspet:
            return "https://www.hillspet.com/search?text=%@"
        case .royalcanin:
            return "https://www.royalcanin.com/us/search?text=%@"
        case .bluebuffalo:
            return "https://bluebuffalo.com/search/?q=%@"
        case .iams:
            return "https://www.iams.com/search?q=%@"
        case .nutro:
            return "https://www.nutro.com/search?q=%@"
        }
    }

    /// Base URL for building absolute URLs
    var baseURL: String {
        switch self {
        case .chewy:
            return "https://www.chewy.com"
        case .petco:
            return "https://www.petco.com"
        case .petsmart:
            return "https://www.petsmart.com"
        case .purina:
            return "https://www.purina.com"
        case .hillspet:
            return "https://www.hillspet.com"
        case .royalcanin:
            return "https://www.royalcanin.com"
        case .bluebuffalo:
            return "https://bluebuffalo.com"
        case .iams:
            return "https://www.iams.com"
        case .nutro:
            return "https://www.nutro.com"
        }
    }
}

/// Confidence level for scraped ingredients
enum ScrapingConfidence: String {
    case high       // Exact product match with structured data
    case medium     // Likely match, parsed from DOM
    case low        // Uncertain match, may need verification
}

/// Result from a successful scraping operation
struct ScrapedIngredients {
    /// Where the ingredients were found
    let source: ScrapingSource

    /// Product name as found on the website
    let productName: String?

    /// Brand as found on the website
    let brand: String?

    /// Raw ingredients text extracted from the page
    let ingredientsText: String

    /// How confident we are in the match
    let confidence: ScrapingConfidence

    /// URL where the ingredients were found
    let sourceURL: URL?
}

// MARK: - Scraping Errors

/// Errors that can occur during scraping
enum ScrapingError: LocalizedError {
    case noResultsFound
    case ingredientsNotFound
    case parsingFailed(underlying: Error?)
    case networkError(underlying: Error)
    case blocked
    case allSourcesFailed

    var errorDescription: String? {
        switch self {
        case .noResultsFound:
            return "Product not found online"
        case .ingredientsNotFound:
            return "Couldn't find ingredients"
        case .parsingFailed:
            return "Failed to extract ingredients"
        case .networkError:
            return "Network connection failed"
        case .blocked:
            return "Website blocked request"
        case .allSourcesFailed:
            return "Couldn't find ingredients online"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noResultsFound:
            return "We couldn't find this product on pet food websites. Try taking a photo of the ingredients label."
        case .ingredientsNotFound:
            return "The product page doesn't list ingredients. Try taking a photo of the ingredients label."
        case .parsingFailed:
            return "We found the product but couldn't extract the ingredients. Try taking a photo instead."
        case .networkError:
            return "Please check your internet connection and try again."
        case .blocked:
            return "The website isn't responding. Try again later or take a photo of the ingredients."
        case .allSourcesFailed:
            return "We searched multiple pet food websites but couldn't find the ingredients. Try taking a photo of the ingredients label."
        }
    }
}

// MARK: - Protocol

/// Protocol for ingredient web scraping service
protocol IngredientScraperServiceProtocol: Sendable {
    /// Search for and scrape ingredients from pet food websites
    /// - Parameters:
    ///   - productName: The product name to search for
    ///   - brand: Optional brand name to improve search accuracy
    /// - Returns: Scraped ingredient data
    /// - Throws: ScrapingError on failure
    func searchAndScrape(productName: String, brand: String?) async throws -> ScrapedIngredients

    /// Scrape ingredients directly from a known product URL
    /// - Parameters:
    ///   - url: The product page URL to scrape
    ///   - source: The retailer/source for site-specific parsing
    /// - Returns: Scraped ingredient data
    /// - Throws: ScrapingError on failure
    func scrapeFromURL(_ url: URL, source: ScrapingSource) async throws -> ScrapedIngredients
}
