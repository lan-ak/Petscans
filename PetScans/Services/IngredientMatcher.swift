import Foundation

/// Matches raw ingredient text to ingredients in the database
struct IngredientMatcher {
    private var database: IngredientDatabase { IngredientDatabase.shared }

    // Pre-compiled regex patterns (compiled once, reused for all matching)
    private static let parentheticalRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\(.*?\\)", options: [])
    }()

    private static let percentageRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\b\\d+%?\\b", options: [])
    }()

    private static let byproductRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\s*by-?products?\\s*", options: [])
    }()

    // Pre-compiled descriptor patterns
    private static let descriptorPatterns: [NSRegularExpression] = {
        let descriptors = [
            "dried", "dry", "powder", "powdered", "extract", "natural", "artificial",
            "fresh", "deboned", "meal", "concentrate", "concentrated", "organic",
            "raw", "cooked", "ground", "whole", "minced", "shredded", "flaked",
            "dehydrated", "freeze-dried", "frozen", "canned", "prepared",
            "hydrolyzed", "isolated", "pure", "refined", "enriched", "fortified"
        ]
        return descriptors.compactMap { try? NSRegularExpression(pattern: "\\b\($0)\\b", options: []) }
    }()

    init() {}

    /// Match raw ingredient text to known ingredients
    func match(rawIngredients: String) async -> [MatchedIngredient] {
        await database.waitForLoad()
        let synonyms = database.synonyms
        let ingredients = database.ingredients

        let tokens = splitIngredientList(rawIngredients)
        return tokens.enumerated().map { index, labelName in
            let normalized = normalizeToken(labelName)
            var ingredientId = synonyms[normalized]

            // Try without common descriptors if no match
            if ingredientId == nil {
                ingredientId = tryWithoutDescriptors(normalized, synonyms: synonyms)
            }

            // Look up processing level from ingredient database
            let processingLevel: ProcessingLevel?
            if let id = ingredientId, let ingredient = ingredients[id] {
                processingLevel = ingredient.processingLevel
            } else {
                processingLevel = nil
            }

            return MatchedIngredient(
                ingredientId: ingredientId,
                labelName: labelName,
                rank: index + 1,
                processingLevel: processingLevel
            )
        }
    }

    /// Split ingredient list on commas and semicolons
    private func splitIngredientList(_ raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // Cached character set for filtering (avoid recreating on every call)
    private static let allowedChars: CharacterSet = {
        CharacterSet.alphanumerics
            .union(CharacterSet.whitespaces)
            .union(CharacterSet(charactersIn: "'-/"))
    }()

    /// Normalize ingredient token for matching
    private func normalizeToken(_ s: String) -> String {
        var result = s.lowercased()

        // Normalize smart quotes
        result = result.replacingOccurrences(of: "'", with: "'")

        // Remove parentheticals (using pre-compiled regex)
        if let regex = Self.parentheticalRegex {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        // Remove special characters except apostrophe, hyphen, slash
        result = String(result.unicodeScalars.filter { Self.allowedChars.contains($0) })

        // Collapse whitespace
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Try matching without common descriptors like "dried", "powder", etc.
    private func tryWithoutDescriptors(_ normalized: String, synonyms: [String: String]) -> String? {
        var stripped = normalized

        // Remove all descriptors using pre-compiled patterns
        for pattern in Self.descriptorPatterns {
            stripped = pattern.stringByReplacingMatches(
                in: stripped,
                range: NSRange(stripped.startIndex..., in: stripped),
                withTemplate: ""
            )
        }

        // Remove common weight/percentage indicators (using pre-compiled regex)
        if let regex = Self.percentageRegex {
            stripped = regex.stringByReplacingMatches(
                in: stripped,
                range: NSRange(stripped.startIndex..., in: stripped),
                withTemplate: ""
            )
        }

        // Remove "by-product", "by product", "byproduct" as a suffix (using pre-compiled regex)
        if let regex = Self.byproductRegex {
            stripped = regex.stringByReplacingMatches(
                in: stripped,
                range: NSRange(stripped.startIndex..., in: stripped),
                withTemplate: ""
            )
        }

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
