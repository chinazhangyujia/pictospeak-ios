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
    let descriptionGuidance: DescriptionGuidance
    let keyTerms: [SessionKeyTerm]
    let suggestions: [SessionSuggestion]
    let materialUrl: String

    private enum CodingKeys: String, CodingKey {
        case descriptionGuidance = "description_guidance"
        case keyTerms = "key_terms"
        case suggestions
        case materialUrl = "material_url"
    }

    // Computed property for SwiftUI Identifiable
    var id: String {
        return descriptionGuidance.id
    }

    // Convenience computed properties
    var userDescription: String {
        return descriptionGuidance.userDescription
    }

    var standardDescription: String {
        return descriptionGuidance.standardDescription
    }

    var sessionId: String {
        return descriptionGuidance.id
    }
}

struct DescriptionGuidance: Codable {
    let id: String
    let userDescription: String
    let standardDescription: String

    private enum CodingKeys: String, CodingKey {
        case id
        case userDescription = "user_description"
        case standardDescription = "standard_description"
    }
}

struct SessionKeyTerm: Codable, Identifiable {
    let id: String
    let term: String
    let translation: String
    let example: String
}

struct SessionSuggestion: Codable, Identifiable {
    let id: String
    let term: String
    let refinement: String
    let translation: String
    let reason: String
}
