import Foundation

/// Matches raw ingredient text to ingredients in the database
struct IngredientMatcher {
    private let database = IngredientDatabase.shared

    init() {}

    /// Match raw ingredient text to known ingredients
    func match(rawIngredients: String) async -> [MatchedIngredient] {
        await database.waitForLoad()
        let synonyms = database.synonyms

        let tokens = splitIngredientList(rawIngredients)
        return tokens.enumerated().map { index, labelName in
            let normalized = normalizeToken(labelName)
            var ingredientId = synonyms[normalized]

            // Try without common descriptors if no match
            if ingredientId == nil {
                ingredientId = tryWithoutDescriptors(normalized, synonyms: synonyms)
            }

            return MatchedIngredient(
                ingredientId: ingredientId,
                labelName: labelName,
                rank: index + 1
            )
        }
    }

    /// Split ingredient list on commas and semicolons
    private func splitIngredientList(_ raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Normalize ingredient token for matching
    private func normalizeToken(_ s: String) -> String {
        var result = s.lowercased()

        // Normalize smart quotes
        result = result.replacingOccurrences(of: "'", with: "'")

        // Remove parentheticals
        if let regex = try? NSRegularExpression(pattern: "\\(.*?\\)", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        // Remove special characters except apostrophe, hyphen, slash
        let allowedChars = CharacterSet.alphanumerics
            .union(CharacterSet.whitespaces)
            .union(CharacterSet(charactersIn: "'-/"))
        result = result.unicodeScalars
            .filter { allowedChars.contains($0) }
            .map { Character($0) }
            .map { String($0) }
            .joined()

        // Collapse whitespace
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Try matching without common descriptors like "dried", "powder", etc.
    private func tryWithoutDescriptors(_ normalized: String, synonyms: [String: String]) -> String? {
        // Expanded list of common descriptors to strip
        let descriptors = [
            "dried", "dry", "powder", "powdered", "extract", "natural", "artificial",
            "fresh", "deboned", "meal", "concentrate", "concentrated", "organic",
            "raw", "cooked", "ground", "whole", "minced", "shredded", "flaked",
            "dehydrated", "freeze-dried", "frozen", "canned", "prepared",
            "hydrolyzed", "isolated", "pure", "refined", "enriched", "fortified"
        ]

        var stripped = normalized

        // Remove all descriptors
        for descriptor in descriptors {
            stripped = stripped.replacingOccurrences(of: "\\b\(descriptor)\\b", with: "", options: .regularExpression)
        }

        // Remove common weight/percentage indicators
        stripped = stripped.replacingOccurrences(of: "\\b\\d+%?\\b", with: "", options: .regularExpression)

        // Remove "by-product", "by product", "byproduct" as a suffix
        stripped = stripped.replacingOccurrences(of: "\\s*by-?products?\\s*", with: "", options: .regularExpression)

        // Collapse whitespace
        stripped = stripped.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Try exact match first
        if let match = synonyms[stripped] {
            return match
        }

        // Try partial matching - if the stripped text is contained in any synonym key
        // or if any synonym key is contained in the stripped text
        for (key, value) in synonyms {
            if stripped.contains(key) && key.count > 3 {
                return value
            }
            if key.contains(stripped) && stripped.count > 3 {
                return value
            }
        }

        return nil
    }
}
