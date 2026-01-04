import SwiftUI
import SwiftData

struct AddPetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var species: Species = .dog
    @State private var selectedAllergens: Set<String> = []
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.lg) {
                    PetFormView(
                        petName: $name,
                        petSpecies: $species,
                        selectedAllergens: $selectedAllergens
                    )
                }
                .padding(.horizontal, SpacingTokens.screenPadding)
                .padding(.top, SpacingTokens.md)
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPet()
                    }
                    .disabled(!name.isNotBlank || isSubmitting)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func addPet() {
        guard name.isNotBlank, !isSubmitting else { return }
        isSubmitting = true

        let pet = Pet(name: name.trimmed, species: species, allergens: Array(selectedAllergens))
        modelContext.insert(pet)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddPetSheet()
        .modelContainer(for: Pet.self, inMemory: true)
}
