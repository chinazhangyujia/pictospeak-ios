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

    func loadFeedback(image: UIImage, audioData: Data, mediaType: MediaType) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch mediaType {
                case .image:
                    // Use streaming API for real-time updates
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
                    // For video, we would need the video URL from CaptureView
                    // For now, we'll use the image method as a fallback
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
