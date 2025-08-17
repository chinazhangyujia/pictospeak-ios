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

    // MARK: - Computed Properties

    /// Convert sessions to display items on-the-fly
    var displaySessions: [SessionDisplayItem] {
        return sessionService.convertToDisplayItems(sessions)
    }

    // MARK: - Public Methods

    /// Loads the first page of past sessions
    func loadInitialSessions() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await sessionService.getPastSessions()
            sessions = response.items
            currentCursor = response.nextCursor
            hasMorePages = response.nextCursor != nil

            print("✅ Loaded \(sessions.count) initial sessions")
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            print("❌ Error loading initial sessions: \(error)")
        }

        isLoading = false
    }

    /// Loads the next page of sessions (pagination)
    func loadMoreSessions() async {
        guard !isLoading, hasMorePages, let cursor = currentCursor else { return }

        isLoading = true

        do {
            let response = try await sessionService.getPastSessions(cursor: cursor)
            sessions.append(contentsOf: response.items)
            currentCursor = response.nextCursor
            hasMorePages = response.nextCursor != nil

            print("✅ Loaded \(response.items.count) more sessions, total: \(sessions.count)")
        } catch {
            errorMessage = "Failed to load more sessions: \(error.localizedDescription)"
            print("❌ Error loading more sessions: \(error)")
        }

        isLoading = false
    }

    /// Refreshes all sessions by loading from the beginning
    func refreshSessions() async {
        sessions = []
        currentCursor = nil
        hasMorePages = true
        await loadInitialSessions()
    }

    // MARK: - Helper Methods

    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Usage Example

/*
 Example usage in a SwiftUI View:

 struct PastSessionsView: View {
     @StateObject private var viewModel = PastSessionsViewModel()

     var body: some View {
         NavigationView {
             List {
                 ForEach(viewModel.displaySessions) { displaySession in
                     SessionRowView(session: displaySession)
                 }

                 if viewModel.isLoading {
                     ProgressView()
                         .frame(maxWidth: .infinity, alignment: .center)
                 }
             }
             .navigationTitle("Past Sessions")
             .refreshable {
                 await viewModel.refreshSessions()
             }
             .task {
                 await viewModel.loadInitialSessions()
             }
             .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                 Button("OK") {
                     viewModel.clearError()
                 }
             } message: {
                 Text(viewModel.errorMessage ?? "")
             }
         }
     }
 }
 */
