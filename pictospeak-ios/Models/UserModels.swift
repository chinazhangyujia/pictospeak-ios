//
//  UserModels.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - User Models

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let nickname: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case nickname
        case createdAt = "created_at"
    }
}

// MARK: - Backend Response Models (Shared)

struct BackendLanguage: Codable {
    let code: String
    let name: String
}

struct BackendUserSettingResponse: Codable {
    let nativeLanguage: BackendLanguage
    let targetLanguage: BackendLanguage

    private enum CodingKeys: String, CodingKey {
        case nativeLanguage = "native_language"
        case targetLanguage = "target_language"
    }
}

// MARK: - User Info Response

struct UserInfo {
    let user: User?
    let userSetting: UserSetting?
}
