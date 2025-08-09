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
    let keyExpressions: [KeyExpression]
    let score: Int?

    // Custom initializer to handle both old and new formats
    init(originalText: String, refinedText: String, suggestions: [Suggestion], keyExpressions: [KeyExpression], score: Int? = nil) {
        self.originalText = originalText
        self.refinedText = refinedText
        self.suggestions = suggestions
        self.keyExpressions = keyExpressions
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
                expression: streamingSuggestion.expression,
                refinement: streamingSuggestion.refinement,
                reason: streamingSuggestion.reason
            )
        }

        let convertedKeyExpressions = agentResult.keyExpressions.map { streamingExpression in
            KeyExpression(
                expression: streamingExpression.expression,
                explanation: streamingExpression.explanation
            )
        }

        return FeedbackResponse(
            originalText: metadata.userDescription,
            refinedText: agentResult.standardDescription,
            suggestions: convertedSuggestions,
            keyExpressions: convertedKeyExpressions,
            score: agentResult.score
        )
    }
}

struct StreamingAgentResult: Codable {
    let standardDescription: String
    let keyExpressions: [StreamingKeyExpression]
    let suggestions: [StreamingSuggestion]
    let score: Int

    private enum CodingKeys: String, CodingKey {
        case standardDescription = "standard_description"
        case keyExpressions = "key_expressions"
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
    let expression: String
    let refinement: String
    let reason: String
}

// MARK: - Key Expression

struct KeyExpression: Codable, Identifiable {
    let id = UUID()
    let expression: String
    let explanation: String
}

// MARK: - Streaming Models

struct StreamingSuggestion: Codable {
    let expression: String
    let refinement: String
    let reason: String
}

struct StreamingKeyExpression: Codable {
    let expression: String
    let explanation: String
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

// MARK: - Text Range for Highlighting

struct TextRange: Codable {
    let startIndex: Int
    let endIndex: Int
    let color: HighlightColor
}

enum HighlightColor: String, Codable {
    case purple
    case blue
    case green
    case orange
}
