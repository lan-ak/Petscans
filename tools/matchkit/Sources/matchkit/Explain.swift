import Foundation

/// Show, for one product, exactly what the matcher and scorer did to it.
///
/// The aggregate commands say *how much* moved; this says *why* for a single row.
/// It exists because reading a score delta of -86.6 without being able to open the
/// product is guesswork, and the whole point of this harness is not guessing.
enum Explain {
    static func report(catalog: Catalog, data: IngredientData, gtin: String) -> String {
        var found: Catalog.Product?
        catalog.forEachProduct { if $0.gtin == gtin { found = $0 } }
        guard let product = found else { return "no product with gtin \(gtin)" }

        let matched = IngredientMatcher().match(rawIngredients: product.ingredients, data: data)
        let breakdown = ScoreCalculator().calculate(
            species: product.species,
            category: product.category,
            matched: matched,
            data: data,
            avoidanceGroups: []
        )

        var out = """
        \(product.name)
        \(product.gtin)  \(product.species.rawValue)/\(product.category.rawValue)  tier \(product.tier)

        raw label:
        \(product.ingredients)

        \(matched.count) tokens:
        """

        for mi in matched {
            let id = mi.ingredientId ?? "—"
            let level = mi.processingLevel.map { "  \($0.rawValue)" } ?? ""
            out += "\n  \(String(format: "%3d", mi.rank))  \(mi.matchConfidence.rawValue.padded(to: 10)) \(id.padded(to: 26)) \(mi.labelName)\(level)"
        }

        out += "\n\ntotal \(round(breakdown.total * 10) / 10)"
        out += "   safety \(round(breakdown.safety * 10) / 10)"
        out += "   processing \(breakdown.processing.map { String(round($0 * 10) / 10) } ?? "—")"
        out += "   matched \(breakdown.matchedCount)/\(breakdown.totalCount)"

        if breakdown.flags.isEmpty {
            out += "\nno flags"
        } else {
            out += "\nflags:"
            for f in breakdown.flags {
                out += "\n  \(f.severity.rawValue.padded(to: 10)) \(f.type.rawValue.padded(to: 12)) \(f.title) — \(f.ingredientId ?? "—")"
            }
        }
        return out
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
