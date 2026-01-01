import SwiftUI
import SwiftData

struct AddPetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var species: Species = .dog

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Pet Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Enter your pet's name")
                }

                Section {
                    Picker("Species", selection: $species) {
                        ForEach(Species.allCases) { s in
                            Label(s.displayName, systemImage: s.icon)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Species")
                }
            }
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func addPet() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let pet = Pet(name: trimmedName, species: species)
        modelContext.insert(pet)
        try? modelContext.save()
        dismiss()
    }
}
