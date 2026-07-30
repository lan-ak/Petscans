import Foundation

/// The whole ingredient knowledge base as a plain value.
///
/// This exists so the two things that consume it — `IngredientMatcher` and
/// `ScoreCalculator` — can be handed their data instead of reaching for
/// `IngredientDatabase.shared`. That buys three things:
///
/// 1. **Testability.** A test can score a product against a five-ingredient
///    fixture without booting a singleton or waiting on a background load.
/// 2. **An offline harness.** `matchkit` runs the *same* matcher and scorer over
///    the full bundled catalog to measure coverage and audit score changes before
///    they ship. Sharing this type is what makes those numbers predictive of what
///    the app will actually do, rather than an approximation of it.
/// 3. **Determinism.** `synonymsByLengthDescending` is built once here, which is
///    what lets fuzzy matching pick the longest key rather than whichever one
///    `Dictionary` iteration happened to yield this launch.
///
/// Construct it with `load(from:)` for the app bundle, or `init(...)` directly
/// from decoded values in tests and offline tools.
struct IngredientData: Sendable {
    let ingredients: [String: Ingredient]
    let rules: [Rule]
    let synonyms: [String: String]
    let avoidanceGroups: [String: Set<AvoidanceGroup>]

    /// Plain-language explanations, from `ingredient-content.json`. Display-only —
    /// nothing in scoring or matching reads it. Empty until the load lands, and
    /// partial by design: `Ingredient.composedSummary()` covers the gaps.
    let content: [String: IngredientContent]

    /// Alphabetical, for the ingredient picker. Sorted once at load rather than
    /// on every access.
    let sortedIngredients: [Ingredient]

    /// Rules grouped by the ingredient they apply to, for O(1) lookup.
    let rulesByIngredient: [String: [Rule]]

    /// Synonym keys ordered longest-first, so a containment search resolves
    /// "chicken meal" to chicken meal rather than to whichever of chicken /
    /// chicken meal the hash order surfaced first.
    let synonymsByLengthDescending: [(key: String, id: String)]

    static let empty = IngredientData(ingredients: [:], rules: [], synonyms: [:], avoidanceGroups: [:])

    init(
        ingredients: [String: Ingredient],
        rules: [Rule],
        synonyms: [String: String],
        avoidanceGroups: [String: Set<AvoidanceGroup>],
        content: [String: IngredientContent] = [:]
    ) {
        self.ingredients = ingredients
        self.rules = rules
        self.avoidanceGroups = avoidanceGroups
        self.content = content
        self.synonyms = Self.synonymsIncludingIngredientNames(synonyms, ingredients: ingredients)

        self.sortedIngredients = ingredients.values
            .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
        self.rulesByIngredient = Dictionary(grouping: rules) { $0.ingredientId }
        self.synonymsByLengthDescending = self.synonyms
            .map { (key: $0.key, id: $0.value) }
            // Length first, then the key itself: without the tiebreak, two keys of
            // equal length would still be in hash order and the result would vary
            // between launches — the exact bug this ordering exists to remove.
            .sorted { ($0.key.count, $0.key) > ($1.key.count, $1.key) }
    }

    /// Every ingredient's own name, and its scientific name, become lookup keys.
    ///
    /// `synonyms.json` is hand-maintained and only covers the spellings someone
    /// thought to add. Measured against the shipped data, **311 of 625 ingredients
    /// had no synonym pointing at them at all** — half the database was reachable
    /// only by the fuzzy containment fallback, which is a guess. An ingredient
    /// called "Acacia gum" should obviously match the label token "acacia gum";
    /// nothing but an oversight made that a guess instead of a lookup.
    ///
    /// **Curated entries always win** — this only fills gaps. A deliberate mapping
    /// in `synonyms.json` is never overridden by a derived one.
    ///
    /// That rule leaves 142 ingredients shadowed: `synonyms.json` maps "animal fat"
    /// to chicken fat and "beef liver" to the generic liver, even though
    /// `ing_animal_fat` and `ing_beef_liver` exist and are more specific. Letting
    /// names win instead was measured — it moved 92% of products' scores (mean
    /// -1.52) for a net-better but broad label change (385 improved, 18 worse).
    /// Too wide to adopt as a blanket rule: some of those generalizations are
    /// deliberate, because rules and avoidance groups hang off the generic entry.
    /// The shadowed pairs are a curation task, listed by
    /// `DataValidationTests.testIngredientsShadowedByCuratedSynonyms`.
    ///
    /// Derived keys are applied in a defined order (id-sorted) so two ingredients
    /// sharing a normalized name resolve the same way on every launch rather than
    /// by hash order — the same determinism requirement as
    /// `synonymsByLengthDescending`.
    ///
    /// Normalization goes through `IngredientMatcher.normalizeToken`, the same
    /// function the lookup uses. Anything else would produce keys the matcher
    /// cannot reach.
    private static func synonymsIncludingIngredientNames(
        _ curated: [String: String],
        ingredients: [String: Ingredient]
    ) -> [String: String] {
        var result = curated
        for ingredient in ingredients.values.sorted(by: { $0.id < $1.id }) {
            for name in [ingredient.commonName, ingredient.scientificName].compactMap({ $0 }) {
                let key = IngredientMatcher.normalizeToken(name)
                guard !key.isEmpty, key.count > 1 else { continue }
                if result[key] == nil { result[key] = ingredient.id }
            }
        }
        return result
    }

    /// Rules applying to a given species and category.
    func rules(for species: Species, category: Category) -> [Rule] {
        rules.filter {
            $0.appliesTo.species.contains(species) && $0.appliesTo.categories.contains(category)
        }
    }
}

// MARK: - Loading

extension IngredientData {
    /// Where the four data files come from. The app passes a bundle; `matchkit`
    /// and tests pass a directory.
    enum Source {
        case bundle(Bundle)
        case directory(URL)

        func data(named name: String) -> Data? {
            switch self {
            case .bundle(let bundle):
                guard let url = bundle.url(forResource: name, withExtension: "json") else { return nil }
                return try? Data(contentsOf: url)
            case .directory(let dir):
                return try? Data(contentsOf: dir.appendingPathComponent("\(name).json"))
            }
        }
    }

    /// Decodes all four files. A file that is missing or malformed yields an empty
    /// collection and a debug log rather than a failure — the app must still launch
    /// with a degraded database, and the data-validation tests are what actually
    /// catch a broken file before it ships.
    static func load(from source: Source) -> IngredientData {
        IngredientData(
            ingredients: decodeIngredients(source.data(named: "ingredients")),
            rules: decode([Rule].self, from: source.data(named: "rules"), name: "rules") ?? [],
            synonyms: decode([String: String].self, from: source.data(named: "synonyms"), name: "synonyms") ?? [:],
            avoidanceGroups: decodeAvoidanceGroups(source.data(named: "avoidance-groups")),
            content: decode([String: IngredientContent].self,
                            from: source.data(named: "ingredient-content"),
                            name: "ingredient-content") ?? [:]
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?, name: String) -> T? {
        guard let data else {
            debugLog("Failed to load \(name).json")
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            debugLog("Failed to decode \(name).json: \(error)")
            return nil
        }
    }

    private static func decodeIngredients(_ data: Data?) -> [String: Ingredient] {
        guard let list = decode([Ingredient].self, from: data, name: "ingredients") else { return [:] }
        // Keyed rather than `uniqueKeysWithValues`: a duplicate id in the hand-maintained
        // file would trap at launch. Last-wins here, and a data-validation test fails the build.
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    private static func decodeAvoidanceGroups(_ data: Data?) -> [String: Set<AvoidanceGroup>] {
        // File is id -> [group rawValue]; unknown group strings are ignored so a
        // future group added to the JSON can't break decode on an older build.
        guard let raw = decode([String: [String]].self, from: data, name: "avoidance-groups") else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            let groups = Set(pair.value.compactMap(AvoidanceGroup.init(rawValue:)))
            if !groups.isEmpty { result[pair.key] = groups }
        }
    }

    private static func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}
