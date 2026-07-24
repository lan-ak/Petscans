import SwiftUI

struct IngredientSelectionView: View {
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var selectedIngredientIds: Set<String> = []
    @State private var searchTask: Task<Void, Never>?

    let onSubmit: ([Ingredient]) -> Void
    let onCancel: () -> Void

    /// Read in `body`, so SwiftUI's observation tracking re-renders this view when the
    /// background decode publishes. Without that the list could open before the load
    /// finished and stay permanently empty.
    private let database = IngredientDatabase.shared

    /// Use pre-sorted list from database (sorted once on load, not every render)
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

    private var selectedIngredients: [Ingredient] {
        selectedIngredientIds.compactMap { id in
            database.ingredients[id]
        }
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
            .onChange(of: searchText) { _, newValue in
                // Cancel previous search task
                searchTask?.cancel()

                // Debounce: wait 250ms before filtering
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

    @ViewBuilder
    private var ingredientList: some View {
        if database.isLoaded {
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
