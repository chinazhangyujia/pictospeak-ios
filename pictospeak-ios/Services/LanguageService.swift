//
//  LanguageService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - Response Models

struct LanguageSupportedResponse: Codable {
    let targetLanguages: [BackendLanguage]
    let nativeLanguages: [BackendLanguage]

    private enum CodingKeys: String, CodingKey {
        case targetLanguages = "target_languages"
        case nativeLanguages = "native_languages"
    }
}

class LanguageService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = LanguageService()
    private init() {}

    // MARK: - Public Methods

    /// Fetches the supported languages from the backend
    /// - Returns: LanguageSupportedResponse containing lists of target and native languages
    func fetchSupportedLanguages() async throws -> LanguageSupportedResponse {
        guard let url = URL(string: baseURL + "/language/supported") else {
            throw LanguageError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        // No auth token needed for this endpoint

        print("🌐 Making get supported languages request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw LanguageError.serverError
            }

            print("📡 Get supported languages response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Language API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw LanguageError.serverError
            }

            let decoder = JSONDecoder()
            // No specific key decoding strategy needed as we map keys manually in CodingKeys if needed,
            // or if they match. Here we use explicit CodingKeys in LanguageSupportedResponse for snake_case mapping.

            do {
                let supportedLanguages = try decoder.decode(LanguageSupportedResponse.self, from: data)
                print("✅ Successfully fetched supported languages")
                return supportedLanguages
            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw LanguageError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw LanguageError.networkError
        } catch {
            print("❌ Unexpected error: \(error)")
            throw LanguageError.unknownError
        }
    }
}

// MARK: - Error Types

enum LanguageError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError
    case decodingError
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
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
