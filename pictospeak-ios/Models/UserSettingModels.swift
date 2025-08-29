//
//  UserSettingModels.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - User Setting Models

struct UserSetting: Codable {
    let targetLanguage: String
    let nativeLanguage: String

    private enum CodingKeys: String, CodingKey {
        case targetLanguage = "target_language"
        case nativeLanguage = "native_language"
    }
}
