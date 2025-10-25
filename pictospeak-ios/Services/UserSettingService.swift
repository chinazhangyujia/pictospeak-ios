//
//  UserSettingService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - Temporary API Response Model for Backend

private struct BackendLanguageResponse: Codable {
    let code: String
    let name: String
}

private struct BackendUserSettingResponse: Codable {
    let nativeLanguage: BackendLanguageResponse
    let targetLanguage: BackendLanguageResponse

    private enum CodingKeys: String, CodingKey {
        case nativeLanguage = "native_language"
        case targetLanguage = "target_language"
    }
}

class UserSettingService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = UserSettingService()
    private init() {}

    /// Fetches user settings from the backend
    /// - Returns: UserSetting containing native and target language information
    func getUserSettings(authToken: String) async throws -> UserSetting {
        guard let url = URL(string: baseURL + "/user-setting") else {
            throw UserSettingError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw UserSettingError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ User settings API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw UserSettingError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            print("🔍 Data: \(data)")
            do {
                let backendResponse = try decoder.decode(BackendUserSettingResponse.self, from: data)

                // Convert backend response to simplified UserSetting model
                let userSetting = UserSetting(
                    targetLanguage: backendResponse.targetLanguage.name.uppercased(),
                    nativeLanguage: backendResponse.nativeLanguage.name.uppercased()
                )

                print("✅ Successfully fetched user settings")
                return userSetting

            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw UserSettingError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw UserSettingError.networkError
        } catch {
            print("❌ Unexpected error: \(error)")
            throw UserSettingError.unknownError
        }
    }

    /// Updates user settings on the backend
    /// - Parameter userSetting: The UserSetting to update
    func createUserSettings(authToken: String, userSetting: UserSetting) async throws {
        guard let url = URL(string: baseURL + "/user-setting") else {
            throw UserSettingError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        // Encode the userSetting as JSON for the request body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        do {
            let jsonData = try encoder.encode(userSetting)
            urlRequest.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw UserSettingError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Update user settings API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw UserSettingError.serverError
            }

            print("✅ Successfully updated user settings")

        } catch let encodingError as EncodingError {
            print("❌ Encoding error: \(encodingError)")
            throw UserSettingError.encodingError
        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw UserSettingError.networkError
        } catch {
            print("❌ Unexpected error: \(error)")
            throw UserSettingError.unknownError
        }
    }
}

// MARK: - Error Types

enum UserSettingError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError
    case decodingError
    case encodingError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
