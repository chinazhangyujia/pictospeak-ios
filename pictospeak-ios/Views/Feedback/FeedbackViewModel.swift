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
    @Published var keyTermTeachingResponse: KeyTermTeachingStreamingResponse?
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

    func loadFeedback(image: UIImage?, videoURL: URL?, audioData: Data?, mediaType: MediaType) {
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

                    let stream = feedbackService.getFeedbackStreamForImage(authToken: authToken, image: image, audioData: audioData)
                    try await consumeStream(stream)

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

                    let stream = feedbackService.getFeedbackStreamForVideo(
                        authToken: authToken,
                        videoData: videoData,
                        videoFileExtension: fileExtension,
                        audioData: audioData
                    )
                    try await consumeStream(stream)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func consumeStream(_ stream: AsyncThrowingStream<FeedbackResponse, Error>) async throws {
        var lastResponse: FeedbackResponse?
        var lastUpdateTime = Date.distantPast

        for try await response in stream {
            lastResponse = response
            let now = Date()

            // Throttle updates to ~20 FPS (50ms) to prevent UI blocking
            if now.timeIntervalSince(lastUpdateTime) >= 0.05 {
                await MainActor.run {
                    self.feedbackResponse = self.createNewStreamingResponse(newResponse: response)
                    self.isLoading = false
                }
                lastUpdateTime = now
            }
        }

        // Ensure final update is applied
        if let finalResponse = lastResponse {
            await MainActor.run {
                self.feedbackResponse = self.createNewStreamingResponse(newResponse: finalResponse)
                self.isLoading = false
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
                    translations: item.translations,
                    reason: item.reason,
                    example: item.example,
                    favorite: true,
                    phoneticSymbol: item.phoneticSymbol,
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
                    translations: item.translations,
                    reason: item.reason,
                    example: item.example,
                    favorite: true,
                    phoneticSymbol: item.phoneticSymbol,
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
            pronunciationUrl: newResponse.pronunciationUrl,
            standardDescriptionSegments: newResponse.standardDescriptionSegments,
            id: newResponse.id
        )
    }

    func updateKeyTermFavoriteLocally(termId: UUID, isFavorite: Bool) {
        guard let currentFeedback = feedbackResponse else { return }

        let updatedKeyTerms = currentFeedback.keyTerms.map { keyTerm -> KeyTerm in
            guard keyTerm.id == termId else { return keyTerm }
            return KeyTerm(
                term: keyTerm.term,
                translations: keyTerm.translations,
                reason: keyTerm.reason,
                example: keyTerm.example,
                favorite: isFavorite,
                phoneticSymbol: keyTerm.phoneticSymbol,
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
            pronunciationUrl: currentFeedback.pronunciationUrl,
            standardDescriptionSegments: currentFeedback.standardDescriptionSegments,
            id: currentFeedback.id
        )
    }

    func updateSuggestionFavoriteLocally(suggestionId: UUID, isFavorite: Bool) {
        guard let currentFeedback = feedbackResponse else { return }

        let updatedSuggestions = currentFeedback.suggestions.map { suggestion -> Suggestion in
            guard suggestion.id == suggestionId else { return suggestion }
            return Suggestion(
                term: suggestion.term,
                refinement: suggestion.refinement,
                translations: suggestion.translations,
                reason: suggestion.reason,
                example: suggestion.example,
                favorite: isFavorite,
                phoneticSymbol: suggestion.phoneticSymbol,
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
            pronunciationUrl: currentFeedback.pronunciationUrl,
            standardDescriptionSegments: currentFeedback.standardDescriptionSegments,
            id: currentFeedback.id
        )
    }

    func teachSingleTerm(term: String, descriptionGuidanceId: UUID? = nil) {
        guard let id = descriptionGuidanceId ?? feedbackResponse?.id else {
            print("❌ Missing descriptionGuidanceId")
            return
        }

        guard let authToken = contentViewModel.authToken else {
            print("❌ Authentication required")
            return
        }

        // Reset previous response
        keyTermTeachingResponse = nil

        Task {
            do {
                let stream = feedbackService.getTeachSingleTermStream(
                    authToken: authToken,
                    descriptionGuidanceId: id,
                    term: term
                )

                for try await response in stream {
                    await MainActor.run {
                        self.keyTermTeachingResponse = response
                    }
                }
            } catch {
                print("❌ Error teaching single term: \(error)")
            }
        }
    }
}
