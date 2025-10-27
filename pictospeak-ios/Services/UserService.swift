//
//  UserService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - Private Backend Response for Decoding

private struct UserInfoBackendResponse: Codable {
    let user: User
    let userSetting: BackendUserSettingResponse

    private enum CodingKeys: String, CodingKey {
        case user
        case userSetting = "user_setting"
    }
}

class UserService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = UserService()
    private init() {}

    // MARK: - Public Methods

    /// Fetches the current user's information including user details and settings
    /// - Parameter authToken: The authentication token
    /// - Returns: UserInfo containing user details and settings
    func getUserInfo(authToken: String) async throws -> UserInfo {
        guard let url = URL(string: baseURL + "/user/info") else {
            throw UserError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("🌐 Making get user info request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw UserError.serverError
            }

            print("📡 Get user info response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ User info API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw UserError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let backendResponse = try decoder.decode(UserInfoBackendResponse.self, from: data)

                // Convert backend response to simplified UserSetting model
                let userSetting = UserSetting(
                    targetLanguage: backendResponse.userSetting.targetLanguage.name.uppercased(),
                    nativeLanguage: backendResponse.userSetting.nativeLanguage.name.uppercased()
                )

                let userInfo = UserInfo(
                    user: backendResponse.user,
                    userSetting: userSetting
                )

                print("✅ Successfully fetched user info for: \(userInfo.user?.email ?? "unknown")")
                return userInfo
            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw UserError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw UserError.networkError
        } catch {
            print("❌ Unexpected error: \(error)")
            throw UserError.unknownError
        }
    }
}

// MARK: - Error Types

enum UserError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError
    case decodingError
    case noTokenFound
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
        case .noTokenFound:
            return "No authentication token found"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
