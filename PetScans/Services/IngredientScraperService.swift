import Foundation

/// Actor-based web scraping service for pet food ingredients
/// Searches Chewy, PetSmart, and Petco for product ingredient lists
actor IngredientScraperService: IngredientScraperServiceProtocol {

    // MARK: - Properties

    private let session: URLSession

    /// User agents to rotate through (helps avoid blocking)
    private let userAgents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ]

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public Methods

    /// Scrape ingredients directly from a known product URL
    /// - Parameters:
    ///   - url: The product page URL to scrape
    ///   - source: The retailer/source for site-specific parsing
    /// - Returns: Scraped ingredient data
    func scrapeFromURL(_ url: URL, source: ScrapingSource) async throws -> ScrapedIngredients {
        print("DEBUG: Scraping ingredients from \(source.rawValue): \(url.absoluteString)")

        // Fetch product page
        let productHTML = try await fetchPage(url: url)

        // Extract ingredients from product page
        guard let ingredients = extractIngredients(from: productHTML, source: source) else {
            throw ScrapingError.ingredientsNotFound
        }

        // Extract product name from page if possible
        let scrapedProductName = extractProductName(from: productHTML, source: source)

        return ScrapedIngredients(
            source: source,
            productName: scrapedProductName,
            brand: nil,
            ingredientsText: ingredients,
            confidence: .medium,
            sourceURL: url
        )
    }

    /// Search for and scrape ingredients from pet food websites
    /// Tries manufacturer site first if brand matches, then falls back to retailers
    func searchAndScrape(productName: String, brand: String?) async throws -> ScrapedIngredients {
        let searchQuery = buildSearchQuery(productName: productName, brand: brand)

        // Build prioritized source list based on brand
        let sources = buildSourcePriority(brand: brand)
        var isFirstSource = true

        for source in sources {
            do {
                // Add delay between requests to be respectful
                if !isFirstSource {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                }
                isFirstSource = false

                let result = try await scrapeFromSource(source, query: searchQuery)
                return result
            } catch {
                // Log failure and try next source
                print("Scraping failed for \(source.rawValue): \(error.localizedDescription)")
                continue
            }
        }

        // All sources failed
        throw ScrapingError.allSourcesFailed
    }

    /// Build prioritized source list based on brand name
    /// Tries manufacturer site first if brand matches, then falls back to retailers
    private func buildSourcePriority(brand: String?) -> [ScrapingSource] {
        var sources: [ScrapingSource] = []

        // If brand matches a manufacturer, try that first
        if let brand = brand?.lowercased() {
            if brand.contains("purina") || brand.contains("pro plan") || brand.contains("fancy feast") || brand.contains("friskies") || brand.contains("beneful") {
                sources.append(.purina)
            } else if brand.contains("hill") || brand.contains("science diet") || brand.contains("healthy advantage") {
                sources.append(.hillspet)
            } else if brand.contains("royal canin") {
                sources.append(.royalcanin)
            } else if brand.contains("blue buffalo") || brand.contains("blue wilderness") || brand.contains("blue basics") {
                sources.append(.bluebuffalo)
            } else if brand.contains("iams") {
                sources.append(.iams)
            } else if brand.contains("nutro") || brand.contains("wholesome essentials") {
                sources.append(.nutro)
            }
        }

        // Then try general retailers (Chewy is usually most reliable)
        sources.append(contentsOf: [.chewy, .petco])

        return sources
    }

    // MARK: - Private Methods

    /// Build search query from product name and brand
    private func buildSearchQuery(productName: String, brand: String?) -> String {
        if let brand = brand, !brand.isEmpty {
            return "\(brand) \(productName)"
        }
        return productName
    }

    /// Get a random user agent for requests
    private func randomUserAgent() -> String {
        userAgents.randomElement() ?? userAgents[0]
    }

    /// Scrape ingredients from a specific source
    private func scrapeFromSource(_ source: ScrapingSource, query: String) async throws -> ScrapedIngredients {
        // Build search URL
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: String(format: source.searchURLPattern, encodedQuery)) else {
            throw ScrapingError.networkError(underlying: URLError(.badURL))
        }

        // Fetch search results page
        let searchHTML = try await fetchPage(url: searchURL)

        // Find first product link
        guard let productURL = extractFirstProductURL(from: searchHTML, source: source) else {
            throw ScrapingError.noResultsFound
        }

        // Fetch product page
        let productHTML = try await fetchPage(url: productURL)

        // Extract ingredients from product page
        guard let ingredients = extractIngredients(from: productHTML, source: source) else {
            throw ScrapingError.ingredientsNotFound
        }

        // Extract product name from page if possible
        let scrapedProductName = extractProductName(from: productHTML, source: source)

        return ScrapedIngredients(
            source: source,
            productName: scrapedProductName,
            brand: nil, // Could parse this too if needed
            ingredientsText: ingredients,
            confidence: .medium,
            sourceURL: productURL
        )
    }

    /// Fetch a page and return its HTML content
    private func fetchPage(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ScrapingError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScrapingError.networkError(underlying: URLError(.badServerResponse))
        }

        // Check for blocking (403, 429, etc.)
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
            throw ScrapingError.blocked
        }

        guard httpResponse.statusCode == 200 else {
            throw ScrapingError.networkError(underlying: URLError(.badServerResponse))
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ScrapingError.parsingFailed(underlying: nil)
        }

        return html
    }

    /// Extract first product URL from search results
    /// Uses regex patterns instead of SwiftSoup for simplicity
    private func extractFirstProductURL(from html: String, source: ScrapingSource) -> URL? {
        let pattern: String

        switch source {
        // Retailers
        case .chewy:
            // Chewy product URLs: /dp/123456 or /product/name
            pattern = #"href="(/dp/\d+[^"]*)"#

        case .petco:
            // Petco product URLs contain /shop/en/petcostore/product
            pattern = #"href="(/shop/en/petcostore/product[^"]*)"#

        case .petsmart:
            // PetSmart product URLs: /category/subcategory/product-name-12345.html
            pattern = #"href="(/[^"]*-\d+\.html)"#

        // Manufacturer sites
        case .purina:
            // Purina product URLs: /dogs/dog-food/dry-dog-food/pro-plan-...
            pattern = #"href="(/(?:dogs?|cats?)/[^"]*-food[^"]*)"#

        case .hillspet:
            // Hill's product URLs: /dog-food/pd-... or /cat-food/sd-...
            pattern = #"href="(/(?:dog|cat)-food/[^"]*)"#

        case .royalcanin:
            // Royal Canin product URLs: /us/dogs/products/... or /us/cats/products/...
            pattern = #"href="(/us/(?:dogs?|cats?)/products/[^"]*)"#

        case .bluebuffalo:
            // Blue Buffalo product URLs: /natural-dog-food/... or /natural-cat-food/...
            pattern = #"href="(/natural-(?:dog|cat)-food/[^"]*)"#

        case .iams:
            // Iams product URLs: /dog/... or /cat/...
            pattern = #"href="(/(?:dog|cat)/[^"]*product[^"]*)"#

        case .nutro:
            // Nutro product URLs: /products/dog/... or /products/cat/...
            pattern = #"href="(/products/(?:dog|cat)[^"]*)"#
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let relativePath = String(html[range])

        // Build full URL using source's base URL
        if relativePath.hasPrefix("http") {
            return URL(string: relativePath)
        }
        return URL(string: "\(source.baseURL)\(relativePath)")
    }

    /// Maximum length for valid ingredient text (typical lists are 200-1000 chars)
    private let maxIngredientsLength = 2000

    /// Extract ingredients text from product page HTML - TARGETED extraction only
    /// Returns nil if no valid ingredients section found (won't scrape garbage)
    private func extractIngredients(from html: String, source: ScrapingSource) -> String? {
        // Strategy 1: JSON-LD structured data (most reliable)
        if let jsonLD = extractFromJSONLD(html) {
            let cleaned = cleanIngredientsText(jsonLD)
            if isValidIngredientsText(cleaned) {
                return cleaned
            }
        }

        // Strategy 2: Site-specific ingredient section extraction
        if let sectionIngredients = extractIngredientsSection(from: html, source: source) {
            return sectionIngredients
        }

        // Strategy 3: Targeted regex with strict boundaries
        if let regexIngredients = extractWithStrictPatterns(from: html, source: source) {
            return regexIngredients
        }

        // No valid ingredients found - return nil (don't scrape garbage)
        return nil
    }

    /// Extract the ingredients section container from HTML using site-specific patterns
    private func extractIngredientsSection(from html: String, source: ScrapingSource) -> String? {
        let sectionPatterns: [String]

        switch source {
        // Retailers
        case .chewy:
            sectionPatterns = [
                // Chewy uses specific class names for ingredient sections
                #"(?i)<(?:div|section)[^>]*(?:class|id)="[^"]*ingredient[^"]*"[^>]*>([\s\S]{20,2000}?)</(?:div|section)>"#,
                // Ingredient header followed by content in next element
                #"(?i)Ingredients\s*</(?:h\d|strong|b|span)>\s*<(?:p|div|span)[^>]*>([^<]{20,1500})"#
            ]
        case .petco:
            sectionPatterns = [
                // Petco ingredient container
                #"(?i)<(?:div|section)[^>]*(?:class|id)="[^"]*ingredient[^"]*"[^>]*>([\s\S]{20,2000}?)</(?:div|section)>"#,
                // Generic ingredient label pattern
                #"(?i)Ingredients\s*:?\s*</[^>]+>\s*<[^>]+>([^<]{20,1500})"#
            ]

        case .petsmart:
            sectionPatterns = [
                // PetSmart ingredient section (often in accordion/details panels)
                #"(?i)<(?:div|section)[^>]*(?:class|id)="[^"]*ingredient[^"]*"[^>]*>([\s\S]{20,2000}?)</(?:div|section)>"#,
                // PetSmart product details section
                #"(?i)Ingredients\s*:?\s*</(?:h\d|strong|b|span|dt)>\s*<(?:p|div|span|dd)[^>]*>([^<]{20,1500})"#,
                // Generic ingredient pattern
                #"(?i)>Ingredients\s*:?\s*([A-Z][^<]{20,1500})"#
            ]

        // Manufacturer sites - typically have cleaner, more structured markup
        case .purina, .hillspet, .royalcanin, .bluebuffalo, .iams, .nutro:
            sectionPatterns = [
                // Look for ingredient section by class/id (common pattern)
                #"(?i)<(?:div|section)[^>]*(?:class|id)="[^"]*ingredient[^"]*"[^>]*>([\s\S]{20,2000}?)</(?:div|section)>"#,
                // Look for "Ingredients" heading followed by list or paragraph
                #"(?i)Ingredients\s*:?\s*</(?:h\d|strong|b|span|p)>\s*<(?:p|div|ul|span)[^>]*>([\s\S]{20,2000}?)</(?:p|div|ul|span)>"#,
                // Direct ingredient text after label
                #"(?i)>Ingredients\s*:?\s*([A-Z][^<]{20,1500})"#,
                // Accordion/expandable sections common on manufacturer sites
                #"(?i)data-(?:tab|section)="[^"]*ingredient[^"]*"[^>]*>([\s\S]{20,2000}?)</(?:div|section)>"#
            ]
        }

        for pattern in sectionPatterns {
            if let match = extractWithPattern(pattern, from: html) {
                let cleaned = cleanIngredientsText(match)
                if isValidIngredientsText(cleaned) {
                    return cleaned
                }
            }
        }

        return nil
    }

    /// Extract ingredients using strict regex patterns with length limits
    private func extractWithStrictPatterns(from html: String, source: ScrapingSource) -> String? {
        // More restrictive patterns - capture only the content between Ingredients label and next section
        let strictPatterns = [
            // Pattern: "Ingredients:" followed by text, stopping at common section boundaries
            #"(?i)Ingredients\s*:?\s*([A-Z][^<]{20,1500}?)(?=\s*(?:Guaranteed|Calorie|Feeding|Nutritional|</div>|</section>|<h\d))"#,
            // Pattern: Ingredients in a paragraph tag
            #"(?i)>Ingredients\s*:?\s*</[^>]+>\s*<p[^>]*>([^<]{20,1500})</p>"#
        ]

        for pattern in strictPatterns {
            if let match = extractWithPattern(pattern, from: html) {
                let cleaned = cleanIngredientsText(match)
                if isValidIngredientsText(cleaned) {
                    return cleaned
                }
            }
        }

        return nil
    }

    /// Try to extract ingredients from JSON-LD structured data
    private func extractFromJSONLD(_ html: String) -> String? {
        // Find JSON-LD script tags
        let pattern = #"<script[^>]*type="application/ld\+json"[^>]*>([^<]+)</script>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange])

            // Try to parse and find ingredients
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Look for ingredients in various possible locations
                if let ingredients = json["ingredients"] as? String {
                    return ingredients
                }
                if let description = json["description"] as? String,
                   description.lowercased().contains("ingredients") {
                    return extractIngredientsFromDescription(description)
                }
            }
        }

        return nil
    }

    /// Extract ingredients from a description field
    private func extractIngredientsFromDescription(_ description: String) -> String? {
        let lowercased = description.lowercased()
        guard let range = lowercased.range(of: "ingredients") else { return nil }

        let startIndex = description.index(range.upperBound, offsetBy: 1, limitedBy: description.endIndex) ?? range.upperBound
        let remaining = String(description[startIndex...])

        // Clean up and return
        let cleaned = remaining
            .trimmingCharacters(in: CharacterSet(charactersIn: ":; \n\t"))
            .components(separatedBy: "\n").first ?? remaining

        return cleaned.isEmpty ? nil : cleaned
    }

    /// Extract text matching a regex pattern
    private func extractWithPattern(_ pattern: String, from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return String(html[range])
    }

    /// Clean up extracted ingredients text
    private func cleanIngredientsText(_ text: String) -> String {
        var cleaned = text

        // Remove HTML entities
        let entities = [
            ("&amp;", "&"),
            ("&nbsp;", " "),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">")
        ]
        for (entity, replacement) in entities {
            cleaned = cleaned.replacingOccurrences(of: entity, with: replacement)
        }

        // Remove remaining HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            cleaned = tagRegex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: " "
            )
        }

        // Normalize whitespace
        cleaned = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validate that extracted text looks like an actual ingredients list
    private func isValidIngredientsText(_ text: String) -> Bool {
        // Length bounds: 50-2000 characters (typical lists are 200-1000)
        guard text.count >= 50 && text.count <= maxIngredientsLength else { return false }

        // Must be mostly alphabetic (50%+)
        let alphaCount = text.filter { $0.isLetter }.count
        let alphaRatio = Double(alphaCount) / Double(text.count)
        guard alphaRatio > 0.5 else { return false }

        // Should contain commas (ingredient separator) - at least 3
        let commaCount = text.filter { $0 == "," }.count
        guard commaCount >= 3 else { return false }

        // Reject if contains UI/navigation patterns (indicates we scraped wrong section)
        let uiPatterns = [
            "add to cart", "buy now", "shop now", "sign in", "create account",
            "customer review", "write a review", "see all", "load more",
            "subscribe", "save today", "free shipping", "in stock", "out of stock",
            "add to wishlist", "compare", "share this", "print this"
        ]
        let lowercased = text.lowercased()
        for pattern in uiPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        // Check if it starts with a typical ingredient word (first 50 chars)
        let start = String(text.prefix(50)).lowercased()
        let commonFirstIngredients = [
            "chicken", "beef", "salmon", "turkey", "lamb", "duck", "fish", "pork",
            "water", "meat", "poultry", "corn", "rice", "wheat", "barley", "oat",
            "brewers", "pea", "sweet potato", "potato", "tapioca", "animal",
            "deboned", "fresh", "dried", "whole"
        ]
        let hasValidStart = commonFirstIngredients.contains { start.contains($0) }

        // If doesn't start with common ingredient, require higher comma density
        if !hasValidStart {
            // Typical ingredient lists have ~1 comma per 30-50 chars
            let commaDensity = Double(commaCount) / Double(text.count)
            guard commaDensity > 0.015 else { return false }  // ~1 comma per 66 chars minimum
        }

        return true
    }

    /// Extract product name from page
    private func extractProductName(from html: String, source: ScrapingSource) -> String? {
        // Look for title tag or h1
        let patterns = [
            #"<title>([^<|]+)"#,
            #"<h1[^>]*>([^<]+)</h1>"#
        ]

        for pattern in patterns {
            if let name = extractWithPattern(pattern, from: html) {
                let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count < 200 {
                    return cleaned
                }
            }
        }

        return nil
    }
}
