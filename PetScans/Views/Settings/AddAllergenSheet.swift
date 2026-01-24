import SwiftUI
import SwiftData

struct AddAllergenSheet: View {
    @Bindable var pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAllergens: Set<String>

    init(pet: Pet) {
        self.pet = pet
        // Initialize with current allergens
        _selectedAllergens = State(initialValue: Set(pet.allergens))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AllergenSelectionView(selectedAllergens: $selectedAllergens, showHeader: false)
                    .padding(.horizontal, SpacingTokens.screenPadding)
                    .padding(.top, SpacingTokens.md)
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAllergens()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveAllergens() {
        pet.allergens = Array(selectedAllergens).sorted()
        try? modelContext.save()
        dismiss()
    }
}
