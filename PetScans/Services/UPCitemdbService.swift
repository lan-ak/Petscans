import Foundation

/// Actor-based service for UPCitemdb API lookups
/// Uses the paid v1 endpoint with API key authentication
actor UPCitemdbService: UPCitemdbServiceProtocol {

    // MARK: - Properties

    /// Paid API endpoint (v1)
    private let baseURL = "https://api.upcitemdb.com/prod/v1/lookup"
    private let apiKey: String
    private let session: URLSession

    /// Known pet food manufacturers to match against brand field
    private let petFoodManufacturers: Set<String> = [
        "purina", "nestle purina", "mars", "mars petcare", "hill's", "hills",
        "royal canin", "blue buffalo", "general mills", "smucker", "j.m. smucker",
        "diamond", "spectrum", "cardinal", "wellness", "wellpet", "merrick",
        "champion petfoods", "orijen", "acana", "nutro", "natural balance",
        "del monte", "ainsworth", "rachael ray", "nutrish", "taste of the wild",
        "canidae", "fromm", "zignature", "nulo", "solid gold", "earthborn",
        "victor", "stella & chewy's", "open farm", "the honest kitchen", "instinct"
    ]

    /// Pet-related keywords to check in title/description
    private let petKeywords: Set<String> = [
        "dog", "cat", "puppy", "kitten", "pet", "canine", "feline"
    ]

    // MARK: - Init

    init(apiKey: String = APIKeys.upcitemdb, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Look up a barcode using UPCitemdb API
    /// - Parameter barcode: The barcode to look up (UPC, EAN, or GTIN)
    /// - Returns: Product information if found
    /// - Throws: UPCitemdbError on failure
    func lookupBarcode(_ barcode: String) async throws -> UPCitemdbItem {
        // Validate barcode format
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedBarcode.isEmpty,
              cleanedBarcode.allSatisfy({ $0.isNumber }),
              cleanedBarcode.count >= 8 && cleanedBarcode.count <= 14 else {
            throw UPCitemdbError.invalidBarcode
        }

        // Build URL with query parameter
        guard var components = URLComponents(string: baseURL) else {
            throw UPCitemdbError.networkError(underlying: URLError(.badURL))
        }
        components.queryItems = [URLQueryItem(name: "upc", value: cleanedBarcode)]

        guard let url = components.url else {
            throw UPCitemdbError.networkError(underlying: URLError(.badURL))
        }

        // Create request with headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("PetScans/1.0 (iOS Swift App)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "user_key")
        request.setValue("3scale", forHTTPHeaderField: "key_type")
        request.timeoutInterval = 15

        // Execute request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UPCitemdbError.networkError(underlying: error)
        }

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UPCitemdbError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            // Rate limited
            throw UPCitemdbError.rateLimited
        case 404:
            throw UPCitemdbError.productNotFound
        default:
            throw UPCitemdbError.networkError(underlying: URLError(.badServerResponse))
        }

        // Decode response
        let apiResponse: UPCitemdbResponse
        do {
            apiResponse = try JSONDecoder().decode(UPCitemdbResponse.self, from: data)
        } catch {
            throw UPCitemdbError.decodingError(underlying: error)
        }

        // Debug: Log all items returned
        print("DEBUG: UPCitemdb returned \(apiResponse.items.count) items:")
        for (index, item) in apiResponse.items.enumerated() {
            print("DEBUG:   [\(index)] title: \(item.title ?? "nil")")
            print("DEBUG:   [\(index)] brand: \(item.brand ?? "nil")")
            print("DEBUG:   [\(index)] description: \(item.description.map { String($0.prefix(100)) } ?? "nil")")
        }

        // If multiple items, try to find a pet product
        if apiResponse.items.count > 1 {
            // First pass: check title/description for pet keywords
            for item in apiResponse.items {
                let searchText = [item.title, item.description]
                    .compactMap { $0?.lowercased() }
                    .joined(separator: " ")

                for keyword in petKeywords {
                    if searchText.contains(keyword) {
                        print("DEBUG: Selected pet product by keyword '\(keyword)': \(item.title ?? "unknown")")
                        return item
                    }
                }
            }

            // Second pass: check brand against known pet food manufacturers
            for item in apiResponse.items {
                if let brand = item.brand?.lowercased() {
                    for manufacturer in petFoodManufacturers {
                        if brand.contains(manufacturer) {
                            print("DEBUG: Selected pet product by manufacturer '\(manufacturer)': \(item.title ?? "unknown")")
                            return item
                        }
                    }
                }
            }
        }

        // Fallback: return first item
        guard let item = apiResponse.items.first else {
            throw UPCitemdbError.productNotFound
        }

        // Validate the selected item is a pet product
        guard isPetProduct(item) else {
            print("DEBUG: Product '\(item.title ?? "unknown")' is not pet-related, category: \(item.category ?? "nil")")
            throw UPCitemdbError.productNotFound
        }

        return item
    }

    // MARK: - Private Methods

    /// Check if item appears to be a pet product based on keywords, brand, and category
    private func isPetProduct(_ item: UPCitemdbItem) -> Bool {
        let searchText = [item.title, item.description, item.brand, item.category]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        // Check for pet keywords in title/description/category
        for keyword in petKeywords {
            if searchText.contains(keyword) {
                print("DEBUG: Product validated as pet product by keyword '\(keyword)'")
                return true
            }
        }

        // Check for known pet food manufacturers
        if let brand = item.brand?.lowercased() {
            for manufacturer in petFoodManufacturers {
                if brand.contains(manufacturer) {
                    print("DEBUG: Product validated as pet product by manufacturer '\(manufacturer)'")
                    return true
                }
            }
        }

        // Check category for pet-related terms
        if let category = item.category?.lowercased() {
            if category.contains("pet") || category.contains("animal") {
                print("DEBUG: Product validated as pet product by category '\(category)'")
                return true
            }
        }

        return false
    }
}
