//
//  FeedbackViewModel.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import Foundation
import UIKit

@MainActor
class FeedbackViewModel: ObservableObject {
    @Published var feedbackResponse: FeedbackResponse?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let feedbackService = FeedbackService.shared

    func loadFeedback(image: UIImage, audioData: Data, mediaType: MediaType) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response: FeedbackResponse

                switch mediaType {
                case .image:
                    response = try await feedbackService.getFeedbackForImage(image: image, audioData: audioData)
                case .video:
                    // For video, we would need the video URL from CaptureView
                    // For now, we'll use the image method as a fallback
                    response = try await feedbackService.getFeedbackForImage(image: image, audioData: audioData)
                }

                self.feedbackResponse = response
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
