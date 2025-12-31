import SwiftUI

struct SpeciesCategoryPicker: View {
    let productName: String?
    let brand: String?
    @Binding var species: Species
    @Binding var category: Category
    let onAnalyze: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Product info header
            VStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ColorTokens.success)

                if let name = productName {
                    Text(name)
                        .displaySmall()
                        .multilineTextAlignment(.center)
                }

                if let brand = brand {
                    Text(brand)
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(.top)

            Divider()

            // Species picker
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("This product is for:")
                    .heading2()

                Picker("Species", selection: $species) {
                    ForEach(Species.allCases) { s in
                        Label(s.displayName, systemImage: s.icon)
                            .tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // Category picker
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Product type:")
                    .heading2()

                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { c in
                        Label(c.displayName, systemImage: c.icon)
                            .tag(c)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: SpacingTokens.xs) {
                Button {
                    onAnalyze()
                } label: {
                    Text("Analyze Product")
                }
                .primaryButtonStyle()

                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(ColorTokens.textSecondary)
            }
            .padding()
        }
    }
}

#Preview {
    SpeciesCategoryPicker(
        productName: "Premium Dog Food",
        brand: "Acme Pet Foods",
        species: .constant(.dog),
        category: .constant(.food),
        onAnalyze: {},
        onCancel: {}
    )
}
