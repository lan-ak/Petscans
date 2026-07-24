import SwiftUI

/// Shared ingredient search sheet used by onboarding and AddPetSheet
struct IngredientSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAllergens: Set<String>

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
                headerSection

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
            .searchable(text: $searchText, prompt: "Search ingredients")
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

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            Text("What ingredients are you avoiding?")
                .displaySmall()
                .multilineTextAlignment(.center)

            Text("Search from \(allIngredients.count) ingredients")
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(SpacingTokens.screenPadding)
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
