import Foundation

/// One pass of the real `IngredientMatcher` and `ScoreCalculator` over the whole
/// bundled catalog.
///
/// Every command works from this single pass, so coverage, the miss list and the
/// score distribution are always describing the same run over the same catalog.
struct CatalogRun {
    struct Totals {
        var products = 0
        var tokens = 0
        var matchedTokens = 0
        var firstFiveTokens = 0
        var firstFiveMatched = 0

        var matchRate: Double { tokens > 0 ? Double(matchedTokens) / Double(tokens) : 0 }
        var firstFiveRate: Double { firstFiveTokens > 0 ? Double(firstFiveMatched) / Double(firstFiveTokens) : 0 }
    }

    /// A product's scored outcome, kept for the score-delta audit and the
    /// distribution summary. Deliberately small — 27k of these must fit in memory.
    struct Scored {
        let gtin: String
        let total: Double
        let safety: Double
        let processing: Double?
        let rating: String
        let classificationRate: Double
        let matchRate: Double
    }

    var overall = Totals()
    var byCohort: [String: Totals] = [:]
    /// How the matched tokens were matched. A headline match rate hides the fact
    /// that a containment guess and a dictionary lookup are not the same claim.
    var byConfidence: [MatchConfidence: Int] = [:]
    var firstFiveByConfidence: [MatchConfidence: Int] = [:]
    /// Normalized token -> occurrences, for tokens the matcher could not resolve.
    var misses: [String: Int] = [:]
    var scored: [Scored] = []
    var meta: [String: String] = [:]

    static func run(catalog: Catalog, data: IngredientData, scoreProducts: Bool) -> CatalogRun {
        let matcher = IngredientMatcher()
        let calculator = ScoreCalculator()
        var run = CatalogRun()
        run.meta = catalog.meta()
        run.scored.reserveCapacity(scoreProducts ? catalog.productCount() : 0)

        catalog.forEachProduct { product in
            let matched = matcher.match(rawIngredients: product.ingredients, data: data)
            guard !matched.isEmpty else { return }

            let cohort = "\(product.species.rawValue)|\(product.category.rawValue)"
            var cohortTotals = run.byCohort[cohort] ?? Totals()

            run.overall.products += 1
            cohortTotals.products += 1

            var classified = 0
            for mi in matched {
                let hit = mi.isMatched
                run.overall.tokens += 1
                cohortTotals.tokens += 1
                if hit {
                    run.overall.matchedTokens += 1
                    cohortTotals.matchedTokens += 1
                } else {
                    run.misses[Self.normalizedKey(mi.labelName), default: 0] += 1
                }
                run.byConfidence[mi.matchConfidence, default: 0] += 1
                if mi.rank <= 5 {
                    run.overall.firstFiveTokens += 1
                    cohortTotals.firstFiveTokens += 1
                    run.firstFiveByConfidence[mi.matchConfidence, default: 0] += 1
                    if hit {
                        run.overall.firstFiveMatched += 1
                        cohortTotals.firstFiveMatched += 1
                    }
                }
                if mi.processingLevel != nil { classified += 1 }
            }

            run.byCohort[cohort] = cohortTotals

            if scoreProducts {
                // No pet allergens and no avoidance groups: those are per-user, and
                // including them would measure a hypothetical user rather than the
                // product. The audit is about what the data change does, not what any
                // one owner's watch list does on top of it.
                let breakdown = calculator.calculate(
                    species: product.species,
                    category: product.category,
                    matched: matched,
                    data: data,
                    avoidanceGroups: []
                )
                run.scored.append(Scored(
                    gtin: product.gtin,
                    total: breakdown.total,
                    safety: breakdown.safety,
                    processing: breakdown.processing,
                    rating: breakdown.ratingLabel.rawValue,
                    classificationRate: Double(classified) / Double(matched.count),
                    matchRate: Double(matched.filter(\.isMatched).count) / Double(matched.count)
                ))
            }
        }
        return run
    }

    /// Group misses by the same normalization the matcher used, so the miss list
    /// is a list of *lookups to add* rather than a list of label spellings.
    /// Mirrors `IngredientMatcher.normalizeToken`, which is `private`.
    static func normalizedKey(_ label: String) -> String {
        var s = label.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        if let regex = try? NSRegularExpression(pattern: "\\(.*?\\)") {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "'-/"))
        s = String(s.unicodeScalars.filter { allowed.contains($0) })
        return s.split(separator: " ").joined(separator: " ")
    }
}

// MARK: - Rendering

extension CatalogRun {
    func coverageReport() -> String {
        var out = ""
        let version = meta["version"] ?? "?"
        let builtAt = meta["built_at"] ?? "?"
        out += "catalog \(version)  built \(builtAt)  \(overall.products) products, \(overall.tokens) tokens\n\n"
        out += String(format: "match rate            %.1f%%  (%d / %d tokens)\n",
                      overall.matchRate * 100, overall.matchedTokens, overall.tokens)
        out += String(format: "first-5 match rate    %.1f%%  (%d / %d tokens)\n",
                      overall.firstFiveRate * 100, overall.firstFiveMatched, overall.firstFiveTokens)
        out += String(format: "distinct misses       %d\n", misses.count)

        out += "\nhow those matches were made:\n"
        for confidence in MatchConfidence.allCases {
            let n = byConfidence[confidence] ?? 0
            guard n > 0 else { continue }
            let firstFive = firstFiveByConfidence[confidence] ?? 0
            out += String(format: "  %-13s %7d  %5.1f%% of all tokens   (%.1f%% of first-5)\n",
                          (confidence.rawValue as NSString).utf8String!,
                          n, Double(n) / Double(max(overall.tokens, 1)) * 100,
                          Double(firstFive) / Double(max(overall.firstFiveTokens, 1)) * 100)
        }
        let certain = MatchConfidence.allCases.filter(\.isCertain).reduce(0) { $0 + (byConfidence[$1] ?? 0) }
        out += String(format: "  -> %.1f%% of tokens are certain matches; %.1f%% rest on the fuzzy fallback\n",
                      Double(certain) / Double(max(overall.tokens, 1)) * 100,
                      Double(byConfidence[.fuzzy] ?? 0) / Double(max(overall.tokens, 1)) * 100)

        out += "\nby cohort:\n"
        for key in byCohort.keys.sorted() {
            let t = byCohort[key]!
            out += String(format: "  %-12s %6.1f%%  first-5 %5.1f%%  (%d products)\n",
                          (key as NSString).utf8String!, t.matchRate * 100, t.firstFiveRate * 100, t.products)
        }
        return out
    }

    func missesReport(top: Int) -> String {
        let ranked = misses.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
        let totalMisses = misses.values.reduce(0, +)
        var out = "\(totalMisses) unmatched token occurrences across \(misses.count) distinct strings\n\n"

        // The recovery curve is the actionable part: it says where to stop adding
        // synonyms, which is a judgement the raw list can't make for you.
        out += "recovery curve (if the top N were all resolved):\n"
        var cumulative = 0
        var index = 0
        for milestone in [25, 50, 100, 200, 400, 800] {
            while index < min(milestone, ranked.count) {
                cumulative += ranked[index].value
                index += 1
            }
            let lifted = Double(overall.matchedTokens + cumulative) / Double(max(overall.tokens, 1))
            out += String(format: "  top %4d  recovers %6d  (%4.1f%% of misses)  match rate -> %.1f%%\n",
                          milestone, cumulative,
                          totalMisses > 0 ? Double(cumulative) / Double(totalMisses) * 100 : 0,
                          lifted * 100)
        }

        out += "\ntop \(min(top, ranked.count)) unmatched tokens:\n"
        for (token, count) in ranked.prefix(top) {
            out += String(format: "  %6d  %@\n", count, token)
        }
        return out
    }

    /// The score distribution, which is the baseline a later data change is
    /// diffed against.
    func scoreSummary() -> String {
        guard !scored.isEmpty else { return "no products scored\n" }
        let totals = scored.map(\.total).sorted()
        func pct(_ p: Double) -> Double { totals[min(totals.count - 1, Int(Double(totals.count) * p))] }

        var ratings: [String: Int] = [:]
        for s in scored { ratings[s.rating, default: 0] += 1 }

        let onCliff = scored.filter { $0.classificationRate < 0.5 }.count

        var out = "scored \(scored.count) products\n"
        out += String(format: "total score  p10 %.1f  p25 %.1f  median %.1f  p75 %.1f  p90 %.1f\n",
                      pct(0.10), pct(0.25), pct(0.50), pct(0.75), pct(0.90))
        out += "rating labels: "
        out += ["Excellent", "Good", "Caution", "Avoid"]
            .map { "\($0) \(ratings[$0] ?? 0)" }
            .joined(separator: "  ")
        out += "\n"
        out += String(format: "on the flat-80 processing fallback (<50%% classified): %d (%.0f%%)\n",
                      onCliff, Double(onCliff) / Double(scored.count) * 100)
        return out
    }

    /// Machine-readable form, committed as the baseline every later phase diffs against.
    /// Compact on purpose — this file is committed, and 27k products of pretty-printed
    /// JSON with every component was 6 MB. Per product we keep only what the delta
    /// report reads: total, the rating label, and the processing-classification rate.
    /// Component distributions live in the summary block, not per row.
    func baselineJSON() -> Data {
        var perProduct: [String: [String: Any]] = [:]
        for s in scored {
            perProduct[s.gtin] = [
                "total": (s.total * 10).rounded() / 10,
                // The label must be stored, not re-derived from `total`. Deriving it
                // would apply `RatingLabel.from(score:)` alone and miss `labelOverride`,
                // which is what actually decides Caution and Avoid — so every overridden
                // product would read as a regression. That bug reported 8,231 false
                // transitions the first time this ran.
                "rating": s.rating,
                "classificationRate": (s.classificationRate * 100).rounded() / 100
            ]
        }
        let payload: [String: Any] = [
            "catalogVersion": meta["version"] ?? "unknown",
            "catalogBuiltAt": meta["built_at"] ?? "unknown",
            // `version` alone is not an identity. It is stamped at build time and does
            // NOT change when rows are cleaned or enriched afterwards — the catalog can
            // gain and lose products while still calling itself 20260723. Recording the
            // row count and cleaned_at is what makes a stale comparison detectable.
            "catalogCleanedAt": meta["cleaned_at"] ?? "never",
            "catalogEnrichedAt": meta["enriched_at"] ?? "never",
            "catalogRowCount": meta["count"] ?? "unknown",
            "matchRate": (Double(overall.matchedTokens) / Double(max(overall.tokens, 1)) * 1000).rounded() / 1000,
            "products": overall.products,
            "tokens": overall.tokens,
            "matchedTokens": overall.matchedTokens,
            "firstFiveTokens": overall.firstFiveTokens,
            "firstFiveMatched": overall.firstFiveMatched,
            "distinctMisses": misses.count,
            "misses": misses,
            "scores": perProduct
        ]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }
}
