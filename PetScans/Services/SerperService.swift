import Foundation

/// Actor-based service for Google search via Serper.dev API
/// Used to find pet food product URLs on Chewy, Petco, and PetSmart
actor SerperService: SerperServiceProtocol {

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://google.serper.dev/search"
    private let session: URLSession

    /// Known manufacturer/parent company names that should be stripped from queries
    /// These are often included by UPCitemdb but not used by retailers
    private let manufacturerPrefixes = ["Cardinal", "Mars", "Nestle", "Purina", "Spectrum"]

    // MARK: - Init

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Search for a pet food product across multiple retailers
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - retailers: Ordered list of retailers to search (first match wins)
    /// - Returns: The product URL and retailer if found
    func searchProduct(query: String, retailers: [PetRetailer]) async throws -> SerperSearchResult {
        let results = try await searchProductURLs(query: query, retailers: retailers)
        guard let first = results.first else {
            throw SerperError.noResultsFound
        }
        return first
    }

    /// Search for a pet food product across all retailers, returning all matches
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - retailers: List of retailers to search
    /// - Returns: Array of product URLs (one per retailer that has a match)
    func searchProductURLs(query: String, retailers: [PetRetailer]) async throws -> [SerperSearchResult] {
        print("DEBUG: Starting multi-retailer search for: \(query)")

        var results: [SerperSearchResult] = []

        for retailer in retailers {
            // Try primary (targeted) search
            if let result = try await searchRetailer(query: query, retailer: retailer, useFallback: false) {
                print("DEBUG: Found product on \(retailer.displayName): \(result.url)")
                results.append(result)
                continue  // Move to next retailer
            }

            // Try fallback (broader) search if available
            if retailer.fallbackSiteQuery != nil {
                if let result = try await searchRetailer(query: query, retailer: retailer, useFallback: true) {
                    print("DEBUG: Found product on \(retailer.displayName) (fallback): \(result.url)")
                    results.append(result)
                    continue
                }
            }

            print("DEBUG: No results found on \(retailer.displayName)")
        }

        guard !results.isEmpty else {
            throw SerperError.noResultsFound
        }

        print("DEBUG: Found \(results.count) retailer URLs total")
        return results
    }

    /// Search for a pet food product on Chewy.com via Google (legacy method)
    /// - Parameter query: Product name and brand to search for
    /// - Returns: The Chewy product URL if found
    func searchChewyProduct(query: String) async throws -> URL {
        let result = try await searchProduct(query: query, retailers: [.chewy])
        return result.url
    }

    // MARK: - Private Methods

    /// Remove size/quantity specs from query (oz, lb, ct, count, pack, etc.)
    /// Always applied before search - these specs rarely match retailer naming
    private func removeSizeSpecs(_ query: String) -> String {
        let sizePattern = #"\s+\d+\s*(oz|lb|lbs|kg|g|ct|count|pk|pack)\.?\s*\d*\s*(ct|count|pk|pack)?.*$"#
        return query
            .replacingOccurrences(of: sizePattern, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
    }

    /// Generate query variations from most specific to least specific
    private func generateQueryVariations(_ query: String) -> [String] {
        // Always start with size specs removed
        let baseQuery = removeSizeSpecs(query)
        var variations: [String] = [baseQuery]

        // Tier 2: Remove manufacturer prefix
        var noManufacturer = baseQuery
        for prefix in manufacturerPrefixes {
            if noManufacturer.hasPrefix(prefix + " ") {
                noManufacturer = String(noManufacturer.dropFirst(prefix.count + 1))
                break
            }
        }
        if noManufacturer != baseQuery && !noManufacturer.isEmpty {
            variations.append(noManufacturer)
        }

        // Tier 3: First 6 words of cleaned query (core product keywords)
        let words = noManufacturer.split(separator: " ")
        if words.count > 6 {
            let coreQuery = words.prefix(6).joined(separator: " ")
            if !variations.contains(coreQuery) {
                variations.append(coreQuery)
            }
        }

        return variations
    }

    /// Extract key identifying words from the product query (brand + distinctive product words)
    /// Used to validate that search results match the target product
    private func extractProductKeywords(_ query: String) -> [String] {
        let baseQuery = removeSizeSpecs(query)
        var cleanedQuery = baseQuery

        // Remove manufacturer prefix to get actual brand
        for prefix in manufacturerPrefixes {
            if cleanedQuery.hasPrefix(prefix + " ") {
                cleanedQuery = String(cleanedQuery.dropFirst(prefix.count + 1))
                break
            }
        }

        let words = cleanedQuery.split(separator: " ").map(String.init)

        // Get brand (first 2 words)
        var keywords = Array(words.prefix(2))

        // Skip common/generic words to find distinctive product identifiers
        let skipWords: Set<String> = [
            // Brand-related
            "pet", "pets", "treatery",
            // Animal types
            "dog", "dogs", "cat", "cats", "puppy", "puppies", "kitten", "kittens", "adult", "senior",
            // Food types
            "food", "foods", "treat", "treats", "kibble", "dry", "wet", "canned", "freeze-dried",
            // Common descriptors
            "natural", "organic", "premium", "grain-free", "holistic",
            // Generic product words
            "recipe", "formula", "blend", "bites", "chunks", "mix", "nutrition",
            // Marketing words
            "breed", "health", "complete", "balanced", "high-protein",
            // Connectors
            "for", "and", "the", "with", "in", "of", "&"
        ]

        // Look through remaining words for distinctive ones
        for word in words.dropFirst(2) {
            let lower = word.lowercased()
            if !skipWords.contains(lower) && word.count > 2 {
                keywords.append(word)
                if keywords.count >= 4 { break }  // Max 4 keywords total
            }
        }

        return keywords
    }

    /// Check if a search result likely matches our target product
    private func resultMatchesProduct(_ result: OrganicResult, keywords: [String]) -> Bool {
        guard keywords.count >= 2 else { return true }

        let titleLower = result.title.lowercased()
        let linkLower = result.link.lowercased()
        let combined = titleLower + " " + linkLower

        // Brand (first keyword) must appear
        guard combined.contains(keywords[0].lowercased()) else {
            return false
        }

        // If we have product keywords (3rd+), at least one must appear
        let productKeywords = Array(keywords.dropFirst(2))
        if !productKeywords.isEmpty {
            let hasMatch = productKeywords.contains { combined.contains($0.lowercased()) }
            if !hasMatch {
                print("DEBUG: Rejected - missing product keywords \(productKeywords) in '\(result.title)'")
                return false
            }
        }

        return true
    }

    /// Search a specific retailer for the product
    private func searchRetailer(query: String, retailer: PetRetailer, useFallback: Bool) async throws -> SerperSearchResult? {
        let siteQuery = useFallback ? (retailer.fallbackSiteQuery ?? retailer.siteQuery) : retailer.siteQuery
        let queryVariations = generateQueryVariations(query)
        let productKeywords = extractProductKeywords(query)

        print("DEBUG: Product keywords for validation: \(productKeywords)")

        for (index, queryVariation) in queryVariations.enumerated() {
            let searchQuery = "\(queryVariation) \(siteQuery)"
            print("DEBUG: Trying query variation \(index + 1)/\(queryVariations.count): \(searchQuery)")

            let response = try await performSearch(query: searchQuery)

            print("DEBUG: Got \(response.organic.count) results")
            for result in response.organic {
                print("DEBUG:   - \(result.link)")
            }

            if let url = findProductURL(in: response, for: retailer, keywords: productKeywords) {
                print("DEBUG: Found valid product URL on variation \(index + 1)")
                return SerperSearchResult(url: url, retailer: retailer)
            }
        }

        return nil
    }

    /// Perform the actual Serper API search
    private func performSearch(query: String) async throws -> SerperResponse {
        guard let url = URL(string: baseURL) else {
            throw SerperError.networkError(underlying: URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 15

        let body = SerperRequest(q: query, num: 5)
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SerperError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SerperError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw SerperError.invalidAPIKey
        case 429:
            throw SerperError.rateLimited
        default:
            throw SerperError.networkError(underlying: URLError(.badServerResponse))
        }

        do {
            return try JSONDecoder().decode(SerperResponse.self, from: data)
        } catch {
            throw SerperError.decodingError(underlying: error)
        }
    }

    /// Find the first valid product URL for a specific retailer that matches the target product
    private func findProductURL(in response: SerperResponse, for retailer: PetRetailer, keywords: [String]) -> URL? {
        for result in response.organic {
            guard let url = URL(string: result.link) else { continue }

            // Must be a valid retailer product URL structure
            guard retailer.isValidProductURL(url) else {
                print("DEBUG: Filtered out \(result.link) - not a valid \(retailer.displayName) product URL")
                continue
            }

            // Must match our target product keywords
            guard resultMatchesProduct(result, keywords: keywords) else {
                print("DEBUG: Filtered out \(result.link) - doesn't match product keywords: \(keywords)")
                continue
            }

            return url
        }
        return nil
    }
}

// MARK: - Request/Response Models

private struct SerperRequest: Encodable {
    let q: String
    let num: Int
}

private struct SerperResponse: Decodable {
    let organic: [OrganicResult]
}

private struct OrganicResult: Decodable {
    let title: String
    let link: String
    let snippet: String?
}
