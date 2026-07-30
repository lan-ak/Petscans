import XCTest
@testable import matchkit

/// Guards the cost of matching a label, which happens on the main flow of every
/// scan.
///
/// `fuzzyMatch` linearly scans `synonymsByLengthDescending`, and that array grew
/// when ingredient names became lookup keys (826 curated entries -> ~1300). The
/// scan only runs for tokens that miss both exact and descriptor lookup, but a
/// long unmatched label is exactly the worst case, so it's worth pinning.
final class PerformanceTests: XCTestCase {
    func testMatchingATypicalLabelIsFast() {
        let matcher = IngredientMatcher()
        let data = TestSupport.liveData
        // A real 28-token label with a realistic mix of hits and misses.
        let label = """
        Chicken, Chicken Broth, Chicken Liver, Dried Egg Product, Pea Protein, Tricalcium Phosphate, \
        Guar Gum, Potassium Chloride, Salt, Choline Chloride, Zzqx Unobtainium Compound, \
        Vitamin B12 Supplement, Dried Kelp, Taurine, Zinc Amino Acid Chelate, Thiamine Mononitrate, \
        Vitamin E Supplement, Niacin Supplement, Calcium Pantothenate, Riboflavin Supplement, \
        Wibble Phlogiston Blend, Manganese Amino Acid Chelate, Sodium Selenite, Biotin, \
        Vitamin D3 Supplement, Folic Acid, Copper Amino Acid Chelate, Menadione Sodium Bisulfite Complex
        """

        let start = Date()
        let iterations = 200
        for _ in 0..<iterations {
            _ = matcher.match(rawIngredients: label, data: data)
        }
        let perMatch = Date().timeIntervalSince(start) / Double(iterations)

        // Generous: a scan does this once. Anything approaching 100ms would be felt.
        XCTAssertLessThan(perMatch, 0.100,
                          String(format: "matching one label took %.1f ms", perMatch * 1000))
        print(String(format: "[perf] %.2f ms per label (%d tokens)", perMatch * 1000, 28))
    }
}
