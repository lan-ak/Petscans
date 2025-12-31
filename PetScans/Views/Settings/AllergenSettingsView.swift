import SwiftUI

struct AllergenSettingsView: View {
    @AppStorage("petAllergens") private var petAllergensData: Data = Data()
    @State private var allergens: [String] = []
    @State private var newAllergen: String = ""
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                ForEach(allergens.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(allergens[index].capitalized)
                        Spacer()
                        Button(action: {
                            deleteAllergen(at: IndexSet(integer: index))
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .imageScale(.medium)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete(perform: deleteAllergen)
            } header: {
                Text("Your Pet's Allergens")
            } footer: {
                Text("Products containing these ingredients will be flagged during analysis.")
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Allergen", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Allergens")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAllergens()
        }
        .sheet(isPresented: $showAddSheet) {
            addAllergenSheet
        }
    }

    private var addAllergenSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ingredient name", text: $newAllergen)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } header: {
                    Text("New Allergen")
                } footer: {
                    Text("Enter the name of an ingredient your pet is allergic to (e.g., \"chicken\", \"wheat\", \"corn\").")
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
                        newAllergen = ""
                        showAddSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAllergen()
                    }
                    .disabled(newAllergen.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var commonAllergensGrid: some View {
        let commonAllergens = ["Chicken", "Beef", "Dairy", "Wheat", "Corn", "Soy", "Egg", "Fish", "Lamb", "Pork"]

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(commonAllergens, id: \.self) { allergen in
                Button {
                    addCommonAllergen(allergen)
                } label: {
                    Text(allergen)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            allergens.contains(allergen.lowercased())
                            ? Color.gray.opacity(0.3)
                            : Color.blue.opacity(0.1)
                        )
                        .foregroundColor(
                            allergens.contains(allergen.lowercased())
                            ? .secondary
                            : .blue
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(allergens.contains(allergen.lowercased()))
            }
        }
    }

    private func loadAllergens() {
        if let decoded = try? JSONDecoder().decode([String].self, from: petAllergensData) {
            allergens = decoded
        }
    }

    private func saveAllergens() {
        if let encoded = try? JSONEncoder().encode(allergens) {
            petAllergensData = encoded
        }
    }

    private func addAllergen() {
        let trimmed = newAllergen.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !allergens.contains(trimmed) else {
            newAllergen = ""
            showAddSheet = false
            return
        }

        allergens.append(trimmed)
        allergens.sort()
        saveAllergens()
        newAllergen = ""
        showAddSheet = false
    }

    private func addCommonAllergen(_ allergen: String) {
        let lowercased = allergen.lowercased()
        guard !allergens.contains(lowercased) else { return }

        allergens.append(lowercased)
        allergens.sort()
        saveAllergens()
        showAddSheet = false
    }

    private func deleteAllergen(at offsets: IndexSet) {
        allergens.remove(atOffsets: offsets)
        saveAllergens()
    }
}

#Preview {
    NavigationStack {
        AllergenSettingsView()
    }
}
