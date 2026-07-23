import Foundation

/// Turns a raw scanner string into the canonical GTIN-14 the catalog is keyed by, or
/// rejects it. This is the on-device twin of `tools/petcatalog/scripts/petcatalog/gtin.ts`;
/// the two must agree digit-for-digit or a scan silently misses a product that is in the
/// catalog. `BarcodeNormalizerTests` pins the shared cases.
///
/// Three jobs:
///   1. Expand UPC-E (the camera emits these compressed) and zero-pad everything to 14.
///   2. Validate the mod-10 check digit — a misread that corrupts a digit should not
///      trigger a lookup against a real product.
///   3. Reject retailer-internal codes (UPC number system 2/4/5). 28% of the purchased
///      catalog data was seller-invented in-store codes for multipacks; the same codes
///      never appear on a physical product, so a scan can never legitimately produce one.
enum BarcodeNormalizer {

    /// The canonical, look-up-ready form of a scanned code, or nil if it isn't a retail
    /// product barcode we should act on.
    static func canonical(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)

        // Build the candidate GTIN-14 forms this string could represent, then accept the
        // first that is a valid, retail-issued barcode. An 8-digit code is genuinely
        // ambiguous — a compressed UPC-E or an EAN-8 — so we try both and let the check
        // digit decide rather than guessing from the leading zero.
        var candidates: [String] = []
        switch digits.count {
        case 6, 7:
            if let expanded = expandUPCE(digits) { candidates.append(pad14(expanded)) }
        case 8:
            if let expanded = expandUPCE(digits) { candidates.append(pad14(expanded)) }
            candidates.append(pad14(digits)) // EAN-8
        case 12, 13, 14:
            candidates.append(pad14(digits))
        default:
            break
        }

        return candidates.first { hasValidCheckDigit($0) && isRetailIssued($0) }
    }

    // MARK: - Validation (exposed for tests and the catalog-integrity check)

    /// Mod-10 check digit. Weights run right-to-left, which makes the result invariant to
    /// left zero-padding, so a GTIN-14 and the UPC-A inside it agree.
    static func hasValidCheckDigit(_ gtin14: String) -> Bool {
        guard gtin14.count == 14, gtin14.allSatisfy(\.isNumber) else { return false }
        let d = gtin14.compactMap { $0.wholeNumberValue }
        guard d.count == 14 else { return false }
        let check = d[13]
        var sum = 0
        for (i, v) in d[0..<13].reversed().enumerated() {
            sum += v * (i % 2 == 0 ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10 == check
    }

    /// A manufacturer-issued retail code a phone can actually read off a package — not a
    /// coupon, variable-weight sticker, or retailer-internal multipack code.
    static func isRetailIssued(_ gtin14: String) -> Bool {
        guard gtin14.count == 14, gtin14.allSatisfy(\.isNumber) else { return false }

        // "00" + 12 => UPC-A. The digit after the pad is the number system.
        if gtin14.hasPrefix("00") {
            let ns = gtin14[gtin14.index(gtin14.startIndex, offsetBy: 2)]
            return ns != "2" && ns != "4" && ns != "5"
        }

        // "0" + 13 => EAN-13. GS1 reserves 02x/04x and the 2xx prefix for restricted
        // circulation, and 977/978/979/981/982 for periodicals, books and coupons.
        if gtin14.hasPrefix("0") {
            let ean = String(gtin14.dropFirst())
            let p2 = String(ean.prefix(2))
            let p3 = String(ean.prefix(3))
            if p2 == "02" || p2 == "04" { return false }
            if ean.hasPrefix("2") { return false }
            if ["977", "978", "979", "981", "982"].contains(p3) { return false }
            return true
        }

        // Leading indicator digit 1–8 => ITF-14 case/carton code, printed on shipping
        // cases, never on the consumer unit.
        return false
    }

    // MARK: - Private

    private static func pad14(_ digits: String) -> String {
        String(repeating: "0", count: max(0, 14 - digits.count)) + digits
    }

    /// Expand a UPC-E code to its 12-digit UPC-A equivalent. Accepts the 6-digit core, or
    /// the 7/8-digit forms that include the number-system and/or check digit.
    private static func expandUPCE(_ input: String) -> String? {
        var core = input
        // Strip number-system prefix (must be 0) and trailing check digit if present.
        if core.count == 8 { core = String(core.dropFirst().dropLast()) }
        else if core.count == 7 { core = core.hasPrefix("0") ? String(core.dropFirst()) : String(core.dropLast()) }
        guard core.count == 6, core.allSatisfy(\.isNumber) else { return nil }

        let m = Array(core)
        let lastDigit = m[5]
        var mfr: String
        var prod: String

        switch lastDigit {
        case "0", "1", "2":
            mfr = "\(m[0])\(m[1])\(lastDigit)00"
            prod = "00\(m[2])\(m[3])\(m[4])"
        case "3":
            mfr = "\(m[0])\(m[1])\(m[2])00"
            prod = "000\(m[3])\(m[4])"
        case "4":
            mfr = "\(m[0])\(m[1])\(m[2])\(m[3])0"
            prod = "0000\(m[4])"
        default: // 5–9
            mfr = "\(m[0])\(m[1])\(m[2])\(m[3])\(m[4])"
            prod = "0000\(lastDigit)"
        }

        let body = "0" + mfr + prod // number system 0 + 5 + 5 = 11 digits
        let check = upcCheckDigit(body)
        return body + String(check)
    }

    private static func upcCheckDigit(_ elevenDigits: String) -> Int {
        let d = elevenDigits.compactMap { $0.wholeNumberValue }
        guard d.count == 11 else { return 0 }
        var sum = 0
        for (i, v) in d.enumerated() {
            sum += v * (i % 2 == 0 ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10
    }
}
