import SwiftUI

/// View for searching product after identification from photo
/// Similar to AdvancedSearchView but uses product identification instead of barcode
struct ProductSearchView: View {
    /// The product identification from vision API
    let identification: ProductIdentification?

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

                // Progress indicator (skip barcode step visually since we start from image)
                ProductSearchProgressView(
                    currentStep: viewModel.currentStep,
                    completedSteps: viewModel.completedSteps
                )

                // Product info from identification
                if let name = viewModel.productName ?? identification?.productName {
                    productInfoSection(name: name, brand: viewModel.brand ?? identification?.brand)
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
            guard let identification = identification else {
                onCancel()
                return
            }
            await viewModel.startSearchFromImage(identification: identification)
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

            // Primary action: Take photo of ingredients
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

// MARK: - Product Search Progress View

/// Progress view that shows search steps (skipping barcode lookup)
private struct ProductSearchProgressView: View {
    let currentStep: AdvancedSearchViewModel.SearchStep
    let completedSteps: Set<AdvancedSearchViewModel.SearchStep>

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Current step indicator
            ZStack {
                Circle()
                    .fill(stepBackgroundColor)
                    .frame(width: SpacingTokens.iconXXLarge, height: SpacingTokens.iconXXLarge)

                if currentStep == .complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                } else if currentStep == .failed {
                    Image(systemName: "xmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }

            // Status text
            VStack(spacing: SpacingTokens.xxs) {
                Text(statusTitle)
                    .heading2()
                    .multilineTextAlignment(.center)

                Text(statusSubtitle)
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var stepBackgroundColor: Color {
        switch currentStep {
        case .complete:
            return ColorTokens.success
        case .failed:
            return ColorTokens.error
        default:
            return ColorTokens.brandPrimary
        }
    }

    private var statusTitle: String {
        switch currentStep {
        case .lookingUpBarcode:
            return "Identified!"
        case .searchingIngredients:
            return "Getting ingredients..."
        case .analyzingIngredients:
            return "Almost there!"
        case .complete:
            return "All done!"
        case .failed:
            return "Couldn't find ingredients"
        }
    }

    private var statusSubtitle: String {
        switch currentStep {
        case .lookingUpBarcode:
            return "Product recognized from photo"
        case .searchingIngredients:
            return "Searching for the freshest data"
        case .analyzingIngredients:
            return "Getting the most up-to-date info"
        case .complete:
            return "Ready for you to review"
        case .failed:
            return "Let's try another way"
        }
    }
}

// MARK: - Preview

#Preview("Searching") {
    ProductSearchView(
        identification: ProductIdentification(
            brand: "Blue Buffalo",
            productName: "Wilderness Chicken Recipe",
            species: "dog",
            confidence: 0.85,
            primaryProtein: "Chicken",
            primaryCarb: "Rice"
        ),
        onComplete: { _, _, _, _, _ in },
        onFallbackToPhoto: {},
        onCancel: {}
    )
}
