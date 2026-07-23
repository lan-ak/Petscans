import Foundation

/// Resolves a scanned barcode to a product with zero network calls.
///
/// This is the instant path that replaces the old per-scan web research (OpenAI Vision →
/// Serper → Firecrawl, 20–60s). It normalises the raw code and looks it up in the bundled
/// catalog; everything downstream (ingredient matching, scoring) already runs on-device.
///
/// The prior-scan cache tier from the plan lives in `ScannerViewModel`, where the SwiftData
/// `ModelContext` is available — a product the user scored once via OCR or web should not
/// need re-deriving. This service owns only normalisation + catalog, so it stays pure and
/// unit-testable.
struct ProductCatalogService {
    enum Resolution: Equatable {
        /// The scanned string isn't a retail product barcode (QR, coupon, in-store code,
        /// bad check digit). The read should be ignored rather than surfaced as a miss.
        case notAProductBarcode
        /// A valid barcode that isn't in the catalog. Carries the canonical GTIN so the
        /// caller can cache, request a harvest, and log the miss.
        case unknown(gtin: String)
        /// A hit.
        case found(CatalogProduct)
    }

    private let store: LocalCatalogStore

    init(store: LocalCatalogStore = .shared) {
        self.store = store
    }

    func resolve(rawBarcode: String) async -> Resolution {
        guard let gtin = BarcodeNormalizer.canonical(rawBarcode) else {
            return .notAProductBarcode
        }
        if let product = await store.product(gtin: gtin) {
            return .found(product)
        }
        return .unknown(gtin: gtin)
    }
}
