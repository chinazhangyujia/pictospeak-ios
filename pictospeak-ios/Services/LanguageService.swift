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

    /// Maps language name (case-insensitive) to BCP-47 language code
    /// - Parameter languageName: The name of the language (e.g., "English", "Spanish")
    /// - Returns: The BCP-47 language code (e.g., "en-US", "es-ES")
    static func getBCP47Code(for languageName: String) -> String {
        switch languageName.uppercased() {
        case "ENGLISH": return "en-US"
        case "SPANISH": return "es-ES"
        case "FRENCH": return "fr-FR"
        case "GERMAN": return "de-DE"
        case "ITALIAN": return "it-IT"
        case "PORTUGUESE": return "pt-BR"
        case "RUSSIAN": return "ru-RU"
        case "CHINESE": return "zh-CN"
        case "JAPANESE": return "ja-JP"
        case "KOREAN": return "ko-KR"
        default: return "en-US"
        }
    }

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
            return NSLocalizedString("error.invalidURL", comment: "Invalid URL")
        case .networkError:
            return NSLocalizedString("error.network", comment: "Network error")
        case .serverError:
            return NSLocalizedString("error.server", comment: "Server error")
        case .decodingError:
            return NSLocalizedString("error.decoding", comment: "Decoding error")
        case .unknownError:
            return NSLocalizedString("error.unknown", comment: "Unknown error")
        }
    }
}
