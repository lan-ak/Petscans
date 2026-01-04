import SwiftUI
import SwiftData

struct PetDetailView: View {
    @Bindable var pet: Pet
    @Environment(\.modelContext) private var modelContext
    @State private var showAddAllergen = false
    @State private var showEditName = false
    @State private var editedName: String = ""

    var body: some View {
        List {
            Section {
                HStack {
                    PetIconView(species: pet.speciesEnum, size: .large)

                    VStack(alignment: .leading) {
                        Text(pet.name)
                            .heading1()
                        Text(pet.speciesEnum.displayName)
                            .caption()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    Spacer()

                    Button {
                        editedName = pet.name
                        showEditName = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(ColorTokens.brandPrimary)
                    }
                }
            }

            Section {
                if pet.allergens.isEmpty {
                    Text("No ingredients to avoid")
                        .foregroundColor(ColorTokens.textSecondary)
                        .italic()
                } else {
                    ForEach(pet.allergens, id: \.self) { allergen in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ColorTokens.warning)
                            Text(allergen.capitalized)
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteAllergen)
                }
            } header: {
                Text("Ingredients to Avoid")
            } footer: {
                Text("Products containing these ingredients will be flagged when scanning for \(pet.name).")
            }

            Section {
                Button {
                    showAddAllergen = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAllergen) {
            AddAllergenSheet(pet: pet)
        }
        .alert("Edit Name", isPresented: $showEditName) {
            TextField("Name", text: $editedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if editedName.isNotBlank {
                    pet.name = editedName.trimmed
                    pet.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
    }

    private func deleteAllergen(at offsets: IndexSet) {
        var allergens = pet.allergens
        allergens.remove(atOffsets: offsets)
        pet.allergens = allergens
        try? modelContext.save()
    }
}
