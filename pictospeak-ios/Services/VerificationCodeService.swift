//
//  VerificationCodeService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

class VerificationCodeService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = VerificationCodeService()
    private init() {}

    // MARK: - Public Methods

    /// Sends a verification code to the user's email
    /// - Parameters:
    ///   - targetType: The target type (e.g., EMAIL)
    ///   - targetValue: The email address to send the code to
    ///   - flowType: The flow type (SIGN_UP or RESET_PASSWORD)
    func sendVerificationCode(targetType: TargetType, targetValue: String, flowType: FlowType) async throws {
        guard let url = URL(string: baseURL + "/auth/send_verification_code") else {
            throw VerificationCodeError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        let request = SendVerificationCodeRequest(
            targetType: targetType,
            targetValue: targetValue,
            flowType: flowType
        )

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw VerificationCodeError.encodingError
        }

        print("🌐 Making send verification code request to: \(url)")
        print("📤 Sending code to: \(targetValue) for flow: \(flowType.rawValue)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw VerificationCodeError.serverError
            }

            print("📡 Send verification code response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Send verification code API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw VerificationCodeError.serverError
            }

            print("✅ Verification code sent successfully to: \(targetValue)")

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw VerificationCodeError.networkError
        } catch {
            print("❌ Unexpected error during send verification code: \(error)")
            throw VerificationCodeError.unknownError
        }
    }

    /// Verifies a verification code
    /// - Parameters:
    ///   - targetType: The target type (e.g., EMAIL)
    ///   - targetValue: The email address that received the code
    ///   - flowType: The flow type (SIGN_UP or RESET_PASSWORD)
    ///   - code: The verification code to verify
    /// - Returns: VerifyVerificationCodeResponse containing id and code
    func verifyVerificationCode(targetType: TargetType, targetValue: String, flowType: FlowType, code: String) async throws -> VerifyVerificationCodeResponse {
        guard let url = URL(string: baseURL + "/auth/verify_verification_code") else {
            throw VerificationCodeError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        let request = VerifyVerificationCodeRequest(
            targetType: targetType,
            targetValue: targetValue,
            flowType: flowType,
            code: code
        )

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw VerificationCodeError.encodingError
        }

        print("🌐 Making verify verification code request to: \(url)")
        print("🔐 Verifying code for: \(targetValue) with flow: \(flowType.rawValue)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw VerificationCodeError.serverError
            }

            print("📡 Verify verification code response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Verify verification code API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }

                // Throw specific error for invalid code
                if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                    throw VerificationCodeError.invalidCode
                }

                throw VerificationCodeError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let verificationResponse = try decoder.decode(VerifyVerificationCodeResponse.self, from: data)
                print("✅ Verification code verified successfully for: \(targetValue)")
                print("✅ Verification ID: \(verificationResponse.id)")
                return verificationResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw VerificationCodeError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw VerificationCodeError.networkError
        } catch {
            print("❌ Unexpected error during verify verification code: \(error)")
            throw VerificationCodeError.unknownError
        }
    }
}

// MARK: - Error Types

enum VerificationCodeError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case serverError
    case networkError
    case invalidCode
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .serverError:
            return "Server error occurred"
        case .networkError:
            return "Network error occurred"
        case .invalidCode:
            return "Invalid or expired verification code"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
