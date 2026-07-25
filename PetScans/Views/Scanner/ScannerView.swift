import SwiftUI
import SwiftData

struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Pet.name) private var pets: [Pet]
    @StateObject private var viewModel = ScannerViewModel()
    @StateObject private var cameraPermission = CameraPermission()

    private var useMockScanner: Bool {
        ProcessInfo.processInfo.arguments.contains("-MockScanner")
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .scanning:
                    scanningView

                case .error:
                    errorView

                case .productNotFound:
                    productNotFoundView

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
                            selectedPet: viewModel.selectedPet,
                            mode: .scanResult(
                                onSave: { viewModel.saveToHistory(using: modelContext) },
                                onScanAnother: viewModel.reset
                            )
                        )
                    }

                case .productPhotoCapture:
                    productPhotoCaptureView

                case .productIdentification:
                    productIdentificationView

                case .confirmProduct:
                    productConfirmView

                case .productSearching:
                    productSearchingView
                }
            }
            .transition(.opacity)
            .animateEmphasized(value: viewModel.step)
            .navigationTitle("Identify Product")
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
            } else if !BarcodeScannerView.isSupported {
                ScannerUnavailableView(
                    onSearchWithPhoto: viewModel.goToProductPhotoCapture
                )
            } else if cameraPermission.state == .notDetermined {
                CameraPrimingView(
                    onEnable: {
                        Task { await cameraPermission.request() }
                    }
                )
            } else if cameraPermission.state == .denied {
                CameraDeniedView(
                    onOpenSettings: cameraPermission.openSettings,
                    onSearchWithPhoto: viewModel.goToProductPhotoCapture
                )
            } else {
                BarcodeScannerView(
                    onScan: { code in
                        viewModel.handleBarcodeScan(code, pets: pets, modelContext: modelContext)
                    },
                    onError: { error in
                        Task { @MainActor in
                            viewModel.handleScannerError(error)
                        }
                    }
                )
                .ignoresSafeArea()

                // Scanning reticle overlay
                ScanningReticleView(instructionText: "Point at the barcode", instructionAtBottom: true)
            }
        }
        .accessibilityIdentifier("scanner-view")
        .onChange(of: scenePhase) { _, phase in
            // The user may have granted access in Settings and come back;
            // without this they would return to the same denied screen and read
            // it as the grant not having worked.
            if phase == .active {
                cameraPermission.refresh()
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.currentError {
            NetworkErrorView(
                title: error.errorDescription ?? "Error",
                message: error.recoverySuggestion ?? "An error occurred.",
                canRetry: error.canRetry,
                onRetry: { viewModel.retryLastScan() }
            )
        } else {
            NetworkErrorView(
                title: "Unknown Error",
                message: "Something went wrong. Please try again.",
                canRetry: true,
                onRetry: { viewModel.retryLastScan() }
            )
        }
    }

    private var productNotFoundView: some View {
        ProductNotFoundView(
            reason: viewModel.notFoundReason,
            barcode: viewModel.barcode,
            onSearchWithPhoto: {
                viewModel.goToProductPhotoCapture()
            },
            onScanAnother: {
                viewModel.restartScanning()
            }
        )
    }

    // MARK: - Product Photo Identification Views

    private var productPhotoCaptureView: some View {
        ProductPhotoCaptureView(
            onImageSelected: { image in
                viewModel.handleProductPhotoCapture(image)
            },
            onCancel: {
                viewModel.restartScanning()
            },
            // Reached from the camera-denied / unavailable screens too — prefer the
            // library picker there rather than a dead black preview.
            startInLibraryMode: cameraPermission.state == .denied || !BarcodeScannerView.isSupported
        )
    }

    private var productIdentificationView: some View {
        ProductIdentificationProgressView(
            image: viewModel.productImage,
            identification: viewModel.productIdentification,
            isProcessing: true,
            onCancel: {
                viewModel.restartScanning()
            }
        )
    }

    /// Low-confidence confirmation gate: show what the AI thinks the product is
    /// and let the user confirm or retake before we spend a scrape on it.
    private var productConfirmView: some View {
        ProductIdentificationConfirmView(
            image: viewModel.productImage,
            identification: viewModel.productIdentification,
            onConfirm: {
                viewModel.confirmIdentification()
            },
            onRetake: {
                viewModel.goToProductPhotoCapture()
            },
            onCancel: {
                viewModel.restartScanning()
            }
        )
    }

    private var productSearchingView: some View {
        ProductSearchView(
            identification: viewModel.productIdentification,
            onComplete: { ingredientsText, productName, brand, matched, imageUrl in
                viewModel.handleProductSearchComplete(
                    ingredientsText: ingredientsText,
                    productName: productName,
                    brand: brand,
                    matched: matched,
                    imageUrl: imageUrl
                )
            },
            onRetakePhoto: {
                // Search failed or user wants a do-over → retake the product photo.
                viewModel.goToProductPhotoCapture()
            },
            onCancel: {
                // Back out to the scanner.
                viewModel.restartScanning()
            }
        )
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: Scan.self, inMemory: true)
}
