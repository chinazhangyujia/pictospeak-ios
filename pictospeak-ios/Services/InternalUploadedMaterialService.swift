//
//  InternalUploadedMaterialService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

// MARK: - API Response Model

struct InternalUploadedMaterialsResponse: Codable {
    let items: [Material]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

class InternalUploadedMaterialService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = InternalUploadedMaterialService()
    private init() {}

    /// Fetches internal uploaded materials with pagination support
    /// - Parameter cursor: Optional cursor for pagination. Pass nil for the first page.
    /// - Returns: InternalUploadedMaterialsResponse containing materials and next cursor
    func fetchInternalUploadedMaterials(authToken: String, cursor: String? = nil) async throws -> InternalUploadedMaterialsResponse {
        var urlComponents = URLComponents(string: baseURL + "/material/internal-uploaded")!

        // Add cursor as query parameters if provided
        if let cursor = cursor {
            urlComponents.queryItems = Utils.parseCursorString(cursor)
        }

        guard let url = urlComponents.url else {
            throw InternalUploadedMaterialError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("🌐 Making request to internal uploaded materials endpoint: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw InternalUploadedMaterialError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Internal uploaded materials API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw InternalUploadedMaterialError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let response = try decoder.decode(InternalUploadedMaterialsResponse.self, from: data)

                if let nextCursor = response.nextCursor {
                    print("📄 Next page cursor: \(nextCursor)")
                } else {
                    print("📄 No more pages available")
                }

                print("✅ Successfully fetched internal uploaded materials")
                return response

            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw InternalUploadedMaterialError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw InternalUploadedMaterialError.networkError
        } catch {
            print("❌ Unexpected error: \(error)")
            throw InternalUploadedMaterialError.unknownError
        }
    }
}

// MARK: - Error Types

enum InternalUploadedMaterialError: Error, LocalizedError {
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
