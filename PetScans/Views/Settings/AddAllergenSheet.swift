import SwiftUI
import SwiftData

struct AddAllergenSheet: View {
    @Bindable var pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newAllergen: String = ""

    private let commonAllergens = [
        "Chicken", "Beef", "Dairy", "Wheat",
        "Corn", "Soy", "Egg", "Fish", "Lamb", "Pork"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ingredient name", text: $newAllergen)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } header: {
                    Text("New Allergen")
                } footer: {
                    Text("Enter the name of an ingredient \(pet.name) is allergic to.")
                }

                Section {
                    commonAllergensGrid
                } header: {
                    Text("Common Allergens")
                }
            }
            .navigationTitle("Add Allergen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAllergen(newAllergen)
                    }
                    .disabled(!newAllergen.isNotBlank)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var commonAllergensGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: SpacingTokens.xxs) {
            ForEach(commonAllergens, id: \.self) { allergen in
                Button {
                    addAllergen(allergen)
                } label: {
                    Text(allergen)
                        .labelSmall()
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                        .background(
                            pet.allergens.contains(allergen.lowercased())
                            ? ColorTokens.surfaceSecondary
                            : ColorTokens.brandPrimary.opacity(0.1)
                        )
                        .foregroundColor(
                            pet.allergens.contains(allergen.lowercased())
                            ? ColorTokens.textSecondary
                            : ColorTokens.brandPrimary
                        )
                        .cornerRadius(SpacingTokens.radiusSmall)
                }
                .buttonStyle(.plain)
                .disabled(pet.allergens.contains(allergen.lowercased()))
            }
        }
    }

    private func addAllergen(_ allergen: String) {
        let normalized = allergen.trimmed.lowercased()
        guard !normalized.isEmpty, !pet.allergens.contains(normalized) else {
            dismiss()
            return
        }

        var allergens = pet.allergens
        allergens.append(normalized)
        allergens.sort()
        pet.allergens = allergens
        try? modelContext.save()
        dismiss()
    }
}
