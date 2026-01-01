import SwiftUI
import SwiftData

struct ScanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var scan: Scan
    let shareText: String

    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Product image
                if let urlString = scan.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 150, maxHeight: 150)
                                .cornerRadius(SpacingTokens.radiusMedium)
                        case .failure:
                            productPlaceholder
                        @unknown default:
                            productPlaceholder
                        }
                    }
                }

                // Product header
                VStack(spacing: SpacingTokens.xxs) {
                    if let name = scan.productName {
                        Text(name)
                            .displaySmall()
                            .multilineTextAlignment(.center)
                    }

                    if let brand = scan.brand {
                        Text(brand)
                            .bodySmall()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    HStack(spacing: SpacingTokens.xxs) {
                        Label(scan.speciesEnum.displayName, systemImage: scan.speciesEnum.icon)
                        Text("•")
                        Label(scan.categoryEnum.displayName, systemImage: scan.categoryEnum.icon)
                    }
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)

                    Text(scan.scannedAt.formatted(date: .abbreviated, time: .shortened))
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                // Main score
                ScoreCircleView(score: scan.totalScore, size: 120)

                // Score breakdown
                VStack(spacing: SpacingTokens.xs) {
                    ScoreBarView(label: "Safety", score: scan.scoreBreakdown.safety)

                    if let nutrition = scan.scoreBreakdown.nutrition {
                        ScoreBarView(label: "Nutrition", score: nutrition)
                    }

                    ScoreBarView(label: "Suitability", score: scan.scoreBreakdown.suitability)
                }
                .cardStyle(backgroundColor: ColorTokens.surfaceSecondary)

                // Warning flags
                if !scan.scoreBreakdown.flags.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Warnings")
                            .heading2()

                        ForEach(scan.scoreBreakdown.flags) { flag in
                            WarningFlagView(flag: flag)
                        }
                    }
                }

                // Ingredients
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Ingredients")
                        .heading2()

                    let matched = scan.matchedIngredients
                    ForEach(matched) { ingredient in
                        HStack {
                            Text("\(ingredient.rank).")
                                .foregroundColor(ColorTokens.textSecondary)
                                .frame(width: 24, alignment: .trailing)

                            Text(ingredient.labelName)

                            Spacer()

                            if ingredient.isMatched {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ColorTokens.success)
                            } else {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(ColorTokens.warning)
                            }
                        }
                        .bodySmall()
                    }

                    if !scan.scoreBreakdown.unmatched.isEmpty {
                        Text("Unrecognized ingredients are marked with a question mark")
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
                .cardStyle(backgroundColor: ColorTokens.surfaceSecondary)

                // Notes
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Notes")
                        .heading2()

                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .padding(SpacingTokens.xxs)
                        .background(ColorTokens.surfaceSecondary)
                        .cornerRadius(SpacingTokens.radiusSmall)
                        .onChange(of: notes) { _, newValue in
                            scan.notes = newValue.isEmpty ? nil : newValue
                            scan.updatedAt = Date()
                        }
                }

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Scan", systemImage: "trash")
                }
                .primaryButtonStyle(isDestructive: true)
            }
            .padding()
        }
        .navigationTitle("Scan Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        scan.isFavorite.toggle()
                        scan.updatedAt = Date()
                    } label: {
                        Image(systemName: scan.isFavorite ? "star.fill" : "star")
                            .foregroundColor(scan.isFavorite ? .yellow : .gray)
                    }
                }
            }
        }
        .onAppear {
            notes = scan.notes ?? ""
        }
        .confirmationDialog("Delete this scan?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(scan)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var productPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 40))
            .foregroundColor(ColorTokens.textSecondary)
            .frame(width: 120, height: 120)
            .background(ColorTokens.surfacePrimary)
            .cornerRadius(SpacingTokens.radiusMedium)
    }
}

#Preview {
    NavigationStack {
        ScanDetailView(
            scan: {
                let scan = Scan(
                    barcode: "1234567890",
                    productName: "Premium Dog Food",
                    brand: "Acme Pet Foods",
                    category: .food,
                    targetSpecies: .dog,
                    rawIngredientText: "Chicken, brown rice, peas, carrots, fish oil",
                    matchedIngredients: [
                        MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1),
                        MatchedIngredient(ingredientId: "ing_brown_rice", labelName: "Brown Rice", rank: 2),
                        MatchedIngredient(ingredientId: "ing_peas", labelName: "Peas", rank: 3),
                        MatchedIngredient(ingredientId: nil, labelName: "Carrots", rank: 4),
                        MatchedIngredient(ingredientId: "ing_fish_oil", labelName: "Fish Oil", rank: 5)
                    ],
                    scoreBreakdown: ScoreBreakdown(
                        total: 78,
                        safety: 85,
                        nutrition: 72,
                        suitability: 80,
                        flags: [
                            WarningFlag(severity: .info, title: "Good protein source", explain: "Chicken is a quality protein source.", ingredientId: "ing_chicken", source: nil)
                        ],
                        unmatched: ["Carrots"],
                        matchedCount: 4,
                        totalCount: 5,
                        scoreSource: .databaseVerified,
                        ocrConfidence: nil
                    ),
                    notes: "Got this at the pet store",
                    isFavorite: true
                )
                return scan
            }(),
            shareText: "Test share text"
        )
    }
    .modelContainer(for: Scan.self, inMemory: true)
}
