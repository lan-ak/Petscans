import Foundation

/// Plain-language explanation of one ingredient, for the detail sheet.
///
/// **This content is model-authored and was not reviewed by a person.** That is
/// why it lives in its own file (`ingredient-content.json`) rather than in the
/// hand-curated `ingredients.json`, and why it is display-only: nothing here is
/// read by `ScoreCalculator`, `IngredientMatcher`, or any rule.
///
/// The rule the content is written under, and which
/// `tools/validate-ingredient-content.py` and `ContentValidationTests` enforce:
/// **an entry may only restate, in plainer words, what the ingredient's record
/// already asserts.** It may not introduce a new factual claim — no dosages, no
/// medical claims, no study references, no numbers absent from the record, and no
/// safety verdict that contradicts the record's `riskLevel`.
///
/// `sourceFields` names the parts of the record each entry was derived from. It
/// exists so "restates the record" is auditable rather than merely asserted.
struct IngredientContent: Codable, Equatable {
    /// What the ingredient is, in one or two sentences.
    let whatItIs: String

    /// Why a manufacturer puts it in pet food.
    let whyItsHere: String

    /// Present only when the record carries a concern — a non-safe `riskLevel`, an
    /// allergen risk above Low, a rule, or toxicity data. Absent means the record
    /// asserts nothing to watch for, and inventing something would be exactly the
    /// failure mode this schema guards against.
    let whatToWatchFor: String?

    let generatedAt: String?
    let sourceFields: [String]?

    /// Nothing here may throw: the file is bundled and a malformed entry should cost
    /// that one explanation, not the whole lookup. Mirrors every other loader.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        whatItIs = try c.decodeIfPresent(String.self, forKey: .whatItIs) ?? ""
        whyItsHere = try c.decodeIfPresent(String.self, forKey: .whyItsHere) ?? ""
        whatToWatchFor = try c.decodeIfPresent(String.self, forKey: .whatToWatchFor)
        generatedAt = try c.decodeIfPresent(String.self, forKey: .generatedAt)
        sourceFields = try c.decodeIfPresent([String].self, forKey: .sourceFields)
    }

    init(whatItIs: String, whyItsHere: String, whatToWatchFor: String? = nil,
         generatedAt: String? = nil, sourceFields: [String]? = nil) {
        self.whatItIs = whatItIs
        self.whyItsHere = whyItsHere
        self.whatToWatchFor = whatToWatchFor
        self.generatedAt = generatedAt
        self.sourceFields = sourceFields
    }

    /// An entry with no prose is not worth rendering — the composed fallback is better.
    var isEmpty: Bool {
        whatItIs.trimmingCharacters(in: .whitespaces).isEmpty
            && whyItsHere.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
