import SwiftUI

struct ScanRowView: View {
    let scan: Scan

    private var scoreColor: Color {
        ColorTokens.colorForScore(scan.totalScore)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: scan.scannedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            // Score circle
            ZStack {
                Circle()
                    .fill(ColorTokens.backgroundForScore(scan.totalScore))
                    .frame(width: 50, height: 50)

                Text("\(Int(scan.totalScore))")
                    .heading2()
                    .foregroundColor(scoreColor)
            }

            // Product info
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack {
                    Text(scan.productName ?? "Unknown Product")
                        .heading2()
                        .lineLimit(1)

                    if scan.isFavorite {
                        Image(systemName: "star.fill")
                            .caption()
                            .foregroundColor(.yellow)
                    }

                    if scan.hasCriticalFlags {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .caption()
                            .foregroundColor(ColorTokens.error)
                    }
                }

                if let brand = scan.brand {
                    Text(brand)
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: SpacingTokens.xxs) {
                    Label(scan.speciesEnum.displayName, systemImage: scan.speciesEnum.icon)
                    Text("•")
                    Label(scan.categoryEnum.displayName, systemImage: scan.categoryEnum.icon)
                    Spacer()
                    Text(formattedDate)
                }
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
            }
        }
        .padding(.vertical, SpacingTokens.xxxs)
    }
}

#Preview {
    List {
        ScanRowView(scan: {
            let scan = Scan(
                barcode: "1234567890",
                productName: "Premium Dog Food",
                brand: "Acme Pet Foods",
                category: .food,
                targetSpecies: .dog,
                rawIngredientText: "Chicken, rice, vegetables",
                matchedIngredients: [],
                scoreBreakdown: ScoreBreakdown(
                    total: 85,
                    safety: 90,
                    nutrition: 80,
                    suitability: 85,
                    flags: [],
                    unmatched: [],
                    matchedCount: 10,
                    totalCount: 10
                ),
                isFavorite: true
            )
            return scan
        }())

        ScanRowView(scan: {
            let scan = Scan(
                productName: "Cat Treats",
                brand: nil,
                category: .treat,
                targetSpecies: .cat,
                rawIngredientText: "Fish, wheat",
                matchedIngredients: [],
                scoreBreakdown: ScoreBreakdown(
                    total: 45,
                    safety: 50,
                    nutrition: 40,
                    suitability: 45,
                    flags: [WarningFlag(severity: .critical, title: "Issue", explain: "Problem", ingredientId: nil)],
                    unmatched: [],
                    matchedCount: 5,
                    totalCount: 8
                )
            )
            return scan
        }())
    }
}
