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
    let keyTerms: [KeyTerm]
    let suggestions: [Suggestion]
    let materialUrl: String

    private enum CodingKeys: String, CodingKey {
        case descriptionTeaching = "description_teaching"
        case keyTerms = "key_terms"
        case suggestions
        case materialUrl = "material_url"
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

    var sessionId: UUID {
        return descriptionTeaching.id ?? UUID()
    }
}
