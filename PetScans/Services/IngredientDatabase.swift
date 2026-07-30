import Foundation

/// Loads the bundled ingredient database in the background and publishes it.
///
/// This is now a thin observable wrapper: the data itself, and every operation on
/// it, lives in `IngredientData`. Keeping the singleton free of logic is what lets
/// `IngredientMatcher`, `ScoreCalculator` and the `matchkit` offline harness run
/// against the same code with no shared global.
///
/// `@Observable` so views reading the collections below re-render when the load
/// lands. Since removing the splash screen, a view can be on screen before the
/// decode finishes — without this, `IngredientSearchSheet` would render an
/// empty list and never update.
@Observable
final class IngredientDatabase {
    static let shared = IngredientDatabase()

    /// The decoded database. Empty until the background load lands.
    private(set) var data: IngredientData = .empty

    /// Whether the bundled JSON has been decoded and published. False for the first
    /// few hundred milliseconds of a launch, so anything rendering the collections
    /// below should show a loading state rather than an empty one until it flips.
    private(set) var isLoaded = false

    // Pass-throughs, so existing call sites read the same way they always have.
    var ingredients: [String: Ingredient] { data.ingredients }
    var rules: [Rule] { data.rules }
    var synonyms: [String: String] { data.synonyms }

    /// Curated map of ingredient ID -> the avoidance groups it belongs to, from
    /// `avoidance-groups.json`. Consumed by `ScoreCalculator` to raise warning flags
    /// for the groups an owner selected. Empty until the load lands.
    var avoidanceGroups: [String: Set<AvoidanceGroup>] { data.avoidanceGroups }

    /// Pre-sorted ingredient list (sorted once on load, not on every access)
    var sortedIngredients: [Ingredient] { data.sortedIngredients }

    /// Rules indexed by ingredient ID for O(1) lookup
    var rulesByIngredient: [String: [Rule]] { data.rulesByIngredient }

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
            let loaded = IngredientData.load(from: .bundle(.main))

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.data = loaded
                self.isLoaded = true
            }

            LaunchMetrics.mark("ingredientDBLoaded")
            #if DEBUG
            print("IngredientDatabase loaded: \(loaded.ingredients.count) ingredients, \(loaded.rules.count) rules, \(loaded.synonyms.count) synonyms")
            #endif
        }
    }

    /// Wait for the database to finish loading, then hand back the data.
    ///
    /// Returning it rather than making callers read `.shared` afterwards means the
    /// matcher and scorer take their input as a parameter and stay pure.
    @discardableResult
    func waitForLoad() async -> IngredientData {
        await loadingTask.value
        return data
    }

    /// Get rules that apply to a specific species and category
    func rules(for species: Species, category: Category) -> [Rule] {
        data.rules(for: species, category: category)
    }
}
