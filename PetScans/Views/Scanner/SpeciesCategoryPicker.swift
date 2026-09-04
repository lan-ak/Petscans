import SwiftUI
import SwiftData

struct SpeciesCategoryPicker: View {
    @Binding var productName: String
    let brand: String?
    let isUnknownProduct: Bool

    @Query(sort: \Pet.name) private var pets: [Pet]

    @Binding var selectedPet: Pet?
    @Binding var species: Species
    @Binding var category: Category
    let onAnalyze: () -> Void
    let onCancel: () -> Void

    @State private var isGeneralScan: Bool = false

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Product info header
            VStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ColorTokens.success)

                if isUnknownProduct {
                    TextField("Product name (optional)", text: $productName)
                        .font(TypographyTokens.heading2)
                        .multilineTextAlignment(.center)
                        .padding(SpacingTokens.sm)
                        .insetSurface(fill: ColorTokens.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                } else if !productName.isEmpty {
                    Text(productName)
                        .displaySmall()
                        .multilineTextAlignment(.center)
                }

                if let brand = brand {
                    Text(brand)
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .padding(.top)

            Divider()

            if pets.isEmpty {
                // Fallback to species picker when no pets configured
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("This product is for:")
                        .heading2()

                    Picker("Species", selection: $species) {
                        ForEach(Species.allCases) { s in
                            Label(s.displayName, systemImage: s.icon)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Add pets in Settings to track individual allergens")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .padding(.horizontal)
            } else {
                // Pet selection with general scan option
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Scanning for:")
                        .heading2()

                    // General scan option
                    ScanTargetRow(
                        target: .general,
                        isSelected: isGeneralScan,
                        onSelect: {
                            withStandardAnimation {
                                isGeneralScan = true
                                selectedPet = nil
                            }
                        }
                    )

                    ForEach(pets) { pet in
                        ScanTargetRow(
                            target: .pet(pet),
                            isSelected: selectedPet?.id == pet.id,
                            onSelect: {
                                withStandardAnimation {
                                    selectedPet = pet
                                    isGeneralScan = false
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)

                // Show species picker when general scan is selected
                if isGeneralScan {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("This product is for:")
                            .heading2()

                        Picker("Species", selection: $species) {
                            ForEach(Species.allCases) { s in
                                Label(s.displayName, systemImage: s.icon)
                                    .tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Category picker
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Product type:")
                    .heading2()

                Picker("Category", selection: $category) {
                    ForEach(Category.allCases.filter { $0 != .cosmetic }) { c in
                        Label(c.displayName, systemImage: c.icon)
                            .tag(c)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: SpacingTokens.xs) {
                Button {
                    onAnalyze()
                } label: {
                    Text("Analyze Product")
                }
                .primaryButtonStyle()

                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(ColorTokens.textSecondary)
            }
            .padding()
        }
        .dismissKeyboardOnTap()
        .onAppear {
            // Paths that don't preselect a pet (OCR, manual, web) would otherwise land here
            // with nothing highlighted. Default to the first pet, matching the instant
            // catalog path in ScannerViewModel.apply(_:pets:).
            if selectedPet == nil, let first = pets.first {
                selectedPet = first
            }
        }
    }
}

#Preview {
    SpeciesCategoryPicker(
        productName: .constant("Premium Dog Food"),
        brand: "Acme Pet Foods",
        isUnknownProduct: false,
        selectedPet: .constant(nil),
        species: .constant(.dog),
        category: .constant(.food),
        onAnalyze: {},
        onCancel: {}
    )
}
