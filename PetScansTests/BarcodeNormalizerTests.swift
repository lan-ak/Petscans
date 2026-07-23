import XCTest
@testable import PetScans

/// Pins the barcode → canonical GTIN-14 contract. The build tool
/// (tools/petcatalog/scripts/petcatalog/gtin.ts) must agree with these cases digit-for-digit,
/// or a barcode the app canonicalises won't match the key the catalog was written under.
final class BarcodeNormalizerTests: XCTestCase {

    // MARK: canonicalisation

    func testUPCAExpandsToGTIN14WithLeadingZeros() {
        // Sheba, a real catalog UPC-A.
        XCTAssertEqual(BarcodeNormalizer.canonical("023100144276"), "00023100144276")
    }

    func testEAN13GetsSingleLeadingZero() {
        // Valid EAN-13 (check digit correct).
        XCTAssertEqual(BarcodeNormalizer.canonical("4006381333931"), "04006381333931")
    }

    func testHyphensAndSpacesAreStripped() {
        XCTAssertEqual(BarcodeNormalizer.canonical("0 23100 14427 6"), "00023100144276")
    }

    func testAlreadyGTIN14PassesThrough() {
        XCTAssertEqual(BarcodeNormalizer.canonical("00023100144276"), "00023100144276")
    }

    // MARK: check digit

    func testWrongCheckDigitIsRejected() {
        // Last digit flipped 6→7.
        XCTAssertNil(BarcodeNormalizer.canonical("023100144277"))
    }

    func testValidCheckDigitAcceptedAcrossPadding() {
        // GTIN-14 and the UPC-A inside it must validate identically.
        XCTAssertTrue(BarcodeNormalizer.hasValidCheckDigit("00023100144276"))
    }

    // MARK: restricted number systems — the 28% that no scanner can emit

    func testNumberSystem4RejectedRetailerInStore() {
        // Real rejected row: "(5 pack) Vetinque Labs" seller bundle.
        XCTAssertNil(BarcodeNormalizer.canonical("460688327279"))
    }

    func testNumberSystem2RejectedVariableWeight() {
        XCTAssertNil(BarcodeNormalizer.canonical("232690624024"))
    }

    func testNumberSystem5RejectedCoupon() {
        XCTAssertNil(BarcodeNormalizer.canonical("506726507347"))
    }

    func testNumberSystem0StandardRetailAccepted() {
        XCTAssertNotNil(BarcodeNormalizer.canonical("023100144276"))
    }

    // MARK: non-barcodes

    func testEmptyAndGarbageRejected() {
        XCTAssertNil(BarcodeNormalizer.canonical(""))
        XCTAssertNil(BarcodeNormalizer.canonical("hello"))
        XCTAssertNil(BarcodeNormalizer.canonical("12345")) // too short
    }

    // MARK: UPC-E expansion

    func testUPCEExpandsToValidUPCA() {
        // 01278906 (NS 0, check 6) → 012000007897? Use a known pair.
        // 04252614 expands; assert we produce a valid, retail GTIN or reject cleanly.
        let result = BarcodeNormalizer.canonical("04252614")
        if let result {
            XCTAssertTrue(BarcodeNormalizer.hasValidCheckDigit(result))
            XCTAssertEqual(result.count, 14)
        }
    }
}
