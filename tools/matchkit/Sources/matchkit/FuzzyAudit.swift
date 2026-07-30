import Foundation

/// Measures how much of the match rate rests on a guess, and how ambiguous that
/// guess is.
///
/// The old fuzzy fallback iterated the synonyms *dictionary* and returned the
/// first containment hit. Swift's `Dictionary` iteration order depends on a
/// per-process hash seed, so when more than one synonym key matched a token, the
/// winner was effectively arbitrary — and different between launches of the same
/// build, with the result persisted into the saved scan.
///
/// `candidates` counts how many distinct synonym keys match each fuzzy-resolved
/// token. Any token with two or more was a coin flip.
enum FuzzyAudit {
    struct Finding {
        let token: String
        let occurrences: Int
        let chosen: String
        let candidateCount: Int
        let alternatives: [String]
    }

    static func report(catalog: Catalog, data: IngredientData, top: Int) -> String {
        let matcher = IngredientMatcher()

        // Collect the distinct normalized tokens that land on the fuzzy path.
        var fuzzyTokens: [String: Int] = [:]
        catalog.forEachProduct { product in
            for mi in matcher.match(rawIngredients: product.ingredients, data: data)
            where mi.matchConfidence == .fuzzy {
                fuzzyTokens[CatalogRun.normalizedKey(mi.labelName), default: 0] += 1
            }
        }

        var findings: [Finding] = []
        var ambiguousOccurrences = 0
        var totalOccurrences = 0

        for (token, count) in fuzzyTokens {
            totalOccurrences += count
            let matching = data.synonymsByLengthDescending.filter { entry in
                entry.key.count > 3 && (token.contains(entry.key) || entry.key.contains(token))
            }
            guard let winner = matching.first else { continue }
            let distinctIds = Set(matching.map(\.id))
            if distinctIds.count > 1 { ambiguousOccurrences += count }

            findings.append(Finding(
                token: token,
                occurrences: count,
                chosen: winner.id,
                candidateCount: distinctIds.count,
                alternatives: Array(distinctIds.subtracting([winner.id]).sorted().prefix(4))
            ))
        }

        var out = "\(totalOccurrences) token occurrences resolved by the fuzzy fallback, "
        out += "across \(fuzzyTokens.count) distinct tokens\n"
        out += String(format: "%d of those occurrences (%.1f%%) had MORE THAN ONE candidate ingredient — "
                      + "under the old dictionary-order fallback the winner was arbitrary and could differ between launches\n\n",
                      ambiguousOccurrences,
                      totalOccurrences > 0 ? Double(ambiguousOccurrences) / Double(totalOccurrences) * 100 : 0)

        out += "most frequent ambiguous fuzzy matches:\n"
        let ambiguous = findings.filter { $0.candidateCount > 1 }.sorted { $0.occurrences > $1.occurrences }
        for f in ambiguous.prefix(top) {
            out += String(format: "  %6d  %-44s -> %@  (%d candidates: %@)\n",
                          f.occurrences,
                          (f.token as NSString).utf8String!,
                          f.chosen, f.candidateCount, f.alternatives.joined(separator: ", "))
        }
        return out
    }
}
