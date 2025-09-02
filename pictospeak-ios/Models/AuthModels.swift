//
//  AuthModels.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - Authentication Request Models

struct UserSignUpRequest: Codable {
    let email: String
    let password: String
    let nickname: String
    let targetLanguage: String
    let nativeLanguage: String

    private enum CodingKeys: String, CodingKey {
        case email
        case password
        case nickname
        case targetLanguage = "target_language"
        case nativeLanguage = "native_language"
    }
}

struct UserSignInRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Authentication Response Models

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}
