import Foundation
import SwiftData

/// Seeds data for App Store screenshots.
///
/// Every product below is a real row from the bundled `catalog.sqlite` — real
/// GTIN, real brand, real retail name, real pack shot, real ingredient list.
/// The previous version invented products ("Generic Brand", `imageUrl: nil`),
/// which is why the live screenshots had blank product headers and redacted
/// title bars. A store listing for a scanner that can't show it recognizing
/// anything is arguing against itself.
///
/// Pet is "Luna", allergic to chicken and wheat, so the three hero products
/// produce a clean pass, a caution, and an allergen conflict — the three
/// verdicts the app exists to deliver. Six more catalog rows sit behind them
/// (`createCatalogScans`) purely so the History list has depth; they contain
/// neither chicken nor wheat, so they score on their own merits and give the
/// list a real spread from 94 down to 0.
///
/// Scores and explanations here are authored, not computed, so they have to be
/// kept honest against the real ingredient lists above them. If you swap a
/// product, swap its ingredients and its reasoning too.
enum ScreenshotDataSeeder {

    static func seed(context: ModelContext) {
        let pet = Pet(
            name: "Luna",
            species: .dog,
            allergens: ["chicken", "wheat"]
        )
        context.insert(pet)

        let scans = [
            createExcellentScan(),
            createGoodScan(),
            createAvoidScan()
        ] + createCatalogScans()

        // Fixed, descending timestamps. `Scan.init` stamps `Date()` on every row, so
        // nine rows built in one pass share a timestamp to the millisecond and
        // History's `sort: \Scan.scannedAt, order: .reverse` degenerates into whatever
        // order SwiftData happens to return. That is not a cosmetic problem: shot 1
        // opens a scan by matching its product name, and an unstable order put the
        // named product below the fold where the list had not rendered it yet.
        //
        // The three hero products are first, so every shot that opens one finds it
        // without scrolling, and shot 5 leads with a 92, a 68 and a 0 rather than with
        // whichever row won the race.
        let seedDate = Date()
        for (offset, scan) in scans.enumerated() {
            let stamp = seedDate.addingTimeInterval(Double(-offset) * 60)
            scan.scannedAt = stamp
            scan.createdAt = stamp
            scan.updatedAt = stamp
            context.insert(scan)
        }

        try? context.save()
    }

    // MARK: - Excellent — Merrick, grain-free beef

    /// The hero shot. Nothing in it conflicts with Luna's chicken/wheat profile,
    /// so it demonstrates a clean pass on a brand people recognize off a shelf.
    private static func createExcellentScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_beef_fresh", labelName: "Deboned Beef", rank: 1),
            MatchedIngredient(ingredientId: "ing_lamb_meal", labelName: "Lamb Meal", rank: 2),
            MatchedIngredient(ingredientId: "ing_sweet_potato", labelName: "Sweet Potatoes", rank: 3),
            MatchedIngredient(ingredientId: "ing_peas", labelName: "Peas", rank: 4),
            MatchedIngredient(ingredientId: "ing_flaxseed", labelName: "Flaxseed Oil", rank: 5),
            MatchedIngredient(ingredientId: "ing_apples", labelName: "Apples", rank: 6),
            MatchedIngredient(ingredientId: "ing_salmon_oil", labelName: "Salmon Oil", rank: 7),
            MatchedIngredient(ingredientId: "ing_blueberries", labelName: "Blueberries", rank: 8)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 92,
            safety: 95,
            suitability: 88,
            processing: 90,
            flags: [],
            unmatched: [],
            matchedCount: 8,
            totalCount: 8,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Named whole-meat first ingredient", impact: .positive, ingredientName: "Deboned Beef"),
                    ExplanationFactor(id: "2", description: "Rich in omega-3 fatty acids", impact: .positive, ingredientName: "Salmon Oil"),
                    ExplanationFactor(id: "3", description: "Antioxidant-rich whole fruit", impact: .positive, ingredientName: "Blueberries")
                ],
                summary: "All ingredients are safe and beneficial for dogs."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Luna."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Majority minimally processed", impact: .positive, ingredientName: nil)
                ],
                summary: "Mostly minimally processed ingredients."
            )
        )

        return Scan(
            barcode: "00022808383390",
            productName: "Grain-Free Real Texas Beef + Sweet Potato Recipe",
            brand: "Merrick",
            imageUrl: "https://i5.walmartimages.com/seo/Merrick-Grain-Free-Real-Texas-Beef-Sweet-Potato-Recipe-Dry-Dog-Food-4-lb_6d8f5d88-c690-4c06-bcf8-53de4189cad3_1.0660777aea1c77aabf1dddfabadab473.jpeg",
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Deboned Beef, Lamb Meal, Sweet Potatoes, Peas, Potatoes, Flaxseed Oil, Apples, Salmon Oil, Blueberries",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    // MARK: - Good — Purina ONE, salmon

    /// A middling result: safe for Luna, but carrying a filler and one vague
    /// ingredient. Shows the app doing something more useful than pass/fail.
    private static func createGoodScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_hydrolyzed_salmon", labelName: "Salmon", rank: 1),
            MatchedIngredient(ingredientId: "ing_rice_flour", labelName: "Rice Flour", rank: 2),
            MatchedIngredient(ingredientId: "ing_barley", labelName: "Pearled Barley", rank: 3),
            MatchedIngredient(ingredientId: "ing_oatmeal", labelName: "Oat Meal", rank: 4),
            MatchedIngredient(ingredientId: "ing_corn_gluten_meal", labelName: "Corn Gluten Meal", rank: 5),
            MatchedIngredient(ingredientId: "ing_beef_fat", labelName: "Beef Fat", rank: 6),
            MatchedIngredient(ingredientId: nil, labelName: "Liver Flavor", rank: 7)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 68,
            safety: 75,
            suitability: 82,
            processing: 58,
            flags: [
                WarningFlag(
                    severity: .info,
                    title: "Unspecified ingredient",
                    explain: "\"Liver flavor\" doesn't name a species or a source, so there's no way to tell what's actually in it.",
                    ingredientId: nil,
                    source: nil,
                    type: .general
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Plant protein filler",
                    explain: "Corn gluten meal raises the protein number on the label without contributing the amino acid profile a dog gets from meat.",
                    ingredientId: "ing_corn_gluten_meal",
                    source: "AAFCO 2024",
                    type: .safety
                )
            ],
            unmatched: ["Liver Flavor"],
            matchedCount: 6,
            totalCount: 7,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Named whole-fish first ingredient", impact: .positive, ingredientName: "Salmon"),
                    ExplanationFactor(id: "2", description: "Whole grain carbohydrate", impact: .positive, ingredientName: "Pearled Barley"),
                    ExplanationFactor(id: "3", description: "Plant protein used as filler", impact: .negative, ingredientName: "Corn Gluten Meal")
                ],
                summary: "Generally safe with minor considerations."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Luna."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Refined grain fraction", impact: .negative, ingredientName: "Rice Flour"),
                    ExplanationFactor(id: "2", description: "Highly processed protein isolate", impact: .negative, ingredientName: "Corn Gluten Meal")
                ],
                summary: "Several refined and processed ingredients."
            )
        )

        return Scan(
            barcode: "00370255731777",
            productName: "Sensitive Skin & Stomach Dry Dog Food",
            brand: "Purina ONE",
            imageUrl: "https://i5.walmartimages.com/seo/Purina-One-31-lb-Sensitive-Skin-and-Stomach-Dog-Food_d6af95aa-cd09-4619-8147-437e9c8bf4e0.27a051e993fe9e5a36a247590b3b8a34.jpeg",
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Salmon, Rice Flour, Pearled Barley, Oat Meal, Corn Gluten Meal, Beef Fat, Liver Flavor",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    // MARK: - Avoid — Milk-Bone, wheat + additives

    /// The allergen shot. Wheat flour is the first ingredient and poultry digest
    /// is chicken-derived, so this trips both of Luna's allergens at once and
    /// carries preservatives and dye on top of it.
    private static func createAvoidScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_wheat", labelName: "Wheat Flour", rank: 1),
            MatchedIngredient(ingredientId: "ing_meat_and_bone_meal", labelName: "Meat and Bone Meal", rank: 2),
            MatchedIngredient(ingredientId: "ing_sorbitol", labelName: "Sugar", rank: 3),
            MatchedIngredient(ingredientId: "ing_poultry_digest", labelName: "Poultry Digest", rank: 4),
            MatchedIngredient(ingredientId: "ing_bha", labelName: "BHA/BHT", rank: 5),
            MatchedIngredient(ingredientId: "ing_artificial_colors", labelName: "Added Color", rank: 6)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 0,
            safety: 38,
            suitability: 0,
            processing: 22,
            flags: [
                WarningFlag(
                    severity: .high,
                    title: "Allergen detected: Wheat",
                    explain: "Wheat flour is the first ingredient, and wheat is listed in Luna's allergen profile.",
                    ingredientId: "ing_wheat",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .high,
                    title: "Allergen detected: Chicken",
                    explain: "Poultry digest is chicken-derived, and chicken is listed in Luna's allergen profile.",
                    ingredientId: "ing_poultry_digest",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Controversial preservative",
                    explain: "BHA and BHT are synthetic preservatives. Both are permitted in pet food, but are restricted in human food in several countries.",
                    ingredientId: "ing_bha",
                    source: "FDA 21 CFR 582.3169",
                    type: .safety
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Artificial coloring",
                    explain: "Added color does nothing for the dog. It's there so the treat looks like meat to the person buying it.",
                    ingredientId: "ing_artificial_colors",
                    source: nil,
                    type: .safety
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Unnamed meat source",
                    explain: "\"Meat and bone meal\" doesn't identify a species, so the protein quality can't be assessed.",
                    ingredientId: "ing_meat_and_bone_meal",
                    source: "AAFCO 2024",
                    type: .safety
                )
            ],
            unmatched: [],
            matchedCount: 6,
            totalCount: 6,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Synthetic preservative", impact: .negative, ingredientName: "BHA/BHT"),
                    ExplanationFactor(id: "2", description: "Unnamed protein source", impact: .negative, ingredientName: "Meat and Bone Meal"),
                    ExplanationFactor(id: "3", description: "Added sugar in a daily treat", impact: .negative, ingredientName: "Sugar")
                ],
                summary: "Contains ingredients that may require attention."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Contains allergen for Luna", impact: .negative, ingredientName: "Wheat Flour"),
                    ExplanationFactor(id: "2", description: "Contains allergen for Luna", impact: .negative, ingredientName: "Poultry Digest")
                ],
                summary: "Contains 2 ingredients Luna should avoid. Score set to Avoid.",
                labelOverride: .avoid
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Refined flour base", impact: .negative, ingredientName: "Wheat Flour"),
                    ExplanationFactor(id: "2", description: "Rendered by-product", impact: .negative, ingredientName: "Meat and Bone Meal")
                ],
                summary: "Several processed or ultra-processed ingredients."
            )
        )

        return Scan(
            barcode: "00079100902071",
            productName: "MaroSnacks Small Dog Treats With Bone Marrow",
            brand: "Milk-Bone",
            imageUrl: "https://i5.walmartimages.com/seo/Milk-Bone-MaroSnacks-Small-Dog-Treats-With-Bone-Marrow-10-Ounces_64feec16-9d1e-4ed2-be4e-8b40c9ae14c9.8e796c560ff714305e7734c8be383cf2.jpeg",
            category: .treat,
            targetSpecies: .dog,
            rawIngredientText: "Wheat Flour, Meat and Bone Meal, Sugar, Poultry Digest, Beef Fat (Preserved with BHA/BHT), Salt, Added Color",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    // MARK: - Catalog depth — the shelf behind "30,000+ foods built in"

    /// Six more real catalog rows, so the History list reads as a scored shelf
    /// rather than three items sitting under a caption claiming thirty thousand.
    ///
    /// All six are dog products containing neither chicken nor wheat, so none of
    /// them trips Luna's profile and every score reflects the food rather than an
    /// allergen override — which is what lets the list show a real spread from 94
    /// down to 34 instead of a column of reds.
    ///
    /// Ingredient text is the decompressed `catalog.sqlite` row, verbatim. Where the
    /// ingredient dictionary genuinely has no entry — cane sugar, molasses — the row
    /// is left unmatched rather than pointed at an invented id, so the recognition
    /// percentages on each detail screen stay true.
    private static func createCatalogScans() -> [Scan] {
        [
            scan(
                barcode: "00064992080686",
                name: "ORIJEN Regional Red Grain-Free Dry Dog Food, 15-lb bag",
                brand: "ORIJEN",
                imageUrl: "https://image.chewy.com/is/catalog/60886._AC_SX275_V1460478784_.jpg",
                category: .food,
                total: 94, safety: 96, suitability: 95, processing: 90,
                ingredientText: "Beef, Wild Boar, Lamb, Pork, Beef Liver, Beef Meal, Lamb Meal, Mackerel Meal, Herring Meal, Pork Meal, Whole Red Lentils, Whole Pinto Beans, Whole Navy Beans, Whole Green Lentils, Whole Chickpeas",
                matched: [
                    ("ing_beef", "Beef"), ("ing_wild_boar", "Wild Boar"), ("ing_lamb", "Lamb"),
                    ("ing_pork", "Pork"), ("ing_beef_liver", "Beef Liver"), ("ing_beef_meal", "Beef Meal"),
                    ("ing_lamb_meal", "Lamb Meal"), ("ing_mackerel_meal", "Mackerel Meal"),
                    ("ing_herring_meal", "Herring Meal"), ("ing_pork_meal", "Pork Meal"),
                    ("ing_red_lentils", "Whole Red Lentils"), ("ing_pinto_beans", "Whole Pinto Beans"),
                    ("ing_navy_beans", "Whole Navy Beans"), ("ing_green_lentils", "Whole Green Lentils"),
                    ("ing_chickpeas", "Whole Chickpeas")
                ],
                flags: [],
                safetySummary: "Five named whole meats before the first plant ingredient.",
                processingSummary: "Whole meats and whole pulses, minimally processed."
            ),
            scan(
                barcode: "00064992513252",
                name: "Acana Singles Grain-Free Pork & Squash Dry Dog Food, 25 lb",
                brand: "ACANA",
                imageUrl: "https://i5.walmartimages.com/seo/Acana-Singles-Grain-Free-Pork-Squash-Dry-Dog-Food-25-lb_de784214-54ba-4fca-ba59-7057fe56c1f4_2.fbb07149abfdc1494c2b8d7eb493a38c.jpeg",
                category: .food,
                total: 88, safety: 92, suitability: 94, processing: 84,
                ingredientText: "Deboned pork, pork meal, whole green peas, red lentils, pork liver, pork fat, pinto beans, chickpeas, herring oil, green lentils, whole butternut squash",
                matched: [
                    ("ing_pork_fresh", "Deboned Pork"), ("ing_pork_meal", "Pork Meal"),
                    ("ing_green_peas", "Whole Green Peas"), ("ing_red_lentils", "Red Lentils"),
                    ("ing_pork_liver", "Pork Liver"), ("ing_pork_fat", "Pork Fat"),
                    ("ing_pinto_beans", "Pinto Beans"), ("ing_chickpeas", "Chickpeas"),
                    ("ing_herring_oil", "Herring Oil"), ("ing_green_lentils", "Green Lentils"),
                    ("ing_butternut_squash", "Whole Butternut Squash")
                ],
                flags: [],
                safetySummary: "Single named protein, no allergens on Luna's list.",
                processingSummary: "Whole ingredients throughout; no refined grain fraction."
            ),
            scan(
                barcode: "00723633612005",
                name: "L.I.T. Limited Ingredient Treats Potato & Duck Formula",
                brand: "Natural Balance",
                imageUrl: "https://i5.walmartimages.com/seo/Natural-Balance-Pet-Foods-L-I-T-Original-Biscuits-Dog-Treats-Duck-Potato-14-oz_6a990f0a-234e-45ad-abe6-5744dc70f25a_1.78cb7081438ce3ad6b8279f88046b8eb.jpeg",
                category: .treat,
                total: 71, safety: 80, suitability: 92, processing: 58,
                ingredientText: "Dried Potatoes, Duck, Potato Protein, Cane Molasses, Canola Oil, Natural Flavor, Natural Mixed Tocopherols, Natural Hickory Smoke Flavor, Citric Acid, Rosemary Extract",
                matched: [
                    ("ing_dried_potato", "Dried Potatoes"), ("ing_duck", "Duck"),
                    ("ing_potato_protein", "Potato Protein"), (nil, "Cane Molasses"),
                    ("ing_canola_oil", "Canola Oil"), ("ing_natural_flavor", "Natural Flavor"),
                    ("ing_mixed_tocopherols", "Natural Mixed Tocopherols"),
                    ("ing_smoke_flavor", "Natural Hickory Smoke Flavor"),
                    ("ing_citric_acid", "Citric Acid"), ("ing_rosemary_extract", "Rosemary Extract")
                ],
                flags: [
                    WarningFlag(
                        severity: .info,
                        title: "Added sugar",
                        explain: "Cane molasses is the fourth ingredient. In a treat given daily it adds sugar the dog has no need for.",
                        ingredientId: nil,
                        source: nil,
                        type: .general
                    )
                ],
                safetySummary: "Short ingredient list, nothing on Luna's avoid list.",
                processingSummary: "A dried, formed biscuit rather than a whole food."
            ),
            scan(
                barcode: "00840243136810",
                name: "Blue Buffalo Stix Natural Bacon Dog Treats, 6-oz bag",
                brand: "Blue Buffalo",
                imageUrl: "https://image.chewy.com/ca/is/image/catalog/1000021822_MAIN._AC_SX275_V1692680047_.jpg",
                category: .treat,
                total: 58, safety: 72, suitability: 90, processing: 44,
                ingredientText: "Lamb, Potatoes, Vegetable Glycerin, Pea Protein, Cane Sugar, Gelatin, Flaxseed, Chickpeas, preserved with Lactic Acid, Salt, Natural Smoke Flavor",
                matched: [
                    ("ing_lamb", "Lamb"), ("ing_potatoes", "Potatoes"),
                    ("ing_vegetable_glycerin", "Vegetable Glycerin"), ("ing_pea_protein", "Pea Protein"),
                    (nil, "Cane Sugar"), ("ing_gelatin", "Gelatin"), ("ing_flaxseed", "Flaxseed"),
                    ("ing_chickpeas", "Chickpeas"), ("ing_lactic_acid", "Lactic Acid"),
                    ("ing_salt", "Salt"), ("ing_smoke_flavor", "Natural Smoke Flavor")
                ],
                flags: [
                    WarningFlag(
                        severity: .warn,
                        title: "Added sugar",
                        explain: "Cane sugar is the fifth ingredient, ahead of the flaxseed and the chickpeas.",
                        ingredientId: nil,
                        source: nil,
                        type: .safety
                    ),
                    WarningFlag(
                        severity: .info,
                        title: "Humectant base",
                        explain: "Vegetable glycerin keeps a soft treat chewy on the shelf. It is safe, but it is third on the list — ahead of most of the food.",
                        ingredientId: "ing_vegetable_glycerin",
                        source: nil,
                        type: .general
                    )
                ],
                safetySummary: "Named meat first, but sugar sits high on the list.",
                processingSummary: "A soft, formed treat held together by glycerin and gelatin."
            ),
            scan(
                barcode: "00022808750086",
                name: "Merrick Natural Cut Beef Chew Treats Medium - 4 Count",
                brand: "Merrick",
                imageUrl: "https://i5.walmartimages.com/seo/Merrick-Dog-Natural-Cut-Beef-Medium-Chew-4-Count_eafaa8fd-a5e0-45a6-bbd5-60e0b1292fb2.a634cee090d7c6be8dcdb8fdbd45c842.jpeg",
                category: .treat,
                total: 46, safety: 62, suitability: 88, processing: 30,
                ingredientText: "Rice, Vegetable Glycerin, Beef, Brewers Dried Yeast, Potatoes, Citric Acid, Dried Cultured Whey, Beef Fat, Sugar, Salt, Natural Flavors, Malted Barley, Mixed Tocopherols for freshness",
                matched: [
                    ("ing_white_rice", "Rice"), ("ing_vegetable_glycerin", "Vegetable Glycerin"),
                    ("ing_beef", "Beef"), ("ing_dried_brewers_yeast", "Brewers Dried Yeast"),
                    ("ing_potatoes", "Potatoes"), ("ing_citric_acid", "Citric Acid"),
                    ("ing_dried_whey", "Dried Cultured Whey"), ("ing_beef_fat", "Beef Fat"),
                    (nil, "Sugar"), ("ing_salt", "Salt"), ("ing_natural_flavor", "Natural Flavors"),
                    ("ing_barley", "Malted Barley"), ("ing_mixed_tocopherols", "Mixed Tocopherols")
                ],
                flags: [
                    WarningFlag(
                        severity: .warn,
                        title: "Meat is third",
                        explain: "A beef chew whose first two ingredients are rice and glycerin. The beef is behind both.",
                        ingredientId: "ing_beef",
                        source: nil,
                        type: .safety
                    ),
                    WarningFlag(
                        severity: .warn,
                        title: "Added sugar",
                        explain: "Sugar is listed outright, on a chew meant to be given whole.",
                        ingredientId: nil,
                        source: nil,
                        type: .safety
                    )
                ],
                safetySummary: "Safe ingredients, but the beef is not doing most of the work.",
                processingSummary: "A formed, extruded chew built on refined starch."
            ),
            scan(
                barcode: "00093766747012",
                name: "Solid Gold Beef Jerky Formula Dog Treats, 10 Oz",
                brand: "Solid Gold",
                imageUrl: "https://i5.walmartimages.com/seo/Solid-Gold-Beef-Jerky-Formula-Dog-Treats-10-Oz_a1a12ea6-95af-432d-b64e-19280a11f7c0_1.6a500119f1d48fe1cf18b59ab3264e33.jpeg",
                category: .treat,
                total: 34, safety: 45, suitability: 86, processing: 28,
                ingredientText: "Beef, Brown Rice, Oats, Beef Meal, Tapioca Starch, Beef Liver, Brown Sugar, Glycerine, Cane Molasses, Salt, Garlic Powder, Natural Smoke Flavor, Phosphoric Acid (A Preservative), Potassium Sorbate (A Preservative)",
                matched: [
                    ("ing_beef", "Beef"), ("ing_brown_rice", "Brown Rice"), ("ing_oats", "Oats"),
                    ("ing_beef_meal", "Beef Meal"), ("ing_tapioca_starch", "Tapioca Starch"),
                    ("ing_beef_liver", "Beef Liver"), (nil, "Brown Sugar"), ("ing_glycerin", "Glycerine"),
                    (nil, "Cane Molasses"), ("ing_salt", "Salt"), ("ing_garlic", "Garlic Powder"),
                    ("ing_smoke_flavor", "Natural Smoke Flavor"),
                    ("ing_phosphoric_acid", "Phosphoric Acid"), ("ing_potassium_sorbate", "Potassium Sorbate")
                ],
                flags: [
                    WarningFlag(
                        severity: .high,
                        title: "Garlic",
                        explain: "Garlic is toxic to dogs in quantity — it damages red blood cells. A little in a treat is not a poisoning, but it does not belong in something fed daily.",
                        ingredientId: "ing_garlic",
                        source: "ASPCA Animal Poison Control",
                        type: .safety
                    ),
                    WarningFlag(
                        severity: .warn,
                        title: "Three added sugars",
                        explain: "Brown sugar, glycerine and cane molasses all appear in the top nine ingredients.",
                        ingredientId: nil,
                        source: nil,
                        type: .safety
                    )
                ],
                safetySummary: "Garlic plus three added sugars in a treat meant for daily use.",
                processingSummary: "Rendered meal, refined starch and humectants."
            )
        ]
    }

    /// Compact builder for the catalog-depth rows above. The three hero scans are
    /// written out longhand instead, because each of them is read close-up in a
    /// screenshot and every factor in them is on camera.
    private static func scan(
        barcode: String,
        name: String,
        brand: String,
        imageUrl: String,
        category: Category,
        total: Double,
        safety: Double,
        suitability: Double,
        processing: Double,
        ingredientText: String,
        matched: [(String?, String)],
        flags: [WarningFlag],
        safetySummary: String,
        processingSummary: String
    ) -> Scan {
        let matchedIngredients = matched.enumerated().map { index, entry in
            MatchedIngredient(ingredientId: entry.0, labelName: entry.1, rank: index + 1)
        }
        let unmatched = matched.filter { $0.0 == nil }.map { $0.1 }

        let breakdown = ScoreBreakdown(
            total: total,
            safety: safety,
            suitability: suitability,
            processing: processing,
            flags: flags,
            unmatched: unmatched,
            matchedCount: matched.count - unmatched.count,
            totalCount: matched.count,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(factors: [], summary: safetySummary),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Luna."
            ),
            processingExplanation: ScoreExplanation(factors: [], summary: processingSummary)
        )

        return Scan(
            barcode: barcode,
            productName: name,
            brand: brand,
            imageUrl: imageUrl,
            category: category,
            targetSpecies: .dog,
            rawIngredientText: ingredientText,
            matchedIngredients: matchedIngredients,
            scoreBreakdown: breakdown
        )
    }
}
