import Foundation

/// Compares current scoring against a committed baseline.
///
/// The headline number is not the mean shift — it's the **rating-label transition
/// matrix**. Users don't perceive "median total moved 1.4 points"; they perceive a
/// food they trusted moving from Good to Caution. A change that shifts scores a
/// lot while moving few labels is far less disruptive than one that shifts scores
/// slightly across a threshold, and only the matrix distinguishes the two.
enum ScoreDelta {
    static func report(
        baseline: [String: [String: Any]],
        current: [CatalogRun.Scored],
        baselineStamp: [String: String],
        currentStamp: [String: String]
    ) -> String {
        var out = "baseline \(describe(baselineStamp)) -> current \(describe(currentStamp))\n"

        // The catalog is edited in place by the petcatalog clean/enrich steps without
        // the version changing, so identical versions do not mean identical data.
        if baselineStamp["version"] == currentStamp["version"],
           baselineStamp["cleanedAt"] != currentStamp["cleanedAt"]
            || baselineStamp["rowCount"] != currentStamp["rowCount"] {
            out += """

                WARNING: both sides report catalog version \(currentStamp["version"] ?? "?"), but the
                underlying data differs (rows \(baselineStamp["rowCount"] ?? "?") -> \(currentStamp["rowCount"] ?? "?"),
                cleaned \(baselineStamp["cleanedAt"] ?? "?") -> \(currentStamp["cleanedAt"] ?? "?")).
                Some of the delta below is the catalog changing, not the code. Re-baseline
                before treating this as a scoring audit.

                """
        }
        out += "\n"

        var deltas: [Double] = []
        var transitions: [String: Int] = [:]
        var crossedCliff = 0
        var crossedCliffDelta: [Double] = []
        var missingFromBaseline = 0

        let labels = ["Excellent", "Good", "Caution", "Avoid"]

        var baselineLacksLabels = false

        for product in current {
            guard let before = baseline[product.gtin] else {
                missingFromBaseline += 1
                continue
            }
            let beforeTotal = before["total"] as? Double ?? 0
            let delta = product.total - beforeTotal
            deltas.append(delta)

            // Read the stored label. Never re-derive it from the score — see the
            // note in `CatalogRun.baselineJSON`.
            guard let beforeLabel = before["rating"] as? String else {
                baselineLacksLabels = true
                continue
            }
            if beforeLabel != product.rating {
                transitions["\(beforeLabel) -> \(product.rating)", default: 0] += 1
            }

            // Products that were on the flat-80 processing fallback and now aren't.
            let beforeRate = before["classificationRate"] as? Double ?? 0
            if beforeRate < 0.5 && product.classificationRate >= 0.5 {
                crossedCliff += 1
                crossedCliffDelta.append(delta)
            }
        }

        if baselineLacksLabels {
            out += "WARNING: baseline predates stored rating labels — regenerate it, "
            out += "label transitions below are incomplete\n\n"
        }

        guard !deltas.isEmpty else { return out + "no overlapping products\n" }

        let sorted = deltas.sorted()
        let changed = deltas.filter { abs($0) >= 0.05 }.count
        out += String(format: "%d products compared, %d changed (%.1f%%)\n",
                      deltas.count, changed, Double(changed) / Double(deltas.count) * 100)
        out += String(format: "total-score delta   mean %+.2f   median %+.2f   p10 %+.2f   p90 %+.2f   min %+.2f   max %+.2f\n",
                      deltas.reduce(0, +) / Double(deltas.count),
                      sorted[sorted.count / 2],
                      sorted[sorted.count / 10],
                      sorted[sorted.count * 9 / 10],
                      sorted.first!, sorted.last!)
        if missingFromBaseline > 0 {
            out += "\(missingFromBaseline) products not present in the baseline (new catalog rows), excluded\n"
        }

        out += "\nrating-label transitions (this is the number users feel):\n"
        if transitions.isEmpty {
            out += "  none — every product kept its label\n"
        } else {
            for from in labels {
                for to in labels where from != to {
                    if let n = transitions["\(from) -> \(to)"] {
                        let direction = labels.firstIndex(of: to)! > labels.firstIndex(of: from)! ? "worse" : "better"
                        out += String(format: "  %-22s %6d  (%@)\n", ("\(from) -> \(to)" as NSString).utf8String!, n, direction)
                    }
                }
            }
        }

        out += "\nprocessing-cliff crossings (<50%% classified -> >=50%%): \(crossedCliff)\n"
        if !crossedCliffDelta.isEmpty {
            let s = crossedCliffDelta.sorted()
            out += String(format: "  their delta   median %+.2f   min %+.2f   max %+.2f\n",
                          s[s.count / 2], s.first!, s.last!)
            let worse = crossedCliffDelta.filter { $0 < -0.05 }.count
            out += "  \(worse) of them scored WORSE after crossing — expected, since newly-matched supplements are mostly level 3-4\n"
        }
        return out
    }
}

extension ScoreDelta {
    fileprivate static func describe(_ stamp: [String: String]) -> String {
        "catalog \(stamp["version"] ?? "?") (\(stamp["rowCount"] ?? "?") rows, cleaned \(stamp["cleanedAt"] ?? "never"))"
    }
}
