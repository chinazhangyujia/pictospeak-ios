//
//  FavoriteService.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation

class FavoriteService {
    private let baseURL = "http://127.0.0.1:8000" // Local FastAPI server

    // MARK: - Singleton

    static let shared = FavoriteService()
    private init() {}

    // MARK: - Helper Methods

    private func generateRandomBearerToken() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let tokenLength = 32
        let randomString = String((0 ..< tokenLength).map { _ in characters.randomElement()! })
        return "Bearer \(randomString)"
    }

    // MARK: - Public Methods

    func updateKeyTermFavorite(termId: String, favorite: Bool) async throws {
        guard let url = URL(string: baseURL + "/key-term-and-suggestion/key-term/favorite") else {
            throw FavoriteError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(generateRandomBearerToken(), forHTTPHeaderField: "Authorization")

        let requestBody = UpdateKeyTermFavoriteRequest(termId: termId, favorite: favorite)
        let jsonData = try JSONEncoder().encode(requestBody)
        urlRequest.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw FavoriteError.serverError
        }
    }

    func updateSuggestionFavorite(suggestionId: String, favorite: Bool) async throws {
        guard let url = URL(string: baseURL + "/key-term-and-suggestion/suggestion/favorite") else {
            throw FavoriteError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(generateRandomBearerToken(), forHTTPHeaderField: "Authorization")

        let requestBody = UpdateSuggestionFavoriteRequest(suggestionId: suggestionId, favorite: favorite)
        let jsonData = try JSONEncoder().encode(requestBody)
        urlRequest.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw FavoriteError.serverError
        }
    }
}

// MARK: - Request Models

struct UpdateKeyTermFavoriteRequest: Codable {
    let termId: String
    let favorite: Bool

    private enum CodingKeys: String, CodingKey {
        case termId = "term_id"
        case favorite
    }
}

struct UpdateSuggestionFavoriteRequest: Codable {
    let suggestionId: String
    let favorite: Bool

    private enum CodingKeys: String, CodingKey {
        case suggestionId = "suggestion_id"
        case favorite
    }
}

// MARK: - Errors

enum FavoriteError: Error, LocalizedError {
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error occurred"
        }
    }
}
