import Foundation

enum Species: String, Codable, CaseIterable, Identifiable {
    case dog
    case cat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dog: return "Dog"
        case .cat: return "Cat"
        }
    }

    /// Distinct per species. Both cases used to return `pawprint`, which made
    /// the species picker carry no visual signal — an owner could tap past the
    /// segmented control (default `.dog`) and get dog scoring for a cat with
    /// nothing on screen indicating it.
    var icon: String {
        switch self {
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        }
    }
}

/// The most common food allergens per species.
///
/// Lives beside `Species` rather than in the picker that draws it: these ids are the keys
/// of `AllergenFamily`, so the scorer's data-validation tests have to be able to see them.
/// A chip with no family silently falls back to bare name matching, which is how "dairy" —
/// matching no ingredient at all — shipped for four versions.
///
/// The most common food allergens per species, offered as one-tap quick-pick
/// chips. Ranked from Mueller & Olivry, "Critically appraised topic on adverse
/// food reactions of companion animals (2)", BMC Vet Res 2016 — beef/dairy/
/// chicken/wheat dominate dogs; beef/fish/chicken/wheat dominate cats. IDs are
/// lowercased to match how allergens are persisted and how ingredient rows
/// compute their selected state.
enum QuickPickAllergens {
    static func list(for species: Species) -> [(id: String, name: String)] {
        switch species {
        case .dog:
            return [
                ("beef", "Beef"),
                ("dairy", "Dairy"),
                ("chicken", "Chicken"),
                ("wheat", "Wheat"),
                ("soy", "Soy"),
                ("lamb", "Lamb")
            ]
        case .cat:
            return [
                ("beef", "Beef"),
                ("fish", "Fish"),
                ("chicken", "Chicken"),
                ("wheat", "Wheat"),
                ("dairy", "Dairy"),
                ("corn", "Corn")
            ]
        }
    }
}
