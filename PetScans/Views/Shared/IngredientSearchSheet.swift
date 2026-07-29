import SwiftUI

/// Shared ingredient search sheet used by onboarding and AddPetSheet
struct IngredientSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAllergens: Set<String>

    /// When presented directly (from a pet's "Add Ingredient"), show the common
    /// quick-pick chips at the top so the fast path survives collapsing the old
    /// two-sheet flow. When reached via `AllergenSelectionView` (add-pet form),
    /// that view already shows the chips, so this stays off to avoid duplicates.
    var showCommonChips: Bool = false

    /// Drives which quick-pick chips appear when `showCommonChips` is on — the
    /// common allergens differ between dogs and cats (see `QuickPickAllergens`).
    var species: Species = .dog

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchTask: Task<Void, Never>?

    /// Read in `body`, so SwiftUI's observation tracking re-renders this sheet when the
    /// background decode publishes. Without that the list could open before the load
    /// finished and stay permanently empty.
    private let database = IngredientDatabase.shared

    private var allIngredients: [Ingredient] {
        database.sortedIngredients
    }

    private var filteredIngredients: [Ingredient] {
        if debouncedSearchText.isEmpty {
            return allIngredients
        }
        return allIngredients.filter { ingredient in
            ingredient.commonName.localizedCaseInsensitiveContains(debouncedSearchText) ||
            (ingredient.scientificName?.localizedCaseInsensitiveContains(debouncedSearchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // A plain inline search field rather than `.searchable`: this sheet
                // is presented on top of AddAllergenSheet's NavigationStack while the
                // History tab already owns a `.searchable`, and inlining a second
                // search field into a nav bar that has one borrowed crashes UIKit
                // ("Attempted to inline a search text field that was already
                // borrowed"). A TextField avoids UISearchController entirely.
                searchBar
                    .padding(.horizontal, SpacingTokens.screenPadding)
                    .padding(.top, SpacingTokens.sm)
                    .padding(.bottom, SpacingTokens.xs)

                // Quick-pick chips for the most common allergens — the fast path
                // preserved from the old chips sheet. Hidden while searching so
                // the results list gets the room.
                if showCommonChips && searchText.isEmpty {
                    commonChipsSection
                }

                if !selectedAllergens.isEmpty {
                    selectedCountBadge
                }

                ingredientList

                actionBar
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Search Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        debouncedSearchText = newValue
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// Styled to match the app's standard input (see `PetFormView.baseNameField`):
    /// surfacePrimary fill, medium radius, a `border` stroke so it reads as a
    /// tap target against the tinted background instead of washing into it.
    private var searchBar: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorTokens.textSecondary)

            TextField("Search \(allIngredients.count) ingredients", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.surfacePrimary)
        .cornerRadius(SpacingTokens.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    private var commonChipsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Common")
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: SpacingTokens.xxs) {
                ForEach(QuickPickAllergens.list(for: species), id: \.id) { allergen in
                    let isSelected = selectedAllergens.contains(allergen.id)
                    Button {
                        if isSelected {
                            selectedAllergens.remove(allergen.id)
                        } else {
                            selectedAllergens.insert(allergen.id)
                        }
                    } label: {
                        Text(allergen.name)
                            .lineLimit(1)
                            .chipStyle(isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpacingTokens.screenPadding)
        .padding(.bottom, SpacingTokens.xs)
    }

    private var selectedCountBadge: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(ColorTokens.brandPrimary)

            Text("\(selectedAllergens.count) ingredient\(selectedAllergens.count == 1 ? "" : "s") selected")
                .labelMedium()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(ColorTokens.brandPrimary.opacity(0.1))
        .cornerRadius(SpacingTokens.radiusCircular)
        .padding(.horizontal)
        .padding(.bottom, SpacingTokens.xxs)
    }

    @ViewBuilder
    private var ingredientList: some View {
        if database.isLoaded {
            List {
                ForEach(filteredIngredients) { ingredient in
                    IngredientRowView(
                        ingredient: ingredient,
                        isSelected: selectedAllergens.contains(ingredient.commonName.lowercased()),
                        onToggle: { toggleSelection(ingredient) }
                    )
                }
            }
            .listStyle(.plain)
        } else {
            // Only reachable in the first moments after launch, while the bundled
            // JSON is still decoding. A spinner beats an empty list, which reads as
            // "we have no ingredients".
            ProgressView()
                .tint(ColorTokens.brandPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var actionBar: some View {
        VStack(spacing: SpacingTokens.xs) {
            Divider()

            Button(selectedAllergens.isEmpty ? "Done" : "Done (\(selectedAllergens.count) selected)") {
                dismiss()
            }
            .primaryButtonStyle()
            .padding(.horizontal, SpacingTokens.screenPadding)
            .padding(.bottom, SpacingTokens.screenPadding)
        }
        .background(ColorTokens.surfacePrimary)
    }

    // MARK: - Actions

    private func toggleSelection(_ ingredient: Ingredient) {
        let allergenName = ingredient.commonName.lowercased()
        if selectedAllergens.contains(allergenName) {
            selectedAllergens.remove(allergenName)
        } else {
            selectedAllergens.insert(allergenName)
        }
    }
}

#Preview {
    IngredientSearchSheet(selectedAllergens: .constant([]))
}
