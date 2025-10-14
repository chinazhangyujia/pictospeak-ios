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
    let verificationCodeId: String
    let verificationCode: String

    private enum CodingKeys: String, CodingKey {
        case email
        case password
        case nickname
        case targetLanguage = "target_language"
        case nativeLanguage = "native_language"
        case verificationCodeId = "verification_code_id"
        case verificationCode = "verification_code"
    }
}

struct UserSignInRequest: Codable {
    let email: String
    let password: String
}

struct PasswordResetRequest: Codable {
    let email: String
}

struct ResetPasswordRequest: Codable {
    let targetType: TargetType
    let targetValue: String
    let newPassword: String
    let verificationCodeId: String
    let verificationCode: String

    private enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetValue = "target_value"
        case newPassword = "new_password"
        case verificationCodeId = "verification_code_id"
        case verificationCode = "verification_code"
    }
}

// MARK: - Verification Code Request Models

enum TargetType: String, Codable {
    case EMAIL
}

enum FlowType: String, Codable {
    case signUp = "SIGN_UP"
    case resetPassword = "RESET_PASSWORD"

    private enum CodingKeys: String, CodingKey {
        case signUp = "SIGN_UP"
        case resetPassword = "RESET_PASSWORD"
    }
}

struct SendVerificationCodeRequest: Codable {
    let targetType: TargetType
    let targetValue: String
    let flowType: FlowType

    private enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetValue = "target_value"
        case flowType = "flow_type"
    }
}

struct VerifyVerificationCodeRequest: Codable {
    let targetType: TargetType
    let targetValue: String
    let flowType: FlowType
    let code: String

    private enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetValue = "target_value"
        case flowType = "flow_type"
        case code
    }
}

struct VerifyVerificationCodeResponse: Codable {
    let id: String
    let code: String
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
