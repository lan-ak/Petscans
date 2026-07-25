import Foundation

/// Singleton that loads and provides access to the bundled ingredient database
/// Uses background loading to avoid blocking app startup
///
/// `@Observable` so views reading the collections below re-render when the load
/// lands. Since removing the splash screen, a view can be on screen before the
/// decode finishes — without this, `IngredientSearchSheet` would render an
/// empty list and never update.
@Observable
final class IngredientDatabase {
    static let shared = IngredientDatabase()

    private(set) var ingredients: [String: Ingredient] = [:]
    private(set) var rules: [Rule] = []
    private(set) var synonyms: [String: String] = [:]

    /// Pre-sorted ingredient list (sorted once on load, not on every access)
    private(set) var sortedIngredients: [Ingredient] = []

    /// Rules indexed by ingredient ID for O(1) lookup
    private(set) var rulesByIngredient: [String: [Rule]] = [:]

    /// Whether the bundled JSON has been decoded and published. False for the first
    /// few hundred milliseconds of a launch, so anything rendering the collections
    /// above should show a loading state rather than an empty one until it flips.
    private(set) var isLoaded = false

    /// Assigned exactly once, in `init`, before any other reference to the instance
    /// exists — so `waitForLoad()` can never observe it as nil.
    ///
    /// It used to be cleared at the end of the load, which made it a genuine data
    /// race for no benefit: the write happened on the main actor while `waitForLoad()`
    /// reads it from whatever executor its caller is on, and awaiting an
    /// already-finished `Task` returns immediately regardless.
    private var loadingTask: Task<Void, Never>!

    private init() {
        // Start loading immediately in background - doesn't block main thread
        loadingTask = Task.detached(priority: .userInitiated) { [weak self] in
            let ingredients = Self.loadIngredients()
            let rules = Self.loadRules()
            let synonyms = Self.loadSynonyms()

            // Pre-sort ingredients once (expensive operation done in background)
            let sorted = Array(ingredients.values)
                .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }

            // Pre-index rules by ingredient ID for O(1) lookup
            let ruleIndex = Dictionary(grouping: rules) { $0.ingredientId }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.ingredients = ingredients
                self.rules = rules
                self.synonyms = synonyms
                self.sortedIngredients = sorted
                self.rulesByIngredient = ruleIndex
                self.isLoaded = true
            }

            LaunchMetrics.mark("ingredientDBLoaded")
            #if DEBUG
            print("IngredientDatabase loaded: \(ingredients.count) ingredients, \(rules.count) rules, \(synonyms.count) synonyms")
            #endif
        }
    }

    /// Wait for database to finish loading (call before accessing data)
    func waitForLoad() async {
        await loadingTask.value
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
