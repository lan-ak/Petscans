import SwiftUI

struct IngredientSelectionView: View {
    @State private var searchText: String = ""
    @State private var selectedIngredientIds: Set<String> = []

    let onSubmit: ([Ingredient]) -> Void
    let onCancel: () -> Void

    private var allIngredients: [Ingredient] {
        Array(IngredientDatabase.shared.ingredients.values)
            .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
    }

    private var filteredIngredients: [Ingredient] {
        if searchText.isEmpty {
            return allIngredients
        }
        return allIngredients.filter { ingredient in
            ingredient.commonName.localizedCaseInsensitiveContains(searchText) ||
            (ingredient.scientificName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var selectedIngredients: [Ingredient] {
        allIngredients.filter { selectedIngredientIds.contains($0.id) }
    }

    private var canSubmit: Bool {
        !selectedIngredientIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Selected count indicator
                if !selectedIngredientIds.isEmpty {
                    selectedCountBadge
                }

                // Ingredient list
                ingredientList

                // Bottom action bar
                actionBar
            }
            .background(ColorTokens.backgroundPrimary)
            .navigationTitle("Select Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search ingredients")
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            Text("Select Ingredients")
                .displaySmall()

            Text("Choose from our database of \(allIngredients.count) ingredients")
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(SpacingTokens.screenPadding)
    }

    private var selectedCountBadge: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(ColorTokens.brandPrimary)

            Text("\(selectedIngredientIds.count) ingredient\(selectedIngredientIds.count == 1 ? "" : "s") selected")
                .labelMedium()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(ColorTokens.brandPrimary.opacity(0.1))
        .cornerRadius(SpacingTokens.radiusCircular)
        .padding(.horizontal)
        .padding(.bottom, SpacingTokens.xxs)
    }

    private var ingredientList: some View {
        List {
            ForEach(filteredIngredients) { ingredient in
                IngredientRowView(
                    ingredient: ingredient,
                    isSelected: selectedIngredientIds.contains(ingredient.id),
                    onToggle: { toggleSelection(ingredient) }
                )
            }
        }
        .listStyle(.plain)
    }

    private var actionBar: some View {
        VStack(spacing: SpacingTokens.xs) {
            Divider()

            HStack(spacing: SpacingTokens.sm) {
                Button("Cancel") {
                    onCancel()
                }
                .secondaryButtonStyle()

                Button(canSubmit ? "Analyze (\(selectedIngredientIds.count))" : "Analyze") {
                    onSubmit(selectedIngredients)
                }
                .primaryButtonStyle()
                .disabled(!canSubmit)
            }
            .padding(.horizontal, SpacingTokens.screenPadding)
            .padding(.bottom, SpacingTokens.screenPadding)
        }
        .background(ColorTokens.surfacePrimary)
    }

    // MARK: - Actions

    private func toggleSelection(_ ingredient: Ingredient) {
        if selectedIngredientIds.contains(ingredient.id) {
            selectedIngredientIds.remove(ingredient.id)
        } else {
            selectedIngredientIds.insert(ingredient.id)
        }
    }
}

#Preview {
    IngredientSelectionView(
        onSubmit: { ingredients in
            print("Selected: \(ingredients.map { $0.commonName })")
        },
        onCancel: {}
    )
}
