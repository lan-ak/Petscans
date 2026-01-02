import SwiftUI
import SwiftData

struct PetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.name) private var pets: [Pet]
    @State private var showAddPet = false

    var body: some View {
        List {
            if !pets.isEmpty {
                Section {
                    ForEach(pets) { pet in
                        NavigationLink {
                            PetDetailView(pet: pet)
                        } label: {
                            PetRowView(pet: pet)
                        }
                    }
                    .onDelete(perform: deletePets)
                } header: {
                    Text("Your Pets")
                }
            }

            Section {
                Button {
                    showAddPet = true
                } label: {
                    Label("Add Pet", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("My Pets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddPet) {
            AddPetSheet()
        }
        .overlay {
            if pets.isEmpty {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "pawprint",
            title: "No Pets Yet",
            subtitle: "Add your pets to track their allergens",
            actionTitle: "Add Your First Pet",
            action: { showAddPet = true }
        )
    }

    private func deletePets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(pets[index])
        }
        try? modelContext.save()
    }
}
