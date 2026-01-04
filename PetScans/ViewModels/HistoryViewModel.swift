import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel for the history view, managing filtering and CRUD operations
@MainActor
final class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedSpecies: Species?
    @Published var selectedCategory: Category?
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    @Published var showDeleteError: Bool = false
    @Published var deleteErrorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce search text by 300ms to avoid filtering on every keystroke
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.debouncedSearchText = value
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    /// Filter scans based on current filter state
    func filteredScans(from scans: [Scan]) -> [Scan] {
        scans.filter { scan in
            // Species filter
            if let species = selectedSpecies, scan.targetSpecies != species.rawValue {
                return false
            }

            // Category filter
            if let category = selectedCategory, scan.category != category.rawValue {
                return false
            }

            // Search filter (uses debounced value)
            if !debouncedSearchText.isEmpty {
                let searchLower = debouncedSearchText.lowercased()
                let nameMatch = scan.productName?.lowercased().contains(searchLower) ?? false
                let brandMatch = scan.brand?.lowercased().contains(searchLower) ?? false
                if !nameMatch && !brandMatch {
                    return false
                }
            }

            return true
        }
    }

    var hasActiveFilters: Bool {
        selectedSpecies != nil || selectedCategory != nil
    }

    // MARK: - Actions

    func clearFilters() {
        selectedSpecies = nil
        selectedCategory = nil
    }

    func delete(_ scan: Scan, using modelContext: ModelContext) {
        modelContext.delete(scan)
        do {
            try modelContext.save()
        } catch {
            deleteErrorMessage = "Failed to delete scan: \(error.localizedDescription)"
            showDeleteError = true
        }
    }

    func toggleFavorite(_ scan: Scan, using modelContext: ModelContext) {
        scan.isFavorite.toggle()
        scan.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            // Revert on failure
            scan.isFavorite.toggle()
            deleteErrorMessage = "Failed to update favorite: \(error.localizedDescription)"
            showDeleteError = true
        }
    }

    /// Generate share text for a scan
    func generateShareText(for scan: Scan) -> String {
        return scan.scoreBreakdown.generateShareText(
            productName: scan.productName,
            brand: scan.brand,
            species: scan.speciesEnum,
            category: scan.categoryEnum
        )
    }
}
