import SwiftUI

/// Expandable banner showing allergen warnings prominently at the top of results
struct AllergenAlertBanner: View {
    /// Nil on a saved scan, which does not persist which pet it was run for. The
    /// headline drops the name rather than the warning.
    let petName: String?
    let allergenFlags: [WarningFlag]
    let allergenNames: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header - always visible
            Button {
                withSnappyAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: SpacingTokens.iconMedium))
                        .foregroundColor(ColorTokens.severityHigh)

                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text(headline)
                            .heading2()
                            .foregroundColor(ColorTokens.textPrimary)

                        Text(allergenNames.joined(separator: ", "))
                            .bodySmall()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ColorTokens.textSecondary)
                        .font(.caption)
                }
                .padding(SpacingTokens.sm)
            }
            .buttonStyle(.plain)

            // Expanded detail cards
            if isExpanded {
                VStack(spacing: SpacingTokens.xs) {
                    ForEach(allergenFlags) { flag in
                        WarningFlagView(flag: flag)
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.sm)
            }
        }
        .background(ColorTokens.severityHigh.opacity(0.12))
        .cornerRadius(SpacingTokens.radiusMedium)
    }

    private var headline: String {
        guard let petName else { return "Contains Ingredients To Avoid" }
        return "Contains Ingredients \(petName) Should Avoid"
    }
}

#Preview {
    VStack(spacing: SpacingTokens.lg) {
        AllergenAlertBanner(
            petName: "Max",
            allergenFlags: [
                WarningFlag(
                    severity: .high,
                    title: "Flagged ingredient",
                    explain: "Chicken is on Max's list of ingredients to avoid.",
                    ingredientId: "ing_chicken",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .high,
                    title: "Flagged ingredient",
                    explain: "Beef is on Max's list of ingredients to avoid.",
                    ingredientId: "ing_beef",
                    source: nil,
                    type: .allergen
                )
            ],
            allergenNames: ["Chicken", "Beef"]
        )
    }
    .padding()
}
