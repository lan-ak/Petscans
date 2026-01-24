import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Scan.scannedAt, order: .reverse) private var allScans: [Scan]
    @StateObject private var viewModel = HistoryViewModel()

    private var filteredScans: [Scan] {
        viewModel.filteredScans(from: allScans)
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredScans.isEmpty {
                    emptyStateView
                } else {
                    List {
                        Section {
                            ForEach(filteredScans) { scan in
                                NavigationLink(value: scan) {
                                    ScanRowView(scan: scan)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.delete(scan, using: modelContext)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        viewModel.toggleFavorite(scan, using: modelContext)
                                    } label: {
                                        Label(
                                            scan.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: scan.isFavorite ? "star.slash" : "star"
                                        )
                                    }
                                    .tint(.yellow)
                                }
                            }
                        } header: {
                            FilterChipsView(
                                selectedSpecies: $viewModel.selectedSpecies,
                                selectedCategory: $viewModel.selectedCategory,
                                showFavoritesOnly: $viewModel.showFavoritesOnly
                            )
                            .textCase(nil)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Scan.self) { scan in
                SavedScanDetailView(scan: scan, shareText: viewModel.generateShareText(for: scan)) {
                    viewModel.delete(scan, using: modelContext)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search products")
            .alert("Error", isPresented: $viewModel.showDeleteError) {
                Button("OK") {}
            } message: {
                Text(viewModel.deleteErrorMessage ?? "An error occurred")
            }
            .accessibilityIdentifier("history-view")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.sm) {
            EmptyStateView(
                icon: "clock",
                title: "No Scans Yet",
                subtitle: "Scan a product to see it here"
            )

            if viewModel.hasActiveFilters {
                Button("Clear Filters") {
                    viewModel.clearFilters()
                }
                .secondaryButtonStyle()
            }
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: Scan.self, inMemory: true)
}
