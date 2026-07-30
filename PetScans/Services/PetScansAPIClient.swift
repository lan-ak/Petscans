import Foundation

/// Shared client for the PetScans backend proxy.
///
/// All paid third-party calls (OpenAI Vision, Firecrawl, Serper) now go through
/// our Cloudflare Worker instead of hitting the providers directly. The Worker
/// holds the real API keys; this client only
/// presents an anonymous, per-device bearer token. That keeps secrets out of
/// the app binary and lets the backend cache results and cap spend.
///
/// The proxy is transparent: request and response bodies are forwarded
/// verbatim, so each service keeps its existing encoders/decoders and only
/// swaps how the URLRequest is built (base URL + Authorization header).
actor PetScansAPIClient {
    static let shared = PetScansAPIClient()

    /// Base URL of the deployed Worker. Configure per build via the
    /// `PetScansAPIBaseURL` key in Info.plist; falls back to the constant below.
    /// Replace the fallback with your `wrangler deploy` URL.
    private let baseURLString: String

    private let session: URLSession

    // Cached device token (persisted so we mint at most once per ~month).
    private var cachedToken: String?
    private var cachedExpiry: Date?

    private static let tokenKey = "petscans.api.token"
    private static let expiryKey = "petscans.api.token.expiresAt"
    private static let deviceIdKey = "petscans.api.deviceId"

    init(session: URLSession = .shared) {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "PetScansAPIBaseURL") as? String,
           !configured.isEmpty {
            self.baseURLString = configured.hasSuffix("/") ? String(configured.dropLast()) : configured
        } else {
            self.baseURLString = "https://REPLACE-WITH-YOUR-WORKER.workers.dev"
        }
        self.session = session

        // Restore any persisted token.
        let defaults = UserDefaults.standard
        if let token = defaults.string(forKey: Self.tokenKey) {
            let exp = defaults.double(forKey: Self.expiryKey)
            if exp > 0 {
                self.cachedToken = token
                self.cachedExpiry = Date(timeIntervalSince1970: exp)
            }
        }
    }

    // MARK: - Public

    /// Build an authorized URLRequest against the proxy for the given path.
    /// Callers set `httpBody` afterwards as needed.
    func authorizedRequest(
        path: String,
        method: String = "GET",
        timeout: TimeInterval = 30
    ) async throws -> URLRequest {
        let token = try await validToken()
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: baseURLString + normalizedPath) else {
            throw PetScansAPIError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // MARK: - Token management

    private func validToken() async throws -> String {
        // Reuse the cached token until it's within 60s of expiry.
        if let token = cachedToken, let expiry = cachedExpiry, expiry.timeIntervalSinceNow > 60 {
            return token
        }
        return try await mintToken()
    }

    private func mintToken() async throws -> String {
        guard let url = URL(string: baseURLString + "/v1/auth/token") else {
            throw PetScansAPIError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TokenRequest(deviceId: deviceId()))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PetScansAPIError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PetScansAPIError.tokenRequestFailed
        }

        let decoded: TokenResponse
        do {
            decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw PetScansAPIError.tokenRequestFailed
        }

        let expiry = Date(timeIntervalSince1970: TimeInterval(decoded.expiresAt))
        cachedToken = decoded.token
        cachedExpiry = expiry
        let defaults = UserDefaults.standard
        defaults.set(decoded.token, forKey: Self.tokenKey)
        defaults.set(expiry.timeIntervalSince1970, forKey: Self.expiryKey)

        return decoded.token
    }

    /// Stable, anonymous per-install identifier used only for rate limiting.
    private func deviceId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.deviceIdKey), existing.count >= 8 {
            return existing
        }
        let generated = "ios-" + UUID().uuidString
        defaults.set(generated, forKey: Self.deviceIdKey)
        return generated
    }
}

// MARK: - Models & Errors

private struct TokenRequest: Encodable {
    let deviceId: String
}

private struct TokenResponse: Decodable {
    let token: String
    let expiresAt: Int
}

enum PetScansAPIError: LocalizedError {
    case invalidConfiguration
    case tokenRequestFailed
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "The PetScans API is not configured correctly."
        case .tokenRequestFailed:
            return "Couldn't authenticate with the PetScans service."
        case .networkError:
            return "Network error contacting the PetScans service."
        }
    }
}
