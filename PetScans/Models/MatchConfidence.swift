import Foundation

/// How a label token was resolved to a database ingredient.
///
/// A match rate is only meaningful if you know what kind of matches make it up.
/// `.exact` is a lookup; `.fuzzy` is a guess that happens to be right most of the
/// time. Presenting them identically is how an app ends up confidently naming the
/// wrong ingredient — so this is recorded at match time, persisted with the scan,
/// and shown differently in the UI.
///
/// Persisted inside `MatchedIngredient`, so unknown raw values decode to `.none`
/// rather than throwing.
enum MatchConfidence: String, Codable, CaseIterable {
    /// The normalized token is a synonym key verbatim.
    case exact

    /// Matched after stripping descriptors like "dried", "deboned", "meal".
    case descriptor

    /// Matched after stripping a formulaic suffix — "X supplement",
    /// "X fermentation product", "X amino acid chelate".
    case suffixFamily

    /// Matched by containment against a synonym key. A guess: right often enough
    /// to be worth keeping, wrong often enough that it must look different.
    case fuzzy

    /// No ingredient, but the token's *kind* is recognisable ("some vitamin").
    /// Display only — never counted as a database match, never affects the score.
    case classOnly

    /// Nothing resolved.
    case none

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MatchConfidence(rawValue: raw) ?? .none
    }

    /// Whether this resolved to an actual database ingredient. `.classOnly` is
    /// deliberately excluded: knowing a token is "a vitamin" is not knowing what
    /// it is, and the recognition figure users see must not claim otherwise.
    var isDatabaseMatch: Bool {
        switch self {
        case .exact, .descriptor, .suffixFamily, .fuzzy: return true
        case .classOnly, .none: return false
        }
    }

    /// Whether the match is certain enough to present without qualification.
    var isCertain: Bool {
        self == .exact || self == .descriptor
    }
}
