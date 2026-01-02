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

        #if DEBUG
        print("IngredientDatabase loaded: \(ingredients.count) ingredients, \(rules.count) rules, \(synonyms.count) synonyms")
        #endif
    }

    private static func loadIngredients() -> [String: Ingredient] {
        guard let url = Bundle.main.url(forResource: "ingredients", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("Failed to load ingredients.json")
            #endif
            return [:]
        }

        do {
            let list = try JSONDecoder().decode([Ingredient].self, from: data)
            return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            #if DEBUG
            print("Failed to decode ingredients.json: \(error)")
            #endif
            return [:]
        }
    }

    private static func loadRules() -> [Rule] {
        guard let url = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("Failed to load rules.json")
            #endif
            return []
        }

        do {
            return try JSONDecoder().decode([Rule].self, from: data)
        } catch {
            #if DEBUG
            print("Failed to decode rules.json: \(error)")
            #endif
            return []
        }
    }

    private static func loadSynonyms() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "synonyms", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("Failed to load synonyms.json")
            #endif
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            #if DEBUG
            print("Failed to decode synonyms.json: \(error)")
            #endif
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
