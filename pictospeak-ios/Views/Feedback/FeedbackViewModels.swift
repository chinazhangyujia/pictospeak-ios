//
//  FeedbackViewModels.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation

// MARK: - Clickable Text Models

struct ClickableTextMatch {
    let range: NSRange
    let text: String
    let cardType: CardType? // Optional now, nil if it's a segment
    let cardId: UUID? // Optional now, nil if it's a segment
    let isSegment: Bool // New flag
}

enum CardType {
    case keyTerm
    case suggestion
}
