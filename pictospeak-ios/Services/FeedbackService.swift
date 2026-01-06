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
    // MARK: - Properties

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

    // MARK: - Public API

    /// Streams feedback for an image-based description
    func getFeedbackStreamForImage(
        authToken: String,
        image: UIImage?,
        materialId: UUID?,
        audioData: Data?
    ) -> AsyncThrowingStream<FeedbackStreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.status(.uploadingMedia))

                    let compressedAudio = try await compressAudioIfNeeded(audioData)

                    try await streamImageAPI(
                        authToken: authToken,
                        image: image,
                        materialId: materialId,
                        audioData: compressedAudio
                    ) { event in
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Streams feedback for a video-based description
    func getFeedbackStreamForVideo(
        authToken: String,
        videoData: Data?,
        videoFileExtension: String?,
        materialId: UUID?,
        audioData: Data?
    ) -> AsyncThrowingStream<FeedbackStreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.status(.uploadingMedia))

                    let processedVideo = try await processVideoIfNeeded(videoData, fileExtension: videoFileExtension)
                    let compressedAudio = try await compressAudioIfNeeded(audioData)

                    try await streamVideoAPI(
                        authToken: authToken,
                        videoData: processedVideo.data,
                        frames: processedVideo.frames,
                        materialId: materialId,
                        audioData: compressedAudio
                    ) { event in
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Streams teaching content for a single term
    func getTeachSingleTermStream(
        authToken: String,
        descriptionGuidanceId: UUID,
        term: String
    ) -> AsyncThrowingStream<KeyTermTeachingStreamingResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard var components = URLComponents(string: baseURL + "/key-term-and-suggestion/teach-single-term") else {
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

                    print("🌐 Teaching request: \(url)")

                    try await performStreamingRequest(request: request) { (response: KeyTermTeachingStreamingResponse) in
                        continuation.yield(response)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private API Streaming

    private func streamImageAPI(
        authToken: String,
        image: UIImage?,
        materialId: UUID?,
        audioData: Data?,
        onUpdate: @escaping (FeedbackStreamEvent) -> Void
    ) async throws {
        var parts: [MultipartFormPart] = []

        // Add material_id or image (mutually exclusive)
        if let materialId = materialId {
            parts.append(createFormField(name: "material_id", value: materialId.uuidString))
        } else if let image = image {
            let imageData = try prepareImageForUpload(image)
            parts.append(MultipartFormPart(
                name: "image",
                filename: "image.jpg",
                contentType: "image/jpeg",
                data: imageData
            ))
        } else {
            throw FeedbackError.encodingError
        }

        // Add audio if present
        if let audioData = audioData {
            parts.append(MultipartFormPart(
                name: "audio",
                filename: "audio.m4a",
                contentType: "audio/mp4",
                data: audioData
            ))
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
        videoData: Data?,
        frames: [Data],
        materialId: UUID?,
        audioData: Data?,
        onUpdate: @escaping (FeedbackStreamEvent) -> Void
    ) async throws {
        var parts: [MultipartFormPart] = []

        // Add material_id or video (mutually exclusive)
        if let materialId = materialId {
            parts.append(createFormField(name: "material_id", value: materialId.uuidString))
        } else if let videoData = videoData {
            parts.append(MultipartFormPart(
                name: "video",
                filename: "video.mp4",
                contentType: "video/mp4",
                data: videoData
            ))
        }

        // Add frames (always required for video endpoint)
        for (index, frameData) in frames.enumerated() {
            parts.append(MultipartFormPart(
                name: "frames",
                filename: "frame_\(index).jpg",
                contentType: "image/jpeg",
                data: frameData
            ))
        }

        // Add audio if present
        if let audioData = audioData {
            parts.append(MultipartFormPart(
                name: "audio",
                filename: "audio.m4a",
                contentType: "audio/mp4",
                data: audioData
            ))
        }

        try await streamFeedbackAPI(
            authToken: authToken,
            endpoint: "/description/guidance/video",
            parts: parts,
            onUpdate: onUpdate
        )
    }

    private func streamFeedbackAPI(
        authToken: String,
        endpoint: String,
        parts: [MultipartFormPart],
        onUpdate: @escaping (FeedbackStreamEvent) -> Void
    ) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw FeedbackError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let body = buildMultipartBody(parts: parts, boundary: boundary)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        print("🌐 Request: \(url)")
        print("📦 Body size: \(ByteCountFormatter.string(fromByteCount: Int64(body.count), countStyle: .file))")

        try await performStreamingRequest(
            request: request,
            onUpdate: { (response: StreamingFeedbackResponse) in
                onUpdate(.response(response.toFeedbackResponse()))
            },
            onSignal: { signal in
                if let status = FeedbackStatus(rawValue: signal.status) {
                    onUpdate(.status(status))
                }
            }
        )
    }

    // MARK: - Media Processing

    private struct ProcessedVideo {
        let data: Data?
        let frames: [Data]
    }

    private func processVideoIfNeeded(_ videoData: Data?, fileExtension: String?) async throws -> ProcessedVideo {
        guard let videoData = videoData else {
            return ProcessedVideo(data: nil, frames: [])
        }

        print("📹 Original video: \(ByteCountFormatter.string(fromByteCount: Int64(videoData.count), countStyle: .file))")

        let tempDir = FileManager.default.temporaryDirectory
        let originalURL = tempDir.appendingPathComponent("temp_video_original_\(UUID().uuidString).\(fileExtension ?? "mp4")")
        try videoData.write(to: originalURL)

        defer {
            try? FileManager.default.removeItem(at: originalURL)
        }

        let compressedURL = try await compressVideo(inputURL: originalURL)
        defer {
            try? FileManager.default.removeItem(at: compressedURL)
        }

        let compressedData = try Data(contentsOf: compressedURL)
        let ratio = Double(videoData.count) / Double(compressedData.count)
        print("📹 Compressed video: \(ByteCountFormatter.string(fromByteCount: Int64(compressedData.count), countStyle: .file)) (\(String(format: "%.1fx", ratio)))")

        let frames = await generateFrames(from: compressedURL)

        return ProcessedVideo(data: compressedData, frames: frames)
    }

    private func prepareImageForUpload(_ image: UIImage) throws -> Data {
        let originalSize = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        print("🖼️  Original image: \(ByteCountFormatter.string(fromByteCount: Int64(originalSize), countStyle: .file))")

        let resized = resizeImage(image: image, targetSize: CGSize(width: 1024, height: 1024))

        guard let imageData = resized.jpegData(compressionQuality: 0.6) else {
            throw FeedbackError.encodingError
        }

        if originalSize > 0 {
            let ratio = Double(originalSize) / Double(imageData.count)
            print("🖼️  Compressed image: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)) (\(String(format: "%.1fx", ratio)))")
        }

        return imageData
    }

    private func compressAudioIfNeeded(_ audioData: Data?) async throws -> Data? {
        guard let audioData = audioData else { return nil }

        print("🎵 Original audio: \(ByteCountFormatter.string(fromByteCount: Int64(audioData.count), countStyle: .file))")

        guard let compressed = try? await compressAudio(data: audioData) else {
            return audioData
        }

        let ratio = Double(audioData.count) / Double(compressed.count)
        print("🎵 Compressed audio: \(ByteCountFormatter.string(fromByteCount: Int64(compressed.count), countStyle: .file)) (\(String(format: "%.1fx", ratio)))")

        return compressed
    }

    private func generateFrames(from videoURL: URL, count: Int = 5) async -> [Data] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 512, height: 512)

        var frames: [Data] = []

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let interval = durationSeconds / Double(count)

            for i in 0 ..< count {
                let timeSeconds = Double(i) * interval + (interval / 2)
                let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

                let (image, _) = try await generator.image(at: time)
                if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.5) {
                    frames.append(data)
                }
            }
        } catch {
            print("⚠️ Frame generation error: \(error)")
        }

        return frames
    }

    // MARK: - Compression Helpers

    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        let rect = CGRect(origin: .zero, size: newSize)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
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

        guard exportSession.status == .completed else {
            throw exportSession.error ?? FeedbackError.encodingError
        }

        return outputURL
    }

    private func compressAudio(data: Data) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("temp_audio_in_\(UUID().uuidString).wav")
        let outputURL = tempDir.appendingPathComponent("temp_audio_out_\(UUID().uuidString).m4a")

        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        try data.write(to: inputURL)

        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return data
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            return data
        }

        return try Data(contentsOf: outputURL)
    }

    // MARK: - Multipart Form Helpers

    private func createFormField(name: String, value: String) -> MultipartFormPart {
        guard let data = value.data(using: .utf8) else {
            fatalError("Failed to encode form field: \(name)")
        }
        return MultipartFormPart(name: name, filename: nil, contentType: nil, data: data)
    }

    private func buildMultipartBody(parts: [MultipartFormPart], boundary: String) -> Data {
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

        return body
    }

    // MARK: - Streaming Request Handler

    private func performStreamingRequest<T: Decodable>(
        request: URLRequest,
        onUpdate: @escaping (T) -> Void,
        onSignal: ((DescriptionGuidanceProcessingSignal) -> Void)? = nil
    ) async throws {
        let startTime = Date()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        let latency = Date().timeIntervalSince(startTime)
        print("⏱️  Latency: \(String(format: "%.3fs", latency))")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.serverError
        }

        print("📡 Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            throw FeedbackError.serverError
        }

        var chunkCount = 0
        var buffer = Data()
        var bracketCount = 0
        var inString = false
        var isEscaped = false

        let braceOpen = UInt8(ascii: "{")
        let braceClose = UInt8(ascii: "}")
        let quote = UInt8(ascii: "\"")
        let backslash = UInt8(ascii: "\\")

        for try await byte in bytes {
            if bracketCount == 0 {
                if byte == braceOpen {
                    bracketCount = 1
                    buffer.append(byte)
                }
                continue
            }

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

                    if bracketCount == 0 {
                        if let decoded = try? JSONDecoder().decode(T.self, from: buffer) {
                            chunkCount += 1
                            onUpdate(decoded)
                        } else if let onSignal = onSignal,
                                  let signal = try? JSONDecoder().decode(DescriptionGuidanceProcessingSignal.self, from: buffer)
                        {
                            onSignal(signal)
                        }
                        buffer.removeAll(keepingCapacity: true)
                    }
                }
            }
        }

        // Handle remaining buffer
        if !buffer.isEmpty,
           let trimmed = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty,
           let jsonData = trimmed.data(using: .utf8)
        {
            if let decoded = try? JSONDecoder().decode(T.self, from: jsonData) {
                chunkCount += 1
                onUpdate(decoded)
            } else if let onSignal = onSignal,
                      let signal = try? JSONDecoder().decode(DescriptionGuidanceProcessingSignal.self, from: jsonData)
            {
                onSignal(signal)
            }
        }

        print("✅ Streaming complete: \(chunkCount) chunks")
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
