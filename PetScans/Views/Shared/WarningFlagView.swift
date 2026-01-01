import SwiftUI

struct WarningFlagView: View {
    let flag: WarningFlag

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: flag.severity.icon)
                .foregroundColor(flag.severity.color)
                .font(TypographyTokens.heading3)

            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack {
                    Text(flag.title)
                        .heading3()

                    Spacer()

                    Text(flag.severity.displayName)
                        .badgeStyle(color: flag.severity.color)
                }

                Text(flag.explain)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)

                if let source = flag.source {
                    Text("Source: \(source)")
                        .font(.caption2)
                        .foregroundColor(ColorTokens.textTertiary)
                }
            }
        }
        .cardStyle(
            backgroundColor: flag.severity.color.opacity(0.1),
            cornerRadius: SpacingTokens.radiusMedium
        )
    }
}

#Preview {
    VStack(spacing: SpacingTokens.xs) {
        WarningFlagView(flag: WarningFlag(
            severity: .critical,
            title: "Toxic ingredient",
            explain: "Xylitol is extremely dangerous for dogs and can cause liver failure.",
            ingredientId: "ing_xylitol",
            source: "ASPCA Animal Poison Control"
        ))

        WarningFlagView(flag: WarningFlag(
            severity: .high,
            title: "Possible allergen",
            explain: "Chicken may conflict with your pet's allergen profile.",
            ingredientId: "ing_chicken",
            source: nil
        ))

        WarningFlagView(flag: WarningFlag(
            severity: .warn,
            title: "Use with caution",
            explain: "Garlic in large quantities may be harmful.",
            ingredientId: "ing_garlic",
            source: "Merck Veterinary Manual"
        ))

        WarningFlagView(flag: WarningFlag(
            severity: .info,
            title: "Note",
            explain: "This ingredient is generally safe but monitor for reactions.",
            ingredientId: nil,
            source: nil
        ))
    }
    .padding()
}
