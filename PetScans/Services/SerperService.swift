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

    /// Known multi-word pet food brands for proper detection
    private let knownMultiWordBrands = [
        "Blue Buffalo", "Royal Canin", "Taste of the Wild", "Natural Balance",
        "Science Diet", "Pro Plan", "Purina ONE", "Purina Pro",
        "Wellness Core", "Instinct Raw", "Solid Gold", "Whole Earth",
        "Diamond Naturals", "American Journey", "Open Farm", "Stella Chewy",
        "Stella & Chewy's", "Nulo Freestyle", "Fromm Family", "Zignature",
        "Nutro Ultra", "Nutro Wholesome", "Merrick Grain", "Merrick Backcountry",
        "Canidae Pure", "Hill's Science", "Hills Science"
    ]

    /// Brand name variations/aliases for better search matching
    private let brandAliases: [String: [String]] = [
        "hills": ["hill's", "hills science diet", "hill's science diet"],
        "hill's": ["hills", "hills science diet", "hill's science diet"],
        "royal canin": ["royalcanin", "royal-canin"],
        "blue buffalo": ["blue", "blue wilderness"],
        "purina one": ["purina 1"],
        "purina pro plan": ["pro plan", "proplan"],
        "wellness": ["wellness core", "wellness complete"],
        "orijen": ["acana"],  // Same company, sometimes confused
        "taste of the wild": ["totw"],
        "natural balance": ["naturalbalance"],
        "canidae": ["canidae pure"],
        "instinct": ["instinct raw", "nature's variety"],
        "stella & chewy's": ["stella chewy", "stella and chewy"],
        "nulo": ["nulo freestyle"],
        "nutro": ["nutro ultra", "nutro wholesome"],
        "merrick": ["merrick grain free", "merrick backcountry"],
        "fromm": ["fromm family"],
    ]

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
        try await searchProduct(query: query, brand: nil, retailers: retailers)
    }

    /// Search for a pet food product across multiple retailers with explicit brand
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - brand: Optional explicit brand name for better matching
    ///   - retailers: Ordered list of retailers to search (first match wins)
    /// - Returns: The product URL and retailer if found
    func searchProduct(query: String, brand: String?, retailers: [PetRetailer]) async throws -> SerperSearchResult {
        let results = try await searchProductURLs(query: query, brand: brand, retailers: retailers)
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
        try await searchProductURLs(query: query, brand: nil, retailers: retailers)
    }

    /// Search for a pet food product across all retailers in parallel with explicit brand
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - brand: Optional explicit brand name for better matching
    ///   - retailers: List of retailers to search
    /// - Returns: Array of product URLs (one per retailer that has a match)
    func searchProductURLs(query: String, brand: String?, retailers: [PetRetailer]) async throws -> [SerperSearchResult] {
        print("DEBUG: Starting parallel retailer search for: \(query)" + (brand.map { " (brand: \($0))" } ?? ""))

        // Search all retailers in parallel
        let results = try await withThrowingTaskGroup(of: SerperSearchResult?.self) { group in
            for retailer in retailers {
                group.addTask {
                    // Try primary (targeted) search first
                    if let result = try await self.searchRetailer(
                        query: query,
                        retailer: retailer,
                        useFallback: false,
                        brand: brand
                    ) {
                        print("DEBUG: Found product on \(retailer.displayName): \(result.url)")
                        return result
                    }

                    // Try fallback (broader) search if primary fails
                    if retailer.fallbackSiteQuery != nil {
                        if let result = try await self.searchRetailer(
                            query: query,
                            retailer: retailer,
                            useFallback: true,
                            brand: brand
                        ) {
                            print("DEBUG: Found product on \(retailer.displayName) (fallback): \(result.url)")
                            return result
                        }
                    }

                    print("DEBUG: No results found on \(retailer.displayName)")
                    return nil
                }
            }

            // Collect all successful results
            var collectedResults: [SerperSearchResult] = []
            for try await result in group {
                if let result = result {
                    collectedResults.append(result)
                }
            }
            return collectedResults
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

    // MARK: Query Preprocessing

    /// Normalize product name for search - handles special chars, abbreviations, and common patterns
    private func normalizeProductName(_ query: String) -> String {
        var result = query

        // 1. Expand common abbreviations
        let abbreviations: [(pattern: String, replacement: String)] = [
            (#"\bw/\s*"#, "with "),
            (#"\s*&\s*"#, " and "),
            (#"(?i)\bdr\.?\s+"#, "Doctor "),
            (#"(?i)\blrg\.?\s*"#, "large "),
            (#"(?i)\bsm\.?\s*"#, "small "),
            (#"(?i)\bmed\.?\s*"#, "medium "),
        ]

        for (pattern, replacement) in abbreviations {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        // 2. Remove trademark symbols
        result = result.replacingOccurrences(of: "®", with: "")
        result = result.replacingOccurrences(of: "™", with: "")
        result = result.replacingOccurrences(of: "©", with: "")

        // 3. Normalize apostrophes (smart quotes -> straight)
        result = result.replacingOccurrences(of: "'", with: "'")
        result = result.replacingOccurrences(of: "'", with: "'")

        // 4. Remove content in parentheses if it's size/count info
        let parenSizePattern = #"\s*\([^)]*\d+\s*(oz|lb|kg|ct|count|pack)[^)]*\)"#
        result = result.replacingOccurrences(
            of: parenSizePattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // 5. Normalize hyphens and dashes
        result = result.replacingOccurrences(of: "–", with: "-")
        result = result.replacingOccurrences(of: "—", with: "-")

        // 6. Remove multiple consecutive spaces
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Remove size/quantity specs from query (oz, lb, ct, count, pack, etc.)
    /// Always applied before search - these specs rarely match retailer naming
    private func removeSizeSpecs(_ query: String) -> String {
        // More comprehensive pattern that also catches mid-query sizes
        let patterns = [
            #"\s+\d+(\.\d+)?\s*-?\s*(oz|ounce|ounces|lb|lbs|pound|pounds|kg|g|gram|grams|ct|count|pk|pack|can|cans|pouch|pouches)\.?\s*"#,
            #"\s*\(\s*\d+[^)]*\)\s*"#,  // Anything in parentheses with numbers
            #"\s+x\d+\s*"#,  // "x12" style multipliers
        ]

        var result = query
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Get all variations of a brand name for search
    private func getBrandVariations(_ brand: String) -> [String] {
        let normalized = brand.lowercased().trimmingCharacters(in: .whitespaces)
        var variations = [brand]

        // Check if this brand has known aliases
        if let aliases = brandAliases[normalized] {
            variations.append(contentsOf: aliases)
        }

        // Also check if this brand IS an alias of another brand
        for (key, aliases) in brandAliases {
            if aliases.map({ $0.lowercased() }).contains(normalized) {
                variations.append(key)
                variations.append(contentsOf: aliases)
            }
        }

        return Array(Set(variations))
    }

    /// Detect known multi-word brands in the query
    private func detectBrand(from words: [String]) -> String? {
        let queryStart = words.prefix(5).joined(separator: " ").lowercased()

        for brand in knownMultiWordBrands {
            if queryStart.hasPrefix(brand.lowercased()) {
                return brand
            }
        }

        return nil
    }

    // MARK: Query Variation Generation

    /// Generate query variations from most specific to least specific
    private func generateQueryVariations(_ query: String, brand: String? = nil) -> [String] {
        // Normalize and remove size specs
        let normalizedQuery = normalizeProductName(query)
        let baseQuery = removeSizeSpecs(normalizedQuery)
        var variations: [String] = []

        // Tier 1: Full normalized query
        variations.append(baseQuery)

        // Tier 1b: Query with quoted multi-word brand for exact matching
        let words = baseQuery.split(separator: " ").map(String.init)
        if let detectedBrand = brand ?? detectBrand(from: words) {
            if detectedBrand.contains(" ") {
                let quotedBrandQuery = "\"\(detectedBrand)\" " + baseQuery
                    .replacingOccurrences(of: detectedBrand, with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                if !quotedBrandQuery.isEmpty && !variations.contains(quotedBrandQuery) {
                    variations.append(quotedBrandQuery)
                }
            }
        }

        // Tier 2: Remove manufacturer prefix
        var noManufacturer = baseQuery
        for prefix in manufacturerPrefixes {
            if noManufacturer.lowercased().hasPrefix(prefix.lowercased() + " ") {
                noManufacturer = String(noManufacturer.dropFirst(prefix.count + 1))
                break
            }
        }
        if noManufacturer != baseQuery && !noManufacturer.isEmpty && !variations.contains(noManufacturer) {
            variations.append(noManufacturer)
        }

        // Tier 3: Core product terms (brand + distinctive keywords only)
        let coreTerms = extractCoreProductTerms(noManufacturer)
        if !coreTerms.isEmpty && !variations.contains(coreTerms) {
            variations.append(coreTerms)
        }

        // Tier 4: First 6 words of cleaned query
        let cleanedWords = noManufacturer.split(separator: " ")
        if cleanedWords.count > 6 {
            let shortQuery = cleanedWords.prefix(6).joined(separator: " ")
            if !variations.contains(shortQuery) {
                variations.append(shortQuery)
            }
        }

        // Tier 5: Try brand aliases (only add first alias to limit API calls)
        if let brand = brand ?? detectBrand(from: words) {
            let aliases = getBrandVariations(brand)
            if let firstAlias = aliases.first(where: { $0.lowercased() != brand.lowercased() }) {
                let aliasQuery = baseQuery.replacingOccurrences(
                    of: brand,
                    with: firstAlias,
                    options: .caseInsensitive
                )
                if aliasQuery != baseQuery && !variations.contains(aliasQuery) {
                    variations.append(aliasQuery)
                }
            }
        }

        print("DEBUG: Generated \(variations.count) query variations")
        return variations
    }

    /// Extract core product terms (brand + distinctive keywords, skip generic terms)
    private func extractCoreProductTerms(_ query: String) -> String {
        let words = query.split(separator: " ").map(String.init)

        // Generic terms to skip
        let genericTerms: Set<String> = [
            "food", "foods", "dog", "cat", "puppy", "kitten", "adult", "senior",
            "dry", "wet", "canned", "recipe", "formula", "complete", "balanced",
            "natural", "organic", "premium", "grain-free", "holistic",
            "nutrition", "health", "healthy", "breed", "small", "large", "medium",
            "indoor", "outdoor", "active", "weight", "management", "sensitive",
            "digestive", "original", "classic", "traditional", "real", "made",
            "high", "protein", "low", "fat", "fiber", "calorie"
        ]

        var kept: [String] = []

        for (index, word) in words.enumerated() {
            let lower = word.lowercased()

            // Always keep first 2 words (usually brand)
            if index < 2 {
                kept.append(word)
            } else if !genericTerms.contains(lower) && word.count > 2 {
                // Keep distinctive terms (protein sources, specific product lines)
                kept.append(word)
            }

            // Limit to 5 significant terms
            if kept.count >= 5 { break }
        }

        return kept.joined(separator: " ")
    }

    // MARK: Keyword Extraction

    /// Product keywords structure for validation
    private struct ProductKeywords {
        let brand: [String]
        let product: [String]
        let original: String

        var isEmpty: Bool { brand.isEmpty && product.isEmpty }

        /// All keywords combined for legacy compatibility
        var all: [String] { brand + product }
    }

    /// Extract key identifying words from the product query (brand + distinctive product words)
    /// Used to validate that search results match the target product
    private func extractProductKeywords(_ query: String, brand: String? = nil) -> ProductKeywords {
        let normalizedQuery = normalizeProductName(query)
        let baseQuery = removeSizeSpecs(normalizedQuery)
        var cleanedQuery = baseQuery

        // Remove manufacturer prefix to get actual brand
        for prefix in manufacturerPrefixes {
            if cleanedQuery.lowercased().hasPrefix(prefix.lowercased() + " ") {
                cleanedQuery = String(cleanedQuery.dropFirst(prefix.count + 1))
                break
            }
        }

        let words = cleanedQuery.split(separator: " ").map(String.init)

        // Detect multi-word brand or use provided brand
        let detectedBrand = brand ?? detectBrand(from: words)
        let brandWordCount: Int
        if let detected = detectedBrand {
            brandWordCount = detected.split(separator: " ").count
        } else {
            brandWordCount = min(2, words.count)  // Default: first 2 words
        }

        // Extract brand keywords
        let brandKeywords = Array(words.prefix(brandWordCount))

        // Skip common/generic words to find distinctive product identifiers
        let skipWords: Set<String> = [
            // Brand-related
            "pet", "pets", "treatery",
            // Animal types
            "dog", "dogs", "cat", "cats", "puppy", "puppies", "kitten", "kittens", "adult", "senior",
            // Food types
            "food", "foods", "treat", "treats", "kibble", "dry", "wet", "canned", "freeze-dried",
            "raw", "frozen", "dehydrated",
            // Common descriptors
            "natural", "organic", "premium", "grain-free", "holistic", "limited", "ingredient",
            // Generic product words
            "recipe", "formula", "blend", "bites", "chunks", "mix", "nutrition", "diet",
            // Marketing words
            "breed", "health", "complete", "balanced", "high-protein", "real", "made",
            // Size/age descriptors
            "small", "medium", "large", "mini", "giant", "toy",
            // Connectors
            "for", "and", "the", "with", "in", "of", "&", "a", "an"
        ]

        // Extract product keywords (distinctive terms after brand)
        var productKeywords: [String] = []
        for word in words.dropFirst(brandWordCount) {
            let lower = word.lowercased()
            if !skipWords.contains(lower) && word.count > 2 {
                productKeywords.append(word)
                if productKeywords.count >= 3 { break }  // Max 3 product keywords
            }
        }

        return ProductKeywords(
            brand: brandKeywords,
            product: productKeywords,
            original: cleanedQuery
        )
    }

    // MARK: Result Matching

    /// Check if a search result likely matches our target product (uses ProductKeywords)
    private func resultMatchesProduct(_ result: OrganicResult, keywords: ProductKeywords) -> Bool {
        guard !keywords.isEmpty else { return true }

        let titleLower = result.title.lowercased()
        let linkLower = result.link.lowercased()
        let combined = titleLower + " " + linkLower

        // Brand validation: at least one brand keyword must match (with fuzzy fallback)
        let brandMatched = keywords.brand.contains { keyword in
            let keywordLower = keyword.lowercased()
            return combined.contains(keywordLower) ||
                   fuzzyContains(combined, keyword: keywordLower, threshold: 0.8)
        }

        guard brandMatched else {
            print("DEBUG: Rejected - no brand match for \(keywords.brand) in '\(result.title)'")
            return false
        }

        // Product keyword validation: if we have them, at least one must match
        if !keywords.product.isEmpty {
            let productMatched = keywords.product.contains { keyword in
                let keywordLower = keyword.lowercased()
                return combined.contains(keywordLower) ||
                       fuzzyContains(combined, keyword: keywordLower, threshold: 0.85)
            }

            if !productMatched {
                print("DEBUG: Rejected - no product keyword match for \(keywords.product) in '\(result.title)'")
                return false
            }
        }

        return true
    }

    // MARK: Fuzzy Matching

    /// Check if text contains a keyword with fuzzy matching (Levenshtein-based)
    private func fuzzyContains(_ text: String, keyword: String, threshold: Double) -> Bool {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for word in words {
            // Only compare words of similar length to avoid false positives
            if word.count >= keyword.count - 2 && word.count <= keyword.count + 2 {
                let similarity = stringSimilarity(word, keyword)
                if similarity >= threshold {
                    return true
                }
            }
        }

        return false
    }

    /// Calculate string similarity (0.0 to 1.0) using Levenshtein distance
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        let s1Lower = s1.lowercased()
        let s2Lower = s2.lowercased()

        if s1Lower == s2Lower { return 1.0 }
        if s1Lower.isEmpty || s2Lower.isEmpty { return 0.0 }

        let distance = levenshteinDistance(s1Lower, s2Lower)
        let maxLength = max(s1Lower.count, s2Lower.count)

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Calculate Levenshtein edit distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { matrix[i][0] = i }
        for j in 0...b.count { matrix[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[a.count][b.count]
    }

    // MARK: Retailer Search

    /// Search a specific retailer for the product
    private func searchRetailer(
        query: String,
        retailer: PetRetailer,
        useFallback: Bool,
        brand: String? = nil
    ) async throws -> SerperSearchResult? {
        let siteQuery = useFallback ? (retailer.fallbackSiteQuery ?? retailer.siteQuery) : retailer.siteQuery
        let queryVariations = generateQueryVariations(query, brand: brand)
        let productKeywords = extractProductKeywords(query, brand: brand)

        print("DEBUG: Product keywords for validation - brand: \(productKeywords.brand), product: \(productKeywords.product)")

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

            // Early exit: if we got zero organic results on a broad query, skip remaining variations
            if response.organic.isEmpty && index >= 2 {
                print("DEBUG: No organic results on variation \(index + 1), skipping remaining for \(retailer.displayName)")
                break
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
    private func findProductURL(in response: SerperResponse, for retailer: PetRetailer, keywords: ProductKeywords) -> URL? {
        for result in response.organic {
            guard let url = URL(string: result.link) else { continue }

            // Must be a valid retailer product URL structure
            guard retailer.isValidProductURL(url) else {
                print("DEBUG: Filtered out \(result.link) - not a valid \(retailer.displayName) product URL")
                continue
            }

            // Must match our target product keywords
            guard resultMatchesProduct(result, keywords: keywords) else {
                print("DEBUG: Filtered out \(result.link) - doesn't match product keywords")
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
