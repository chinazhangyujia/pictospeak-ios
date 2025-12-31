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
    case suggestion
}

// MARK: - Review Item

struct ReviewItem: Codable, Identifiable {
    let id: UUID
    let descriptionGuidanceId: UUID
    let type: ReviewItemType
    let term: String
    let userOriginalTerm: String?
    let translations: [TermTranslation]
    let reason: TermReason
    let example: TermExample
    let favorite: Bool
    let createdAt: Date
    let updatedAt: Date

    init(id: UUID, type: ReviewItemType, term: String, translations: [TermTranslation], favorite: Bool, reason: TermReason, example: TermExample, createdAt: Date, updatedAt: Date, descriptionGuidanceId: UUID = UUID(), userOriginalTerm: String? = nil) {
        self.id = id
        self.type = type
        self.term = term
        self.translations = translations
        self.favorite = favorite
        self.reason = reason
        self.example = example
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.descriptionGuidanceId = descriptionGuidanceId
        self.userOriginalTerm = userOriginalTerm
    }

    // Custom Codable implementation to handle snake_case from JSON
    private enum CodingKeys: String, CodingKey {
        case id, type, term, translations, favorite, reason, example
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case descriptionGuidanceId = "description_guidance_id"
        case userOriginalTerm = "user_original_term"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ReviewItemType.self, forKey: .type)
        term = try container.decode(String.self, forKey: .term)
        translations = try container.decode([TermTranslation].self, forKey: .translations)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        reason = try container.decode(TermReason.self, forKey: .reason)
        example = try container.decode(TermExample.self, forKey: .example)
        descriptionGuidanceId = try container.decode(UUID.self, forKey: .descriptionGuidanceId)
        userOriginalTerm = try container.decodeIfPresent(String.self, forKey: .userOriginalTerm)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Handle updatedAt
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        guard let updatedAtDate = formatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Invalid date format: \(updatedAtString)")
        }
        updatedAt = updatedAtDate

        // Handle createdAt
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        guard let createdAtDate = formatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid date format: \(createdAtString)")
        }
        createdAt = createdAtDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(term, forKey: .term)
        try container.encode(translations, forKey: .translations)
        try container.encode(favorite, forKey: .favorite)
        try container.encode(reason, forKey: .reason)
        try container.encode(example, forKey: .example)
        try container.encode(descriptionGuidanceId, forKey: .descriptionGuidanceId)
        try container.encodeIfPresent(userOriginalTerm, forKey: .userOriginalTerm)

        // Handle date encoding to ISO 8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updatedAtString = formatter.string(from: updatedAt)
        try container.encode(updatedAtString, forKey: .updatedAt)
        
        let createdAtString = formatter.string(from: createdAt)
        try container.encode(createdAtString, forKey: .createdAt)
    }
}

// MARK: - Conversion Methods

extension ReviewItem {
    /// Converts the ReviewItem to a KeyTerm
    /// - Returns: A KeyTerm object with the same data
    func toKeyTerm() -> KeyTerm {
        return KeyTerm(
            term: term,
            translations: translations,
            reason: reason,
            example: example,
            favorite: favorite,
            phoneticSymbol: nil,
            id: id,
            descriptionGuidanceId: descriptionGuidanceId
        )
    }

    /// Converts the ReviewItem to a Suggestion
    /// - Returns: A Suggestion object with the same data
    func toSuggestion() -> Suggestion {
        return Suggestion(
            term: userOriginalTerm ?? "",
            refinement: term,
            translations: translations,
            reason: reason,
            example: example,
            favorite: favorite,
            id: id,
            descriptionGuidanceId: descriptionGuidanceId
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

// MARK: - API Response Models

struct ListReviewItemsResponse: Codable {
    let items: [ReviewItem]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}
