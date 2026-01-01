import SwiftUI

struct SettingsView: View {
    @AppStorage("petAllergens") private var petAllergensData: Data = Data()

    private var allergenCount: Int {
        (try? JSONDecoder().decode([String].self, from: petAllergensData))?.count ?? 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AllergenSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ColorTokens.warning)
                                .frame(width: 28)

                            Text("Pet Allergens")

                            Spacer()

                            if allergenCount > 0 {
                                Text("\(allergenCount)")
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Pet Profile")
                } footer: {
                    Text("Configure ingredients your pet is allergic to. These will be flagged when scanning products.")
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
                    Link(destination: URL(string: "https://world.openpetfoodfacts.org")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(ColorTokens.brandPrimary)
                                .frame(width: 28)

                            Text("Open Pet Food Facts")

                            Spacer()

                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                } header: {
                    Text("Data Source")
                } footer: {
                    Text("Product data is provided by the Open Pet Food Facts community database.")
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
