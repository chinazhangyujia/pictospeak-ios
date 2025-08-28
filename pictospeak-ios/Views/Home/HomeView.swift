//
//  HomeView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var sessionsViewModel = PastSessionsViewModel()
    @State private var selectedMode: NavigationMode = .home

    enum NavigationMode {
        case home
        case review
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection

                    // Start Talking Section
                    startTalkingSection

                    // Review Section
                    reviewSection

                    // Recent Sessions Section
                    recentSessionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 120) // Add bottom padding for navigation overlay
            }
            .background(Color(.systemBackground))

            // Loading overlay for refresh
            if sessionsViewModel.isLoading && sessionsViewModel.sessions.isEmpty {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading sessions...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.8))
            }

            // Custom bottom navigation overlay
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    // Home/Review switch button
                    HStack(spacing: 0) {
                        // Home button
                        Button(action: {
                            selectedMode = .home
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 16))
                                Text("Home")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(selectedMode == .home ? .blue : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(selectedMode == .home ? .white : .clear)
                            )
                        }

                        // Review button
                        Button(action: {
                            selectedMode = .review
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "book")
                                    .font(.system(size: 16))
                                Text("Review")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(selectedMode == .review ? .blue : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(selectedMode == .review ? .white : .clear)
                            )
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(.systemGray6))
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Spacer()

                    // Record button
                    Button(action: {
                        // Navigate to capture view
                        router.goTo(.capture)
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34) // Account for safe area
            }
        }
        .task {
            sessionsViewModel.clearError() // Clear any stale errors
            await sessionsViewModel.loadInitialSessions()
        }
        .refreshable {
            await sessionsViewModel.refreshSessions()
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
            HStack {
                Text("PicTalk")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    // Settings action
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }

            Text("Good evening!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Ready to practice with real scenarios?")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Start Talking Section

    private var startTalkingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start Talking")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Tap a video to start speaking")
                .font(.body)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(scenarioPreviews, id: \.id) { scenario in
                        Button(action: {
                            // Handle scenario selection
                        }) {
                            ScenarioPreviewCard(scenario: scenario)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        HStack {
            Image(systemName: "book")
                .font(.title2)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Review today · 5 due")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            Spacer()

            Button("Start review") {
                // Handle review action
            }
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

                Button(action: {
                    // See all action
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.body)
                            .foregroundColor(.blue)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(sessionsViewModel.sessions.prefix(10))) { session in
                        Button(action: {
                            router.goTo(.feedbackFromSession(sessionId: session.id, pastSessionsViewModel: sessionsViewModel))
                        }) {
                            SessionCard(session: session)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Show loading indicator if there are more sessions to load
                    if sessionsViewModel.hasMorePages && !sessionsViewModel.isLoading {
                        Button(action: {
                            Task {
                                await sessionsViewModel.loadMoreSessions()
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)

                                Text("Load More")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 140, height: 80)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else if sessionsViewModel.isLoading {
                        // Show loading indicator when loading
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)

                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 140, height: 80)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: SessionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // AsyncImage for loading actual session image
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
            .frame(width: 140, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(String(session.standardDescription.prefix(50)))
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(session.standardDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)

                HStack(spacing: 8) {
                    // Key terms count
                    if session.keyTerms.count > 0 {
                        Label("\(session.keyTerms.count)", systemImage: "book.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    // Suggestions count
                    if session.suggestions.count > 0 {
                        Label("\(session.suggestions.count)", systemImage: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    Spacer()
                }
            }
        }
        .frame(width: 140)
    }
}

// MARK: - Scenario Preview Card

struct ScenarioPreviewCard: View {
    let scenario: ScenarioPreview

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Background gradient
                scenario.backgroundColor
                    .frame(width: 120, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Icon
                Image(systemName: scenario.systemImageName)
                    .font(.system(size: 32))
                    .foregroundColor(scenario.foregroundColor)

                // Add a subtle overlay to make text more readable
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 120, height: 80)
            }
        }
        .frame(width: 120)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Models for Placeholder Data

struct ScenarioPreview {
    let id = UUID()
    let systemImageName: String
    let foregroundColor: Color
    let backgroundColor: LinearGradient
    let title: String
}

// MARK: - Placeholder Data

extension HomeView {
    private var scenarioPreviews: [ScenarioPreview] {
        [
            ScenarioPreview(
                systemImageName: "dog.fill",
                foregroundColor: .brown,
                backgroundColor: LinearGradient(
                    colors: [.green.opacity(0.3), .brown.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                title: "Dog Playing"
            ),
            ScenarioPreview(
                systemImageName: "cup.and.saucer.fill",
                foregroundColor: .orange,
                backgroundColor: LinearGradient(
                    colors: [.blue.opacity(0.3), .orange.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                title: "Coffee Shop"
            ),
            ScenarioPreview(
                systemImageName: "cart.fill",
                foregroundColor: .green,
                backgroundColor: LinearGradient(
                    colors: [.blue.opacity(0.3), .green.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                title: "Grocery Store"
            ),
        ]
    }
}

#Preview {
    HomeView()
        .environmentObject(Router())
}
