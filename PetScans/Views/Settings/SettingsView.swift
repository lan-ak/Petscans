import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var pets: [Pet]

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

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(ColorTokens.info)
                            .frame(width: 28)

                        Text("Version")

                        Spacer()

                        Text("1.0.0")
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("View the scientific sources used for ingredient safety data.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
