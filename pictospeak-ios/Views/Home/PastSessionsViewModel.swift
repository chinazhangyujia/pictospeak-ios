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
    weak var reviewViewModel: ReviewViewModel?

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
    }

    /// Loads the first page of past sessions
    func loadInitialSessions() async {
        // Cancel any existing loading task
        loadingTask?.cancel()

        // Create new loading task
        loadingTask = Task {
            await loadInitialSessionsInternal()
        }

        await loadingTask?.value
    }

    /// Loads the initial page of sessions (internal implementation)
    private func loadInitialSessionsInternal() async {
        isLoading = true
        errorMessage = nil

        do {
            // Check if task was cancelled
            if Task.isCancelled { return }

            guard let authToken = contentViewModel.authToken else {
                print("❌ No auth token available for loading sessions")
                errorMessage = "Authentication required"
                isLoading = false
                return
            }

            let response = try await sessionService.getPastSessions(authToken: authToken)

            // Check if task was cancelled after the request
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

    /// Gets or loads a session by ID without throwing errors (UI-safe)
    /// - Parameter sessionId: The session ID to load
    /// - Returns: The session if found/loaded successfully, nil otherwise
    func getOrLoadSessionById(sessionId: String) async -> SessionItem? {
        // Check if already loaded
        if let session = sessions.first(where: { $0.id.uuidString == sessionId }) {
            return session
        }

        do {
            guard let authToken = contentViewModel.authToken else {
                print("❌ No auth token available for loading session")
                return nil
            }

            let session = try await sessionService.getSessionById(authToken: authToken, sessionId: sessionId)

            // Add to loaded sessions
            sessions.append(session)

            return session
        } catch {
            print("❌ Error getting or loading session: \(error)")
        }

        return nil
    }

    /// Refreshes all sessions by loading from the beginning
    func refreshSessions() async {
        // Reset state
        sessions = []
        currentCursor = nil
        hasMorePages = true

        // Load initial sessions
        await loadInitialSessions()
    }

    /// Deletes a session by ID from both remote and local storage
    /// - Returns: Boolean indicating success
    func deleteSession(sessionId: UUID) async -> Bool {
        guard let authToken = contentViewModel.authToken else {
            errorMessage = "Authentication required"
            return false
        }

        do {
            try await sessionService.deleteSession(authToken: authToken, sessionId: sessionId.uuidString)

            // Remove review items associated with this session
            await MainActor.run {
                reviewViewModel?.reviewItems.removeAll { $0.descriptionGuidanceId == sessionId }
            }

            // Remove from local list upon success
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions.remove(at: index)
            }

            return true
        } catch {
            let errorDescription: String
            if let sessionError = error as? SessionError {
                switch sessionError {
                case .networkError:
                    errorDescription = "Network connection issue."
                case .serverError:
                    errorDescription = "Server error. Please try again later."
                case .sessionNotFound:
                    errorDescription = "Session not found."
                    // If it's not found on server, remove it locally to sync up
                    if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                        sessions.remove(at: index)
                    }
                    // Return true since it's effectively deleted (gone from list)
                    return true
                default:
                    errorDescription = "Failed to delete session."
                }
            } else {
                errorDescription = error.localizedDescription
            }

            // Only show error if it's not a "not found" error (which we handled by removing)
            if (error as? SessionError) != .sessionNotFound {
                errorMessage = errorDescription
            }
            return false
        }
    }

    func updateKeyTermFavorite(sessionId: UUID, termId: UUID, favorite: Bool) {
        // First, find the session in the sessions array using sessionId
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            var updatedSession = sessions[sessionIndex]

            // Find and update the KeyTerm in the session
            if let keyTermIndex = updatedSession.keyTerms.firstIndex(where: { $0.id == termId }) {
                // Create updated KeyTerm with new favorite status
                let currentKeyTerm = updatedSession.keyTerms[keyTermIndex]
                let updatedKeyTerm = KeyTerm(
                    term: currentKeyTerm.term,
                    translations: currentKeyTerm.translations,
                    reason: currentKeyTerm.reason,
                    example: currentKeyTerm.example,
                    favorite: favorite,
                    phoneticSymbol: currentKeyTerm.phoneticSymbol,
                    id: currentKeyTerm.id,
                    descriptionGuidanceId: currentKeyTerm.descriptionGuidanceId
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
                let currentSuggestion = updatedSession.suggestions[suggestionIndex]
                let updatedSuggestion = Suggestion(
                    term: currentSuggestion.term,
                    refinement: currentSuggestion.refinement,
                    translations: currentSuggestion.translations,
                    reason: currentSuggestion.reason,
                    example: currentSuggestion.example,
                    favorite: favorite,
                    phoneticSymbol: currentSuggestion.phoneticSymbol,
                    id: currentSuggestion.id,
                    descriptionGuidanceId: currentSuggestion.descriptionGuidanceId
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

    func addKeyTerm(to sessionId: UUID, keyTerm: KeyTerm) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            var updatedSession = sessions[sessionIndex]
            if !updatedSession.keyTerms.contains(where: { $0.id == keyTerm.id }) {
                updatedSession.keyTerms.append(keyTerm)
                sessions[sessionIndex] = updatedSession
                print("✅ Added new KeyTerm to session: \(sessionId)")
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
