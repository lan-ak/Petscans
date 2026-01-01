import SwiftUI

struct CacheSettingsView: View {
    @StateObject private var cacheManager = ProductCacheManager.shared

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Products Cached")
                    Spacer()
                    Text("\(cacheManager.productCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Database Size")
                    Spacer()
                    Text(String(format: "%.1f MB", cacheManager.databaseSizeMB))
                        .foregroundColor(.secondary)
                }

                if let lastSync = cacheManager.lastSyncDate {
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Database Statistics")
            }

            Section {
                switch cacheManager.syncState {
                case .idle:
                    Button(action: {
                        Task {
                            await cacheManager.fullSync()
                        }
                    }) {
                        Label("Download Product Database", systemImage: "arrow.down.circle")
                    }

                case let .syncing(page, totalPages):
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ProgressView(value: cacheManager.progress) {
                                Text("Downloading...")
                            }
                            .progressViewStyle(.linear)
                        }

                        Text("Page \(page) of \(totalPages)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("This may take 1-2 minutes. Please keep the app open.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                case .completed:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Download Complete!")
                    }

                case .failed(let error):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Download Failed")
                        }

                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Try Again") {
                            Task {
                                await cacheManager.fullSync()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Download all available pet food products for offline access. Requires WiFi connection.")
            }

            Section {
                Button(role: .destructive, action: {
                    Task {
                        await cacheManager.clearCache()
                    }
                }) {
                    Label("Clear Cache", systemImage: "trash")
                }
            } header: {
                Text("Management")
            }
        }
        .navigationTitle("Product Database")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cacheManager.refreshStats()
        }
    }
}

#Preview {
    NavigationStack {
        CacheSettingsView()
    }
}
