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
    let id: String
    let title: String
    let userDescription: String
    let standardDescription: String
    let imageUrl: String
    let keyTermsCount: Int
    let suggestionsCount: Int
    let createdAt: Date?

    init(from sessionItem: SessionItem) {
        id = sessionItem.id
        title = String(sessionItem.userDescription.prefix(50))
        userDescription = sessionItem.userDescription
        standardDescription = sessionItem.standardDescription
        imageUrl = sessionItem.materialUrl
        keyTermsCount = sessionItem.keyTerms.count
        suggestionsCount = sessionItem.suggestions.count
        createdAt = nil // Could be parsed from materialUrl or added to API
    }
}
