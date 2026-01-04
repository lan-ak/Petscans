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

    // NOVA-style processing classification (informational only, does not affect scores)
    let processingLevel: ProcessingLevel?
    let processingLevelNotes: String?

    // Source attribution for ingredient data
    let source: String?

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
        case processingLevel
        case processingLevelNotes
        case source
    }

    // Memberwise initializer for programmatic creation
    init(
        id: String,
        commonName: String,
        scientificName: String? = nil,
        species: [Species],
        categories: [Category],
        origin: String,
        riskLevel: String,
        allergenOrSensitizationRisk: String? = nil,
        typicalFunction: String? = nil,
        notes: String? = nil,
        processingLevel: ProcessingLevel? = nil,
        processingLevelNotes: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.commonName = commonName
        self.scientificName = scientificName
        self.species = species
        self.categories = categories
        self.origin = origin
        self.riskLevel = riskLevel
        self.allergenOrSensitizationRisk = allergenOrSensitizationRisk
        self.typicalFunction = typicalFunction
        self.notes = notes
        self.processingLevel = processingLevel
        self.processingLevelNotes = processingLevelNotes
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        commonName = try container.decode(String.self, forKey: .commonName)
        scientificName = try container.decodeIfPresent(String.self, forKey: .scientificName)
        species = try container.decode([Species].self, forKey: .species)
        categories = try container.decode([Category].self, forKey: .categories)
        origin = try container.decode(String.self, forKey: .origin)
        riskLevel = try container.decode(String.self, forKey: .riskLevel)
        allergenOrSensitizationRisk = try container.decodeIfPresent(String.self, forKey: .allergenOrSensitizationRisk)
        typicalFunction = try container.decodeIfPresent(String.self, forKey: .typicalFunction)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // New fields with backward compatibility (optional)
        processingLevel = try container.decodeIfPresent(ProcessingLevel.self, forKey: .processingLevel)
        processingLevelNotes = try container.decodeIfPresent(String.self, forKey: .processingLevelNotes)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }
}
