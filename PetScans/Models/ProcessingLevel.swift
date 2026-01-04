import SwiftUI

/// Pet-Adapted NOVA Classification for food processing levels
/// Based on NOVA food classification system adapted for pet food context
///
/// This classification is for informational purposes only and does NOT
/// affect safety, nutrition, or suitability scores.
enum ProcessingLevel: Int, Codable, CaseIterable, Identifiable {
    /// Group 1: Unprocessed or minimally processed foods
    /// Whole foods with no or minimal processing (fresh meat, whole grains, fresh vegetables)
    case unprocessed = 1

    /// Group 2: Processed culinary ingredients
    /// Extracted/refined ingredients used in preparation (rendered fats, starches, flours, oils)
    case culinaryIngredient = 2

    /// Group 3: Processed foods
    /// Foods processed with preservation methods (meal, dried, canned, by-products)
    case processed = 3

    /// Group 4: Ultra-processed products
    /// Industrial formulations with additives (hydrolyzed proteins, artificial flavors, synthetic vitamins)
    case ultraProcessed = 4

    var id: Int { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .unprocessed: return "Minimally Processed"
        case .culinaryIngredient: return "Culinary Ingredient"
        case .processed: return "Processed"
        case .ultraProcessed: return "Ultra-Processed"
        }
    }

    var shortName: String {
        switch self {
        case .unprocessed: return "Natural"
        case .culinaryIngredient: return "Refined"
        case .processed: return "Processed"
        case .ultraProcessed: return "Ultra"
        }
    }

    var description: String {
        switch self {
        case .unprocessed:
            return "Whole foods with minimal processing such as fresh meat, whole grains, and fresh vegetables."
        case .culinaryIngredient:
            return "Extracted or refined ingredients used in cooking such as rendered fats, starches, and flours."
        case .processed:
            return "Foods processed with salt, oil, or preservation methods such as meal, dried ingredients, and some by-products."
        case .ultraProcessed:
            return "Industrial formulations with additives such as hydrolyzed proteins, artificial flavors, and synthetic vitamins."
        }
    }

    // MARK: - Visual Properties

    var icon: String {
        switch self {
        case .unprocessed: return "leaf.fill"
        case .culinaryIngredient: return "flame.fill"
        case .processed: return "gearshape.fill"
        case .ultraProcessed: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .unprocessed: return ColorTokens.scoreExcellent
        case .culinaryIngredient: return ColorTokens.scoreGood
        case .processed: return ColorTokens.scoreModerate
        case .ultraProcessed: return ColorTokens.scorePoor
        }
    }

    // MARK: - Examples

    /// Example ingredients for each processing level (for educational UI)
    var examples: [String] {
        switch self {
        case .unprocessed:
            return ["Deboned chicken", "Fresh salmon", "Whole brown rice", "Fresh peas", "Whole eggs"]
        case .culinaryIngredient:
            return ["Chicken fat", "Rice flour", "Tapioca starch", "Fish oil", "Sunflower oil"]
        case .processed:
            return ["Chicken meal", "Dried beet pulp", "Meat by-products", "Dried egg product"]
        case .ultraProcessed:
            return ["Hydrolyzed protein", "Artificial colors", "BHA/BHT", "Synthetic vitamins", "Propylene glycol"]
        }
    }
}
