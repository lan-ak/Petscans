import Foundation

/// Diagnoses why the 0-100 score doesn't discriminate.
///
/// The baseline over the shipped catalog shows a median total of ~95.8, a p10 of
/// ~91.2, and **zero** products rated "Good" — because `RatingLabel.from(score:)`
/// puts anything at or above 75 in "Excellent", and essentially every product
/// clears 75. Every Caution and Avoid the user sees comes from `labelOverride`,
/// which is a boolean on "does this contain any caution/toxic ingredient".
///
/// So the number is decorative and the label is a two-way switch. This command
/// takes the score apart to show where the headroom went, so a recalibration is
/// aimed at the actual cause rather than at the thresholds.
enum Calibration {
    struct Sample {
        let total: Double
        let safety: Double
        let processing: Double?
        let rating: String
        let cohort: String
    }

    static func report(catalog: Catalog, data: IngredientData) -> String {
        let matcher = IngredientMatcher()
        let calculator = ScoreCalculator()

        var samples: [Sample] = []
        // The rank weight is exp(-0.22 * (rank - 1)), so ingredient N's penalty is
        // discounted geometrically. Worth stating in absolute terms: how much of a
        // product's total possible penalty weight is even reachable.
        var ingredientCounts: [Int] = []

        catalog.forEachProduct { product in
            let matched = matcher.match(rawIngredients: product.ingredients, data: data)
            guard !matched.isEmpty else { return }
            ingredientCounts.append(matched.count)
            let b = calculator.calculate(species: product.species, category: product.category,
                                         matched: matched, data: data, avoidanceGroups: [])
            samples.append(Sample(total: b.total, safety: b.safety, processing: b.processing,
                                  rating: b.ratingLabel.rawValue,
                                  cohort: "\(product.species.rawValue)|\(product.category.rawValue)"))
        }

        guard !samples.isEmpty else { return "no products\n" }
        var out = "\(samples.count) products\n\n"

        out += "component distributions:\n"
        out += distribution("total", samples.map(\.total))
        out += distribution("safety", samples.map(\.safety))
        out += distribution("processing", samples.compactMap(\.processing))

        // Where the labels actually come from.
        var labels: [String: Int] = [:]
        for s in samples { labels[s.rating, default: 0] += 1 }
        let aboveExcellentThreshold = samples.filter { $0.total >= 75 }.count
        let labelledExcellent = labels["Excellent"] ?? 0

        out += "\nlabels:\n"
        for label in ["Excellent", "Good", "Caution", "Avoid"] {
            let n = labels[label] ?? 0
            out += String(format: "  %-10s %6d  (%.1f%%)\n",
                          (label as NSString).utf8String!, n, Double(n) / Double(samples.count) * 100)
        }
        out += String(format: """
              %d products (%.1f%%) score at or above the Excellent threshold of 75.
              Only %d are labelled Excellent — the other %d are pulled down by labelOverride.
              That is the whole mechanism: the number picks nothing, the override picks everything.

            """,
            aboveExcellentThreshold, Double(aboveExcellentThreshold) / Double(samples.count) * 100,
            labelledExcellent, aboveExcellentThreshold - labelledExcellent)

        // How much of the 0-100 range is in use at all.
        let totals = samples.map(\.total).sorted()
        let span = totals.last! - totals.first!
        let p1 = totals[max(0, totals.count / 100)]
        let p99 = totals[min(totals.count - 1, totals.count * 99 / 100)]
        out += String(format: "range in use: min %.1f  max %.1f  (span %.1f)   p1-p99 band: %.1f  (%.0f%% of the scale)\n",
                      totals.first!, totals.last!, span, p99 - p1, (p99 - p1))

        // The rank decay is the structural reason penalties can't accumulate.
        out += "\nrank-weight reach (weight = exp(-0.22 * (rank - 1))):\n"
        var cumulative = 0.0
        for rank in 1...30 {
            cumulative += exp(-0.22 * Double(rank - 1))
            if [1, 3, 5, 10, 20, 30].contains(rank) {
                out += String(format: "  ranks 1-%-2d  cumulative weight %5.2f\n", rank, cumulative)
            }
        }
        let ceiling = 1.0 / (1.0 - exp(-0.22))
        let median = ingredientCounts.sorted()[ingredientCounts.count / 2]
        out += String(format: """
              Total weight converges to %.2f no matter how many ingredients a product has.
              The median product lists %d ingredients, but everything past ~rank 15 contributes
              less than 1%% of the weight — so a long tail of ultra-processed additives is
              almost invisible to the score. Worst case, an all-ultra-processed product loses
              %.0f processing points; a realistic one with fresh meat first loses far less.

            """, ceiling, median, 15.0 * ceiling)

        return out
    }

    private static func distribution(_ name: String, _ values: [Double]) -> String {
        guard !values.isEmpty else { return "" }
        let v = values.sorted()
        func p(_ q: Double) -> Double { v[min(v.count - 1, Int(Double(v.count) * q))] }
        return String(format: "  %-11s min %5.1f  p10 %5.1f  p25 %5.1f  p50 %5.1f  p75 %5.1f  p90 %5.1f  max %5.1f\n",
                      (name as NSString).utf8String!, v.first!, p(0.10), p(0.25), p(0.50), p(0.75), p(0.90), v.last!)
    }
}
