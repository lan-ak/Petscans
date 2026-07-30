import SwiftUI
import SwiftData

/// Detail sheet showing full ingredient information
/// Especially important for displaying notes explaining caution/toxic ratings
struct IngredientDetailSheet: View {
    let ingredient: Ingredient
    let species: Species
    let pet: Pet?

    @State private var appearancesInHistory: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isInAvoidList: Bool

    /// Convenience initializer that defaults to dog if no species provided
    init(ingredient: Ingredient, species: Species = .dog, pet: Pet? = nil) {
        self.ingredient = ingredient
        self.species = species
        self.pet = pet

        // Check if ingredient is already in pet's avoid list
        let normalized = ingredient.commonName.lowercased()
        _isInAvoidList = State(initialValue: pet?.allergens.contains(normalized) ?? false)
    }

    /// The risk level for the current species
    private var currentRiskLevel: String {
        ingredient.riskLevel(for: species)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    headerSection

                    aboutSection

                    if RiskTier(currentRiskLevel) != .safe {
                        riskSection
                    }

                    if let symptoms = ingredient.toxicitySymptoms, !symptoms.isEmpty {
                        toxicitySymptomsSection(symptoms)
                    }

                    if let dose = ingredient.toxicDose(for: species) {
                        toxicDoseSection(dose)
                    }

                    // Only when there is no authored content. The About section is
                    // written *from* `notes`, so showing both repeats the same
                    // sentence twice in a row — visible on Sweet potato, where the
                    // About text and the Notes card said the same thing.
                    if !hasAuthoredContent, let notes = ingredient.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    rulesSection

                    detailsSection

                    historySection

                    if !ingredient.allSources.isEmpty {
                        sourcesSection
                    }

                    if let pet = pet {
                        avoidListSection(pet: pet)
                    }
                }
                .padding(SpacingTokens.screenPadding)
            }
            .background(ColorTokens.backgroundPrimary)
            .task { await countAppearancesInHistory() }
            .navigationTitle("Ingredient Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Text(ingredient.commonName)
                    .heading1()

                Spacer()

                riskBadge
            }

            if let scientificName = ingredient.scientificName, !scientificName.isEmpty {
                Text(scientificName)
                    .bodySmall()
                    .italic()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            if let function = ingredient.typicalFunction, !function.isEmpty {
                Text(function)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
    }

    /// Badge text and colour both come from `RiskTier`, the classification
    /// `ScoreCalculator` scores against.
    ///
    /// This used to run its own ladder that lumped "safe_in_moderation" in with
    /// "caution" — so 40 ingredients wore a warning badge while the score treated
    /// them as a 6-point deduction rather than 15. The badge was overstating the
    /// concern relative to the number beside it.
    private var riskBadge: some View {
        let tier = RiskTier(currentRiskLevel)
        return HStack(spacing: SpacingTokens.xxxs) {
            Image(systemName: tier.icon)
            Text(tier.displayName)
        }
        .labelSmall()
        .foregroundColor(.white)
        .padding(.horizontal, SpacingTokens.xxs)
        .padding(.vertical, SpacingTokens.xxxs)
        .background(tier.color)
        .cornerRadius(SpacingTokens.radiusSmall)
    }

    // MARK: - About

    /// Plain-language explanation, always present.
    ///
    /// Prefers the authored entry from `ingredient-content.json`; falls back to
    /// `composedSummary()`, assembled from fields every record has. The point of the
    /// fallback is that no ingredient is ever a dead tap — before this, 69 of the
    /// most common ingredients in the catalog opened a sheet with nothing in it.
    ///
    /// Authored content is display-only and model-written; it deliberately carries
    /// no severity colouring, so it reads as description rather than as a verdict.
    /// Verdicts live in the risk section and in "What the research says".
    private var authoredContent: IngredientContent? {
        let entry = IngredientDatabase.shared.data.content[ingredient.id]
        return (entry?.isEmpty == false) ? entry : nil
    }

    private var hasAuthoredContent: Bool { authoredContent != nil }

    @ViewBuilder
    private var aboutSection: some View {
        if let authored = authoredContent {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(authored.whatItIs)
                    .bodyText()
                    .foregroundColor(ColorTokens.textPrimary)

                if !authored.whyItsHere.isEmpty {
                    Text(authored.whyItsHere)
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                if let watch = authored.whatToWatchFor, !watch.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text("What to watch for")
                            .heading3()
                            .foregroundColor(ColorTokens.textSecondary)
                        Text(watch)
                            .bodySmall()
                            .foregroundColor(ColorTokens.textPrimary)
                    }
                    .padding(.top, SpacingTokens.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
        } else if let composed = ingredient.composedSummary() {
            Text(composed)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
        }
    }

    // MARK: - Risk Section

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: riskIcon)
                    .foregroundColor(riskColor)
                Text("Safety Information")
                    .heading2()
            }

            Text(riskExplanation)
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)

            // Show if risk differs between species
            if ingredient.riskLevel.dog != ingredient.riskLevel.cat {
                speciesRiskComparisonView
            }
        }
        .cardStyle(backgroundColor: riskColor.opacity(0.1))
    }

    private var speciesRiskComparisonView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Species-specific risk:")
                .caption()
                .foregroundColor(ColorTokens.textTertiary)

            HStack(spacing: SpacingTokens.md) {
                speciesRiskBadge(species: .dog, riskLevel: ingredient.riskLevel.dog)
                speciesRiskBadge(species: .cat, riskLevel: ingredient.riskLevel.cat)
            }
        }
        .padding(.top, SpacingTokens.xxs)
    }

    private func speciesRiskBadge(species: Species, riskLevel: String) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Image(systemName: species.icon)
                .font(.system(size: 12))
            // The tier's own wording, not the raw database string: `.capitalized` printed
            // "Toxic" where every other badge says "Avoid", and would render the stored
            // `safe_in_moderation` family as "Safe_In_Moderation". The colour on the next
            // line already routes through `RiskTier`.
            Text(RiskTier(riskLevel).displayName)
                .caption()
        }
        .foregroundColor(riskColorFor(riskLevel))
    }

    private func riskColorFor(_ riskLevel: String) -> Color {
        RiskTier(riskLevel).color
    }

    private var riskIcon: String {
        RiskTier(currentRiskLevel).icon
    }

    private var riskColor: Color {
        riskColorFor(currentRiskLevel)
    }

    private var riskExplanation: String {
        let animal = species.displayName.lowercased() + "s"
        switch RiskTier(currentRiskLevel) {
        case .toxic:
            return "This ingredient is not recommended for \(animal). It may cause adverse health effects. Please review the information below for details."
        case .caution:
            return "This ingredient may not be suitable for all \(animal). Some animals may have sensitivities or there may be concerns with certain formulations. Check the notes below for specific information."
        case .moderation, .mostlySafe:
            return "This ingredient is generally fine for \(animal) in normal amounts. A few animals are sensitive to it — the notes below cover what to watch for."
        case .safe:
            return "This ingredient is generally considered safe for \(animal) when used appropriately."
        }
    }

    // MARK: - Toxicity Symptoms Section

    private func toxicitySymptomsSection(_ symptoms: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(ColorTokens.error)
                Text("Possible Symptoms")
                    .heading2()
            }

            FlowLayout(spacing: SpacingTokens.xxs) {
                ForEach(symptoms, id: \.self) { symptom in
                    Text(symptom)
                        .caption()
                        .foregroundColor(ColorTokens.error)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxxs)
                        .background(ColorTokens.error.opacity(0.1))
                        .cornerRadius(SpacingTokens.radiusSmall)
                }
            }
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
    }

    // MARK: - Toxic Dose Section

    private func toxicDoseSection(_ dose: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(ColorTokens.warning)
                Text("Toxic Dose")
                    .heading2()
            }

            Text(dose)
                .bodySmall()
                .foregroundColor(ColorTokens.textPrimary)
        }
        .cardStyle(backgroundColor: ColorTokens.warning.opacity(0.1))
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(ColorTokens.info)
                Text("Notes")
                    .heading2()
            }

            Text(notes)
                .bodySmall()
                .foregroundColor(ColorTokens.textPrimary)
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
    }

    // MARK: - Safety Rules

    /// The curated rules that apply to this ingredient, with the strength of the
    /// evidence behind each.
    ///
    /// `rules.json` carries an `evidence` field on all 47 rules and nothing
    /// displayed it. Saying "strong evidence" or "limited evidence" out loud is
    /// what separates a warning a reader can act on from one they have to take on
    /// faith — and admitting when a concern is debated builds more trust than a
    /// uniformly confident tone.
    @ViewBuilder
    private var rulesSection: some View {
        let rules = (IngredientDatabase.shared.rulesByIngredient[ingredient.id] ?? [])
            .filter { $0.appliesTo.species.contains(species) }
            .sorted { $0.severity.sortOrder < $1.severity.sortOrder }

        if !rules.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "checklist")
                        .foregroundColor(ColorTokens.textSecondary)
                    Text("What the research says")
                        .heading2()
                }

                ForEach(rules, id: \.id) { rule in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        HStack(spacing: SpacingTokens.xxs) {
                            Image(systemName: rule.severity.icon)
                                .foregroundColor(rule.severity.color)
                            Text(rule.severity.displayName)
                                .labelSmall()
                                .foregroundColor(rule.severity.color)

                            let evidence = evidenceLabel(rule.evidence)
                            if !evidence.isEmpty {
                                Text("· \(evidence)")
                                    .caption()
                                    .foregroundColor(ColorTokens.textTertiary)
                            }
                        }

                        Text(rule.explain)
                            .bodySmall()
                            .foregroundColor(ColorTokens.textPrimary)

                        if let source = rule.source {
                            Text(source)
                                .caption()
                                .foregroundColor(ColorTokens.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
        }
    }

    /// Turns the raw `evidence` value into something a reader can weigh.
    ///
    /// The shipped vocabulary is only "strong" (29 rules) and "medium" (18); the
    /// rest are here so a future value renders sensibly rather than as a bare word,
    /// and anything unrecognised falls through to the raw string instead of being
    /// dropped — silently hiding the strength of a safety claim is the one outcome
    /// worth avoiding.
    private func evidenceLabel(_ evidence: String) -> String {
        switch evidence.lowercased() {
        case "strong": return "Strong evidence"
        case "medium", "moderate": return "Moderate evidence"
        case "limited", "weak": return "Limited evidence"
        case "debated", "mixed": return "Debated"
        default: return evidence.isEmpty ? "" : evidence.capitalized
        }
    }

    // MARK: - History

    /// How often this ingredient shows up in the user's own scans.
    ///
    /// Connects an abstract ingredient to what they actually buy, which is more
    /// use to them than another adjective about the ingredient itself.
    @ViewBuilder
    private var historySection: some View {
        if let count = appearancesInHistory, count > 0 {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(ColorTokens.textSecondary)
                Text(count == 1
                     ? "Found in 1 of your saved scans"
                     : "Found in \(count) of your saved scans")
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Counts saved scans containing this ingredient.
    ///
    /// Runs off the main render pass and caps the fetch: `matchedIngredients`
    /// decodes JSON per scan, so this stays cheap at realistic history sizes and
    /// bounded at unrealistic ones.
    private func countAppearancesInHistory() async {
        guard appearancesInHistory == nil else { return }
        var descriptor = FetchDescriptor<Scan>(sortBy: [SortDescriptor(\.scannedAt, order: .reverse)])
        descriptor.fetchLimit = 500
        let scans = (try? modelContext.fetch(descriptor)) ?? []
        appearancesInHistory = scans.count { scan in
            scan.matchedIngredients.contains { $0.ingredientId == ingredient.id }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Details")
                .heading2()

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: SpacingTokens.sm) {
                detailItem(label: "Origin", value: ingredient.origin.capitalized)

                if let processingLevel = ingredient.processingLevel {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text("Processing")
                            .caption()
                            .foregroundColor(ColorTokens.textTertiary)
                        ProcessingBadgeView(level: processingLevel, size: .small)
                    }
                }

                if let allergenRisk = ingredient.allergenRisk(for: species) {
                    detailItem(label: "Allergen Risk", value: allergenRisk)
                }

                speciesItem
            }
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
    }

    private func detailItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(label)
                .caption()
                .foregroundColor(ColorTokens.textTertiary)
            Text(value)
                .bodySmall()
                .foregroundColor(ColorTokens.textPrimary)
        }
    }

    private var speciesItem: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text("Suitable For")
                .caption()
                .foregroundColor(ColorTokens.textTertiary)
            HStack(spacing: SpacingTokens.xs) {
                ForEach(ingredient.species) { species in
                    HStack(spacing: SpacingTokens.xxxs) {
                        Image(systemName: species.icon)
                            .font(.system(size: 12))
                        Text(species.displayName)
                            .bodySmall()
                    }
                    .foregroundColor(ColorTokens.textPrimary)
                }
            }
        }
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text("Sources")
                .caption()
                .foregroundColor(ColorTokens.textTertiary)

            ForEach(ingredient.allSources, id: \.self) { source in
                Text("• \(source)")
                    .caption()
                    .foregroundColor(ColorTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Avoid List Section

    private func avoidListSection(pet: Pet) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            if isInAvoidList {
                Button {
                    removeFromAvoidList(pet: pet)
                } label: {
                    Label("Remove from \(pet.name)'s Avoid List", systemImage: "minus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.error)
            } else {
                Button {
                    addToAvoidList(pet: pet)
                } label: {
                    Label("Add to \(pet.name)'s Avoid List", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.brandPrimary)
            }
        }
        .padding(.top, SpacingTokens.sm)
    }

    private func addToAvoidList(pet: Pet) {
        let normalized = ingredient.commonName.lowercased()
        guard !pet.allergens.contains(normalized) else { return }

        var allergens = pet.allergens
        allergens.append(normalized)
        allergens.sort()
        pet.allergens = allergens
        try? modelContext.save()
        isInAvoidList = true
    }

    private func removeFromAvoidList(pet: Pet) {
        let normalized = ingredient.commonName.lowercased()
        var allergens = pet.allergens
        allergens.removeAll { $0 == normalized }
        pet.allergens = allergens
        try? modelContext.save()
        isInAvoidList = false
    }
}

// MARK: - Flow Layout for Symptom Chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview("Safe Ingredient") {
    IngredientDetailSheet(
        ingredient: Ingredient(
            id: "ing_chicken",
            commonName: "Chicken",
            scientificName: "Gallus gallus domesticus",
            species: [.dog, .cat],
            categories: [.food],
            origin: "natural",
            riskLevel: "safe",
            allergenOrSensitizationRisk: "Medium",
            typicalFunction: "Primary protein source",
            notes: "High-quality protein source commonly used in pet food. Fresh chicken provides essential amino acids.",
            processingLevel: .unprocessed,
            processingLevelNotes: "Fresh whole meat",
            source: "AAFCO 2024, Section 9.2"
        ),
        species: .dog
    )
}

#Preview("Caution Ingredient") {
    IngredientDetailSheet(
        ingredient: Ingredient(
            id: "ing_carrageenan",
            commonName: "Carrageenan",
            scientificName: nil,
            species: [.dog, .cat],
            categories: [.food],
            origin: "natural",
            riskLevel: "caution",
            allergenOrSensitizationRisk: nil,
            typicalFunction: "Thickener, stabilizer",
            notes: "Some studies suggest potential for GI inflammation in sensitive animals. Degraded carrageenan (poligeenan) is a known carcinogen, though food-grade carrageenan is different. Controversial additive.",
            processingLevel: .ultraProcessed,
            processingLevelNotes: "Extracted and refined from seaweed",
            source: "AAFCO 2024, Section 9.18"
        ),
        species: .dog
    )
}

#Preview("Toxic with Symptoms") {
    IngredientDetailSheet(
        ingredient: Ingredient(
            id: "ing_grapes",
            commonName: "Grapes",
            scientificName: "Vitis vinifera",
            species: [.dog, .cat],
            categories: [.food],
            origin: "natural",
            riskLevel: RiskLevel(dog: "toxic", cat: "caution"),
            typicalFunction: "Fruit",
            notes: "Tartaric acid content causes kidney injury in dogs. Only one cat case reported.",
            processingLevel: .unprocessed,
            toxicitySymptoms: ["vomiting", "diarrhea", "lethargy", "kidney failure", "decreased urination"],
            toxicDose: ["dog": "One grape per 4.5 kg body weight may cause kidney injury", "cat": "Unknown - limited data"],
            sources: ["AAFCO 2024", "ASPCA Poison Control", "Merck Veterinary Manual"]
        ),
        species: .dog
    )
}

#Preview("Species-Specific Risk") {
    IngredientDetailSheet(
        ingredient: Ingredient(
            id: "ing_propylene_glycol",
            commonName: "Propylene Glycol",
            scientificName: nil,
            species: [.dog],
            categories: [.food],
            origin: "synthetic",
            riskLevel: RiskLevel(dog: "safe", cat: "toxic"),
            typicalFunction: "Humectant, preservative",
            notes: "FDA has banned propylene glycol in cat food due to causing Heinz body anemia in cats. Safe for dogs at appropriate levels.",
            processingLevel: .ultraProcessed,
            processingLevelNotes: "Synthetic chemical compound",
            toxicitySymptoms: ["Heinz body anemia", "weakness", "lethargy"],
            toxicDose: ["cat": "Any amount may cause hemolytic anemia in cats"],
            sources: ["AAFCO 2024, Section 9.17", "FDA"]
        ),
        species: .cat
    )
}
