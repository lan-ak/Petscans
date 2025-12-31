import SwiftUI
import SwiftData

struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScannerViewModel()

    // Get allergens from UserDefaults
    @AppStorage("petAllergens") private var petAllergensData: Data = Data()

    private var petAllergens: [String] {
        (try? JSONDecoder().decode([String].self, from: petAllergensData)) ?? []
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

                case .selectOptions:
                    SpeciesCategoryPicker(
                        productName: viewModel.productName,
                        brand: viewModel.brand,
                        species: $viewModel.selectedSpecies,
                        category: $viewModel.selectedCategory,
                        onAnalyze: {
                            viewModel.performAnalysis(petAllergens: petAllergens)
                        },
                        onCancel: viewModel.reset
                    )

                case .manualEntry:
                    ManualEntryView(
                        initialProductName: viewModel.productName,
                        initialBrand: viewModel.brand,
                        onSubmit: viewModel.handleManualEntry,
                        onCancel: viewModel.reset
                    )

                case .results:
                    if let breakdown = viewModel.scoreBreakdown {
                        ResultsView(
                            productName: viewModel.productName,
                            brand: viewModel.brand,
                            imageUrl: viewModel.imageUrl,
                            species: viewModel.selectedSpecies,
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

                // Overlay with manual entry button
                VStack {
                    Spacer()

                    Button {
                        viewModel.goToManualEntry()
                    } label: {
                        Label("Enter Manually", systemImage: "keyboard")
                            .font(.headline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 40)
                }
            } else {
                ScannerUnavailableView {
                    viewModel.goToManualEntry()
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Looking up product...")
                .font(.headline)
                .foregroundColor(.secondary)

            if let code = viewModel.barcode {
                Text("Barcode: \(code)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Cancel") {
                viewModel.reset()
            }
            .padding(.top, 20)
            .foregroundColor(.secondary)
        }
    }

    private var errorView: some View {
        if let error = viewModel.currentError {
            NetworkErrorView(
                title: error.errorDescription ?? "Error",
                message: error.recoverySuggestion ?? "An error occurred.",
                canRetry: error.canRetry,
                onRetry: error.canRetry ? viewModel.retryLastScan : nil,
                onAlternative: viewModel.goToManualEntry,
                alternativeLabel: "Enter Manually"
            )
        } else {
            NetworkErrorView(
                title: "Unknown Error",
                message: "Something went wrong. Please try again.",
                canRetry: true,
                onRetry: viewModel.retryLastScan,
                onAlternative: viewModel.goToManualEntry,
                alternativeLabel: "Enter Manually"
            )
        }
    }
}

#Preview {
    ScannerView()
        .modelContainer(for: Scan.self, inMemory: true)
}
