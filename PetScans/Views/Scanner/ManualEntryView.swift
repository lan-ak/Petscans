import SwiftUI

struct ManualEntryView: View {
    @State private var productName: String
    @State private var brand: String
    @State private var ingredientsText: String

    let onSubmit: (String?, String?, String) -> Void
    let onCancel: () -> Void

    init(
        initialProductName: String? = nil,
        initialBrand: String? = nil,
        onSubmit: @escaping (String?, String?, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _productName = State(initialValue: initialProductName ?? "")
        _brand = State(initialValue: initialBrand ?? "")
        _ingredientsText = State(initialValue: "")
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    private var canSubmit: Bool {
        !ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                Text("Enter Product Details")
                    .displaySmall()

                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Product Name")
                        .labelMedium()
                        .foregroundColor(ColorTokens.textSecondary)

                    TextField("e.g. Premium Dog Food", text: $productName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Brand")
                        .labelMedium()
                        .foregroundColor(ColorTokens.textSecondary)

                    TextField("e.g. Acme Pet Foods", text: $brand)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    HStack {
                        Text("Ingredients")
                            .labelMedium()
                            .foregroundColor(ColorTokens.textSecondary)

                        Text("(Required)")
                            .caption()
                            .foregroundColor(ColorTokens.error)
                    }

                    Text("Copy and paste the ingredients list from the product label")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)

                    TextEditor(text: $ingredientsText)
                        .frame(minHeight: 150)
                        .padding(SpacingTokens.xxs)
                        .background(ColorTokens.surfaceSecondary)
                        .cornerRadius(SpacingTokens.radiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.radiusSmall)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                }

                HStack(spacing: SpacingTokens.sm) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .secondaryButtonStyle()

                    Button("Analyze") {
                        onSubmit(
                            productName.isEmpty ? nil : productName,
                            brand.isEmpty ? nil : brand,
                            ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .primaryButtonStyle()
                    .disabled(!canSubmit)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

#Preview {
    ManualEntryView(
        initialProductName: "Test Product",
        onSubmit: { name, brand, ingredients in
            print("Submit: \(name ?? "nil"), \(brand ?? "nil"), \(ingredients)")
        },
        onCancel: {}
    )
}
