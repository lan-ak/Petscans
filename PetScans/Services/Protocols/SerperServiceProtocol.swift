import Foundation

// MARK: - Pet Retailer

/// Pet food retailers supported for product search
enum PetRetailer: String, CaseIterable, Sendable {
    case chewy
    case petco
    case petsmart

    /// Display name for UI
    var displayName: String {
        switch self {
        case .chewy: return "Chewy"
        case .petco: return "Petco"
        case .petsmart: return "PetSmart"
        }
    }

    /// Site query for Google search targeting product pages
    var siteQuery: String {
        switch self {
        case .chewy:
            return "site:chewy.com/dp"
        case .petco:
            return "site:petco.com/shop/en/petcostore/product"
        case .petsmart:
            return "site:petsmart.ca .html"
        }
    }

    /// Fallback site query (broader search)
    var fallbackSiteQuery: String? {
        switch self {
        case .chewy:
            return "site:chewy.com"
        case .petco:
            return "site:petco.com"
        case .petsmart:
            return "site:petsmart.ca"
        }
    }

    /// Validates if a URL is a valid product page for this retailer
    func isValidProductURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        switch self {
        case .chewy:
            return host.contains("chewy.com") && url.path.contains("/dp/")
        case .petco:
            return host.contains("petco.com") && url.path.contains("/shop/en/petcostore/product/")
        case .petsmart:
            return host.contains("petsmart.ca") &&
                   url.path.hasSuffix(".html") &&
                   url.path.contains(where: { $0.isNumber })
        }
    }
}

// MARK: - Search Result

/// Result from a successful product search
struct SerperSearchResult: Sendable {
    /// The product page URL
    let url: URL
    /// Which retailer the URL is from
    let retailer: PetRetailer
}

// MARK: - Protocol

/// Protocol for Google search via Serper.dev API
protocol SerperServiceProtocol: Sendable {
    /// Search for a pet food product across multiple retailers
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - retailers: Ordered list of retailers to search (first match wins)
    /// - Returns: The product URL and retailer if found
    /// - Throws: SerperError on failure
    func searchProduct(query: String, retailers: [PetRetailer]) async throws -> SerperSearchResult

    /// Search for a pet food product across all retailers, returning all matches
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - retailers: List of retailers to search
    /// - Returns: Array of product URLs (one per retailer that has a match)
    /// - Throws: SerperError on failure (only if no results found at all)
    func searchProductURLs(query: String, retailers: [PetRetailer]) async throws -> [SerperSearchResult]

    /// Search for a pet food product on Chewy.com via Google (legacy method)
    /// - Parameter query: Product name and brand to search for
    /// - Returns: The Chewy product URL if found
    /// - Throws: SerperError on failure
    func searchChewyProduct(query: String) async throws -> URL
}

/// Errors that can occur during Serper API operations
enum SerperError: LocalizedError {
    case invalidAPIKey
    case noResultsFound
    case rateLimited
    case networkError(underlying: Error)
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid Serper API key"
        case .noResultsFound:
            return "No Chewy results found"
        case .rateLimited:
            return "Search rate limit exceeded"
        case .networkError:
            return "Network error during search"
        case .decodingError:
            return "Failed to parse search results"
        }
    }
}
