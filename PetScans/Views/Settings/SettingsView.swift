import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var pets: [Pet]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PetListView()
                    } label: {
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .foregroundColor(ColorTokens.brandPrimary)
                                .frame(width: 28)

                            Text("My Pets")

                            Spacer()

                            if pets.count > 0 {
                                Text("\(pets.count)")
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Pet Profiles")
                } footer: {
                    Text("Manage your pets and their individual allergen profiles.")
                }

                Section {
                    NavigationLink {
                        CacheSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "internaldrive")
                                .foregroundColor(ColorTokens.brandPrimary)
                                .frame(width: 28)

                            Text("Product Database")
                        }
                    }
                } header: {
                    Text("Offline Access")
                } footer: {
                    Text("Download the complete pet food database for offline scanning and faster lookups.")
                }

                Section {
                    NavigationLink {
                        ReferencesView()
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(ColorTokens.brandPrimary)
                                .frame(width: 28)

                            Text("Scientific References")
                        }
                    }

                    Link(destination: URL(string: "https://petscans.app/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(ColorTokens.brandPrimary)
                                .frame(width: 28)

                            Text("Privacy Policy")

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .foregroundColor(ColorTokens.textPrimary)
                    }

                    Link(destination: URL(string: "https://petscans.app/support")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(ColorTokens.brandPrimary)
                                .frame(width: 28)

                            Text("Contact Support")

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .foregroundColor(ColorTokens.textPrimary)
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(ColorTokens.info)
                            .frame(width: 28)

                        Text("Version")

                        Spacer()

                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("View the scientific sources used for ingredient safety data.")
                }
            }
            .navigationTitle("Settings")
            .accessibilityIdentifier("settings-view")
        }
    }
}

#Preview {
    SettingsView()
}
