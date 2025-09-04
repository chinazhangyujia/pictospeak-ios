//
//  PastSessionsViewModel.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation
import SwiftUI

@MainActor
class PastSessionsViewModel: ObservableObject {
    @Published var sessions: [SessionItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true

    private var currentCursor: String?
    private let sessionService = SessionService.shared
    private var loadingTask: Task<Void, Never>?
    var contentViewModel: ContentViewModel

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
    }

    /// Loads the first page of past sessions
    func loadInitialSessions() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            guard !isLoading else { return }

            isLoading = true
            errorMessage = nil

            do {
                guard let authToken = contentViewModel.authToken else {
                    print("❌ No auth token available for loading sessions")
                    errorMessage = "Authentication required"
                    isLoading = false
                    return
                }

                let response = try await sessionService.getPastSessions(authToken: authToken)

                // Check if task was cancelled
                if Task.isCancelled { return }

                sessions = response.items
                currentCursor = response.nextCursor
                hasMorePages = response.nextCursor != nil

                print("✅ Loaded \(sessions.count) initial sessions")
            } catch {
                // Check if task was cancelled
                if Task.isCancelled { return }

                let errorDescription: String
                if let sessionError = error as? SessionError {
                    switch sessionError {
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

                errorMessage = "Failed to load sessions: \(errorDescription)"
                print("❌ Error loading initial sessions: \(error)")
            }

            isLoading = false
        }

        await loadingTask?.value
    }

    /// Loads the next page of sessions (pagination)
    func loadMoreSessions() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            guard !isLoading, hasMorePages, let cursor = currentCursor else { return }

            isLoading = true

            do {
                guard let authToken = contentViewModel.authToken else {
                    print("❌ No auth token available for loading more sessions")
                    errorMessage = "Authentication required"
                    isLoading = false
                    return
                }

                let response = try await sessionService.getPastSessions(authToken: authToken, cursor: cursor)

                // Check if task was cancelled
                if Task.isCancelled { return }

                sessions.append(contentsOf: response.items)
                currentCursor = response.nextCursor
                hasMorePages = response.nextCursor != nil

                print("✅ Loaded \(response.items.count) more sessions, total: \(sessions.count)")
            } catch {
                // Check if task was cancelled
                if Task.isCancelled { return }

                let errorDescription: String
                if let sessionError = error as? SessionError {
                    switch sessionError {
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

                errorMessage = "Failed to load more sessions: \(errorDescription)"
                print("❌ Error loading more sessions: \(error)")
            }

            isLoading = false
        }

        await loadingTask?.value
    }

    /// Refreshes all sessions by loading from the beginning
    func refreshSessions() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            sessions = []
            currentCursor = nil
            hasMorePages = true
            await loadInitialSessions()
        }

        await loadingTask?.value
    }

    func updateKeyTermFavorite(sessionId: UUID, termId: UUID, favorite: Bool) {
        // First, find the session in the sessions array using sessionId
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            var updatedSession = sessions[sessionIndex]

            // Find and update the KeyTerm in the session
            if let keyTermIndex = updatedSession.keyTerms.firstIndex(where: { $0.id == termId }) {
                // Create updated KeyTerm with new favorite status
                let updatedKeyTerm = KeyTerm(
                    term: updatedSession.keyTerms[keyTermIndex].term,
                    translation: updatedSession.keyTerms[keyTermIndex].translation,
                    example: updatedSession.keyTerms[keyTermIndex].example,
                    favorite: favorite,
                    id: updatedSession.keyTerms[keyTermIndex].id
                )

                // Update the session with the modified KeyTerm
                updatedSession.keyTerms[keyTermIndex] = updatedKeyTerm

                // Update the sessions array
                sessions[sessionIndex] = updatedSession

                print("✅ Updated KeyTerm favorite status: \(termId) -> \(favorite)")
            } else {
                print("❌ KeyTerm not found with ID: \(termId)")
            }
        } else {
            print("❌ Session not found with ID: \(sessionId)")
        }
    }

    /// Updates the favorite status of a Suggestion by ID
    /// - Parameters:
    ///   - sessionId: The UUID of the session containing the suggestion
    ///   - suggestionId: The UUID of the Suggestion to update
    ///   - favorite: The new favorite status
    func updateSuggestionFavorite(sessionId: UUID, suggestionId: UUID, favorite: Bool) {
        // First, find the session in the sessions array using sessionId
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            var updatedSession = sessions[sessionIndex]

            // Find and update the Suggestion in the session
            if let suggestionIndex = updatedSession.suggestions.firstIndex(where: { $0.id == suggestionId }) {
                // Create updated Suggestion with new favorite status
                let updatedSuggestion = Suggestion(
                    term: updatedSession.suggestions[suggestionIndex].term,
                    refinement: updatedSession.suggestions[suggestionIndex].refinement,
                    translation: updatedSession.suggestions[suggestionIndex].translation,
                    reason: updatedSession.suggestions[suggestionIndex].reason,
                    favorite: favorite,
                    id: updatedSession.suggestions[suggestionIndex].id
                )

                // Update the session with the modified Suggestion
                updatedSession.suggestions[suggestionIndex] = updatedSuggestion

                // Update the sessions array
                sessions[sessionIndex] = updatedSession

                print("✅ Updated Suggestion favorite status: \(suggestionId) -> \(favorite)")
            } else {
                print("❌ Suggestion not found with ID: \(suggestionId)")
            }
        } else {
            print("❌ Session not found with ID: \(sessionId)")
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
