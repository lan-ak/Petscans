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
                    shareButton

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

    /// Same rendered-card share as the fresh-scan screen, so a scan shared from
    /// History looks identical to one shared right after scanning. Falls back to
    /// the plain text block if the render fails.
    @ViewBuilder
    private var shareButton: some View {
        let productName = scan.productName ?? "Scanned product"
        if let image = ShareCardRenderer.render(
            productName: productName,
            brand: scan.brand,
            breakdown: scan.scoreBreakdown,
            // Saved scans don't persist which pet they were run for — the same
            // reason ProductScoreView passes petName: nil here. Allergen titles
            // still carry the pet context inside the card's flag list.
            petName: nil
        ) {
            let card = ShareCard(image: image, text: shareText)
            ShareLink(
                item: card,
                preview: SharePreview(productName, image: Image(uiImage: image))
            ) {
                Image(systemName: "square.and.arrow.up")
            }
        } else {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
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
