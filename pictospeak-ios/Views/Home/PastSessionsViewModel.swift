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
    @Published var activeSession: SessionItem? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true

    private var currentCursor: String?
    private let sessionService = SessionService.shared
    private var loadingTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Convert sessions to display items on-the-fly
    var displaySessions: [SessionDisplayItem] {
        return sessionService.convertToDisplayItems(sessions)
    }
    


    // MARK: - Public Methods

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
                let response = try await sessionService.getPastSessions()
                
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
                let response = try await sessionService.getPastSessions(cursor: cursor)
                
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

    // MARK: - Active Session Management
    
    /// Sets the active session by finding it in the sessions list using sessionId
    /// - Parameter sessionId: The UUID of the session to set as active
    func setActiveSession(by sessionId: UUID) {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            activeSession = session
            print("✅ Set active session: \(activeSession)")
        } else {
            print("❌ Session not found with ID: \(sessionId)")
        }
    }
    
    /// Clears the active session when leaving detailed view
    func clearActiveSession() {
        activeSession = nil
        print("✅ Cleared active session")
    }
    
    // MARK: - Favorite Management Methods
    
    /// Updates the favorite status of a KeyTerm by ID
    /// - Parameters:
    ///   - termId: The UUID of the KeyTerm to update
    ///   - favorite: The new favorite status
    func updateKeyTermFavorite(termId: UUID, favorite: Bool) {
        guard let activeSession = activeSession else {
            print("❌ No active session to update")
            return
        }
        
        // Update the active session first
        if let keyTermIndex = activeSession.keyTerms.firstIndex(where: { $0.id == termId }) {
            // Create updated KeyTerm with new favorite status
            let updatedKeyTerm = KeyTerm(
                term: activeSession.keyTerms[keyTermIndex].term,
                translation: activeSession.keyTerms[keyTermIndex].translation,
                example: activeSession.keyTerms[keyTermIndex].example,
                favorite: favorite,
                id: activeSession.keyTerms[keyTermIndex].id
            )
            
            // Update the active session with the modified KeyTerm
            var updatedActiveSession = activeSession
            updatedActiveSession.keyTerms[keyTermIndex] = updatedKeyTerm
            self.activeSession = updatedActiveSession
            
            // Now find and replace the corresponding session in the sessions array
            if let sessionIndex = sessions.firstIndex(where: { $0.sessionId == activeSession.sessionId }) {
                sessions[sessionIndex] = updatedActiveSession
            }
            
            print("✅ Updated KeyTerm favorite status: \(termId) -> \(favorite)")
        } else {
            print("❌ KeyTerm not found with ID: \(termId)")
        }
    }
    
    /// Updates the favorite status of a Suggestion by ID
    /// - Parameters:
    ///   - suggestionId: The UUID of the Suggestion to update
    ///   - favorite: The new favorite status
    func updateSuggestionFavorite(suggestionId: UUID, favorite: Bool) {
        guard let activeSession = activeSession else {
            print("❌ No active session to update")
            return
        }
        
        // Update the active session first
        if let suggestionIndex = activeSession.suggestions.firstIndex(where: { $0.id == suggestionId }) {
            // Create updated Suggestion with new favorite status
            let updatedSuggestion = Suggestion(
                term: activeSession.suggestions[suggestionIndex].term,
                refinement: activeSession.suggestions[suggestionIndex].refinement,
                translation: activeSession.suggestions[suggestionIndex].translation,
                reason: activeSession.suggestions[suggestionIndex].reason,
                favorite: favorite,
                id: activeSession.suggestions[suggestionIndex].id
            )
            
            // Update the active session with the modified Suggestion
            var updatedActiveSession = activeSession
            updatedActiveSession.suggestions[suggestionIndex] = updatedSuggestion
            self.activeSession = updatedActiveSession
            
            // Now find and replace the corresponding session in the sessions array
            if let sessionIndex = sessions.firstIndex(where: { $0.sessionId == activeSession.sessionId }) {
                sessions[sessionIndex] = updatedActiveSession
            }
            
            print("✅ Updated Suggestion favorite status: \(suggestionId) -> \(favorite)")
        } else {
            print("❌ Suggestion not found with ID: \(suggestionId)")
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
