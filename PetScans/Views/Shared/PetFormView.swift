import SwiftUI

/// Shared pet form component used by onboarding and AddPetSheet
struct PetFormView: View {
    @Binding var petName: String
    @Binding var petSpecies: Species
    @Binding var selectedAllergens: Set<String>

    /// Onboarding asks about avoidance groups instead (see `AvoidanceGroup`),
    /// so it opts out. AddPetSheet keeps the ingredient-level picker: by the
    /// time someone adds a second pet in Settings they have seen ingredient
    /// lists and can answer it.
    var showAllergens: Bool = true

    /// Onboarding turns this off: with the avoidance groups below it, an 80pt
    /// icon pushed the last group off screen, and the title already labels the
    /// page. AddPetSheet keeps it — that sheet has room.
    var showHeaderIcon: Bool = true

    /// Shown under the name field once a submit has been attempted while blank.
    var nameError: String?

    /// Lets the owning screen drive focus — onboarding autofocuses the field so
    /// the keyboard is already up on arrival.
    var isNameFocused: FocusState<Bool>.Binding?

    /// Called when the keyboard's return key is pressed.
    var onSubmitName: () -> Void = {}

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            if showHeaderIcon {
                // Heart icon (generic for all pets)
                Image(systemName: "heart.fill")
                    .font(.system(size: SpacingTokens.iconXXLarge))
                    .foregroundColor(ColorTokens.brandPrimary)
            }

            // Title
            Text("Let's meet your pet")
                .font(TypographyTokens.displayMedium)
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            // Pet info section
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    nameField

                    if let nameError {
                        Text(nameError)
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.error)
                    }
                }

                Picker("Species", selection: $petSpecies) {
                    ForEach(Species.allCases) { species in
                        Label(species.displayName, systemImage: species.icon)
                            .tag(species)
                    }
                }
                .pickerStyle(.segmented)
            }

            if showAllergens {
                Divider()
                    .padding(.vertical, SpacingTokens.xxs)

                // Ingredients to avoid section
                AllergenSelectionView(selectedAllergens: $selectedAllergens, species: petSpecies, showHeader: true)
            }
        }
    }

    /// `focused(_:)` needs a concrete binding, so the focusable and plain
    /// variants are built separately rather than conditionally applying the
    /// modifier.
    @ViewBuilder
    private var nameField: some View {
        if let isNameFocused {
            baseNameField.focused(isNameFocused)
        } else {
            baseNameField
        }
    }

    private var baseNameField: some View {
        TextField("Pet Name", text: $petName)
            .font(TypographyTokens.bodyLarge)
            .textInputAutocapitalization(.words)
            // Pet names are not dictionary words — autocorrect turns "Nala"
            // into "Nada" and "Mochi" into "Mocha" as the user types.
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit(onSubmitName)
            .padding()
            .insetSurface()
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium)
                    .stroke(nameError == nil ? Color.clear : ColorTokens.error, lineWidth: 1)
            )
            .accessibilityIdentifier("pet-name-field")
    }
}

#Preview {
    ScrollView {
        PetFormView(
            petName: .constant(""),
            petSpecies: .constant(.dog),
            selectedAllergens: .constant([])
        )
        .padding()
    }
    .background(ColorTokens.backgroundPrimary)
}
