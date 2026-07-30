import Foundation

/// A one-or-two sentence description assembled from the structured fields every
/// ingredient already has.
///
/// This is the floor, not the ceiling. Authored content in `ingredient-content.json`
/// supersedes it wherever it exists; this is what shows for everything else, so no
/// ingredient is ever a dead tap. It composes only from `typicalFunction` (populated
/// on every record), `origin` and `processingLevel` — asserting nothing the record
/// doesn't already say, which is the same rule the authored content follows.
///
/// Deliberately short. A composed sentence that runs on reads as padding; two
/// clauses read as a definition.
extension Ingredient {
    func composedSummary() -> String? {
        var sentences: [String] = []

        if let function = typicalFunction?.trimmingCharacters(in: .whitespaces), !function.isEmpty {
            // "Typical role:" rather than "Used as a …". `typicalFunction` mixes two
            // grammatical kinds — role nouns ("Antioxidant", "Primary protein") and
            // purpose phrases ("Blood clotting, bone metabolism", "Enhanced zinc
            // absorption") — and no single inflected frame is correct for both. Forcing
            // one produced "Used as an electrolytes and flavor" and "Used as a liver
            // function". A label reads as slightly clinical but is never wrong, which is
            // the right trade for a fallback that authored content replaces.
            sentences.append("Typical role: \(Self.humanise(function)).")
        }

        if let origin = Self.originPhrase(origin) {
            var second = origin
            if let processing = Self.processingPhrase(processingLevel) {
                second += ", \(processing)"
            }
            sentences.append(second + ".")
        } else if let processing = Self.processingPhrase(processingLevel) {
            sentences.append(processing.prefix(1).uppercased() + processing.dropFirst() + ".")
        }

        let result = sentences.joined(separator: " ")
        return result.isEmpty ? nil : result
    }

    /// "Stabilizer, prebiotic fiber" -> "stabiliser and prebiotic fibre".
    ///
    /// `typicalFunction` is free text with 395 distinct values, comma-separated when
    /// it lists more than one role. Joining the last pair with "and" is what stops it
    /// reading like a database field pasted into a sentence.
    private static func humanise(_ function: String) -> String {
        let parts = function
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).lowercased() + $0.dropFirst() }

        switch parts.count {
        case 0: return function.lowercased()
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default: return parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
        }
    }

    private static func originPhrase(_ origin: String) -> String? {
        switch origin.lowercased() {
        case "natural": return "A natural ingredient"
        case "natural_derived": return "Derived from a natural source"
        case "synthetic": return "Made synthetically"
        case "mineral": return "A mineral"
        case "chelated_mineral": return "A mineral bound to amino acids so it is easier to absorb"
        default: return nil
        }
    }

    private static func processingPhrase(_ level: ProcessingLevel?) -> String? {
        switch level {
        case .unprocessed: return "minimally processed"
        case .culinaryIngredient: return "refined for use as an ingredient"
        case .processed: return "processed"
        case .ultraProcessed: return "ultra-processed"
        case nil: return nil
        }
    }
}
