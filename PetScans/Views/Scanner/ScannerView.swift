import SwiftUI
import SwiftData

struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScannerViewModel()

    private var useMockScanner: Bool {
        ProcessInfo.processInfo.arguments.contains("-MockScanner")
    }

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

                case .advancedSearch:
                    advancedSearchView

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
                        ProductScoreView(
                            productName: viewModel.productName,
                            brand: viewModel.brand,
                            imageUrl: viewModel.imageUrl,
                            species: viewModel.selectedPet?.speciesEnum ?? viewModel.selectedSpecies,
                            category: viewModel.selectedCategory,
                            scoreBreakdown: breakdown,
                            matchedIngredients: viewModel.matchedIngredients,
                            shareText: viewModel.generateShareText(),
                            petName: viewModel.selectedPet?.name,
                            mode: .scanResult(
                                onSave: { viewModel.saveToHistory(using: modelContext) },
                                onScanAnother: viewModel.reset
                            )
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
            if useMockScanner {
                // Mock scanner for App Store screenshots
                MockScannerPreviewView()
                    .ignoresSafeArea()

                ScanningReticleView()

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
            } else if BarcodeScannerView.isSupported {
                BarcodeScannerView(
                    onScan: viewModel.handleBarcodeScan,
                    onError: { error in
                        Task { @MainActor in
                            viewModel.currentError = .networkError(underlying: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error]))
                            viewModel.step = .error
                        }
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
        .accessibilityIdentifier("scanner-view")
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
            productName: viewModel.productName,
            brand: viewModel.brand,
            imageUrl: viewModel.imageUrl,
            isManualSearch: viewModel.isManualSearch,
            onAdvancedSearch: {
                viewModel.startAdvancedSearch()
            },
            onTakePhoto: {
                viewModel.step = .ocrCapture
            },
            onManualEntry: {
                viewModel.goToIngredientSelection()
            },
            onRetry: {
                viewModel.restartScanning()
            }
        )
    }

    private var advancedSearchView: some View {
        AdvancedSearchView(
            barcode: viewModel.barcode ?? "",
            onComplete: { ingredientsText, productName, brand, matched, imageUrl in
                viewModel.handleAdvancedSearchComplete(
                    ingredientsText: ingredientsText,
                    productName: productName,
                    brand: brand,
                    matched: matched,
                    imageUrl: imageUrl
                )
            },
            onFallbackToPhoto: {
                viewModel.step = .ocrCapture
            },
            onCancel: {
                viewModel.step = .productNotFound
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
