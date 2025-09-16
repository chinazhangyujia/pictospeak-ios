//
//  ReviewView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var sessionsViewModel: PastSessionsViewModel = .init(contentViewModel: ContentViewModel())

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection

                    // Review Progress Section
                    reviewProgressSection

                    // Recent Sessions Section
                    recentSessionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            sessionsViewModel.contentViewModel = contentViewModel

            // Check if auth token is nil on initial load and redirect to auth
            if contentViewModel.authToken == nil {
                print("🔐 No auth token on initial load, navigating to auth view")
                router.goTo(.auth)
            }
        }
        .task {
            // Only load data if we have an auth token
            if contentViewModel.authToken != nil {
                sessionsViewModel.clearError() // Clear any stale errors
                await sessionsViewModel.loadInitialSessions()
            }
        }
        .refreshable {
            await sessionsViewModel.refreshSessions()
        }
        .onChange(of: contentViewModel.authToken) { oldValue, newValue in
            // Auto-route to auth when token becomes null
            if oldValue != nil && newValue == nil {
                print("🔐 Auth token became null, navigating to auth view")
                router.goTo(.auth)
            }
            // When token becomes available, load data
            else if oldValue == nil && newValue != nil {
                print("🔐 Auth token became available, loading data")
                Task {
                    sessionsViewModel.clearError()
                    await sessionsViewModel.loadInitialSessions()
                }
            }
        }
        .alert("Error Loading Sessions", isPresented: .constant(sessionsViewModel.errorMessage != nil)) {
            Button("OK") {
                sessionsViewModel.clearError()
            }
            Button("Retry") {
                Task {
                    sessionsViewModel.clearError() // Clear error before retrying
                    await sessionsViewModel.loadInitialSessions()
                }
            }
        } message: {
            Text(sessionsViewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice makes perfect!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Review your past sessions and improve your skills")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Review Progress Section

    private var reviewProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                // Sessions completed today
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(sessionsViewModel.sessions.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Review due
                VStack(alignment: .leading, spacing: 4) {
                    Text("5")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Due")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Recent Sessions Section

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Sessions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            if sessionsViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading sessions...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if sessionsViewModel.sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No sessions yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Start practicing to see your sessions here")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessionsViewModel.sessions.prefix(10)) { session in
                        Button(action: {
                            router.goTo(.feedbackFromSession(sessionId: session.id, pastSessionsViewModel: sessionsViewModel))
                        }) {
                            ReviewSessionCard(session: session)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Review Session Card

struct ReviewSessionCard: View {
    let session: SessionItem

    var body: some View {
        HStack(spacing: 12) {
            // Session image
            AsyncImage(url: URL(string: session.materialUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Session details
            VStack(alignment: .leading, spacing: 4) {
                Text(session.standardDescription)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            Spacer()

            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ReviewView()
        .environmentObject(Router())
        .environmentObject(ContentViewModel())
}
