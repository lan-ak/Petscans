import SwiftUI
import SwiftData

/// Wrapper view for displaying a saved scan with navigation bar actions
struct SavedScanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var scan: Scan
    let shareText: String
    let onDelete: () -> Void

    var body: some View {
        ProductScoreView(scan: scan, shareText: shareText) {
            onDelete()
            dismiss()
        }
        .navigationTitle("Scan Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: SpacingTokens.sm) {
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
    }
}

#Preview {
    NavigationStack {
        SavedScanDetailView(
            scan: {
                let scan = Scan(
                    barcode: "1234567890",
                    productName: "Premium Dog Food",
                    brand: "Acme Pet Foods",
                    category: .food,
                    targetSpecies: .dog,
                    rawIngredientText: "Chicken, brown rice, peas",
                    matchedIngredients: [
                        MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1),
                        MatchedIngredient(ingredientId: "ing_brown_rice", labelName: "Brown Rice", rank: 2)
                    ],
                    scoreBreakdown: ScoreBreakdown(
                        total: 78,
                        safety: 85,
                        suitability: 80,
                        processing: 72,
                        flags: [],
                        unmatched: [],
                        matchedCount: 2,
                        totalCount: 2,
                        scoreSource: .databaseVerified,
                        ocrConfidence: nil,
                        safetyExplanation: nil,
                        suitabilityExplanation: nil,
                        processingExplanation: nil
                    ),
                    isFavorite: true
                )
                return scan
            }(),
            shareText: "Test share text",
            onDelete: {}
        )
    }
    .modelContainer(for: Scan.self, inMemory: true)
}
