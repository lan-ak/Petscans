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

// MARK: - Agent API Models

/// Configuration for Agent API requests
struct AgentSearchConfig {
    let productName: String
    let brand: String?
    let maxCredits: Int
    let model: AgentModel

    enum AgentModel: String {
        case sparkMini = "spark-1-mini"  // Default, 60% cheaper
        case sparkPro = "spark-1-pro"    // Higher accuracy
    }

    init(productName: String, brand: String? = nil, maxCredits: Int = 50, model: AgentModel = .sparkMini) {
        self.productName = productName
        self.brand = brand
        self.maxCredits = maxCredits
        self.model = model
    }
}

/// Result from Agent API search
struct AgentSearchResult {
    let product: FirecrawlProduct
    let creditsUsed: Int
    let source: String?
}

/// Status of an Agent API job
enum AgentJobStatus: String, Decodable {
    case processing
    case completed
    case failed
}

// MARK: - Firecrawl Errors

enum FirecrawlError: LocalizedError {
    case networkError(underlying: Error)
    case invalidAPIKey
    case rateLimited
    case scrapeFailed(message: String)
    case extractionFailed
    case decodingError(underlying: Error)
    case agentJobTimeout
    case agentJobFailed(message: String)
    case insufficientCredits

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
        case .agentJobTimeout:
            return "Search took too long"
        case .agentJobFailed(let message):
            return "Search failed: \(message)"
        case .insufficientCredits:
            return "Insufficient API credits"
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

    /// Search for and extract pet food product data using Agent API
    /// - Parameter config: Search configuration with product details
    /// - Returns: Extracted product data including ingredients
    func searchAndExtractProduct(config: AgentSearchConfig) async throws -> AgentSearchResult
}
