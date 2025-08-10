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
    let cardType: CardType
    let cardId: UUID
}

enum CardType {
    case keyTerm
    case suggestion
}
