//
//  SessionModels.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - Session API Response Models

struct PaginatedSessionResponse: Codable {
    let items: [SessionItem]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct SessionItem: Codable, Identifiable {
    let descriptionTeaching: DescriptionTeaching
    var keyTerms: [KeyTerm]
    var suggestions: [Suggestion]
    let materialUrl: String
    let materialThumbnailUrl: String?
    let standardDescriptionSegments: [String]

    private enum CodingKeys: String, CodingKey {
        case descriptionTeaching = "description_teaching"
        case keyTerms = "key_terms"
        case suggestions
        case materialUrl = "material_url"
        case materialThumbnailUrl = "material_thumbnail_url"
        case standardDescriptionSegments = "standard_description_segments"
    }

    // Computed property for SwiftUI Identifiable
    var id: UUID {
        return descriptionTeaching.id ?? UUID()
    }

    // Convenience computed properties
    var userDescription: String {
        return descriptionTeaching.userDescription
    }

    var standardDescription: String {
        return descriptionTeaching.standardDescription
    }

    var pronunciationUrl: String? {
        return descriptionTeaching.standardDescriptionPronunciationUrl
    }

    var sessionId: UUID {
        return descriptionTeaching.id ?? UUID()
    }
}
