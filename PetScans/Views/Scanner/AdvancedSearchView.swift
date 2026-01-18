import SwiftUI

/// Main view for the Advanced Search feature
/// Orchestrates the multi-step barcode lookup and web scraping process
struct AdvancedSearchView: View {
    /// The barcode to search for
    let barcode: String

    /// Called when search completes successfully
    /// Parameters: ingredientsText, productName, brand, matchedIngredients, imageUrl
    let onComplete: (String, String?, String?, [MatchedIngredient], URL?) -> Void

    /// Called when user chooses to fall back to photo capture
    let onFallbackToPhoto: () -> Void

    /// Called when user cancels the search
    let onCancel: () -> Void

    // MARK: - State

    @StateObject private var viewModel = AdvancedSearchViewModel(
        firecrawlService: FirecrawlService(apiKey: APIKeys.firecrawl)
    )

    // MARK: - Body

    var body: some View {
        ZStack {
            // Floating paw prints background
            FloatingElementsView.paws(opacity: 0.45)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: SpacingTokens.lg) {
                Spacer()

                // Progress indicator
                AdvancedSearchProgressView(
                    currentStep: viewModel.currentStep,
                    completedSteps: viewModel.completedSteps
                )

                // Product info (appears when found)
                if let name = viewModel.productName {
                    productInfoSection(name: name, brand: viewModel.brand)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                // Action buttons based on state
                actionSection
            }
            .padding()
        }
        .animateEmphasized(value: viewModel.currentStep)
        .task {
            await viewModel.startSearch(barcode: barcode)
        }
    }

    // MARK: - Product Info Section

    private func productInfoSection(name: String, brand: String?) -> some View {
        VStack(spacing: SpacingTokens.xxs) {
            Text(name)
                .heading2()
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let brand = brand, !brand.isEmpty {
                Text(brand)
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
            }
        }
        .padding(.horizontal, SpacingTokens.lg)
    }

    // MARK: - Action Section

    @ViewBuilder
    private var actionSection: some View {
        if viewModel.currentStep == .failed {
            // Error state with recovery options
            errorSection
        } else if viewModel.currentStep == .complete {
            // Success state
            successSection
        } else {
            // In progress - show cancel button
            inProgressSection
        }
    }

    // MARK: - Error Section

    private var errorSection: some View {
        VStack(spacing: SpacingTokens.md) {
            if let error = viewModel.error {
                VStack(spacing: SpacingTokens.xs) {
                    Text(error.errorDescription ?? "Search failed")
                        .heading2()
                        .foregroundColor(ColorTokens.error)

                    Text(error.recoverySuggestion ?? "Please try another method.")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, SpacingTokens.sm)
            }

            // Primary action: Take photo
            Button {
                onFallbackToPhoto()
            } label: {
                Label("Take Photo of Ingredients", systemImage: "camera.fill")
            }
            .primaryButtonStyle()

            // Secondary action: Cancel
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.horizontal)
        .padding(.bottom, SpacingTokens.lg)
    }

    // MARK: - Success Section

    private var successSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Show match stats
            if !viewModel.matchedIngredients.isEmpty {
                let matchedCount = viewModel.matchedIngredients.filter { $0.isMatched }.count
                let totalCount = viewModel.matchedIngredients.count

                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorTokens.success)
                    Text("\(matchedCount) of \(totalCount) ingredients recognized")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }

            // Continue button
            Button {
                if let ingredients = viewModel.ingredientsText {
                    onComplete(ingredients, viewModel.productName, viewModel.brand, viewModel.matchedIngredients, viewModel.productImageURL)
                }
            } label: {
                Label("Continue to Analysis", systemImage: "arrow.right")
            }
            .primaryButtonStyle()

            // Option to retake/change
            Button("Take Photo Instead") {
                onFallbackToPhoto()
            }
            .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.horizontal)
        .padding(.bottom, SpacingTokens.lg)
    }

    // MARK: - In Progress Section

    private var inProgressSection: some View {
        Button("Cancel") {
            onCancel()
        }
        .foregroundColor(ColorTokens.textSecondary)
        .padding(.bottom, SpacingTokens.lg)
    }
}

// MARK: - Preview

#Preview("Searching") {
    AdvancedSearchView(
        barcode: "123456789012",
        onComplete: { _, _, _, _, _ in },
        onFallbackToPhoto: {},
        onCancel: {}
    )
}
