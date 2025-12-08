//
//  SessionService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

class SessionService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = SessionService()
    private init() {}

    func getSessionById(authToken: String, sessionId: String) async throws -> SessionItem {
        guard let url = URL(string: baseURL + "/description/guidance/\(sessionId)") else {
            throw SessionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("🌐 Making request to session detail endpoint: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw SessionError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Session detail API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                if httpResponse.statusCode == 404 {
                    throw SessionError.sessionNotFound
                }
                throw SessionError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let sessionItem = try decoder.decode(SessionItem.self, from: data)
                print("✅ Successfully decoded session for ID: \(sessionId)")
                return sessionItem
            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw SessionError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw SessionError.networkError
        } catch let decodingError as DecodingError {
            print("❌ Failed to decode session response: \(decodingError)")
            throw SessionError.decodingError
        } catch {
            print("❌ Unexpected error fetching session: \(error)")
            print("❌ Error type: \(type(of: error))")
            throw SessionError.networkError
        }
    }

    /// Fetches past sessions with pagination support
    /// - Parameter cursor: Optional cursor for pagination. Pass nil for the first page.
    /// - Returns: PaginatedSessionResponse containing sessions and next cursor
    func getPastSessions(authToken: String, cursor: String? = nil) async throws -> PaginatedSessionResponse {
        var urlComponents = URLComponents(string: baseURL + "/description/guidance/list")!

        // Add cursor as query parameters if provided
        if let cursor = cursor {
            urlComponents.queryItems = Utils.parseCursorString(cursor)
        }

        guard let url = urlComponents.url else {
            throw SessionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30 // Add timeout

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("🌐 Making request to past sessions endpoint: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw SessionError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Past sessions API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw SessionError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let paginatedResponse = try decoder.decode(PaginatedSessionResponse.self, from: data)

                print("📄 Paginated response: \(paginatedResponse)")

                if let nextCursor = paginatedResponse.nextCursor {
                    print("📄 Next page cursor: \(nextCursor)")
                } else {
                    print("📄 No more pages available")
                }

                return paginatedResponse
            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw SessionError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw SessionError.networkError
        } catch let decodingError as DecodingError {
            print("❌ Failed to decode past sessions response: \(decodingError)")
            throw SessionError.decodingError
        } catch {
            print("❌ Unexpected error fetching past sessions: \(error)")
            print("❌ Error type: \(type(of: error))")
            throw SessionError.networkError
        }
    }

    /// Deletes a session (description guidance) by ID
    func deleteSession(authToken: String, sessionId: String) async throws {
        guard let url = URL(string: baseURL + "/description/guidance/\(sessionId)") else {
            throw SessionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.timeoutInterval = 30

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("🌐 Making DELETE request to session endpoint: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw SessionError.serverError
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                print("❌ Session deletion API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                if httpResponse.statusCode == 404 {
                    throw SessionError.sessionNotFound
                }
                throw SessionError.serverError
            }

            print("✅ Successfully deleted session ID: \(sessionId)")

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw SessionError.networkError
        } catch {
            print("❌ Unexpected error deleting session: \(error)")
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
            return NSLocalizedString("error.invalidURL", comment: "")
        case .encodingError:
            return NSLocalizedString("error.encoding", comment: "")
        case .decodingError:
            return NSLocalizedString("error.decoding", comment: "")
        case .serverError:
            return NSLocalizedString("error.server", comment: "")
        case .networkError:
            return NSLocalizedString("error.network", comment: "")
        case .sessionNotFound:
            return NSLocalizedString("error.session.notFound", comment: "")
        }
    }
}
