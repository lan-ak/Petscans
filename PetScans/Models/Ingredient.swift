import Foundation

/// Per-species risk level for an ingredient
/// Allows different risk classifications for dogs vs cats (e.g., propylene glycol is safe for dogs but toxic to cats)
struct RiskLevel: Codable, Equatable {
    let dog: String
    let cat: String

    /// Get risk level for a specific species
    subscript(species: Species) -> String {
        switch species {
        case .dog: return dog
        case .cat: return cat
        }
    }

    /// Create a uniform risk level (same for all species)
    static func uniform(_ level: String) -> RiskLevel {
        RiskLevel(dog: level, cat: level)
    }
}

struct Ingredient: Codable, Identifiable {
    let id: String
    let commonName: String
    let scientificName: String?
    let species: [Species]
    let categories: [Category]
    let origin: String
    let riskLevel: RiskLevel
    let allergenOrSensitizationRisk: String?
    let typicalFunction: String?
    let notes: String?

    // NOVA-style processing classification (informational only, does not affect scores)
    let processingLevel: ProcessingLevel?
    let processingLevelNotes: String?

    // Toxicity data from ASPCA/Merck sources
    let toxicitySymptoms: [String]?
    let toxicDose: [String: String]?

    // Source attribution for ingredient data (multiple sources supported)
    let sources: [String]?

    // Legacy field for backward compatibility
    private let source: String?

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
        case toxicitySymptoms
        case toxicDose
        case sources
        case source
    }

    /// Get risk level string for a specific species
    func riskLevel(for species: Species) -> String {
        riskLevel[species]
    }

    /// Get toxic dose for a specific species, if available
    func toxicDose(for species: Species) -> String? {
        toxicDose?[species.rawValue]
    }

    /// Get all sources (combines legacy `source` with new `sources` array)
    var allSources: [String] {
        var result = sources ?? []
        if let legacySource = source, !result.contains(legacySource) {
            result.insert(legacySource, at: 0)
        }
        return result
    }

    // Memberwise initializer for programmatic creation
    init(
        id: String,
        commonName: String,
        scientificName: String? = nil,
        species: [Species],
        categories: [Category],
        origin: String,
        riskLevel: RiskLevel,
        allergenOrSensitizationRisk: String? = nil,
        typicalFunction: String? = nil,
        notes: String? = nil,
        processingLevel: ProcessingLevel? = nil,
        processingLevelNotes: String? = nil,
        toxicitySymptoms: [String]? = nil,
        toxicDose: [String: String]? = nil,
        sources: [String]? = nil
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
        self.toxicitySymptoms = toxicitySymptoms
        self.toxicDose = toxicDose
        self.sources = sources
        self.source = nil
    }

    // Convenience initializer with string risk level (for backward compatibility in code)
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
        self.riskLevel = .uniform(riskLevel)
        self.allergenOrSensitizationRisk = allergenOrSensitizationRisk
        self.typicalFunction = typicalFunction
        self.notes = notes
        self.processingLevel = processingLevel
        self.processingLevelNotes = processingLevelNotes
        self.toxicitySymptoms = nil
        self.toxicDose = nil
        self.sources = source.map { [$0] }
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

        // Decode riskLevel: try object first, fall back to string for backward compatibility
        if let riskLevelObject = try? container.decode(RiskLevel.self, forKey: .riskLevel) {
            riskLevel = riskLevelObject
        } else if let riskLevelString = try? container.decode(String.self, forKey: .riskLevel) {
            riskLevel = .uniform(riskLevelString)
        } else {
            riskLevel = .uniform("safe")
        }

        allergenOrSensitizationRisk = try container.decodeIfPresent(String.self, forKey: .allergenOrSensitizationRisk)
        typicalFunction = try container.decodeIfPresent(String.self, forKey: .typicalFunction)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Processing fields
        processingLevel = try container.decodeIfPresent(ProcessingLevel.self, forKey: .processingLevel)
        processingLevelNotes = try container.decodeIfPresent(String.self, forKey: .processingLevelNotes)

        // New toxicity fields
        toxicitySymptoms = try container.decodeIfPresent([String].self, forKey: .toxicitySymptoms)
        toxicDose = try container.decodeIfPresent([String: String].self, forKey: .toxicDose)

        // Source fields (support both legacy and new format)
        sources = try container.decodeIfPresent([String].self, forKey: .sources)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }
}
