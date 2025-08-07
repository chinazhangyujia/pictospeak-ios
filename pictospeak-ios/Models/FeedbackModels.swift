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
