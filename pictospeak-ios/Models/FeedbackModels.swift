//
//  FeedbackModels.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation

// MARK: - Main Feedback Response

struct FeedbackResponse: Codable {
    let originalText: String
    let refinedText: String
    let suggestions: [Suggestion]
    let keyTerms: [KeyTerm]
    let score: Int?
    let chosenKeyTerms: [String]?
    let chosenRefinements: [String]?
    let chosenItemsGenerated: Bool
    let pronunciationUrl: String?
    let standardDescriptionSegments: [String]
    let id: UUID?

    // Custom initializer to handle both old and new formats
    init(originalText: String, refinedText: String, suggestions: [Suggestion], keyTerms: [KeyTerm], score: Int? = nil, chosenKeyTerms: [String]? = nil, chosenRefinements: [String]? = nil, chosenItemsGenerated: Bool = false, pronunciationUrl: String? = nil, standardDescriptionSegments: [String] = [], id: UUID? = nil) {
        self.originalText = originalText
        self.refinedText = refinedText
        self.suggestions = suggestions
        self.keyTerms = keyTerms
        self.score = score
        self.chosenKeyTerms = chosenKeyTerms
        self.chosenRefinements = chosenRefinements
        self.chosenItemsGenerated = chosenItemsGenerated
        self.pronunciationUrl = pronunciationUrl
        self.standardDescriptionSegments = standardDescriptionSegments
        self.id = id
    }
}

// MARK: - Streaming API Response

struct StreamingFeedbackResponse: Codable {
    let isFinal: Bool
    let descriptionTeaching: DescriptionTeaching
    let keyTerms: [KeyTerm]
    let suggestions: [Suggestion]
    let metadata: StreamingMetadata

    private enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case descriptionTeaching = "description_teaching"
        case keyTerms = "key_terms"
        case suggestions
        case metadata
    }

    // Convert to FeedbackResponse format
    func toFeedbackResponse() -> FeedbackResponse {
        return FeedbackResponse(
            originalText: descriptionTeaching.userDescription,
            refinedText: descriptionTeaching.standardDescription,
            suggestions: suggestions,
            keyTerms: keyTerms,
            score: nil,
            chosenKeyTerms: metadata.chosenKeyTerms,
            chosenRefinements: metadata.chosenRefinements,
            chosenItemsGenerated: metadata.chosenItemsGenerated,
            pronunciationUrl: descriptionTeaching.standardDescriptionPronunciationUrl,
            standardDescriptionSegments: metadata.standardDescriptionSegments,
            id: descriptionTeaching.id
        )
    }
}

struct DescriptionTeaching: Codable {
    let userDescription: String
    let standardDescription: String
    let standardDescriptionPronunciationUrl: String?
    let id: UUID?
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case userDescription = "user_description"
        case standardDescription = "standard_description"
        case standardDescriptionPronunciationUrl = "standard_description_pronunciation_url"
        case id
        case createdAt = "created_at"
    }
}

struct StreamingMetadata: Codable {
    let userDescription: String
    let chosenKeyTerms: [String]
    let chosenRefinements: [String]
    let chosenItemsGenerated: Bool
    let standardDescriptionSegments: [String]

    private enum CodingKeys: String, CodingKey {
        case userDescription = "user_description"
        case chosenKeyTerms = "chosen_key_terms"
        case chosenRefinements = "chosen_refinements"
        case chosenItemsGenerated = "chosen_items_generated"
        case standardDescriptionSegments = "standard_description_segments"
    }
}

struct KeyTermTeachingStreamingResponse: Codable {
    let isFinal: Bool
    let keyTerm: KeyTerm

    private enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case keyTerm = "key_term"
    }
}

// MARK: - Suggestion

struct Suggestion: Codable, Identifiable {
    let id: UUID
    let descriptionGuidanceId: UUID?
    let term: String
    let refinement: String
    let translations: [TermTranslation]
    let reason: TermReason
    let example: TermExample
    let favorite: Bool
    let phoneticSymbol: String?

    init(term: String, refinement: String, translations: [TermTranslation], reason: TermReason, example: TermExample, favorite: Bool, phoneticSymbol: String? = nil, id: UUID? = nil, descriptionGuidanceId: UUID? = nil) {
        self.term = term
        self.refinement = refinement
        self.translations = translations
        self.reason = reason
        self.example = example
        self.favorite = favorite
        self.phoneticSymbol = phoneticSymbol
        self.id = id ?? UUID()
        self.descriptionGuidanceId = descriptionGuidanceId
    }

    // Custom Codable implementation to handle optional id from JSON
    private enum CodingKeys: String, CodingKey {
        case id, term, refinement, translations, reason, example, favorite
        case phoneticSymbol = "phonetic_symbol"
        case descriptionGuidanceId = "description_guidance_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term)
        refinement = try container.decode(String.self, forKey: .refinement)
        translations = try container.decode([TermTranslation].self, forKey: .translations)
        reason = try container.decode(TermReason.self, forKey: .reason)
        example = try container.decodeIfPresent(TermExample.self, forKey: .example) ?? TermExample(sentence: "", sentenceTranslation: "")
        favorite = try container.decode(Bool.self, forKey: .favorite)
        phoneticSymbol = try container.decodeIfPresent(String.self, forKey: .phoneticSymbol)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? .zero
        descriptionGuidanceId = try container.decodeIfPresent(UUID.self, forKey: .descriptionGuidanceId)
    }
}

// MARK: - Shared Items

struct TermTranslation: Codable {
    let pos: String
    let translation: String
}

struct TermReason: Codable {
    let reason: String
    let reasonTranslation: String

    private enum CodingKeys: String, CodingKey {
        case reason
        case reasonTranslation = "reason_translation"
    }
}

struct TermExample: Codable {
    let sentence: String
    let sentenceTranslation: String

    private enum CodingKeys: String, CodingKey {
        case sentence
        case sentenceTranslation = "sentence_translation"
    }
}

struct KeyTerm: Codable, Identifiable {
    let id: UUID
    let descriptionGuidanceId: UUID?
    let term: String
    let phoneticSymbol: String?
    let translations: [TermTranslation]
    let reason: TermReason
    let example: TermExample
    let favorite: Bool

    init(term: String, translations: [TermTranslation], reason: TermReason, example: TermExample, favorite: Bool, phoneticSymbol: String? = nil, id: UUID? = nil, descriptionGuidanceId: UUID? = nil) {
        self.term = term
        self.translations = translations
        self.reason = reason
        self.example = example
        self.favorite = favorite
        self.phoneticSymbol = phoneticSymbol
        self.id = id ?? .zero
        self.descriptionGuidanceId = descriptionGuidanceId
    }

    // Custom Codable implementation to handle optional id from JSON
    private enum CodingKeys: String, CodingKey {
        case id, term, translations, reason, example, favorite
        case phoneticSymbol = "phonetic_symbol"
        case descriptionGuidanceId = "description_guidance_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term)
        translations = try container.decode([TermTranslation].self, forKey: .translations)
        reason = try container.decode(TermReason.self, forKey: .reason)
        example = try container.decode(TermExample.self, forKey: .example)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        phoneticSymbol = try container.decodeIfPresent(String.self, forKey: .phoneticSymbol)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? .zero
        descriptionGuidanceId = try container.decodeIfPresent(UUID.self, forKey: .descriptionGuidanceId)
    }
}

// MARK: - API Request Models

struct FeedbackRequest: Codable {
    let imageData: Data?
    let videoData: Data?
    let audioData: Data?
    let mediaType: MediaType
}
