//
//  HomeView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var sessionsViewModel = PastSessionsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection

                    // Central Call-to-Action Section
                    centralActionSection

                    // Recent Sessions Section
                    recentSessionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .task {
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

            Text("Spot something interesting nearby?")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Central Call-to-Action Section

    private var centralActionSection: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: CaptureView()) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.purple)
                    }

                    Text("Start a New PicTalk")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
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
                    ForEach(Array(sessionsViewModel.displaySessions.prefix(10))) { displaySession in
                        NavigationLink(destination: SessionFeedbackWrapper(session: displaySession)) {
                            SessionCard(session: displaySession)
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
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: SessionDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // AsyncImage for loading actual session image
            AsyncImage(url: URL(string: session.imageUrl)) { image in
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
                Text(session.title)
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
                    if session.keyTermsCount > 0 {
                        Label("\(session.keyTermsCount)", systemImage: "book.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    // Suggestions count
                    if session.suggestionsCount > 0 {
                        Label("\(session.suggestionsCount)", systemImage: "lightbulb.fill")
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

// MARK: - Session Feedback Wrapper

struct SessionFeedbackWrapper: View {
    let session: SessionDisplayItem
    @State private var showFeedbackView = true

    var body: some View {
        FeedbackView(showFeedbackView: $showFeedbackView, session: session)
    }
}

#Preview {
    HomeView()
}
