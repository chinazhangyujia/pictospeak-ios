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

    // Custom initializer to handle both old and new formats
    init(originalText: String, refinedText: String, suggestions: [Suggestion], keyTerms: [KeyTerm], score: Int? = nil) {
        self.originalText = originalText
        self.refinedText = refinedText
        self.suggestions = suggestions
        self.keyTerms = keyTerms
        self.score = score
    }
}

// MARK: - Streaming API Response

struct StreamingFeedbackResponse: Codable {
    let isFinal: Bool
    let agentResult: StreamingAgentResult
    let metadata: StreamingMetadata

    private enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case agentResult = "agent_result"
        case metadata
    }

    // Convert to FeedbackResponse format
    func toFeedbackResponse() -> FeedbackResponse {
        let convertedSuggestions = agentResult.suggestions.map { streamingSuggestion in
            Suggestion(
                term: streamingSuggestion.term,
                refinement: streamingSuggestion.refinement,
                translation: streamingSuggestion.translation,
                reason: streamingSuggestion.reason
            )
        }

        let convertedKeyTerms = agentResult.keyTerms.map { streamingTerm in
            KeyTerm(
                term: streamingTerm.term,
                translation: streamingTerm.translation,
                example: streamingTerm.example
            )
        }

        return FeedbackResponse(
            originalText: metadata.userDescription,
            refinedText: agentResult.standardDescription,
            suggestions: convertedSuggestions,
            keyTerms: convertedKeyTerms,
            score: agentResult.score
        )
    }
}

struct StreamingAgentResult: Codable {
    let standardDescription: String
    let keyTerms: [StreamingKeyTerm]
    let suggestions: [StreamingSuggestion]
    let score: Int

    private enum CodingKeys: String, CodingKey {
        case standardDescription = "standard_description"
        case keyTerms = "key_terms"
        case suggestions
        case score
    }
}

struct StreamingMetadata: Codable {
    let id: UUID
    let userDescription: String

    private enum CodingKeys: String, CodingKey {
        case id
        case userDescription = "user_description"
    }
}

// MARK: - Suggestion

struct Suggestion: Codable, Identifiable {
    let id = UUID()
    let term: String
    let refinement: String
    let translation: String
    let reason: String
}

// MARK: - Key Term

struct KeyTerm: Codable, Identifiable {
    let id = UUID()
    let term: String
    let translation: String
    let example: String
}

// MARK: - Streaming Models

struct StreamingSuggestion: Codable {
    let term: String
    let refinement: String
    let translation: String
    let reason: String
}

struct StreamingKeyTerm: Codable {
    let term: String
    let translation: String
    let example: String
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
