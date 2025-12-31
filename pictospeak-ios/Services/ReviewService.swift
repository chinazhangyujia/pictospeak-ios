//
//  ReviewService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

class ReviewService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = ReviewService()
    private init() {}

    /// Fetches review items with pagination support
    /// - Parameters:
    ///   - authToken: Authentication token for the request
    ///   - cursor: Optional cursor for pagination. Pass nil for the first page.
    /// - Returns: ListReviewItemsResponse containing review items and next cursor
    func getReviewItems(authToken: String, cursor: String? = nil) async throws -> ListReviewItemsResponse {
        var urlComponents = URLComponents(string: baseURL + "/key-term-and-suggestion/review/favorite")!

        // Add cursor as query parameters if provided
        if let cursor = cursor {
            urlComponents.queryItems = Utils.parseCursorString(cursor)
        }

        guard let url = urlComponents.url else {
            throw ReviewError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30 // Add timeout

        // Add Authorization header with Bearer token
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        print("🌐 Making request to review items endpoint: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw ReviewError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Review items API error: \(httpResponse.statusCode)")
                // Try to read error response body
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw ReviewError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let reviewResponse = try decoder.decode(ListReviewItemsResponse.self, from: data)

                if let nextCursor = reviewResponse.nextCursor {
                    print("📄 Next page cursor: \(nextCursor)")
                } else {
                    print("📄 No more pages available")
                }

                return reviewResponse
            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                throw ReviewError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            print("❌ URL Error code: \(urlError.code.rawValue)")
            throw ReviewError.networkError
        } catch let decodingError as DecodingError {
            print("❌ Failed to decode review items response: \(decodingError)")
            throw ReviewError.decodingError
        } catch {
            print("❌ Unexpected error fetching review items: \(error)")
            print("❌ Error type: \(type(of: error))")
            throw ReviewError.networkError
        }
    }
}

// MARK: - Error Types

enum ReviewError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case serverError
    case networkError
    case reviewItemNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error.invalidURL", comment: "Invalid URL")
        case .encodingError:
            return NSLocalizedString("error.encoding", comment: "Encoding error")
        case .decodingError:
            return NSLocalizedString("error.decoding", comment: "Decoding error")
        case .serverError:
            return NSLocalizedString("error.server", comment: "Server error")
        case .networkError:
            return NSLocalizedString("error.network", comment: "Network error")
        case .reviewItemNotFound:
            return NSLocalizedString("error.review.itemNotFound", comment: "Item not found")
        }
    }
}
