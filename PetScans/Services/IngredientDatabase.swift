import Foundation

/// Singleton that loads and provides access to the bundled ingredient database
final class IngredientDatabase {
    static let shared = IngredientDatabase()

    let ingredients: [String: Ingredient]
    let rules: [Rule]
    let synonyms: [String: String]

    private init() {
        ingredients = Self.loadIngredients()
        rules = Self.loadRules()
        synonyms = Self.loadSynonyms()

        print("IngredientDatabase loaded: \(ingredients.count) ingredients, \(rules.count) rules, \(synonyms.count) synonyms")
    }

    private static func loadIngredients() -> [String: Ingredient] {
        guard let url = Bundle.main.url(forResource: "ingredients", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load ingredients.json")
            return [:]
        }

        do {
            let list = try JSONDecoder().decode([Ingredient].self, from: data)
            return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            print("Failed to decode ingredients.json: \(error)")
            return [:]
        }
    }

    private static func loadRules() -> [Rule] {
        guard let url = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load rules.json")
            return []
        }

        do {
            return try JSONDecoder().decode([Rule].self, from: data)
        } catch {
            print("Failed to decode rules.json: \(error)")
            return []
        }
    }

    private static func loadSynonyms() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "synonyms", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load synonyms.json")
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Failed to decode synonyms.json: \(error)")
            return [:]
        }
    }

    /// Get rules that apply to a specific species and category
    func rules(for species: Species, category: Category) -> [Rule] {
        rules.filter { rule in
            rule.appliesTo.species.contains(species) &&
            rule.appliesTo.categories.contains(category)
        }
    }
}
