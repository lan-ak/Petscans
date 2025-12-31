import Foundation

struct Ingredient: Codable, Identifiable {
    let id: String
    let commonName: String
    let scientificName: String?
    let species: [Species]
    let categories: [Category]
    let origin: String
    let riskLevel: String
    let allergenOrSensitizationRisk: String?
    let typicalFunction: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case commonName
        case scientificName
        case species
        case categories
        case origin
        case riskLevel
        case allergenOrSensitizationRisk
        case typicalFunction
        case notes
    }
}
