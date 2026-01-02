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
    func getFeedbackStreamForImage(authToken: String, image: UIImage, audioData: Data?) -> AsyncThrowingStream<FeedbackResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Compress audio if present
                    var finalAudioData = audioData
                    if let audio = audioData {
                        print("🎵 Original audio size: \(ByteCountFormatter.string(fromByteCount: Int64(audio.count), countStyle: .file))")
                        finalAudioData = try? await self.compressAudio(data: audio)
                        if let compressed = finalAudioData {
                            let ratio = Double(audio.count) / Double(compressed.count)
                            print("🎵 Compressed audio size: \(ByteCountFormatter.string(fromByteCount: Int64(compressed.count), countStyle: .file)) (Ratio: \(String(format: "%.1f", ratio))x)")
                        }
                    }

                    try await streamImageAPI(authToken: authToken, image: image, audioData: finalAudioData) { feedbackResponse in
                        continuation.yield(feedbackResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func getFeedbackStreamForVideo(authToken: String, videoData: Data, videoFileExtension: String?, audioData: Data?) -> AsyncThrowingStream<FeedbackResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    print("📹 Original video size: \(ByteCountFormatter.string(fromByteCount: Int64(videoData.count), countStyle: .file))")

                    // Create temp file for original video data
                    let tempDir = FileManager.default.temporaryDirectory
                    let originalFilename = "temp_video_original_\(UUID().uuidString).\(videoFileExtension ?? "mp4")"
                    let tempOriginalURL = tempDir.appendingPathComponent(originalFilename)
                    try videoData.write(to: tempOriginalURL)

                    // Compress Video
                    let compressedVideoURL = try await self.compressVideo(inputURL: tempOriginalURL)
                    let compressedVideoData = try Data(contentsOf: compressedVideoURL)

                    let videoRatio = Double(videoData.count) / Double(compressedVideoData.count)
                    print("📹 Compressed video size: \(ByteCountFormatter.string(fromByteCount: Int64(compressedVideoData.count), countStyle: .file)) (Ratio: \(String(format: "%.1f", videoRatio))x)")

                    // Generate Frames from Compressed Video (efficient)
                    let frames = await self.generateFrames(from: compressedVideoURL)

                    // Compress Audio if present
                    var finalAudioData = audioData
                    if let audio = audioData {
                        print("🎵 Original audio size: \(ByteCountFormatter.string(fromByteCount: Int64(audio.count), countStyle: .file))")
                        finalAudioData = try? await self.compressAudio(data: audio)
                        if let compressed = finalAudioData {
                            let ratio = Double(audio.count) / Double(compressed.count)
                            print("🎵 Compressed audio size: \(ByteCountFormatter.string(fromByteCount: Int64(compressed.count), countStyle: .file)) (Ratio: \(String(format: "%.1f", ratio))x)")
                        }
                    }

                    // Cleanup temp files
                    try? FileManager.default.removeItem(at: tempOriginalURL)
                    try? FileManager.default.removeItem(at: compressedVideoURL)

                    try await streamVideoAPI(
                        authToken: authToken,
                        videoData: compressedVideoData,
                        videoFileExtension: "mp4", // Compressed output is always mp4
                        frames: frames,
                        audioData: finalAudioData
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

    func getTeachSingleTermStream(authToken: String, descriptionGuidanceId: UUID, term: String) -> AsyncThrowingStream<KeyTermTeachingStreamingResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard var components = URLComponents(string: self.baseURL + "/key-term-and-suggestion/teach-single-term") else {
                        throw FeedbackError.invalidURL
                    }

                    components.queryItems = [
                        URLQueryItem(name: "description_guidance_id", value: descriptionGuidanceId.uuidString),
                        URLQueryItem(name: "term", value: term),
                    ]

                    guard let url = components.url else {
                        throw FeedbackError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

                    print("🌐 Making request to FastAPI endpoint: \(url)")

                    try await self.performStreamingRequest(request: request) { (response: KeyTermTeachingStreamingResponse) in
                        continuation.yield(response)
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

        // Limit frame size to reducing upload size
        generator.maximumSize = CGSize(width: 512, height: 512)

        var frames: [Data] = []

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Calculate evenly distributed timestamps (taking the middle of each segment)
            let interval = durationSeconds / Double(count)

            for i in 0 ..< count {
                let timeSeconds = Double(i) * interval + (interval / 2)
                let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

                let (image, _) = try await generator.image(at: time)
                // High compression for frames as they are just context
                if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.5) {
                    frames.append(data)
                }
            }
        } catch {
            print("Error generating frames: \(error)")
        }

        return frames
    }

    private func streamImageAPI(authToken: String, image: UIImage, audioData: Data?, onUpdate: @escaping (FeedbackResponse) -> Void) async throws {
        // 1. Resize Image
        let originalSize = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        print("🖼️ Original image size (est. full quality): \(ByteCountFormatter.string(fromByteCount: Int64(originalSize), countStyle: .file))")

        let resizedImage = resizeImage(image: image, targetSize: CGSize(width: 1024, height: 1024))

        // 2. Compress Image (0.6 is usually good balance)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw FeedbackError.encodingError
        }

        if originalSize > 0 {
            let ratio = Double(originalSize) / Double(imageData.count)
            print("🖼️ Compressed image size: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)) (Ratio: \(String(format: "%.1f", ratio))x)")
        }

        var parts = [
            MultipartFormPart(name: "image", filename: "image.jpg", contentType: "image/jpeg", data: imageData),
        ]

        if let audioData = audioData {
            // Check if it's likely M4A (starts with ftypM4A usually, or based on our compression)
            // For now assuming the compression helper returns m4a or original wav
            let isM4A = audioData.count < 1_000_000 // Simple heuristic or rely on our compressAudio
            let ext = "m4a" // We are aggressively converting to m4a
            let type = "audio/mp4"
            parts.append(MultipartFormPart(name: "audio", filename: "audio.\(ext)", contentType: type, data: audioData))
        }

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
        audioData: Data?,
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
        ]

        if let audioData = audioData {
            parts.append(MultipartFormPart(name: "audio", filename: "audio.m4a", contentType: "audio/mp4", data: audioData))
        }

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

        try await performStreamingRequest(request: urlRequest) { (streamingResponse: StreamingFeedbackResponse) in
            onUpdate(streamingResponse.toFeedbackResponse())
        }
    }

    private func performStreamingRequest<T: Decodable>(
        request: URLRequest,
        onUpdate: @escaping (T) -> Void
    ) async throws {
        let startTime = Date()
        print("⏱️ Start time: \(startTime)")

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            let endTime = Date()
            let latency = endTime.timeIntervalSince(startTime)
            print("⏱️ Latency (headers received): \(String(format: "%.3f", latency)) seconds")

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
            var bracketCount = 0
            var inString = false
            var isEscaped = false

            // Byte constants for performance
            let braceOpen = UInt8(ascii: "{")
            let braceClose = UInt8(ascii: "}")
            let quote = UInt8(ascii: "\"")
            let backslash = UInt8(ascii: "\\")

            for try await byte in bytes {
                // If we haven't started an object yet, we look for the opening brace
                if bracketCount == 0 {
                    if byte == braceOpen {
                        bracketCount = 1
                        buffer.append(byte)
                    }
                    // Ignore whitespace/garbage between objects
                    continue
                }

                // We are inside an object
                buffer.append(byte)

                if isEscaped {
                    isEscaped = false
                    continue
                }

                if byte == backslash {
                    isEscaped = true
                    continue
                }

                if byte == quote {
                    inString.toggle()
                    continue
                }

                if !inString {
                    if byte == braceOpen {
                        bracketCount += 1
                    } else if byte == braceClose {
                        bracketCount -= 1

                        // If we closed the outermost bracket, we have a complete object candidate
                        if bracketCount == 0 {
                            // Try to decode this chunk
                            do {
                                let decodedObject = try JSONDecoder().decode(T.self, from: buffer)
                                chunkCount += 1

                                onUpdate(decodedObject)
                            } catch {
                                print("⚠️ Failed to decode JSON chunk: \(error)")
                                if let jsonString = String(data: buffer, encoding: .utf8) {
                                    print("📦 Invalid JSON content: \(jsonString)")
                                }
                            }
                            // Clear buffer for next object
                            buffer.removeAll(keepingCapacity: true)
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
                            let decodedObject = try JSONDecoder().decode(T.self, from: jsonData)
                            chunkCount += 1
                            print("📦 Final Object \(chunkCount): \(trimmed)")

                            onUpdate(decodedObject)
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

    // MARK: - Compression Helpers

    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? image
    }

    private func compressVideo(inputURL: URL) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("compressed_video_\(UUID().uuidString).mp4")

        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw FeedbackError.encodingError
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            print("Video compression failed: \(String(describing: exportSession.error))")
            throw exportSession.error ?? FeedbackError.encodingError
        }
    }

    private func compressAudio(data: Data) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("temp_audio_in_\(UUID().uuidString).wav")
        let outputURL = tempDir.appendingPathComponent("temp_audio_out_\(UUID().uuidString).m4a")

        do {
            try data.write(to: inputURL)

            let asset = AVAsset(url: inputURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                // Fallback to original data if session creation fails
                try? FileManager.default.removeItem(at: inputURL)
                return data
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a

            await exportSession.export()

            if exportSession.status == .completed {
                let compressedData = try Data(contentsOf: outputURL)
                // Cleanup
                try? FileManager.default.removeItem(at: inputURL)
                try? FileManager.default.removeItem(at: outputURL)
                return compressedData
            } else {
                print("Audio compression failed: \(String(describing: exportSession.error))")
                // Cleanup and fallback
                try? FileManager.default.removeItem(at: inputURL)
                return data
            }
        } catch {
            print("Audio compression error: \(error)")
            return data
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
                translations: [TermTranslation(pos: "phrase", translation: "There is")],
                reason: TermReason(reason: "\"There's\" is a common contraction in spoken English, making the sentence sound more natural.", reasonTranslation: "\"There's\"是口语中常见的缩写，使句子听起来更自然。"),
                example: TermExample(sentence: "There's a book on the table.", sentenceTranslation: "桌子上有一本书。"),
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            Suggestion(
                term: "He is",
                refinement: "He's",
                translations: [TermTranslation(pos: "phrase", translation: "He is")],
                reason: TermReason(reason: "\"He's\" is a natural contraction that makes the speech flow better.", reasonTranslation: "\"He's\"是一个自然的缩写，使语音更流畅。"),
                example: TermExample(sentence: "He's running fast.", sentenceTranslation: "他跑得很快。"),
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            Suggestion(
                term: "a little wet or something",
                refinement: "slightly wet",
                translations: [TermTranslation(pos: "phrase", translation: "slightly wet")],
                reason: TermReason(reason: "\"Slightly wet\" is more precise and fits naturally in the context.", reasonTranslation: "\"Slightly wet\"更精确，自然地适应上下文。"),
                example: TermExample(sentence: "The grass was slightly wet after the rain.", sentenceTranslation: "雨后草地有点湿。"),
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
        ]

        let keyTerms = [
            KeyTerm(
                term: "happily chasing",
                translations: [TermTranslation(pos: "phrase", translation: "To pursue something with joy and enthusiasm")],
                reason: TermReason(reason: "Common phrase to describe playful behavior", reasonTranslation: "描述顽皮行为的常用短语"),
                example: TermExample(sentence: "The dog is happily chasing the ball.", sentenceTranslation: "狗快乐地追逐着球。"),
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            KeyTerm(
                term: "looking ahead",
                translations: [TermTranslation(pos: "phrase", translation: "To focus on what's in front or plan for the future")],
                reason: TermReason(reason: "Describes forward-focused attention", reasonTranslation: "描述向前集中的注意力"),
                example: TermExample(sentence: "The dog is looking ahead to the ball.", sentenceTranslation: "狗正看着前方的球。"),
                favorite: false,
                id: UUID(),
                descriptionGuidanceId: nil
            ),
            KeyTerm(
                term: "droplets scattering",
                translations: [TermTranslation(pos: "phrase", translation: "Small drops of liquid being dispersed in different directions")],
                reason: TermReason(reason: "Vivid description of water movement", reasonTranslation: "生动地描述水的运动"),
                example: TermExample(sentence: "The droplets are scattering around the dog.", sentenceTranslation: "水滴在狗周围散开。"),
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
            return NSLocalizedString("error.invalidURL", comment: "")
        case .encodingError:
            return NSLocalizedString("error.encoding", comment: "")
        case .decodingError:
            return NSLocalizedString("error.decoding", comment: "")
        case .serverError:
            return NSLocalizedString("error.server", comment: "")
        case .networkError:
            return NSLocalizedString("error.network", comment: "")
        }
    }
}
