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
    let translation: String
    let favorite: Bool
    let detail: String
    let updatedAt: Date

    init(id: UUID, type: ReviewItemType, term: String, translation: String, favorite: Bool, detail: String, updatedAt: Date, descriptionGuidanceId: UUID = UUID(), userOriginalTerm: String? = nil) {
        self.id = id
        self.type = type
        self.term = term
        self.translation = translation
        self.favorite = favorite
        self.detail = detail
        self.updatedAt = updatedAt
        self.descriptionGuidanceId = descriptionGuidanceId
        self.userOriginalTerm = userOriginalTerm
    }

    // Custom Codable implementation to handle snake_case from JSON
    private enum CodingKeys: String, CodingKey {
        case id, type, term, translation, favorite, detail
        case updatedAt = "updated_at"
        case descriptionGuidanceId = "description_guidance_id"
        case userOriginalTerm = "user_original_term"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ReviewItemType.self, forKey: .type)
        term = try container.decode(String.self, forKey: .term)
        translation = try container.decode(String.self, forKey: .translation)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        detail = try container.decode(String.self, forKey: .detail)
        descriptionGuidanceId = try container.decode(UUID.self, forKey: .descriptionGuidanceId)
        userOriginalTerm = try container.decodeIfPresent(String.self, forKey: .userOriginalTerm)

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
        try container.encode(descriptionGuidanceId, forKey: .descriptionGuidanceId)
        try container.encodeIfPresent(userOriginalTerm, forKey: .userOriginalTerm)

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
            term: term,
            translation: translation,
            example: detail,
            favorite: favorite,
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
            translation: translation,
            reason: detail, // Using detail as reason
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
