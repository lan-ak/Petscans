import Foundation

/// A category of ingredients an owner would rather their pet didn't eat.
///
/// Onboarding asks this instead of naming individual ingredients: a first-time
/// user has not seen an ingredient list yet and cannot answer "what is your pet
/// allergic to?", but they do know whether they want to avoid artificial
/// colours. Owners think in categories; the 625-ingredient search in
/// `IngredientSearchSheet` stays available in Settings for anyone with a
/// specific diagnosed allergy.
///
/// These are **collected only**. Nothing reads them for scoring — they are
/// persisted by `AvoidancePreferences` and pushed to Superwall for paywall
/// targeting and copy. Wiring them into `ScoreCalculator` is a separate change
/// and is not as simple as filtering on `processingLevel` or `origin`; see the
/// notes on each case below.
enum AvoidanceGroup: String, Codable, CaseIterable, Identifiable {
    /// Industrial formulations: hydrolyzed proteins, artificial flavours.
    ///
    /// Not equivalent to `ProcessingLevel.ultraProcessed`: 29 of the 74 level-4
    /// ingredients in `ingredients.json` are synthetic vitamins, amino acids,
    /// minerals and enzymes (ascorbic acid, L-lysine, choline chloride,
    /// Vitamin A supplement). Those are AAFCO-required and appear in nearly
    /// every complete food, so scoring against level 4 alone would flag every
    /// product. A curated required-nutrient exclusion is needed first.
    case ultraProcessed

    /// Synthetic dyes: Red 40, Yellow 5/6, Blue 1/2, Titanium dioxide.
    ///
    /// Not equivalent to `origin == "synthetic"` on colourant ingredients:
    /// that predicate catches Copper and Riboflavin (color) while classifying
    /// Carmine and Iron oxide as natural.
    case artificialColours

    /// Synthetic preservatives: BHA, BHT, Ethoxyquin, TBHQ.
    ///
    /// The one group that maps cleanly to data — `typicalFunction` containing
    /// "preserv" plus `origin == "synthetic"` is accurate as-is.
    case artificialPreservatives

    /// The proteins and grains behind most food sensitivities.
    case commonAllergens

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ultraProcessed: return "Ultra-processed ingredients"
        case .artificialColours: return "Artificial colours"
        case .artificialPreservatives: return "Artificial preservatives"
        case .commonAllergens: return "Common allergens"
        }
    }

    /// Concrete examples, shown under the title. The category names alone mean
    /// little to a lay owner — "ultra-processed" needs "hydrolyzed protein" next
    /// to it to land.
    var examples: String {
        switch self {
        case .ultraProcessed: return "Hydrolyzed proteins, artificial flavours"
        case .artificialColours: return "Red 40, Yellow 5, Titanium dioxide"
        case .artificialPreservatives: return "BHA, BHT, Ethoxyquin, TBHQ"
        case .commonAllergens: return "Chicken, beef, wheat, dairy, soy"
        }
    }

    var icon: String {
        switch self {
        case .ultraProcessed: return "sparkles"
        case .artificialColours: return "paintpalette.fill"
        case .artificialPreservatives: return "flask.fill"
        case .commonAllergens: return "exclamationmark.triangle.fill"
        }
    }

    /// Superwall attribute key for the per-group boolean. Targeting rules are
    /// far easier to write against booleans than against a joined string.
    var attributeKey: String {
        "avoids_\(rawValue.lowercasedSnakeCase)"
    }
}

private extension String {
    /// `artificialColours` -> `artificial_colours`
    var lowercasedSnakeCase: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                result.append("_")
                result.append(contentsOf: character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
