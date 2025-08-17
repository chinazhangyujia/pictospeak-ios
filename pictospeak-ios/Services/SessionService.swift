//
//  SessionService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

class SessionService {
    private let baseURL = "http://127.0.0.1:8000" // Local FastAPI server

    // MARK: - Singleton

    static let shared = SessionService()
    private init() {}

    // MARK: - Helper Methods

    private func generateRandomBearerToken() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let tokenLength = 32
        let randomString = String((0 ..< tokenLength).map { _ in characters.randomElement()! })
        return "Bearer \(randomString)"
    }

    // MARK: - Public Methods

    /// Fetches past sessions with pagination support
    /// - Parameter cursor: Optional cursor for pagination. Pass nil for the first page.
    /// - Returns: PaginatedSessionResponse containing sessions and next cursor
    func getPastSessions(cursor: String? = nil) async throws -> PaginatedSessionResponse {
        var urlComponents = URLComponents(string: baseURL + "/description/guidance/list")!

        // Add cursor as query parameter if provided
        // The cursor format is "created_at_lt=xxx" so we parse it and add as query parameter
        if let cursor = cursor {
            // Parse cursor format: "created_at_lt=xxx"
            let components = cursor.components(separatedBy: "=")
            if components.count == 2 {
                urlComponents.queryItems = [URLQueryItem(name: components[0], value: components[1])]
            } else {
                // Fallback: use cursor as-is with "cursor" parameter
                urlComponents.queryItems = [URLQueryItem(name: "cursor", value: cursor)]
            }
        }

        guard let url = urlComponents.url else {
            throw SessionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        // Add Authorization header with random Bearer token
        urlRequest.setValue(generateRandomBearerToken(), forHTTPHeaderField: "Authorization")

        print("🌐 Making request to past sessions endpoint: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SessionError.serverError
            }

            print("📡 Past sessions response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Past sessions API error: \(httpResponse.statusCode)")
                throw SessionError.serverError
            }

            let decoder = JSONDecoder()
            let paginatedResponse = try decoder.decode(PaginatedSessionResponse.self, from: data)

            print("✅ Successfully loaded \(paginatedResponse.items.count) past sessions")
            if let nextCursor = paginatedResponse.nextCursor {
                print("📄 Next page cursor: \(nextCursor)")
            } else {
                print("📄 No more pages available")
            }

            return paginatedResponse

        } catch let decodingError as DecodingError {
            print("❌ Failed to decode past sessions response: \(decodingError)")
            throw SessionError.decodingError
        } catch {
            print("❌ Network error fetching past sessions: \(error)")
            throw SessionError.networkError
        }
    }

    /// Converts sessions to display items for UI
    func convertToDisplayItems(_ sessions: [SessionItem]) -> [SessionDisplayItem] {
        return sessions.map { SessionDisplayItem(from: $0) }
    }
}

// MARK: - Error Types

enum SessionError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case serverError
    case networkError
    case sessionNotFound

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
        case .sessionNotFound:
            return "Session not found"
        }
    }
}
