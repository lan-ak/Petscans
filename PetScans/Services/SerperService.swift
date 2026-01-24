import Foundation

/// Actor-based service for Google search via Serper.dev API
/// Used to find pet food product URLs on retailers and manufacturer sites
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

    /// Brand to manufacturer mapping for known brands
    private let brandToManufacturer: [String: ProductSource] = [
        // Purina brands
        "purina": .purina,
        "pro plan": .purina,
        "purina pro plan": .purina,
        "friskies": .purina,
        "fancy feast": .purina,
        "beneful": .purina,
        "purina one": .purina,
        "one": .purina,
        "beyond": .purina,
        "dog chow": .purina,
        "cat chow": .purina,
        "alpo": .purina,
        "moist & meaty": .purina,

        // Hill's brands
        "hill's": .hillspet,
        "hills": .hillspet,
        "science diet": .hillspet,
        "hill's science diet": .hillspet,
        "hills science diet": .hillspet,
        "prescription diet": .hillspet,
        "healthy advantage": .hillspet,

        // Royal Canin
        "royal canin": .royalcanin,
        "royalcanin": .royalcanin,

        // Blue Buffalo
        "blue buffalo": .bluebuffalo,
        "blue": .bluebuffalo,
        "blue wilderness": .bluebuffalo,
        "blue basics": .bluebuffalo,
        "blue freedom": .bluebuffalo,
        "blue life protection": .bluebuffalo,

        // Iams
        "iams": .iams,
        "iams proactive": .iams,

        // Nutro
        "nutro": .nutro,
        "nutro ultra": .nutro,
        "nutro wholesome": .nutro,
        "wholesome essentials": .nutro,

        // Merrick
        "merrick": .merrick,
        "merrick grain free": .merrick,
        "merrick backcountry": .merrick,

        // Wellness
        "wellness": .wellness,
        "wellness core": .wellness,
        "wellness complete": .wellness,
        "wellness simple": .wellness,

        // Champion Petfoods
        "orijen": .orijen,
        "acana": .acana,

        // Canidae
        "canidae": .canidae,
        "canidae pure": .canidae,
        "canidae all life stages": .canidae,

        // Fromm
        "fromm": .fromm,
        "fromm family": .fromm,
        "fromm gold": .fromm,
        "fromm four star": .fromm,

        // Taste of the Wild
        "taste of the wild": .tasteOfTheWild,
        "totw": .tasteOfTheWild,

        // Zignature
        "zignature": .zignature,

        // Nulo
        "nulo": .nulo,
        "nulo freestyle": .nulo,
        "nulo medal series": .nulo,

        // Solid Gold
        "solid gold": .solidGold,

        // Victor
        "victor": .victorDog,
        "victor dog food": .victorDog,

        // Stella & Chewy's
        "stella & chewy's": .stellaChewy,
        "stella chewy": .stellaChewy,
        "stella and chewy": .stellaChewy,

        // Open Farm
        "open farm": .openFarm,

        // The Honest Kitchen
        "honest kitchen": .honestKitchen,
        "the honest kitchen": .honestKitchen,

        // Instinct
        "instinct": .instinct,
        "instinct raw": .instinct,
        "nature's variety": .instinct,

        // Natural Balance
        "natural balance": .naturalBalance,
        "naturalbalance": .naturalBalance,

        // Rachael Ray
        "rachael ray": .rachealRay,
        "nutrish": .rachealRay,
        "rachael ray nutrish": .rachealRay,

        // Earthborn
        "earthborn": .earthborn,
        "earthborn holistic": .earthborn,

        // Diamond
        "diamond": .diamondPet,
        "diamond naturals": .diamondPet,
        "diamond pro": .diamondPet,
    ]

    /// Known retailer domains to filter out during dynamic discovery
    private let retailerDomains: Set<String> = [
        "chewy.com", "petco.com", "petsmart.com", "petsmart.ca",
        "amazon.com", "walmart.com", "target.com", "costco.com",
        "petflow.com", "petfooddirect.com", "1800petmeds.com",
        "entirelypets.com", "petmountain.com", "pets.com",
        "rover.com", "wag.com", "bark.com"
    ]

    /// Known blog/review sites to filter out during dynamic discovery
    private let blogDomains: Set<String> = [
        "dogfoodadvisor.com", "catfooddb.com", "petfoodreviewer.com",
        "allaboutpetfood.com", "pawdiet.com", "petmd.com",
        "akc.org", "aspca.org", "wikipedia.org"
    ]

    // MARK: - Init

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Search for a pet food product across multiple sources
    func searchProduct(query: String, retailers: [ProductSource]) async throws -> SerperSearchResult {
        try await searchProduct(query: query, brand: nil, retailers: retailers)
    }

    /// Search for a pet food product across multiple sources with explicit brand
    func searchProduct(query: String, brand: String?, retailers: [ProductSource]) async throws -> SerperSearchResult {
        let results = try await searchProductURLs(query: query, brand: brand, retailers: retailers)
        guard let first = results.first else {
            throw SerperError.noResultsFound
        }
        return first
    }

    /// Search for a pet food product across all sources, returning all matches
    func searchProductURLs(query: String, retailers: [ProductSource]) async throws -> [SerperSearchResult] {
        try await searchProductURLs(query: query, brand: nil, retailers: retailers)
    }

    /// Search for a pet food product across all sources in parallel with explicit brand
    /// Automatically includes manufacturer site if brand is detected
    func searchProductURLs(query: String, brand: String?, retailers: [ProductSource]) async throws -> [SerperSearchResult] {
        print("DEBUG: Starting parallel search for: \(query)" + (brand.map { " (brand: \($0))" } ?? ""))

        // Get manufacturer source for brand (if any)
        let manufacturerSource = getManufacturerSource(for: brand)
        let discoveredSiteQuery: String? = await {
            // If we have a brand but no known manufacturer, try dynamic discovery
            if let brand = brand, manufacturerSource == nil {
                return await discoverBrandWebsite(brand: brand)
            }
            return nil
        }()

        if let manufacturer = manufacturerSource {
            print("DEBUG: Found manufacturer source: \(manufacturer.displayName)")
        } else if let discovered = discoveredSiteQuery {
            print("DEBUG: Discovered brand website: \(discovered)")
        }

        // Search all sources in parallel
        let results = try await withThrowingTaskGroup(of: SerperSearchResult?.self) { group in
            // Add retailer search tasks
            for source in retailers {
                group.addTask {
                    try await self.searchSource(
                        query: query,
                        source: source,
                        useFallback: false,
                        brand: brand
                    )
                }
            }

            // Add manufacturer search task (if found)
            if let manufacturer = manufacturerSource {
                group.addTask {
                    try await self.searchSource(
                        query: query,
                        source: manufacturer,
                        useFallback: false,
                        brand: brand
                    )
                }
            }

            // Add dynamically discovered site search task (if found)
            if let discoveredQuery = discoveredSiteQuery {
                group.addTask {
                    try await self.searchDynamicSource(
                        query: query,
                        siteQuery: discoveredQuery,
                        brand: brand
                    )
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

        print("DEBUG: Found \(results.count) URLs total")
        return results
    }

    /// Search for a pet food product on Chewy.com via Google (legacy method)
    func searchChewyProduct(query: String) async throws -> URL {
        let result = try await searchProduct(query: query, retailers: [.chewy])
        return result.url
    }

    // MARK: - Brand to Manufacturer Mapping

    /// Get the manufacturer ProductSource for a given brand
    private func getManufacturerSource(for brand: String?) -> ProductSource? {
        guard let brand = brand?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return nil
        }

        // Direct lookup
        if let source = brandToManufacturer[brand] {
            return source
        }

        // Try partial matches (e.g., "purina pro plan sport" should match "purina pro plan")
        for (key, source) in brandToManufacturer {
            if brand.hasPrefix(key + " ") || brand.contains(key) {
                return source
            }
        }

        return nil
    }

    // MARK: - Dynamic Website Discovery

    /// Discover a brand's official website via Google search
    private func discoverBrandWebsite(brand: String) async -> String? {
        let searchQuery = "\(brand) pet food official site"
        print("DEBUG: Attempting to discover website for brand: \(brand)")

        do {
            let response = try await performSearch(query: searchQuery)

            for result in response.organic {
                guard let url = URL(string: result.link),
                      let host = url.host?.lowercased() else {
                    continue
                }

                // Extract domain (remove www. prefix)
                let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

                // Skip retailer domains
                if retailerDomains.contains(where: { domain.contains($0) }) {
                    print("DEBUG: Skipping retailer domain: \(domain)")
                    continue
                }

                // Skip blog/review domains
                if blogDomains.contains(where: { domain.contains($0) }) {
                    print("DEBUG: Skipping blog domain: \(domain)")
                    continue
                }

                // Found a valid manufacturer site
                let siteQuery = "site:\(domain)"
                print("DEBUG: Discovered brand website: \(siteQuery)")
                return siteQuery
            }
        } catch {
            print("DEBUG: Website discovery failed: \(error)")
        }

        return nil
    }

    // MARK: - Source Search

    /// Search a specific source for the product
    private func searchSource(
        query: String,
        source: ProductSource,
        useFallback: Bool,
        brand: String? = nil
    ) async throws -> SerperSearchResult? {
        let siteQuery = useFallback ? (source.fallbackSiteQuery ?? source.siteQuery) : source.siteQuery
        let queryVariations = generateQueryVariations(query, brand: brand)
        let productKeywords = extractProductKeywords(query, brand: brand)

        print("DEBUG: Searching \(source.displayName) - keywords: brand=\(productKeywords.brand), product=\(productKeywords.product)")

        for (index, queryVariation) in queryVariations.enumerated() {
            let searchQuery = "\(queryVariation) \(siteQuery)"
            print("DEBUG: [\(source.displayName)] Trying variation \(index + 1)/\(queryVariations.count): \(searchQuery)")

            let response = try await performSearch(query: searchQuery)

            print("DEBUG: [\(source.displayName)] Got \(response.organic.count) results")

            if let url = findProductURL(in: response, for: source, keywords: productKeywords) {
                print("DEBUG: [\(source.displayName)] Found valid product URL: \(url)")
                return SerperSearchResult(url: url, source: source)
            }

            // Early exit: if we got zero organic results on a broad query, skip remaining variations
            if response.organic.isEmpty && index >= 2 {
                print("DEBUG: [\(source.displayName)] No results on variation \(index + 1), skipping remaining")
                break
            }
        }

        // Try fallback for retailers if available
        if source.isRetailer && !useFallback && source.fallbackSiteQuery != nil {
            print("DEBUG: [\(source.displayName)] Trying fallback search")
            return try await searchSource(query: query, source: source, useFallback: true, brand: brand)
        }

        print("DEBUG: [\(source.displayName)] No results found")
        return nil
    }

    /// Search a dynamically discovered site
    private func searchDynamicSource(
        query: String,
        siteQuery: String,
        brand: String?
    ) async throws -> SerperSearchResult? {
        let queryVariations = generateQueryVariations(query, brand: brand)
        let productKeywords = extractProductKeywords(query, brand: brand)

        print("DEBUG: Searching dynamic source \(siteQuery)")

        for (index, queryVariation) in queryVariations.enumerated() {
            let searchQuery = "\(queryVariation) \(siteQuery)"

            let response = try await performSearch(query: searchQuery)

            for result in response.organic {
                guard let url = URL(string: result.link) else { continue }

                // Validate the result matches our product
                guard resultMatchesProduct(result, keywords: productKeywords) else {
                    continue
                }

                // For dynamic sources, we accept any result from the discovered domain
                print("DEBUG: [Dynamic] Found URL: \(url)")
                // Return as the first matched retailer source for compatibility
                // The data source display will show based on URL domain
                return SerperSearchResult(url: url, source: .chewy)  // Will be corrected by Firecrawl extraction
            }

            if response.organic.isEmpty && index >= 2 {
                break
            }
        }

        return nil
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
    private func removeSizeSpecs(_ query: String) -> String {
        let patterns = [
            #"\s+\d+(\.\d+)?\s*-?\s*(oz|ounce|ounces|lb|lbs|pound|pounds|kg|g|gram|grams|ct|count|pk|pack|can|cans|pouch|pouches)\.?\s*"#,
            #"\s*\(\s*\d+[^)]*\)\s*"#,
            #"\s+x\d+\s*"#,
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

        if let aliases = brandAliases[normalized] {
            variations.append(contentsOf: aliases)
        }

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
        let normalizedQuery = normalizeProductName(query)
        let baseQuery = removeSizeSpecs(normalizedQuery)
        var variations: [String] = []

        variations.append(baseQuery)

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

        let coreTerms = extractCoreProductTerms(noManufacturer)
        if !coreTerms.isEmpty && !variations.contains(coreTerms) {
            variations.append(coreTerms)
        }

        let cleanedWords = noManufacturer.split(separator: " ")
        if cleanedWords.count > 6 {
            let shortQuery = cleanedWords.prefix(6).joined(separator: " ")
            if !variations.contains(shortQuery) {
                variations.append(shortQuery)
            }
        }

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

        return variations
    }

    /// Extract core product terms (brand + distinctive keywords, skip generic terms)
    private func extractCoreProductTerms(_ query: String) -> String {
        let words = query.split(separator: " ").map(String.init)

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

            if index < 2 {
                kept.append(word)
            } else if !genericTerms.contains(lower) && word.count > 2 {
                kept.append(word)
            }

            if kept.count >= 5 { break }
        }

        return kept.joined(separator: " ")
    }

    // MARK: Keyword Extraction

    private struct ProductKeywords {
        let brand: [String]
        let product: [String]
        let original: String

        var isEmpty: Bool { brand.isEmpty && product.isEmpty }
        var all: [String] { brand + product }
    }

    private func extractProductKeywords(_ query: String, brand: String? = nil) -> ProductKeywords {
        let normalizedQuery = normalizeProductName(query)
        let baseQuery = removeSizeSpecs(normalizedQuery)
        var cleanedQuery = baseQuery

        for prefix in manufacturerPrefixes {
            if cleanedQuery.lowercased().hasPrefix(prefix.lowercased() + " ") {
                cleanedQuery = String(cleanedQuery.dropFirst(prefix.count + 1))
                break
            }
        }

        let words = cleanedQuery.split(separator: " ").map(String.init)

        let detectedBrand = brand ?? detectBrand(from: words)
        let brandWordCount: Int
        if let detected = detectedBrand {
            brandWordCount = detected.split(separator: " ").count
        } else {
            brandWordCount = min(2, words.count)
        }

        let brandKeywords = Array(words.prefix(brandWordCount))

        let skipWords: Set<String> = [
            "pet", "pets", "treatery",
            "dog", "dogs", "cat", "cats", "puppy", "puppies", "kitten", "kittens", "adult", "senior",
            "food", "foods", "treat", "treats", "kibble", "dry", "wet", "canned", "freeze-dried",
            "raw", "frozen", "dehydrated",
            "natural", "organic", "premium", "grain-free", "holistic", "limited", "ingredient",
            "recipe", "formula", "blend", "bites", "chunks", "mix", "nutrition", "diet",
            "breed", "health", "complete", "balanced", "high-protein", "real", "made",
            "small", "medium", "large", "mini", "giant", "toy",
            "for", "and", "the", "with", "in", "of", "&", "a", "an"
        ]

        var productKeywords: [String] = []
        for word in words.dropFirst(brandWordCount) {
            let lower = word.lowercased()
            if !skipWords.contains(lower) && word.count > 2 {
                productKeywords.append(word)
                if productKeywords.count >= 3 { break }
            }
        }

        return ProductKeywords(
            brand: brandKeywords,
            product: productKeywords,
            original: cleanedQuery
        )
    }

    // MARK: Result Matching

    private func resultMatchesProduct(_ result: OrganicResult, keywords: ProductKeywords) -> Bool {
        guard !keywords.isEmpty else { return true }

        let titleLower = result.title.lowercased()
        let linkLower = result.link.lowercased()
        let combined = titleLower + " " + linkLower

        let brandMatched = keywords.brand.contains { keyword in
            let keywordLower = keyword.lowercased()
            return combined.contains(keywordLower) ||
                   fuzzyContains(combined, keyword: keywordLower, threshold: 0.8)
        }

        guard brandMatched else {
            return false
        }

        if !keywords.product.isEmpty {
            let productMatched = keywords.product.contains { keyword in
                let keywordLower = keyword.lowercased()
                return combined.contains(keywordLower) ||
                       fuzzyContains(combined, keyword: keywordLower, threshold: 0.85)
            }

            if !productMatched {
                return false
            }
        }

        return true
    }

    // MARK: Fuzzy Matching

    private func fuzzyContains(_ text: String, keyword: String, threshold: Double) -> Bool {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for word in words {
            if word.count >= keyword.count - 2 && word.count <= keyword.count + 2 {
                let similarity = stringSimilarity(word, keyword)
                if similarity >= threshold {
                    return true
                }
            }
        }

        return false
    }

    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        let s1Lower = s1.lowercased()
        let s2Lower = s2.lowercased()

        if s1Lower == s2Lower { return 1.0 }
        if s1Lower.isEmpty || s2Lower.isEmpty { return 0.0 }

        let distance = levenshteinDistance(s1Lower, s2Lower)
        let maxLength = max(s1Lower.count, s2Lower.count)

        return 1.0 - (Double(distance) / Double(maxLength))
    }

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
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }

        return matrix[a.count][b.count]
    }

    // MARK: URL Finding

    private func findProductURL(in response: SerperResponse, for source: ProductSource, keywords: ProductKeywords) -> URL? {
        for result in response.organic {
            guard let url = URL(string: result.link) else { continue }

            guard source.isValidProductURL(url) else {
                continue
            }

            guard resultMatchesProduct(result, keywords: keywords) else {
                continue
            }

            return url
        }
        return nil
    }

    // MARK: API

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
