import SwiftUI
import SwiftData

struct SpeciesCategoryPicker: View {
    @Binding var productName: String
    let brand: String?
    let isUnknownProduct: Bool

    @Query(sort: \Pet.name) private var pets: [Pet]

    @Binding var selectedPet: Pet?
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

                if isUnknownProduct {
                    TextField("Product name (optional)", text: $productName)
                        .font(TypographyTokens.heading2)
                        .multilineTextAlignment(.center)
                        .padding(SpacingTokens.sm)
                        .background(ColorTokens.surfaceSecondary)
                        .cornerRadius(SpacingTokens.radiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                } else if !productName.isEmpty {
                    Text(productName)
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

            if pets.isEmpty {
                // Fallback to species picker when no pets configured
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

                    Text("Add pets in Settings to track individual allergens")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .padding(.horizontal)
            } else {
                // Pet selection
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Scanning for:")
                        .heading2()

                    ForEach(pets) { pet in
                        PetSelectionRow(
                            pet: pet,
                            isSelected: selectedPet?.id == pet.id,
                            onSelect: { selectedPet = pet }
                        )
                    }
                }
                .padding(.horizontal)
            }

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
                .disabled(!pets.isEmpty && selectedPet == nil)

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
        productName: .constant("Premium Dog Food"),
        brand: "Acme Pet Foods",
        isUnknownProduct: false,
        selectedPet: .constant(nil),
        species: .constant(.dog),
        category: .constant(.food),
        onAnalyze: {},
        onCancel: {}
    )
}
