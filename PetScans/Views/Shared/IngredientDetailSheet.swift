import SwiftUI

/// Detail sheet showing full ingredient information
/// Especially important for displaying notes explaining caution/toxic ratings
struct IngredientDetailSheet: View {
    let ingredient: Ingredient
    let species: Species
    @Environment(\.dismiss) private var dismiss

    /// Convenience initializer that defaults to dog if no species provided
    init(ingredient: Ingredient, species: Species = .dog) {
        self.ingredient = ingredient
        self.species = species
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

                    if currentRiskLevel != "safe" {
                        riskSection
                    }

                    if let symptoms = ingredient.toxicitySymptoms, !symptoms.isEmpty {
                        toxicitySymptomsSection(symptoms)
                    }

                    if let dose = ingredient.toxicDose(for: species) {
                        toxicDoseSection(dose)
                    }

                    if let notes = ingredient.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    detailsSection

                    if !ingredient.allSources.isEmpty {
                        sourcesSection
                    }
                }
                .padding(SpacingTokens.screenPadding)
            }
            .background(ColorTokens.backgroundPrimary)
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

    @ViewBuilder
    private var riskBadge: some View {
        let risk = currentRiskLevel.lowercased()
        if risk.contains("caution") || risk.contains("moderation") {
            HStack(spacing: SpacingTokens.xxxs) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Caution")
            }
            .labelSmall()
            .foregroundColor(.white)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.warning)
            .cornerRadius(SpacingTokens.radiusSmall)
        } else if risk.contains("toxic") || risk.contains("avoid") {
            HStack(spacing: SpacingTokens.xxxs) {
                Image(systemName: "xmark.circle.fill")
                Text("Avoid")
            }
            .labelSmall()
            .foregroundColor(.white)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.error)
            .cornerRadius(SpacingTokens.radiusSmall)
        } else {
            HStack(spacing: SpacingTokens.xxxs) {
                Image(systemName: "checkmark.circle.fill")
                Text("Safe")
            }
            .labelSmall()
            .foregroundColor(.white)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.success)
            .cornerRadius(SpacingTokens.radiusSmall)
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
            Image(species.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
            Text(riskLevel.capitalized)
                .caption()
        }
        .foregroundColor(riskColorFor(riskLevel))
    }

    private func riskColorFor(_ riskLevel: String) -> Color {
        let risk = riskLevel.lowercased()
        if risk.contains("toxic") || risk.contains("avoid") {
            return ColorTokens.error
        } else if risk.contains("caution") || risk.contains("moderation") {
            return ColorTokens.warning
        } else {
            return ColorTokens.success
        }
    }

    private var riskIcon: String {
        let risk = currentRiskLevel.lowercased()
        if risk.contains("caution") || risk.contains("moderation") {
            return "exclamationmark.triangle.fill"
        } else if risk.contains("toxic") || risk.contains("avoid") {
            return "xmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var riskColor: Color {
        riskColorFor(currentRiskLevel)
    }

    private var riskExplanation: String {
        let risk = currentRiskLevel.lowercased()
        if risk.contains("caution") || risk.contains("moderation") {
            return "This ingredient may not be suitable for all \(species.displayName.lowercased())s. Some animals may have sensitivities or there may be concerns with certain formulations. Check the notes below for specific information."
        } else if risk.contains("toxic") || risk.contains("avoid") {
            return "This ingredient is not recommended for \(species.displayName.lowercased())s. It may cause adverse health effects. Please review the information below for details."
        } else {
            return "This ingredient is generally considered safe for \(species.displayName.lowercased())s when used appropriately."
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

                if let allergenRisk = ingredient.allergenOrSensitizationRisk, !allergenRisk.isEmpty {
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
                        Image(species.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
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
