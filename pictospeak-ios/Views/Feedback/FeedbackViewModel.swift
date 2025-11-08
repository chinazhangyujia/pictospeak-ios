//
//  FeedbackViewModel.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation
import SwiftUI

@MainActor
class FeedbackViewModel: ObservableObject {
    @Published var feedbackResponse: FeedbackResponse?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let feedbackService = FeedbackService.shared
    var contentViewModel: ContentViewModel

    // Initializer for previews with fake data
    init(contentViewModel: ContentViewModel, previewData: FeedbackResponse? = nil) {
        self.contentViewModel = contentViewModel
        if let previewData = previewData {
            feedbackResponse = previewData
            isLoading = false
            errorMessage = nil
        }
    }

    func loadFeedback(image: UIImage?, videoURL: URL?, audioData: Data, mediaType: MediaType) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch mediaType {
                case .image:
                    guard let image = image else {
                        await MainActor.run {
                            self.errorMessage = "Missing image for feedback request."
                            self.isLoading = false
                        }
                        return
                    }

                    guard let authToken = contentViewModel.authToken else {
                        await MainActor.run {
                            self.errorMessage = "Authentication required"
                            self.isLoading = false
                        }
                        return
                    }

                    for try await response in feedbackService.getFeedbackStreamForImage(authToken: authToken, image: image, audioData: audioData) {
                        await MainActor.run {
                            self.feedbackResponse = response
                            self.isLoading = false
                        }
                    }
                case .video:
                    guard let videoURL = videoURL else {
                        await MainActor.run {
                            self.errorMessage = "Missing video for feedback request."
                            self.isLoading = false
                        }
                        return
                    }

                    let videoData: Data
                    do {
                        videoData = try await Task.detached(priority: .userInitiated) {
                            try Data(contentsOf: videoURL)
                        }.value
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Unable to load the selected video."
                            self.isLoading = false
                        }
                        return
                    }

                    guard let authToken = contentViewModel.authToken else {
                        await MainActor.run {
                            self.errorMessage = "Authentication required"
                            self.isLoading = false
                        }
                        return
                    }

                    let fileExtension = videoURL.pathExtension.isEmpty ? nil : videoURL.pathExtension

                    for try await response in feedbackService.getFeedbackStreamForVideo(
                        authToken: authToken,
                        videoData: videoData,
                        videoFileExtension: fileExtension,
                        audioData: audioData
                    ) {
                        await MainActor.run {
                            self.feedbackResponse = response
                            self.isLoading = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
