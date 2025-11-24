//
//  ReviewViewModel.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation
import SwiftUI

@MainActor
class ReviewViewModel: ObservableObject {
    @Published var reviewItems: [ReviewItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true

    private var currentCursor: String?
    private let reviewService = ReviewService.shared
    private var loadingTask: Task<Void, Never>?
    var contentViewModel: ContentViewModel

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
    }

    /// Loads the first page of review items
    func loadInitialReviewItems() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            guard !isLoading else { return }

            isLoading = true
            errorMessage = nil

            do {
                guard let authToken = contentViewModel.authToken else {
                    print("❌ No auth token available for loading review items")
                    errorMessage = "Authentication required"
                    isLoading = false
                    return
                }

                let response = try await reviewService.getReviewItems(authToken: authToken)

                // Check if task was cancelled
                if Task.isCancelled { return }

                reviewItems = response.items
                currentCursor = response.nextCursor
                hasMorePages = response.nextCursor != nil

                print("✅ Loaded \(reviewItems.count) initial review items")
            } catch {
                // Check if task was cancelled
                if Task.isCancelled { return }

                let errorDescription: String
                if let reviewError = error as? ReviewError {
                    switch reviewError {
                    case .networkError:
                        errorDescription = "Network connection issue. Please check your internet connection."
                    case .serverError:
                        errorDescription = "Server error. Please try again later."
                    case .decodingError:
                        errorDescription = "Data format error. Please contact support."
                    case .invalidURL:
                        errorDescription = "Invalid request. Please try again."
                    default:
                        errorDescription = "Unknown error occurred. Please try again."
                    }
                } else {
                    errorDescription = error.localizedDescription
                }

                errorMessage = "Failed to load review items: \(errorDescription)"
                print("❌ Error loading initial review items: \(error)")
            }

            isLoading = false
        }

        await loadingTask?.value
    }

    /// Loads the next page of review items (pagination)
    func loadMoreReviewItems() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            guard !isLoading, hasMorePages, let cursor = currentCursor else { return }

            isLoading = true

            do {
                guard let authToken = contentViewModel.authToken else {
                    print("❌ No auth token available for loading more review items")
                    errorMessage = "Authentication required"
                    isLoading = false
                    return
                }

                let response = try await reviewService.getReviewItems(authToken: authToken, cursor: cursor)

                // Check if task was cancelled
                if Task.isCancelled { return }

                reviewItems.append(contentsOf: response.items)
                currentCursor = response.nextCursor
                hasMorePages = response.nextCursor != nil

                print("✅ Loaded \(response.items.count) more review items, total: \(reviewItems.count)")
            } catch {
                // Check if task was cancelled
                if Task.isCancelled { return }

                let errorDescription: String
                if let reviewError = error as? ReviewError {
                    switch reviewError {
                    case .networkError:
                        errorDescription = "Network connection issue. Please check your internet connection."
                    case .serverError:
                        errorDescription = "Server error. Please try again later."
                    case .decodingError:
                        errorDescription = "Data format error. Please contact support."
                    case .invalidURL:
                        errorDescription = "Invalid request. Please try again."
                    default:
                        errorDescription = "Unknown error occurred. Please try again."
                    }
                } else {
                    errorDescription = error.localizedDescription
                }

                errorMessage = "Failed to load more review items: \(errorDescription)"
                print("❌ Error loading more review items: \(error)")
            }

            isLoading = false
        }

        await loadingTask?.value
    }

    /// Refreshes all review items by loading from the beginning
    func refreshReviewItems() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            reviewItems = []
            currentCursor = nil
            hasMorePages = true
            await loadInitialReviewItems()
        }

        await loadingTask?.value
    }

    /// Updates the favorite status of a ReviewItem by ID
    /// - Parameters:
    ///   - itemId: The UUID of the ReviewItem to update
    ///   - favorite: The new favorite status
    func updateReviewItemFavorite(itemId: UUID, favorite: Bool) {
        // Find and update the ReviewItem in the array
        if let itemIndex = reviewItems.firstIndex(where: { $0.id == itemId }) {
            let item = reviewItems[itemIndex]

            // Create updated ReviewItem with new favorite status
            let updatedItem = ReviewItem(
                id: item.id,
                type: item.type,
                term: item.term,
                translation: item.translation,
                favorite: favorite,
                detail: item.detail,
                updatedAt: item.updatedAt,
                descriptionGuidanceId: item.descriptionGuidanceId,
                userOriginalTerm: item.userOriginalTerm
            )

            // Update the review items array
            reviewItems[itemIndex] = updatedItem

            // Update server-side favorite status
            Task {
                guard let authToken = contentViewModel.authToken else {
                    print("❌ No auth token available for updating favorite")
                    return
                }

                do {
                    switch item.type {
                    case .keyTerm:
                        try await FavoriteService.shared.updateKeyTermFavorite(
                            authToken: authToken,
                            termId: itemId.uuidString,
                            favorite: favorite
                        )
                    case .suggestion:
                        try await FavoriteService.shared.updateSuggestionFavorite(
                            authToken: authToken,
                            suggestionId: itemId.uuidString,
                            favorite: favorite
                        )
                    }
                    print("✅ Successfully updated \(item.type) favorite on server: \(itemId) -> \(favorite)")
                } catch {
                    print("❌ Failed to update \(item.type) favorite on server: \(error)")
                    // Optionally revert local change here if needed
                }
            }
        } else {
            print("❌ ReviewItem not found with ID: \(itemId)")
        }
    }

    // MARK: - Helper Methods

    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }

    /// Cancel any ongoing loading operations
    func cancelLoading() {
        loadingTask?.cancel()
        isLoading = false
    }

    deinit {
        loadingTask?.cancel()
    }
}
