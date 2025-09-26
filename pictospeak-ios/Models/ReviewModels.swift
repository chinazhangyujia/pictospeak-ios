//
//  ReviewModels.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation

// MARK: - Review Item Type

enum ReviewItemType: String, Codable, CaseIterable {
    case keyTerm = "key_term"
    case suggestion = "suggestion"
}

// MARK: - Review Item

struct ReviewItem: Codable, Identifiable {
    let id: UUID
    let type: ReviewItemType
    let term: String
    let translation: String
    let favorite: Bool
    let detail: String
    let updatedAt: Date
    
    init(id: UUID, type: ReviewItemType, term: String, translation: String, favorite: Bool, detail: String, updatedAt: Date) {
        self.id = id
        self.type = type
        self.term = term
        self.translation = translation
        self.favorite = favorite
        self.detail = detail
        self.updatedAt = updatedAt
    }
    
    // Custom Codable implementation to handle snake_case from JSON
    private enum CodingKeys: String, CodingKey {
        case id, type, term, translation, favorite, detail
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ReviewItemType.self, forKey: .type)
        term = try container.decode(String.self, forKey: .term)
        translation = try container.decode(String.self, forKey: .translation)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        detail = try container.decode(String.self, forKey: .detail)
        
        // Handle date string decoding
        let dateString = try container.decode(String.self, forKey: .updatedAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        updatedAt = date
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(term, forKey: .term)
        try container.encode(translation, forKey: .translation)
        try container.encode(favorite, forKey: .favorite)
        try container.encode(detail, forKey: .detail)
        
        // Handle date encoding to ISO 8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: updatedAt)
        try container.encode(dateString, forKey: .updatedAt)
    }
}

// MARK: - Conversion Methods

extension ReviewItem {
    /// Converts the ReviewItem to a KeyTerm
    /// - Returns: A KeyTerm object with the same data
    func toKeyTerm() -> KeyTerm {
        return KeyTerm(
            term: self.term,
            translation: self.translation,
            example: self.detail,
            favorite: self.favorite,
            id: self.id
        )
    }
    
    /// Converts the ReviewItem to a Suggestion
    /// - Returns: A Suggestion object with the same data
    func toSuggestion() -> Suggestion {
        return Suggestion(
            term: self.term,
            refinement: "",
            translation: self.translation,
            reason: self.detail, // Using detail as reason
            favorite: self.favorite,
            id: self.id
        )
    }
    
    /// Converts the ReviewItem to the appropriate type based on its type property
    /// - Returns: Either a KeyTerm or Suggestion depending on the type
    func toTypedItem() -> Any {
        switch type {
        case .keyTerm:
            return toKeyTerm()
        case .suggestion:
            return toSuggestion()
        }
    }
}

// MARK: - Convenience Initializers

extension ReviewItem {
    /// Creates a ReviewItem from a KeyTerm
    /// - Parameter keyTerm: The KeyTerm to convert
    /// - Returns: A ReviewItem of type keyTerm
    static func from(keyTerm: KeyTerm) -> ReviewItem {
        return ReviewItem(
            id: keyTerm.id,
            type: .keyTerm,
            term: keyTerm.term,
            translation: keyTerm.translation,
            favorite: keyTerm.favorite,
            detail: keyTerm.example,
            updatedAt: Date()
        )
    }
    
    /// Creates a ReviewItem from a Suggestion
    /// - Parameter suggestion: The Suggestion to convert
    /// - Returns: A ReviewItem of type suggestion
    static func from(suggestion: Suggestion) -> ReviewItem {
        return ReviewItem(
            id: suggestion.id,
            type: .suggestion,
            term: suggestion.term,
            translation: suggestion.translation,
            favorite: suggestion.favorite,
            detail: suggestion.reason,
            updatedAt: Date()
        )
    }
}

// MARK: - API Response Models

struct ListReviewItemsResponse: Codable {
    let items: [ReviewItem]
    let nextCursor: String?
    
    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}
