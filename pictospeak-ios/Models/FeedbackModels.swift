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

    // Custom initializer to handle both old and new formats
    init(originalText: String, refinedText: String, suggestions: [Suggestion], keyTerms: [KeyTerm], score: Int? = nil, chosenKeyTerms: [String]? = nil, chosenRefinements: [String]? = nil, chosenItemsGenerated: Bool = false, pronunciationUrl: String? = nil) {
        self.originalText = originalText
        self.refinedText = refinedText
        self.suggestions = suggestions
        self.keyTerms = keyTerms
        self.score = score
        self.chosenKeyTerms = chosenKeyTerms
        self.chosenRefinements = chosenRefinements
        self.chosenItemsGenerated = chosenItemsGenerated
        self.pronunciationUrl = pronunciationUrl
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
            pronunciationUrl: descriptionTeaching.standardDescriptionPronunciationUrl
        )
    }
}

struct DescriptionTeaching: Codable {
    let userDescription: String
    let standardDescription: String
    let standardDescriptionPronunciationUrl: String?
    let id: UUID?

    private enum CodingKeys: String, CodingKey {
        case userDescription = "user_description"
        case standardDescription = "standard_description"
        case standardDescriptionPronunciationUrl = "standard_description_pronunciation_url"
        case id
    }
}

struct StreamingMetadata: Codable {
    let userDescription: String
    let chosenKeyTerms: [String]
    let chosenRefinements: [String]
    let chosenItemsGenerated: Bool

    private enum CodingKeys: String, CodingKey {
        case userDescription = "user_description"
        case chosenKeyTerms = "chosen_key_terms"
        case chosenRefinements = "chosen_refinements"
        case chosenItemsGenerated = "chosen_items_generated"
    }
}

// MARK: - Suggestion

struct Suggestion: Codable, Identifiable {
    let id: UUID
    let term: String
    let refinement: String
    let translation: String
    let reason: String

    init(term: String, refinement: String, translation: String, reason: String, id: UUID? = nil) {
        self.term = term
        self.refinement = refinement
        self.translation = translation
        self.reason = reason
        self.id = id ?? UUID()
    }

    // Custom Codable implementation to handle optional id from JSON
    private enum CodingKeys: String, CodingKey {
        case id, term, refinement, translation, reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term)
        refinement = try container.decode(String.self, forKey: .refinement)
        translation = try container.decode(String.self, forKey: .translation)
        reason = try container.decode(String.self, forKey: .reason)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    }
}

// MARK: - Key Term

struct KeyTerm: Codable, Identifiable {
    let id: UUID
    let term: String
    let translation: String
    let example: String

    init(term: String, translation: String, example: String, id: UUID? = nil) {
        self.term = term
        self.translation = translation
        self.example = example
        self.id = id ?? UUID()
    }

    // Custom Codable implementation to handle optional id from JSON
    private enum CodingKeys: String, CodingKey {
        case id, term, translation, example
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term)
        translation = try container.decode(String.self, forKey: .translation)
        example = try container.decode(String.self, forKey: .example)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    }
}

// MARK: - API Request Models

struct FeedbackRequest: Codable {
    let imageData: Data?
    let videoData: Data?
    let audioData: Data?
    let mediaType: MediaType
}

enum MediaType: String, Codable {
    case image
    case video
}
