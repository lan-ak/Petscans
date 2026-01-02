import SwiftUI

struct OnboardingPetSetupPage: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedAllergens: Set<String>

    @State private var customAllergen: String = ""

    private let commonAllergens = [
        "Chicken", "Beef", "Dairy", "Wheat",
        "Corn", "Soy", "Egg", "Fish", "Lamb", "Pork"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                Text("Let's meet your pet")
                    .font(TypographyTokens.displayMedium)
                    .foregroundColor(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                VStack(spacing: SpacingTokens.lg) {
                    TextField("Pet Name", text: $petName)
                        .font(TypographyTokens.bodyLarge)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(ColorTokens.surfacePrimary)
                        .cornerRadius(SpacingTokens.radiusMedium)

                    Picker("Species", selection: $petSpecies) {
                        ForEach(Species.allCases) { species in
                            Label(species.displayName, systemImage: species.icon)
                                .tag(species)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                allergenSection

                Text("You can add more pets and allergens later in Settings")
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SpacingTokens.screenPadding)
        }
    }

    private var allergenSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Any known allergies? (optional)")
                .font(TypographyTokens.labelMedium)
                .foregroundColor(ColorTokens.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: SpacingTokens.xxs) {
                ForEach(commonAllergens, id: \.self) { allergen in
                    allergenButton(for: allergen)
                }
            }

            customAllergenInput

            if !customAllergensSelected.isEmpty {
                customAllergensChips
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
            TextField("Add custom...", text: $customAllergen)
                .font(TypographyTokens.body)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .background(ColorTokens.surfacePrimary)
                .cornerRadius(SpacingTokens.radiusSmall)

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
        let commonNormalized = Set(commonAllergens.map { $0.lowercased() })
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
}

#Preview {
    OnboardingPetSetupPage(
        petName: .constant(""),
        petSpecies: .constant(.dog),
        selectedAllergens: .constant([])
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
