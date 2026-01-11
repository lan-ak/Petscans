import Foundation

/// Actor-based service for UPCitemdb API lookups
/// Uses the trial endpoint (100 requests/day limit, no API key required)
actor UPCitemdbService: UPCitemdbServiceProtocol {

    // MARK: - Properties

    /// Trial API endpoint (free tier, 100 requests/day)
    private let baseURL = "https://api.upcitemdb.com/prod/trial/lookup"
    private let session: URLSession

    // MARK: - Init

    init(session: URLSession = .shared) {
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
            // Rate limited - trial has 100 requests/day
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

        // Return first matching item
        guard let item = apiResponse.items.first else {
            throw UPCitemdbError.productNotFound
        }

        return item
    }
}
