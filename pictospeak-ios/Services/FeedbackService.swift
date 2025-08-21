//
//  FeedbackService.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation
import UIKit

class FeedbackService {
    private let baseURL = "http://127.0.0.1:8000" // Local FastAPI server - use 127.0.0.1 for simulator

    // MARK: - Singleton

    static let shared = FeedbackService()
    private init() {}

    // MARK: - Helper Methods

    private func generateRandomBearerToken() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let tokenLength = 32
        let randomString = String((0 ..< tokenLength).map { _ in characters.randomElement()! })
        return "Bearer \(randomString)"
    }

    // MARK: - Public Methods

    func getFeedbackForImage(image: UIImage, audioData: Data) async throws -> FeedbackResponse {
        // Call actual FastAPI endpoint
        return try await callImageAPI(image: image, audioData: audioData)
    }

    // New streaming method that emits updates as they arrive
    func getFeedbackStreamForImage(image: UIImage, audioData: Data) -> AsyncThrowingStream<FeedbackResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await streamImageAPI(image: image, audioData: audioData) { feedbackResponse in
                        continuation.yield(feedbackResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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

    private func callImageAPI(image: UIImage, audioData: Data) async throws -> FeedbackResponse {
        // Use the streaming API but only return the last result
        var lastResponse: FeedbackResponse?

        for try await response in getFeedbackStreamForImage(image: image, audioData: audioData) {
            lastResponse = response
        }

        guard let finalResponse = lastResponse else {
            throw FeedbackError.serverError
        }

        return finalResponse
    }

    private func streamImageAPI(image: UIImage, audioData: Data, onUpdate: @escaping (FeedbackResponse) -> Void) async throws {
        guard let url = URL(string: baseURL + "/description/guidance/image") else {
            throw FeedbackError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // Add Authorization header with random Bearer token
        urlRequest.setValue(generateRandomBearerToken(), forHTTPHeaderField: "Authorization")

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FeedbackError.encodingError
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add audio data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body

        print("🌐 Making request to FastAPI endpoint: \(url)")
        print("📦 Request body size: \(body.count) bytes")

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FeedbackError.serverError
            }

            print("📡 Response status: \(httpResponse.statusCode)")
            print("📡 Response headers: \(httpResponse.allHeaderFields)")

            guard httpResponse.statusCode == 200 else {
                throw FeedbackError.serverError
            }

            var chunkCount = 0
            var buffer = Data()

            print("🚀 Starting real-time streaming - processing object by object...")

            // Process streaming response object by object
            for try await byte in bytes {
                buffer.append(byte)

                // Try to extract complete JSON objects from buffer using bracket matching
                if let bufferString = String(data: buffer, encoding: .utf8) {
                    var startIndex = 0

                    while startIndex < bufferString.count {
                        // Find the start of a JSON object
                        if let jsonStart = bufferString.firstIndex(of: "{") {
                            let searchStart = bufferString.index(jsonStart, offsetBy: 0)

                            // Use bracket counting to find complete JSON object
                            var bracketCount = 0
                            var inString = false
                            var escapeNext = false
                            var jsonEnd: String.Index?

                            for (index, char) in bufferString[searchStart...].enumerated() {
                                let currentIndex = bufferString.index(searchStart, offsetBy: index)

                                if escapeNext {
                                    escapeNext = false
                                    continue
                                }

                                if char == "\\" {
                                    escapeNext = true
                                    continue
                                }

                                if char == "\"" {
                                    inString.toggle()
                                    continue
                                }

                                if !inString {
                                    if char == "{" {
                                        bracketCount += 1
                                    } else if char == "}" {
                                        bracketCount -= 1
                                        if bracketCount == 0 {
                                            jsonEnd = bufferString.index(after: currentIndex)
                                            break
                                        }
                                    }
                                }
                            }

                            // If we found a complete JSON object
                            if let jsonEnd = jsonEnd {
                                let jsonString = String(bufferString[jsonStart ..< jsonEnd])

                                // Validate it's proper JSON and parse it
                                if let jsonData = jsonString.data(using: .utf8) {
                                    do {
                                        // Try to decode as StreamingFeedbackResponse
                                        let streamingResponse = try JSONDecoder().decode(StreamingFeedbackResponse.self, from: jsonData)
                                        chunkCount += 1
                                        print("📦 Streamed Object \(chunkCount): \(jsonString)")

                                        // Convert to FeedbackResponse and emit update
                                        let feedbackResponse = streamingResponse.toFeedbackResponse()
                                        onUpdate(feedbackResponse)

                                        // Remove processed JSON from buffer
                                        let remainingString = String(bufferString[jsonEnd...])
                                        buffer = remainingString.data(using: .utf8) ?? Data()
                                        break
                                    } catch {
                                        print("⚠️ Failed to decode JSON as StreamingFeedbackResponse: \(error)")
                                        // Try basic JSON validation
                                        do {
                                            let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                                            print("📦 Valid JSON but not expected format: \(jsonString)")
                                        } catch {
                                            print("❌ Invalid JSON: \(error)")
                                        }
                                        break
                                    }
                                }
                            } else {
                                // Incomplete JSON object, wait for more data
                                break
                            }
                        } else {
                            // No JSON start found, clear buffer of any junk
                            buffer = Data()
                            break
                        }
                    }
                }
            }

            // Handle any remaining data in buffer
            if !buffer.isEmpty, let finalString = String(data: buffer, encoding: .utf8) {
                let trimmed = finalString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if let jsonData = trimmed.data(using: .utf8) {
                        do {
                            let streamingResponse = try JSONDecoder().decode(StreamingFeedbackResponse.self, from: jsonData)
                            chunkCount += 1
                            print("📦 Final Object \(chunkCount): \(trimmed)")

                            let feedbackResponse = streamingResponse.toFeedbackResponse()
                            onUpdate(feedbackResponse)
                        } catch {
                            print("⚠️ Failed to decode final JSON: \(error)")
                        }
                    }
                }
            }

            print("✅ Streaming complete. Total objects received: \(chunkCount)")

        } catch {
            print("❌ Network error: \(error)")
            throw FeedbackError.networkError
        }
    }

    private func callAPI<T: Codable>(endpoint: String, request: T) async throws -> FeedbackResponse {
        guard let url = URL(string: baseURL + endpoint) else {
            throw FeedbackError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // Add Authorization header with random Bearer token
        urlRequest.setValue(generateRandomBearerToken(), forHTTPHeaderField: "Authorization")
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
                term: "There is",
                refinement: "There's",
                translation: "There is",
                reason: "\"There's\" is a common contraction in spoken English, making the sentence sound more natural."
            ),
            Suggestion(
                term: "He is",
                refinement: "He's",
                translation: "He is",
                reason: "\"He's\" is a natural contraction that makes the speech flow better."
            ),
            Suggestion(
                term: "a little wet or something",
                refinement: "slightly wet",
                translation: "a little wet or something",
                reason: "\"Slightly wet\" is more precise and fits naturally in the context."
            ),
        ]

        let keyTerms = [
            KeyTerm(
                term: "happily chasing",
                translation: "To pursue something with joy and enthusiasm - common phrase to describe playful behavior",
                example: "The dog is happily chasing the ball."
            ),
            KeyTerm(
                term: "looking ahead",
                translation: "To focus on what's in front or plan for the future - describes forward-focused attention",
                example: "The dog is looking ahead to the ball."
            ),
            KeyTerm(
                term: "droplets scattering",
                translation: "Small drops of liquid being dispersed in different directions - vivid description of water movement",
                example: "The droplets are scattering around the dog."
            ),
        ]

        return FeedbackResponse(
            originalText: originalText,
            refinedText: refinedText,
            suggestions: suggestions,
            keyTerms: keyTerms,
            chosenItemsGenerated: true
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
