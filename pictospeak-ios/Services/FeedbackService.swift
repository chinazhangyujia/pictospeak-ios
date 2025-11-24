//
//  FeedbackService.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVFoundation
import Foundation
import UIKit

class FeedbackService {
    private let baseURL = APIConfiguration.baseURL
    private struct MultipartFormPart {
        let name: String
        let filename: String?
        let contentType: String?
        let data: Data
    }

    // MARK: - Singleton

    static let shared = FeedbackService()
    private init() {}

    // MARK: - Helper Methods

    // New streaming method that emits updates as they arrive
    func getFeedbackStreamForImage(authToken: String, image: UIImage, audioData: Data) -> AsyncThrowingStream<FeedbackResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await streamImageAPI(authToken: authToken, image: image, audioData: audioData) { feedbackResponse in
                        continuation.yield(feedbackResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func getFeedbackStreamForVideo(authToken: String, videoData: Data, videoFileExtension: String?, audioData: Data) -> AsyncThrowingStream<FeedbackResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Create temp file for video data to generate frames
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempVideoURL = tempDir.appendingPathComponent("temp_video_frames_\(UUID().uuidString).\(videoFileExtension ?? "mp4")")
                    try videoData.write(to: tempVideoURL)

                    let frames = await self.generateFrames(from: tempVideoURL)

                    // Cleanup temp file
                    try? FileManager.default.removeItem(at: tempVideoURL)

                    try await streamVideoAPI(
                        authToken: authToken,
                        videoData: videoData,
                        videoFileExtension: videoFileExtension,
                        frames: frames,
                        audioData: audioData
                    ) { feedbackResponse in
                        continuation.yield(feedbackResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func generateFrames(from videoURL: URL, count: Int = 5) async -> [Data] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var frames: [Data] = []

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Calculate evenly distributed timestamps (taking the middle of each segment)
            let interval = durationSeconds / Double(count)

            for i in 0 ..< count {
                let timeSeconds = Double(i) * interval + (interval / 2)
                let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

                // Use the async image generation API if available (iOS 16+), or wrapper for older
                if #available(iOS 16.0, *) {
                    let (image, _) = try await generator.image(at: time)
                    if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.7) {
                        frames.append(data)
                    }
                } else {
                    // Fallback for older iOS versions
                    let image = try generator.copyCGImage(at: time, actualTime: nil)
                    if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.7) {
                        frames.append(data)
                    }
                }
            }
        } catch {
            print("Error generating frames: \(error)")
        }

        return frames
    }

    private func streamImageAPI(authToken: String, image: UIImage, audioData: Data, onUpdate: @escaping (FeedbackResponse) -> Void) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FeedbackError.encodingError
        }

        let parts = [
            MultipartFormPart(name: "image", filename: "image.jpg", contentType: "image/jpeg", data: imageData),
            MultipartFormPart(name: "audio", filename: "audio.wav", contentType: "audio/wav", data: audioData),
        ]

        try await streamFeedbackAPI(
            authToken: authToken,
            endpoint: "/description/guidance/image",
            parts: parts,
            onUpdate: onUpdate
        )
    }

    private func streamVideoAPI(
        authToken: String,
        videoData: Data,
        videoFileExtension: String?,
        frames: [Data],
        audioData: Data,
        onUpdate: @escaping (FeedbackResponse) -> Void
    ) async throws {
        let normalizedExtension = videoFileExtension?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let fileExtension = (normalizedExtension?.isEmpty == false) ? normalizedExtension! : "mp4"
        let filename = "video.\(fileExtension)"
        let mimeType = mimeTypeForVideoExtension(fileExtension)

        var parts = [
            MultipartFormPart(name: "video", filename: filename, contentType: mimeType, data: videoData),
            MultipartFormPart(name: "audio", filename: "audio.wav", contentType: "audio/wav", data: audioData),
        ]

        for (index, frameData) in frames.enumerated() {
            parts.append(MultipartFormPart(name: "frames", filename: "frame_\(index).jpg", contentType: "image/jpeg", data: frameData))
        }

        try await streamFeedbackAPI(
            authToken: authToken,
            endpoint: "/description/guidance/video",
            parts: parts,
            onUpdate: onUpdate
        )
    }

    private func mimeTypeForVideoExtension(_ fileExtension: String) -> String {
        let normalizedExtension = fileExtension.lowercased()
        guard normalizedExtension == "mp4" else {
            return "video/mp4"
        }
        return "video/mp4"
    }

    private func streamFeedbackAPI(
        authToken: String,
        endpoint: String,
        parts: [MultipartFormPart],
        onUpdate: @escaping (FeedbackResponse) -> Void
    ) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw FeedbackError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        for part in parts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)

            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append("\(disposition)\r\n".data(using: .utf8)!)

            if let contentType = part.contentType {
                body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
            } else {
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append(part.data)
            body.append("\r\n".data(using: .utf8)!)
        }

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

    // MARK: - Mock Data

    private func createMockFeedbackResponse() -> FeedbackResponse {
        let originalText = "There is a dog happily chasing a ball on the ground. He is looking ahead as he runs over the a little wet or something grass, with droplets scattering around him."
        let refinedText = "There's a dog happily chasing a ball on the ground. He's looking ahead as he runs over the slightly wet grass, with droplets scattering around him."

        let suggestions = [
            Suggestion(
                term: "There is",
                refinement: "There's",
                translation: "There is",
                reason: "\"There's\" is a common contraction in spoken English, making the sentence sound more natural.",
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            Suggestion(
                term: "He is",
                refinement: "He's",
                translation: "He is",
                reason: "\"He's\" is a natural contraction that makes the speech flow better.",
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            Suggestion(
                term: "a little wet or something",
                refinement: "slightly wet",
                translation: "a little wet or something",
                reason: "\"Slightly wet\" is more precise and fits naturally in the context.",
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
        ]

        let keyTerms = [
            KeyTerm(
                term: "happily chasing",
                translation: "To pursue something with joy and enthusiasm - common phrase to describe playful behavior",
                example: "The dog is happily chasing the ball.",
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            KeyTerm(
                term: "looking ahead",
                translation: "To focus on what's in front or plan for the future - describes forward-focused attention",
                example: "The dog is looking ahead to the ball.",
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            KeyTerm(
                term: "droplets scattering",
                translation: "Small drops of liquid being dispersed in different directions - vivid description of water movement",
                example: "The droplets are scattering around the dog.",
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
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
