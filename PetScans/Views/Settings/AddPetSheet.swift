import SwiftUI
import SwiftData

struct AddPetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var species: Species = .dog
    @State private var selectedAllergens: Set<String> = []
    @State private var customAllergen: String = ""

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

                Section {
                    allergenGrid
                    customAllergenInput

                    if !customAllergensSelected.isEmpty {
                        customAllergensChips
                    }
                } header: {
                    Text("Allergens (optional)")
                } footer: {
                    Text("Select any ingredients your pet is allergic to.")
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
                    .disabled(!name.isNotBlank)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var allergenGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: SpacingTokens.xxs) {
            ForEach(CommonAllergens.all, id: \.self) { allergen in
                allergenButton(for: allergen)
            }
        }
    }

    private func allergenButton(for allergen: String) -> some View {
        let normalized = allergen.lowercased()
        let isSelected = selectedAllergens.contains(normalized)

        return Button {
            toggleAllergen(normalized)
        } label: {
            Text(allergen)
                .labelSmall()
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxs)
                .background(
                    isSelected
                    ? ColorTokens.brandPrimary
                    : ColorTokens.brandPrimary.opacity(0.1)
                )
                .foregroundColor(
                    isSelected
                    ? .white
                    : ColorTokens.brandPrimary
                )
                .cornerRadius(SpacingTokens.radiusSmall)
        }
        .buttonStyle(.plain)
    }

    private var customAllergenInput: some View {
        HStack(spacing: SpacingTokens.xs) {
            TextField("Add custom allergen...", text: $customAllergen)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            Button {
                addCustomAllergen()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: SpacingTokens.iconMedium))
                    .foregroundColor(customAllergen.isNotBlank ? ColorTokens.brandPrimary : ColorTokens.textTertiary)
            }
            .disabled(!customAllergen.isNotBlank)
        }
    }

    private var customAllergensSelected: [String] {
        let commonNormalized = Set(CommonAllergens.all.map { $0.lowercased() })
        return selectedAllergens.filter { !commonNormalized.contains($0) }.sorted()
    }

    private var customAllergensChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: SpacingTokens.xxs) {
            ForEach(customAllergensSelected, id: \.self) { allergen in
                HStack(spacing: SpacingTokens.xxs) {
                    Text(allergen.capitalized)
                        .labelSmall()

                    Button {
                        selectedAllergens.remove(allergen)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: SpacingTokens.iconSmall))
                    }
                }
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxs)
                .background(ColorTokens.brandPrimary)
                .foregroundColor(.white)
                .cornerRadius(SpacingTokens.radiusSmall)
            }
        }
    }

    private func toggleAllergen(_ allergen: String) {
        if selectedAllergens.contains(allergen) {
            selectedAllergens.remove(allergen)
        } else {
            selectedAllergens.insert(allergen)
        }
    }

    private func addCustomAllergen() {
        let normalized = customAllergen.trimmed.lowercased()
        guard !normalized.isEmpty, !selectedAllergens.contains(normalized) else {
            customAllergen = ""
            return
        }

        selectedAllergens.insert(normalized)
        customAllergen = ""
    }

    private func addPet() {
        guard name.isNotBlank else { return }

        let pet = Pet(name: name.trimmed, species: species, allergens: Array(selectedAllergens))
        modelContext.insert(pet)
        try? modelContext.save()
        dismiss()
    }
}
