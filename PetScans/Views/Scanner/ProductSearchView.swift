import SwiftUI

/// View for searching a product's ingredients after it's been identified from a photo.
/// Drives the shared `SearchProgressView` off `AdvancedSearchViewModel`.
struct ProductSearchView: View {
    /// The product identification from vision API
    let identification: ProductIdentification?

    /// Called when search completes successfully
    /// Parameters: ingredientsText, productName, brand, matchedIngredients, imageUrl
    let onComplete: (String, String?, String?, [MatchedIngredient], URL?) -> Void

    /// Called when the user wants to retake the product photo (retry the search).
    let onRetakePhoto: () -> Void

    /// Called when the user backs out to the scanner.
    let onCancel: () -> Void

    // MARK: - State

    @StateObject private var viewModel = AdvancedSearchViewModel(
        firecrawlService: FirecrawlService()
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

                // Shared progress indicator (starts from the identified product,
                // so the barcode-lookup step is pre-completed).
                SearchProgressView(
                    currentStep: viewModel.currentStep,
                    completedSteps: viewModel.completedSteps,
                    isSoftFailure: viewModel.failureIsSoft
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
            errorSection
        } else if viewModel.currentStep == .complete {
            successSection
        } else {
            inProgressSection
        }
    }

    // MARK: - Error Section

    private var errorSection: some View {
        // When a retake can't change the outcome (product found, but no ingredients
        // online), lead with "Back to Scanner" so the user isn't looped into the
        // same failing identify+scrape.
        let retakeWontHelp = viewModel.error?.retakeWontHelp ?? false
        let titleColor = viewModel.failureIsSoft ? ColorTokens.warning : ColorTokens.error

        return VStack(spacing: SpacingTokens.md) {
            if let error = viewModel.error {
                VStack(spacing: SpacingTokens.xs) {
                    Text(error.errorDescription ?? "Search failed")
                        .heading2()
                        .foregroundColor(titleColor)

                    Text(error.recoverySuggestion ?? "Let's try another photo.")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, SpacingTokens.sm)
            }

            if retakeWontHelp {
                // Product located but ingredients unavailable — scanning another
                // product is the action that can actually succeed.
                Button {
                    onCancel()
                } label: {
                    Label("Scan Another", systemImage: "barcode.viewfinder")
                }
                .primaryButtonStyle()

                Button("Try Another Photo") {
                    onRetakePhoto()
                }
                .foregroundColor(ColorTokens.textSecondary)
            } else {
                // Couldn't read/identify the photo — a better one may help.
                Button {
                    onRetakePhoto()
                } label: {
                    Label("Try Another Photo", systemImage: "camera.fill")
                }
                .primaryButtonStyle()

                Button("Back to Scanner") {
                    onCancel()
                }
                .foregroundColor(ColorTokens.textSecondary)
            }
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
            Button("Retake Photo") {
                onRetakePhoto()
            }
            .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.horizontal)
        .padding(.bottom, SpacingTokens.lg)
    }

    // MARK: - In Progress Section

    private var inProgressSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            // Set expectations: the vision + retailer scrape can be slow, so tell
            // the user up front rather than leaving a silent spinner.
            Text("This can take up to a minute — we're reading the label and checking retailers.")
                .caption()
                .foregroundColor(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.lg)

            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(ColorTokens.textSecondary)
        }
        .padding(.bottom, SpacingTokens.lg)
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
        onRetakePhoto: {},
        onCancel: {}
    )
}
