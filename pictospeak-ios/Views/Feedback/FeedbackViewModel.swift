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
                            self.feedbackResponse = self.createNewStreamingResponse(newResponse: response)
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
                            self.feedbackResponse = self.createNewStreamingResponse(newResponse: response)
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

    // we don't want to use the raw streaming response to override the existing response object in the memory
    // this is because while streaming, the user could favorite an item. If we do the override, the favorite state will be reset to false
    private func createNewStreamingResponse(newResponse: FeedbackResponse) -> FeedbackResponse {
        guard let oldResponse = feedbackResponse else { return newResponse }

        // Create sets of favorited IDs from the old response, ignoring .zero IDs
        let favoritedKeyTermIds = Set(oldResponse.keyTerms.filter { $0.favorite && $0.id != .zero }.map { $0.id })
        let favoritedSuggestionIds = Set(oldResponse.suggestions.filter { $0.favorite && $0.id != .zero }.map { $0.id })

        if favoritedKeyTermIds.isEmpty && favoritedSuggestionIds.isEmpty {
            return newResponse
        }

        let updatedKeyTerms = newResponse.keyTerms.map { item -> KeyTerm in
            if favoritedKeyTermIds.contains(item.id) {
                return KeyTerm(
                    term: item.term,
                    translation: item.translation,
                    example: item.example,
                    favorite: true,
                    id: item.id,
                    descriptionGuidanceId: item.descriptionGuidanceId
                )
            }
            return item
        }

        let updatedSuggestions = newResponse.suggestions.map { item -> Suggestion in
            if favoritedSuggestionIds.contains(item.id) {
                return Suggestion(
                    term: item.term,
                    refinement: item.refinement,
                    translation: item.translation,
                    reason: item.reason,
                    favorite: true,
                    id: item.id,
                    descriptionGuidanceId: item.descriptionGuidanceId
                )
            }
            return item
        }

        return FeedbackResponse(
            originalText: newResponse.originalText,
            refinedText: newResponse.refinedText,
            suggestions: updatedSuggestions,
            keyTerms: updatedKeyTerms,
            score: newResponse.score,
            chosenKeyTerms: newResponse.chosenKeyTerms,
            chosenRefinements: newResponse.chosenRefinements,
            chosenItemsGenerated: newResponse.chosenItemsGenerated,
            pronunciationUrl: newResponse.pronunciationUrl
        )
    }

    func updateKeyTermFavoriteLocally(termId: UUID, isFavorite: Bool) {
        guard let currentFeedback = feedbackResponse else { return }

        let updatedKeyTerms = currentFeedback.keyTerms.map { keyTerm -> KeyTerm in
            guard keyTerm.id == termId else { return keyTerm }
            return KeyTerm(
                term: keyTerm.term,
                translation: keyTerm.translation,
                example: keyTerm.example,
                favorite: isFavorite,
                id: keyTerm.id,
                descriptionGuidanceId: keyTerm.descriptionGuidanceId
            )
        }

        feedbackResponse = FeedbackResponse(
            originalText: currentFeedback.originalText,
            refinedText: currentFeedback.refinedText,
            suggestions: currentFeedback.suggestions,
            keyTerms: updatedKeyTerms,
            score: currentFeedback.score,
            chosenKeyTerms: currentFeedback.chosenKeyTerms,
            chosenRefinements: currentFeedback.chosenRefinements,
            chosenItemsGenerated: currentFeedback.chosenItemsGenerated,
            pronunciationUrl: currentFeedback.pronunciationUrl
        )
    }

    func updateSuggestionFavoriteLocally(suggestionId: UUID, isFavorite: Bool) {
        guard let currentFeedback = feedbackResponse else { return }

        let updatedSuggestions = currentFeedback.suggestions.map { suggestion -> Suggestion in
            guard suggestion.id == suggestionId else { return suggestion }
            return Suggestion(
                term: suggestion.term,
                refinement: suggestion.refinement,
                translation: suggestion.translation,
                reason: suggestion.reason,
                favorite: isFavorite,
                id: suggestion.id,
                descriptionGuidanceId: suggestion.descriptionGuidanceId
            )
        }

        feedbackResponse = FeedbackResponse(
            originalText: currentFeedback.originalText,
            refinedText: currentFeedback.refinedText,
            suggestions: updatedSuggestions,
            keyTerms: currentFeedback.keyTerms,
            score: currentFeedback.score,
            chosenKeyTerms: currentFeedback.chosenKeyTerms,
            chosenRefinements: currentFeedback.chosenRefinements,
            chosenItemsGenerated: currentFeedback.chosenItemsGenerated,
            pronunciationUrl: currentFeedback.pronunciationUrl
        )
    }
}
