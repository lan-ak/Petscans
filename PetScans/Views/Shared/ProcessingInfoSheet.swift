import SwiftUI

/// Educational sheet explaining NOVA processing levels
struct ProcessingInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    // Introduction
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("What is Processing Level?")
                            .heading1()

                        Text("Processing level indicates how much an ingredient has been altered from its natural state. This classification is adapted from the NOVA food classification system for pet food ingredients.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Levels
                    ForEach(ProcessingLevel.allCases) { level in
                        levelCard(level)
                    }

                    // Disclaimer section
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        HStack(spacing: SpacingTokens.xxs) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(ColorTokens.info)
                            Text("Important Note")
                                .heading2()
                        }

                        Text("Processing level is for informational purposes only and does not indicate whether an ingredient is good or bad for your pet. Many processed ingredients (like vitamin supplements) are essential for complete nutrition.")
                            .bodySmall()
                            .foregroundColor(ColorTokens.textSecondary)

                        Text("Always consult with your veterinarian about the best diet for your pet's specific needs.")
                            .bodySmall()
                            .foregroundColor(ColorTokens.textSecondary)
                            .italic()
                    }
                    .cardStyle(backgroundColor: ColorTokens.info.opacity(0.1))
                }
                .padding(SpacingTokens.screenPadding)
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Processing Levels")
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

    private func levelCard(_ level: ProcessingLevel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                ProcessingBadgeView(level: level, size: .medium)
                Spacer()
                Text("Group \(level.rawValue)")
                    .caption()
                    .foregroundColor(ColorTokens.textTertiary)
            }

            Text(level.description)
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)

            // Examples
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text("Examples:")
                    .captionEmphasis()
                    .foregroundColor(ColorTokens.textTertiary)

                Text(level.examples.joined(separator: ", "))
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
        .cardStyle(backgroundColor: ColorTokens.surfacePrimary)
    }
}

#Preview {
    ProcessingInfoSheet()
}
