import Foundation

// MARK: - Product Source

/// Product sources supported for ingredient search (retailers + manufacturers)
enum ProductSource: String, CaseIterable, Sendable {
    // Retailers
    case chewy
    case petco
    case petsmart

    // Manufacturers
    case purina
    case hillspet
    case royalcanin
    case bluebuffalo
    case iams
    case nutro
    case merrick
    case wellness
    case orijen
    case acana
    case canidae
    case fromm
    case tasteOfTheWild
    case zignature
    case nulo
    case solidGold
    case victorDog
    case stellaChewy
    case openFarm
    case honestKitchen
    case instinct
    case naturalBalance
    case rachealRay
    case earthborn
    case diamondPet

    /// Whether this source is a retailer (vs manufacturer)
    var isRetailer: Bool {
        switch self {
        case .chewy, .petco, .petsmart:
            return true
        default:
            return false
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        // Retailers
        case .chewy: return "Chewy"
        case .petco: return "Petco"
        case .petsmart: return "PetSmart"
        // Manufacturers
        case .purina: return "Purina"
        case .hillspet: return "Hill's"
        case .royalcanin: return "Royal Canin"
        case .bluebuffalo: return "Blue Buffalo"
        case .iams: return "Iams"
        case .nutro: return "Nutro"
        case .merrick: return "Merrick"
        case .wellness: return "Wellness"
        case .orijen: return "Orijen"
        case .acana: return "Acana"
        case .canidae: return "Canidae"
        case .fromm: return "Fromm"
        case .tasteOfTheWild: return "Taste of the Wild"
        case .zignature: return "Zignature"
        case .nulo: return "Nulo"
        case .solidGold: return "Solid Gold"
        case .victorDog: return "Victor"
        case .stellaChewy: return "Stella & Chewy's"
        case .openFarm: return "Open Farm"
        case .honestKitchen: return "The Honest Kitchen"
        case .instinct: return "Instinct"
        case .naturalBalance: return "Natural Balance"
        case .rachealRay: return "Rachael Ray"
        case .earthborn: return "Earthborn"
        case .diamondPet: return "Diamond"
        }
    }

    /// Site query for Google search targeting product pages
    var siteQuery: String {
        switch self {
        // Retailers
        case .chewy:
            return "site:chewy.com/dp"
        case .petco:
            return "site:petco.com/shop/en/petcostore/product"
        case .petsmart:
            return "site:petsmart.ca .html"
        // Manufacturers
        case .purina:
            return "site:purina.com"
        case .hillspet:
            return "site:hillspet.com"
        case .royalcanin:
            return "site:royalcanin.com"
        case .bluebuffalo:
            return "site:bluebuffalo.com"
        case .iams:
            return "site:iams.com"
        case .nutro:
            return "site:nutro.com"
        case .merrick:
            return "site:merrickpetcare.com"
        case .wellness:
            return "site:wellnesspetfood.com"
        case .orijen:
            return "site:orijenpetfoods.com"
        case .acana:
            return "site:acana.com"
        case .canidae:
            return "site:canidae.com"
        case .fromm:
            return "site:frommfamily.com"
        case .tasteOfTheWild:
            return "site:tasteofthewildpetfood.com"
        case .zignature:
            return "site:zignature.com"
        case .nulo:
            return "site:nulo.com"
        case .solidGold:
            return "site:solidgoldpet.com"
        case .victorDog:
            return "site:victorpetfood.com"
        case .stellaChewy:
            return "site:stellaandchewys.com"
        case .openFarm:
            return "site:openfarmpet.com"
        case .honestKitchen:
            return "site:thehonestkitchen.com"
        case .instinct:
            return "site:instinctpetfood.com"
        case .naturalBalance:
            return "site:naturalbalanceinc.com"
        case .rachealRay:
            return "site:rachaelraypetfood.com"
        case .earthborn:
            return "site:earthbornholisticpetfood.com"
        case .diamondPet:
            return "site:diamondpet.com"
        }
    }

    /// Fallback site query (broader search) - only for retailers
    var fallbackSiteQuery: String? {
        switch self {
        case .chewy:
            return "site:chewy.com"
        case .petco:
            return "site:petco.com"
        case .petsmart:
            return "site:petsmart.ca"
        default:
            return nil  // Manufacturers don't need fallback
        }
    }

    /// Validates if a URL is a valid product page for this source
    func isValidProductURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        switch self {
        // Retailers - strict validation
        case .chewy:
            return host.contains("chewy.com") && url.path.contains("/dp/")
        case .petco:
            return host.contains("petco.com") && url.path.contains("/shop/en/petcostore/product/")
        case .petsmart:
            return host.contains("petsmart.ca") &&
                   url.path.hasSuffix(".html") &&
                   url.path.contains(where: { $0.isNumber })
        // Manufacturers - looser validation (any page on their domain with product content)
        case .purina:
            return host.contains("purina.com")
        case .hillspet:
            return host.contains("hillspet.com")
        case .royalcanin:
            return host.contains("royalcanin.com")
        case .bluebuffalo:
            return host.contains("bluebuffalo.com")
        case .iams:
            return host.contains("iams.com")
        case .nutro:
            return host.contains("nutro.com")
        case .merrick:
            return host.contains("merrickpetcare.com")
        case .wellness:
            return host.contains("wellnesspetfood.com")
        case .orijen:
            return host.contains("orijenpetfoods.com") || host.contains("orijen.com")
        case .acana:
            return host.contains("acana.com")
        case .canidae:
            return host.contains("canidae.com")
        case .fromm:
            return host.contains("frommfamily.com")
        case .tasteOfTheWild:
            return host.contains("tasteofthewildpetfood.com")
        case .zignature:
            return host.contains("zignature.com")
        case .nulo:
            return host.contains("nulo.com")
        case .solidGold:
            return host.contains("solidgoldpet.com")
        case .victorDog:
            return host.contains("victorpetfood.com")
        case .stellaChewy:
            return host.contains("stellaandchewys.com")
        case .openFarm:
            return host.contains("openfarmpet.com")
        case .honestKitchen:
            return host.contains("thehonestkitchen.com")
        case .instinct:
            return host.contains("instinctpetfood.com")
        case .naturalBalance:
            return host.contains("naturalbalanceinc.com")
        case .rachealRay:
            return host.contains("rachaelraypetfood.com")
        case .earthborn:
            return host.contains("earthbornholisticpetfood.com")
        case .diamondPet:
            return host.contains("diamondpet.com")
        }
    }

    /// All retailer sources
    static var retailers: [ProductSource] {
        [.chewy, .petco, .petsmart]
    }
}

// MARK: - Search Result

/// Result from a successful product search
struct SerperSearchResult: Sendable {
    /// The product page URL
    let url: URL
    /// Which source the URL is from
    let source: ProductSource
}

// MARK: - Dynamic Source (for discovered websites)

/// A dynamically discovered product source (for brands not in the known list)
struct DynamicProductSource: Sendable {
    let brand: String
    let domain: String
    let siteQuery: String

    var displayName: String { brand }

    func isValidProductURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains(domain.lowercased())
    }
}

// MARK: - Protocol

/// Protocol for Google search via Serper.dev API
protocol SerperServiceProtocol: Sendable {
    /// Search for a pet food product across multiple sources
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - retailers: Ordered list of retailers to search (first match wins)
    /// - Returns: The product URL and source if found
    /// - Throws: SerperError on failure
    func searchProduct(query: String, retailers: [ProductSource]) async throws -> SerperSearchResult

    /// Search for a pet food product across multiple sources with explicit brand
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - brand: Optional explicit brand name for better matching
    ///   - retailers: Ordered list of retailers to search (first match wins)
    /// - Returns: The product URL and source if found
    /// - Throws: SerperError on failure
    func searchProduct(query: String, brand: String?, retailers: [ProductSource]) async throws -> SerperSearchResult

    /// Search for a pet food product across all sources, returning all matches
    /// Automatically includes manufacturer site if brand is detected
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - retailers: List of retailers to search
    /// - Returns: Array of product URLs (one per source that has a match)
    /// - Throws: SerperError on failure (only if no results found at all)
    func searchProductURLs(query: String, retailers: [ProductSource]) async throws -> [SerperSearchResult]

    /// Search for a pet food product across all sources with explicit brand
    /// Automatically includes manufacturer site if brand is detected
    /// - Parameters:
    ///   - query: Product name and brand to search for
    ///   - brand: Optional explicit brand name for better matching and manufacturer detection
    ///   - retailers: List of retailers to search
    /// - Returns: Array of product URLs (one per source that has a match)
    /// - Throws: SerperError on failure (only if no results found at all)
    func searchProductURLs(query: String, brand: String?, retailers: [ProductSource]) async throws -> [SerperSearchResult]

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
            return "No results found"
        case .rateLimited:
            return "Search rate limit exceeded"
        case .networkError:
            return "Network error during search"
        case .decodingError:
            return "Failed to parse search results"
        }
    }
}
