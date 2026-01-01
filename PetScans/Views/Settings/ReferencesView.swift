import SwiftUI

struct ReferencesView: View {
    var body: some View {
        List {
            Section {
                Text("PetScans uses data from trusted veterinary and regulatory sources to provide accurate ingredient safety information.")
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Section {
                ReferenceRow(
                    name: "AAFCO",
                    description: "Association of American Feed Control Officials - defines pet food ingredient standards",
                    url: "https://www.aafco.org"
                )

                ReferenceRow(
                    name: "FDA Center for Veterinary Medicine",
                    description: "U.S. Food and Drug Administration - regulates pet food safety",
                    url: "https://www.fda.gov/animal-veterinary"
                )

                ReferenceRow(
                    name: "EFSA",
                    description: "European Food Safety Authority - EU regulatory standards for pet food additives",
                    url: "https://www.efsa.europa.eu"
                )
            } header: {
                Text("Regulatory Sources")
            } footer: {
                Text("Official regulatory bodies that set standards for pet food ingredients and safety.")
            }

            Section {
                ReferenceRow(
                    name: "ASPCA Animal Poison Control",
                    description: "24/7 poison control center with extensive database of toxic substances",
                    url: "https://www.aspca.org/pet-care/animal-poison-control"
                )

                ReferenceRow(
                    name: "Merck Veterinary Manual",
                    description: "Comprehensive veterinary reference for toxicology and nutrition",
                    url: "https://www.merckvetmanual.com"
                )

                ReferenceRow(
                    name: "Pet Poison Helpline",
                    description: "Animal poison control service and educational resource",
                    url: "https://www.petpoisonhelpline.com"
                )
            } header: {
                Text("Veterinary & Toxicology")
            } footer: {
                Text("Expert veterinary resources for ingredient safety and toxicity information.")
            }

            Section {
                ReferenceRow(
                    name: "Open Pet Food Facts",
                    description: "Community database of pet food products and ingredients",
                    url: "https://world.openpetfoodfacts.org"
                )

                ReferenceRow(
                    name: "EWG Skin Deep",
                    description: "Environmental Working Group database for cosmetic ingredient safety",
                    url: "https://www.ewg.org/skindeep"
                )
            } header: {
                Text("Research Databases")
            } footer: {
                Text("Open databases used to supplement our curated ingredient information.")
            }

            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("How Safety Scores Work")
                        .heading2()

                    Text("Safety scores are calculated based on:")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)

                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        BulletPoint(text: "Ingredient risk levels (safe, caution, toxic)")
                        BulletPoint(text: "Species-specific toxicity rules")
                        BulletPoint(text: "Allergen matching against your pet's profile")
                        BulletPoint(text: "Position in ingredient list (first ingredients matter most)")
                    }
                }
                .padding(.vertical, SpacingTokens.xs)

                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Evidence Quality")
                        .heading2()

                    Text("Each safety rule is rated by evidence strength:")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)

                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        EvidenceRow(level: "Strong", description: "Multiple peer-reviewed studies, regulatory consensus")
                        EvidenceRow(level: "Medium", description: "Limited studies with regulatory guidance")
                        EvidenceRow(level: "Weak", description: "Case reports or preliminary research")
                    }
                }
                .padding(.vertical, SpacingTokens.xs)
            } header: {
                Text("Methodology")
            } footer: {
                Text("Our scoring algorithm prioritizes ingredients at the top of the list and applies species-specific safety rules.")
            }

            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Important Disclaimer")
                        .heading2()
                        .foregroundColor(ColorTokens.warning)

                    Text("PetScans provides educational information only and is not a substitute for professional veterinary advice. Always consult your veterinarian before making dietary changes or if you suspect your pet has ingested something harmful.")
                        .bodySmall()
                        .foregroundColor(ColorTokens.textSecondary)

                    Text("In case of emergency, contact your veterinarian or the ASPCA Animal Poison Control Center at (888) 426-4435.")
                        .captionEmphasis()
                }
                .padding(.vertical, SpacingTokens.xs)
            } header: {
                Text("Disclaimer")
            }
        }
        .navigationTitle("Scientific References")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ReferenceRow: View {
    let name: String
    let description: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack {
                    Text(name)
                        .bodyText()
                        .foregroundColor(ColorTokens.brandPrimary)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .caption()
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Text(description)
                    .caption()
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.vertical, SpacingTokens.xs)
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Text("•")
                .foregroundColor(ColorTokens.brandPrimary)
            Text(text)
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
    }
}

struct EvidenceRow: View {
    let level: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            Text(level)
                .captionEmphasis()
                .foregroundColor(level == "Strong" ? ColorTokens.success : (level == "Medium" ? ColorTokens.warning : ColorTokens.textSecondary))
                .frame(width: 60, alignment: .leading)

            Text(description)
                .caption()
                .foregroundColor(ColorTokens.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        ReferencesView()
    }
}
