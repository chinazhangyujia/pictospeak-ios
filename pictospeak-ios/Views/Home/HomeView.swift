//
//  HomeView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
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
            Button(action: {
                // Start new PicTalk action
            }) {
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
                HStack(spacing: 16) {
                    ForEach(sampleSessions, id: \.id) { session in
                        SessionCard(session: session)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder for image/thumbnail
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 140, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(session.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)

                Text(session.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140)
    }
}

// MARK: - Session Model

struct Session {
    let id = UUID()
    let title: String
    let message: String
    let timeAgo: String
}

// MARK: - Sample Data

private let sampleSessions = [
    Session(title: "Coffee Shop", message: "Can I have a coffee? Can I have a coffee? Can I have a coffee?", timeAgo: "Yesterday"),
    Session(title: "Grocery Shopping", message: "Where is the milk?", timeAgo: "2 days ago"),
    Session(title: "Hospital", message: "I have an appointment", timeAgo: "3 days ago"),
    Session(title: "Restaurant", message: "What's on the menu?", timeAgo: "1 week ago"),
]

#Preview {
    HomeView()
}
