import SwiftUI
import SwiftData

struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScannerViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .scanning:
                    scanningView

                case .loading:
                    loadingView

                case .error:
                    errorView

                case .productNotFound:
                    productNotFoundView

                case .ocrCapture:
                    ocrCaptureView

                case .ocrProcessing:
                    ocrProcessingView

                case .selectOptions:
                    SpeciesCategoryPicker(
                        productName: $viewModel.productName,
                        brand: viewModel.brand,
                        isUnknownProduct: viewModel.scoreSource != .databaseVerified,
                        selectedPet: $viewModel.selectedPet,
                        species: $viewModel.selectedSpecies,
                        category: $viewModel.selectedCategory,
                        onAnalyze: {
                            viewModel.performAnalysis()
                        },
                        onCancel: viewModel.reset
                    )

                case .manualEntry:
                    IngredientSelectionView(
                        onSubmit: { selectedIngredients in
                            let ingredientsText = selectedIngredients.map { $0.commonName }.joined(separator: ", ")
                            viewModel.handleManualEntry(name: nil, brandName: nil, ingredients: ingredientsText)
                        },
                        onCancel: viewModel.reset
                    )

                case .results:
                    if let breakdown = viewModel.scoreBreakdown {
                        ResultsView(
                            productName: viewModel.productName,
                            brand: viewModel.brand,
                            imageUrl: viewModel.imageUrl,
                            species: viewModel.selectedPet?.speciesEnum ?? viewModel.selectedSpecies,
                            category: viewModel.selectedCategory,
                            scoreBreakdown: breakdown,
                            matchedIngredients: viewModel.matchedIngredients,
                            shareText: viewModel.generateShareText(),
                            onSave: {
                                viewModel.saveToHistory(using: modelContext)
                            },
                            onScanAnother: viewModel.reset
                        )
                    }
                }
            }
            .navigationTitle("Scan Product")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews

    private var scanningView: some View {
        ZStack {
            if BarcodeScannerView.isSupported {
                BarcodeScannerView(
                    onScan: viewModel.handleBarcodeScan,
                    onError: { error in
                        viewModel.currentError = .networkError(underlying: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error]))
                        viewModel.step = .error
                    }
                )
                .ignoresSafeArea()

                // Scanning reticle overlay
                ScanningReticleView()

                // Overlay with manual entry button
                VStack {
                    Spacer()

                    Button {
                        viewModel.goToManualEntry()
                    } label: {
                        Label("Enter Manually", systemImage: "keyboard")
                            .labelLarge()
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(SpacingTokens.radiusMedium)
                    }
                    .padding(.bottom, SpacingTokens.xxl)
                }
            } else {
                ScannerUnavailableView {
                    viewModel.goToManualEntry()
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Looking up product...")
                .heading2()
                .foregroundColor(ColorTokens.textSecondary)

            if let code = viewModel.barcode {
                Text("Barcode: \(code)")
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Button("Cancel") {
                viewModel.reset()
            }
            .padding(.top, SpacingTokens.md)
            .foregroundColor(ColorTokens.textSecondary)
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.currentError {
            NetworkErrorView(
                title: error.errorDescription ?? "Error",
                message: error.recoverySuggestion ?? "An error occurred.",
                canRetry: error.canRetry,
                onRetry: { viewModel.retryLastScan() },
                onAlternative: viewModel.goToManualEntry,
                alternativeLabel: "Enter Manually"
            )
        } else {
            NetworkErrorView(
                title: "Unknown Error",
                message: "Something went wrong. Please try again.",
                canRetry: true,
                onRetry: { viewModel.retryLastScan() },
                onAlternative: viewModel.goToManualEntry,
                alternativeLabel: "Enter Manually"
            )
        }
    }

    private var productNotFoundView: some View {
        ProductNotFoundView(
            barcode: viewModel.barcode,
            isManualSearch: viewModel.isManualSearch,
            onTakePhoto: {
                viewModel.step = .ocrCapture
            },
            onManualEntry: {
                viewModel.goToIngredientSelection()
            },
            onRetry: {
                viewModel.retryLastScan()
            }
        )
    }

    private var ocrCaptureView: some View {
        IngredientCameraView(
            onImageSelected: { image in
                viewModel.handleOCRCapture(image)
            },
            onCancel: {
                viewModel.step = .productNotFound
            }
        )
    }

    private var ocrProcessingView: some View {
        OCRProcessingView()
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: Scan.self, inMemory: true)
}
