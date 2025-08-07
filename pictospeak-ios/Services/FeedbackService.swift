//
//  FeedbackService.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation
import UIKit

class FeedbackService {
    private let baseURL = "https://api.pictospeak.com" // Replace with your actual API base URL

    // MARK: - Singleton

    static let shared = FeedbackService()
    private init() {}

    // MARK: - Public Methods

    func getFeedbackForImage(image _: UIImage, audioData _: Data) async throws -> FeedbackResponse {
        // TODO: Implement actual API call
        // let request = FeedbackRequest(imageData: image.jpegData(compressionQuality: 0.8),
        //                              videoData: nil,
        //                              audioData: audioData,
        //                              mediaType: .image)
        // return try await callAPI(endpoint: "/description/guidance/image", request: request)

        // Mock response for now
        return createMockFeedbackResponse()
    }

    func getFeedbackForVideo(videoURL _: URL, audioData _: Data) async throws -> FeedbackResponse {
        // TODO: Implement actual API call
        // let videoData = try Data(contentsOf: videoURL)
        // let request = FeedbackRequest(imageData: nil,
        //                              videoData: videoData,
        //                              audioData: audioData,
        //                              mediaType: .video)
        // return try await callAPI(endpoint: "/description/guidance/video", request: request)

        // Mock response for now
        return createMockFeedbackResponse()
    }

    // MARK: - Private Methods

    private func callAPI<T: Codable>(endpoint: String, request: T) async throws -> FeedbackResponse {
        guard let url = URL(string: baseURL + endpoint) else {
            throw FeedbackError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw FeedbackError.encodingError
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw FeedbackError.serverError
        }

        do {
            return try JSONDecoder().decode(FeedbackResponse.self, from: data)
        } catch {
            throw FeedbackError.decodingError
        }
    }

    // MARK: - Mock Data

    private func createMockFeedbackResponse() -> FeedbackResponse {
        let originalText = "There is a dog happily chasing a ball on the ground. He is looking ahead as he runs over the a little wet or something grass, with droplets scattering around him."
        let refinedText = "There's a dog happily chasing a ball on the ground. He's looking ahead as he runs over the slightly wet grass, with droplets scattering around him."

        let suggestions = [
            Suggestion(
                expression: "There is",
                refinement: "There's",
                reason: "\"There's\" is a common contraction in spoken English, making the sentence sound more natural."
            ),
            Suggestion(
                expression: "He is",
                refinement: "He's",
                reason: "\"He's\" is a natural contraction that makes the speech flow better."
            ),
            Suggestion(
                expression: "a little wet or something",
                refinement: "slightly wet",
                reason: "\"Slightly wet\" is more precise and fits naturally in the context."
            ),
        ]

        let keyExpressions = [
            KeyExpression(
                expression: "happily chasing",
                explanation: "To pursue something with joy and enthusiasm - common phrase to describe playful behavior"
            ),
            KeyExpression(
                expression: "looking ahead",
                explanation: "To focus on what's in front or plan for the future - describes forward-focused attention"
            ),
            KeyExpression(
                expression: "droplets scattering",
                explanation: "Small drops of liquid being dispersed in different directions - vivid description of water movement"
            ),
        ]

        return FeedbackResponse(
            originalText: originalText,
            refinedText: refinedText,
            suggestions: suggestions,
            keyExpressions: keyExpressions
        )
    }
}

// MARK: - Error Types

enum FeedbackError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case serverError
    case networkError

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
        }
    }
}
