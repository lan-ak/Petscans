#if DEBUG
import SwiftUI
import UIKit

/// Renders the companion rigs to transparent PNGs so the Superwall onboarding
/// surface can ship the *same* artwork the native screens draw.
///
/// The companions are code-drawn (`CompanionCanvas` and friends), not image
/// assets, so there is no file to hand the webview. Re-drawing them in SVG
/// would be a second source of truth that drifts the first time the rig
/// changes; rendering the real views keeps one.
///
/// DEBUG-only and launch-argument gated, so it is never reachable in a
/// release build. Run with `-ExportCompanions`, then pull them out of the
/// app container:
///
///     xcrun simctl launch <sim> com.petscans.app -ExportCompanions
///     xcrun simctl get_app_container <sim> com.petscans.app data
///
/// Output lands in `Documents/companion-export/`.
@MainActor
enum CompanionExport {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-ExportCompanions")
    }

    /// 3x, matching the densest screen the surface runs on. The webview scales
    /// down cleanly; it cannot scale up.
    private static let scale: CGFloat = 3

    static func runIfRequested() {
        guard isRequested else { return }

        let dir = URL.documentsDirectory.appending(path: "companion-export")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Entrance animations start from a transformed state, and a render
        // taken on frame zero would catch the rig mid-arrival. `entranceDelay`
        // is the only knob that matters here; mood stays neutral because that
        // is what both onboarding screens show.
        write(CompanionView(species: .dog, height: 156 * 1.0), to: dir, name: "companion-dog")
        write(CompanionView(species: .cat, height: 156 * 0.9), to: dir, name: "companion-cat")
        write(CompanionPair(height: 156), to: dir, name: "companion-pair")

        NSLog("[CompanionExport] wrote PNGs to \(dir.path)")
    }

    private static func write<V: View>(_ view: V, to dir: URL, name: String) {
        // Fixed sizing so the renderer measures the rig and not the screen.
        let renderer = ImageRenderer(content: view.fixedSize())
        renderer.scale = scale
        // Transparent, so the art composites onto whichever ground the surface
        // is using — the page background differs between light and dark.
        renderer.isOpaque = false

        guard let image = renderer.uiImage, let data = image.pngData() else {
            NSLog("[CompanionExport] FAILED to render \(name)")
            return
        }
        try? data.write(to: dir.appending(path: "\(name)@3x.png"))
    }
}

/// Writes the cold (no-pet) result for every `DemoFoods` row as JSON, so the
/// onboarding surface can render step 2 without a callback.
///
/// Those six results never change between releases of the surface — no pet,
/// no allergens, a fixed catalogue row — so the surface ships them baked in,
/// and only the personalised re-score goes back to the app. Generated from
/// the real `OnboardingFoodScorer` and `IngredientDatabase`, never typed by
/// hand: a demo that scored differently from the scanner would be a lie told
/// at the first moment of the funnel.
///
///     xcrun simctl launch <sim> com.petscans.app -ExportDemoResults
///     → Documents/demo-results.json
///
/// Copy it to `superwall/paywalls/onboarding-flow/lib/demoResults.json`, and
/// re-run after any change to the catalogue, the matcher or the scorer.
@MainActor
enum DemoResultExport {
    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-ExportDemoResults") else { return }

        var foods: [String: Any] = [:]
        for species in [Species.dog, .cat] {
            for product in await DemoFoods.products(for: species) {
                var food = await export(product, species: species)
                food["personal"] = await personal(product, species: species)
                foods[product.gtin] = food
            }
        }
        // `IngredientSearchSheet`'s list, for "Search for more…" on pet setup.
        let index: [[String: Any]] = IngredientDatabase.shared.sortedIngredients.map { ing in
            [
                "id": ing.commonName.lowercased(),
                "name": ing.commonName,
                "scientific": ing.scientificName ?? "",
                "function": ing.typicalFunction ?? "",
                "dogTier": tierToken(RiskTier(ing.riskLevel.dog)),
                "catTier": tierToken(RiskTier(ing.riskLevel.cat)),
            ]
        }
        let out: [String: Any] = ["foods": foods, "ingredients": index]

        let url = URL.documentsDirectory.appending(path: "demo-results.json")
        if let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
            NSLog("[DemoResultExport] wrote \(foods.count) results to \(url.path)")
        } else {
            NSLog("[DemoResultExport] FAILED to serialise")
        }
    }

    private static func export(_ product: CatalogProduct, species: Species) async -> [String: Any] {
        let result = await OnboardingFoodScorer.score(
            product: product, petName: nil, allergens: [], groups: [], species: species
        )
        let b = result.breakdown
        let db = IngredientDatabase.shared

        return [
            "gtin": product.gtin,
            "species": species.rawValue,
            "name": product.name,
            "brand": product.brand?.trimmed ?? "",
            "score": Int(b.total.rounded()),
            "verdict": b.ratingLabel.rawValue,
            // `OnboardingFoodResultView.hasConcerns`.
            "hasConcerns": b.ratingLabel == .caution || b.ratingLabel == .avoid,
            "flagCount": b.flags.count,
            // Same shape and tokens as `OnboardingFlowCallbacks.score`, so the
            // baked result and a `rescoreForPet` answer are interchangeable.
            "flags": b.flags.map { f -> [String: Any] in
                let severity: String
                switch f.severity {
                case .critical, .high: severity = "high"
                case .warn: severity = "warning"
                case .info: severity = "info"
                }
                return ["label": f.title, "severity": severity, "count": 1]
            },
            "safety": card(b.safety, b.safetyExplanation),
            "processing": b.processing.map { card($0, b.processingExplanation) } ?? NSNull(),
            "ingredients": result.matched.map { mi -> [String: Any] in
                guard let id = mi.ingredientId, let ing = db.ingredients[id] else {
                    return ["label": mi.labelName]
                }
                return ["label": mi.labelName, "detail": detail(ing, species: species)]
            },
        ]
    }

    /// What step 5 shows besides the verdict, which `rescoreForPet` supplies.
    ///
    /// The 1.4.8 callback returns only the score, the verdict and flag titles,
    /// so the allergen banner and the watch-list card are baked here instead,
    /// one profile item at a time: every allergen the owner could pick (the
    /// quick picks and all of `IngredientSearchSheet`) and every group. Flags
    /// are per matched ingredient, so a profile's banner is the union of its
    /// items'. `{pet}` stands in for the name the owner types.
    private static func personal(_ product: CatalogProduct, species: Species) async -> [String: Any] {
        let data = IngredientDatabase.shared.data
        let matched = await IngredientMatcher().match(rawIngredients: product.ingredients)
        let calc = ScoreCalculator()
        func run(_ allergens: [String], _ groups: Set<AvoidanceGroup>) -> ScoreBreakdown {
            calc.calculate(
                species: species, category: product.category, matched: matched, data: data,
                petAllergens: allergens, petName: "{pet}", avoidanceGroups: groups
            )
        }
        func flag(_ f: WarningFlag) -> [String: Any] {
            ["title": f.title, "explain": f.explain, "severity": f.severity.rawValue,
             "severityName": f.severity.displayName, "source": f.source ?? ""]
        }

        let ids = Set(QuickPickAllergens.list(for: species).map(\.id)
            + IngredientDatabase.shared.sortedIngredients.map { $0.commonName.lowercased() })
        var allergens: [String: Any] = [:]
        for id in ids.sorted() {
            let b = run([id], [])
            guard !b.allergenFlags.isEmpty else { continue }
            allergens[id] = ["flags": b.allergenFlags.map(flag), "names": b.allergenIngredientNames]
        }

        var groups: [String: Any] = [:]
        for g in AvoidanceGroup.allCases {
            let explains = run([], [g]).flags.filter { $0.type == .avoidanceGroup }.map(\.explain)
            if !explains.isEmpty { groups[g.rawValue] = explains }
        }

        return [
            "allergens": allergens,
            "groups": groups,
            // The verdict card's line when allergens were picked and none hit.
            "noAllergenSummary": run(["__none__"], []).suitabilityExplanation?.summary ?? "",
        ]
    }

    /// What `ScoreExplanationCard` draws: the label it picks, the bar width it
    /// picks, and the expandable summary and factors.
    private static func card(_ score: Double, _ e: ScoreExplanation?) -> [String: Any] {
        let label = e?.labelOverride ?? RatingLabel.from(score: score)
        let bar: Double
        switch e?.labelOverride {
        case .avoid: bar = 0
        case .caution: bar = 35
        case .good: bar = 60
        default: bar = score
        }
        return [
            "score": Int(score.rounded()),
            "label": label.rawValue,
            "bar": Int(bar.rounded()),
            "summary": e?.summary ?? "",
            "factors": (e?.factors ?? []).map { f in
                ["impact": f.impact.rawValue, "name": f.ingredientName ?? "", "text": f.description]
            },
        ]
    }

    /// The parts of `IngredientDetailSheet` that hold with no pet and no
    /// History: header, about, safety, symptoms, dose, notes and rules.
    private static func detail(_ ing: Ingredient, species: Species) -> [String: Any] {
        let tier = RiskTier(ing.riskLevel(for: species))
        var d: [String: Any] = [
            "name": ing.commonName,
            "scientific": ing.scientificName ?? "",
            "function": ing.typicalFunction ?? "",
            "tier": tierToken(tier),
            "tierName": tier.displayName,
            "notes": ing.notes ?? "",
            "symptoms": ing.toxicitySymptoms ?? [],
            "dose": ing.toxicDose(for: species) ?? "",
            // The Details card and Sources, as `IngredientDetailSheet` lays them out.
            "origin": ing.origin.capitalized,
            "allergenRisk": ing.allergenRisk(for: species) ?? "",
            "suitableFor": ing.species.map(\.rawValue),
            "sources": ing.allSources,
        ]
        if let level = ing.processingLevel {
            let tone: String
            switch level {
            case .unprocessed: tone = "excellent"
            case .culinaryIngredient: tone = "good"
            case .processed: tone = "moderate"
            case .ultraProcessed: tone = "poor"
            }
            d["processing"] = ["name": level.shortName, "tone": tone, "level": level.rawValue]
        }
        if let c = IngredientDatabase.shared.data.content[ing.id], !c.isEmpty {
            d["about"] = ["whatItIs": c.whatItIs, "whyItsHere": c.whyItsHere, "watch": c.whatToWatchFor ?? ""]
        } else {
            d["composed"] = ing.composedSummary() ?? ""
        }
        if ing.riskLevel.dog != ing.riskLevel.cat {
            d["perSpecies"] = [
                "dog": RiskTier(ing.riskLevel.dog).displayName,
                "dogTier": tierToken(RiskTier(ing.riskLevel.dog)),
                "cat": RiskTier(ing.riskLevel.cat).displayName,
                "catTier": tierToken(RiskTier(ing.riskLevel.cat)),
            ]
        }
        d["rules"] = (IngredientDatabase.shared.rulesByIngredient[ing.id] ?? [])
            .filter { $0.appliesTo.species.contains(species) }
            .sorted { $0.severity.sortOrder < $1.severity.sortOrder }
            .map { r in
                ["severity": r.severity.rawValue, "severityName": r.severity.displayName,
                 "evidence": r.evidence, "explain": r.explain, "source": r.source ?? ""]
            }
        return d
    }

    private static func tierToken(_ tier: RiskTier) -> String {
        switch tier {
        case .toxic: return "toxic"
        case .caution: return "caution"
        case .moderation: return "moderation"
        case .mostlySafe: return "mostlySafe"
        case .safe: return "safe"
        }
    }
}
#endif
