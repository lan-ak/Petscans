import Foundation

/// Parses raw ingredient text (especially from OCR) into comma-separated format
/// for IngredientMatcher compatibility
struct IngredientTextParser {

    // MARK: - Properties

    /// Known ingredient names from the synonym database (normalized lowercase)
    private let knownIngredients: Set<String>

    /// Multi-word ingredients sorted by length (longest first) for greedy matching
    private let sortedMultiWordIngredients: [String]

    // MARK: - Regex Patterns

    /// Preamble patterns to remove (e.g., "Ingredients:", "INGREDIENTS")
    private static let preambleRegex: NSRegularExpression? = {
        // Match "ingredients" or "contains" with optional colon, at start or after newline
        try? NSRegularExpression(
            pattern: #"^.*?\b(?:ingredients?|contains)\s*:?\s*"#,
            options: [.caseInsensitive]
        )
    }()

    // MARK: - Init

    init() {
        let synonyms = IngredientDatabase.shared.synonyms
        self.knownIngredients = Set(synonyms.keys)

        // Extract multi-word ingredients and sort by length (longest first)
        self.sortedMultiWordIngredients = synonyms.keys
            .filter { $0.contains(" ") }
            .sorted { $0.count > $1.count }
    }

    /// Initialize with custom synonyms (for testing)
    init(synonymDatabase: [String: String]) {
        self.knownIngredients = Set(synonymDatabase.keys)
        self.sortedMultiWordIngredients = synonymDatabase.keys
            .filter { $0.contains(" ") }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Public Methods

    /// Parse raw OCR text into comma-separated ingredient format
    /// - Parameter rawText: Raw text from OCR or other source
    /// - Returns: Comma-separated ingredient string for IngredientMatcher
    func parse(_ rawText: String) -> String {
        var text = rawText

        // Step 1: Remove preamble ("Ingredients:", etc.)
        text = removePreamble(text)

        // Step 2: If already has commas/semicolons with good density, just normalize
        if hasExistingSeparators(text) {
            return normalizeExistingSeparators(text)
        }

        // Step 3: Parse space-separated text into ingredients
        let ingredients = parseSpaceSeparated(text)

        // Step 4: Join with commas
        return ingredients.joined(separator: ", ")
    }

    // MARK: - Private Methods

    private func removePreamble(_ text: String) -> String {
        guard let regex = Self.preambleRegex else { return text }

        let range = NSRange(text.startIndex..., in: text)
        let result = regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: ""
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasExistingSeparators(_ text: String) -> Bool {
        let commaCount = text.filter { $0 == "," }.count
        let semicolonCount = text.filter { $0 == ";" }.count
        let separatorCount = commaCount + semicolonCount

        // If no separators, definitely need to parse
        guard separatorCount > 0 else { return false }

        // Count words to determine separator density
        let wordCount = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .count

        // If we have at least 1 separator per 5 words, assume pre-formatted
        // This catches "Chicken, Corn, Wheat" but not "Chicken Meal (5%), Corn"
        return Double(separatorCount) / Double(max(1, wordCount)) > 0.15
    }

    private func normalizeExistingSeparators(_ text: String) -> String {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func parseSpaceSeparated(_ text: String) -> [String] {
        var remaining = text.lowercased()
        var ingredients: [String] = []

        while !remaining.isEmpty {
            remaining = remaining.trimmingCharacters(in: .whitespaces)
            guard !remaining.isEmpty else { break }

            // Try to match longest known multi-word ingredient first
            if let (match, rest) = tryMatchMultiWord(remaining) {
                ingredients.append(match)
                remaining = rest
                continue
            }

            // Try to match known single-word ingredient
            if let (match, rest) = tryMatchKnownSingleWord(remaining) {
                ingredients.append(match)
                remaining = rest
                continue
            }

            // Fall back: take first word as unknown ingredient
            let words = remaining.components(separatedBy: .whitespaces)
            if let first = words.first, !first.isEmpty {
                ingredients.append(first)
                remaining = words.dropFirst().joined(separator: " ")
            } else {
                break
            }
        }

        return ingredients
    }

    private func tryMatchMultiWord(_ text: String) -> (String, String)? {
        // Try each multi-word ingredient (already sorted by length)
        for pattern in sortedMultiWordIngredients {
            if text.hasPrefix(pattern) {
                // Ensure we're at a word boundary (not middle of a word)
                let afterMatch = text.dropFirst(pattern.count)
                if afterMatch.isEmpty || afterMatch.first?.isWhitespace == true || afterMatch.first == "," {
                    let rest = String(afterMatch)
                    return (pattern, rest)
                }
            }
        }
        return nil
    }

    private func tryMatchKnownSingleWord(_ text: String) -> (String, String)? {
        let words = text.components(separatedBy: .whitespaces)
        guard let firstWord = words.first, !firstWord.isEmpty else { return nil }

        // Clean the word of trailing punctuation for matching
        let cleanWord = firstWord.trimmingCharacters(in: .punctuationCharacters)

        // Check if single word is a known ingredient
        if knownIngredients.contains(cleanWord) {
            let rest = words.dropFirst().joined(separator: " ")
            return (cleanWord, rest)
        }

        return nil
    }
}
