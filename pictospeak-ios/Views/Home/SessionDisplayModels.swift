//
//  SessionDisplayModels.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - Session Display Models

/// A simplified model for displaying sessions in lists/cards
struct SessionDisplayItem: Identifiable {
    let id: UUID
    let title: String
    let userDescription: String
    let standardDescription: String
    let imageUrl: String
    let keyTermsCount: Int
    let suggestionsCount: Int
    let createdAt: Date?

    // Enhanced feedback data
    let keyTerms: [KeyTerm]
    let suggestions: [Suggestion]
    let pronunciationUrl: String?

    init(from sessionItem: SessionItem) {
        id = sessionItem.id
        title = String(sessionItem.standardDescription.prefix(50))
        userDescription = sessionItem.userDescription
        standardDescription = sessionItem.standardDescription
        imageUrl = sessionItem.materialUrl
        keyTermsCount = sessionItem.keyTerms.count
        suggestionsCount = sessionItem.suggestions.count
        createdAt = nil // Could be parsed from materialUrl or added to API

        // Enhanced feedback data
        keyTerms = sessionItem.keyTerms
        suggestions = sessionItem.suggestions
        pronunciationUrl = sessionItem.descriptionTeaching.standardDescriptionPronunciationUrl
    }

    // Convenience initializer for previews and testing
    init(id: UUID, title: String, userDescription: String, standardDescription: String, imageUrl: String, keyTermsCount: Int, suggestionsCount: Int, createdAt: Date?, keyTerms: [KeyTerm] = [], suggestions: [Suggestion] = [], pronunciationUrl: String? = nil) {
        self.id = id
        self.title = title
        self.userDescription = userDescription
        self.standardDescription = standardDescription
        self.imageUrl = imageUrl
        self.keyTermsCount = keyTermsCount
        self.suggestionsCount = suggestionsCount
        self.createdAt = createdAt
        self.keyTerms = keyTerms
        self.suggestions = suggestions
        self.pronunciationUrl = pronunciationUrl
    }
}
