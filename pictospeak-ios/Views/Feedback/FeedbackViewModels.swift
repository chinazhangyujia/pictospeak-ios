//
//  FeedbackViewModels.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation

// MARK: - Clickable Text Models

struct ClickableTextMatch: Equatable {
    let range: NSRange
    let text: String
    let cardType: CardType? // Optional now, nil if it's a segment
    let cardId: UUID? // Optional now, nil if it's a segment
    let isSegment: Bool // New flag

    static func == (lhs: ClickableTextMatch, rhs: ClickableTextMatch) -> Bool {
        return lhs.range.location == rhs.range.location &&
            lhs.range.length == rhs.range.length &&
            lhs.text == rhs.text &&
            lhs.cardType == rhs.cardType &&
            lhs.cardId == rhs.cardId &&
            lhs.isSegment == rhs.isSegment
    }
}

enum CardType {
    case keyTerm
    case suggestion
}
