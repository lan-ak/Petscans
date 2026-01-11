import Foundation

// MARK: - Firecrawl Models

/// Product data extracted by Firecrawl
struct FirecrawlProduct {
    let name: String
    let brand: String?
    let ingredients: [String]
    let price: Double?
    let imageURL: URL?
}

// MARK: - Firecrawl Errors

enum FirecrawlError: LocalizedError {
    case networkError(underlying: Error)
    case invalidAPIKey
    case rateLimited
    case scrapeFailed(message: String)
    case extractionFailed
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .invalidAPIKey:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limit exceeded"
        case .scrapeFailed(let message):
            return "Scrape failed: \(message)"
        case .extractionFailed:
            return "Could not extract product data"
        case .decodingError:
            return "Failed to parse response"
        }
    }
}

// MARK: - Protocol

/// Protocol for Firecrawl web scraping service
protocol FirecrawlServiceProtocol: Sendable {
    /// Scrape product details from any pet food retailer URL
    /// - Parameter url: The product page URL to scrape
    /// - Returns: Extracted product data including ingredients
    func scrapeProduct(url: URL) async throws -> FirecrawlProduct
}
