//
//  HomeView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var sessionsViewModel: PastSessionsViewModel = .init(contentViewModel: ContentViewModel())
    @StateObject private var materialsModel: InternalUploadedMaterialsViewModel = .init(contentViewModel: ContentViewModel())
    @State private var selectedMode: NavigationMode = .home

    enum NavigationMode {
        case home
        case review
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Internal Materials Section
                    internalMaterialsSection

                    // Review Section
                    reviewSection

                    // Recent Sessions Section
                    recentSessionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 120) // Add bottom padding for navigation overlay
            }
            .background(Color(red: 0.965, green: 0.969, blue: 0.984))

            // Loading overlay for refresh
            if sessionsViewModel.isLoading {
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
        }
        .onAppear {
            sessionsViewModel.contentViewModel = contentViewModel
            materialsModel.contentViewModel = contentViewModel

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
                await materialsModel.loadInitialMaterials()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarRole(.browser)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Good evening!")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .kerning(0.4)
                    .foregroundColor(.primary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // contentViewModel.signOut()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .background(Color.white)
                        .clipShape(Circle())
                        .blendMode(.plusDarker)
                }
            }
        }
        .refreshable {
            await sessionsViewModel.refreshSessions()
            await materialsModel.refresh()
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
                    await materialsModel.loadInitialMaterials()
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
        .alert("Error Loading Materials", isPresented: .constant(materialsModel.errorMessage != nil)) {
            Button("OK") {
                materialsModel.errorMessage = nil
            }
            Button("Retry") {
                Task {
                    materialsModel.errorMessage = nil
                    await materialsModel.refresh()
                }
            }
        } message: {
            Text(materialsModel.errorMessage ?? "")
        }
    }

    private var internalMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("Start Talking")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .kerning(-0.45)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    materialsModel.setCurrentIndex(0)
                    router.goTo(.speakFromMaterials(materialsModel: materialsModel))
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 19, weight: .semibold, design: .default))
                            .foregroundColor(Color(red: 0.0, green: 0.533, blue: 1.0))
                    }
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 10)

            if materialsModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading materials...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(materialsModel.materials.prefix(10).enumerated()), id: \.element.id) { index, material in
                            Button(action: {
                                // Set the current index to the selected material
                                materialsModel.setCurrentIndex(index)
                                // Navigate to speak view with the materials model
                                router.goTo(.speakFromMaterials(materialsModel: materialsModel))
                            }) {
                                MaterialPreviewCard(material: material)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "book")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .opacity(1)
                .blendMode(.plusDarker)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Review today")
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundColor(.black)
                        .kerning(-0.4)

                    Text("Your saved vocabulary")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))
                        .kerning(-0.1)
                }

                Spacer()

                Button("Start review") {
                    // Handle review action
                }
                .font(.system(size: 15, weight: .semibold, design: .default))
                .kerning(-0.23)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(width: 115, height: 34)
                .background(Color(red: 0.247, green: 0.388, blue: 0.910))
                .clipShape(RoundedRectangle(cornerRadius: 1000))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.05), radius: 16, x: 0, y: 1)
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
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 19, weight: .semibold, design: .default))
                            .foregroundColor(Color(red: 0.0, green: 0.533, blue: 1.0))
                    }
                }
            }

            LazyVStack(spacing: 12) {
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
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)

                            Text("Load More")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else if sessionsViewModel.isLoading {
                    // Show loading indicator when loading
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Loading...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: SessionItem

    var body: some View {
        HStack(spacing: 10) {
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
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 1) {
                Text(session.standardDescription)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .kerning(-0.4)

                Text("Today")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))
                    .kerning(-0.1)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.02), radius: 16, x: 0, y: 1)
    }
}

// MARK: - Material Preview Card

struct MaterialPreviewCard: View {
    let material: Material

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Material content based on type
                if material.type == .image {
                    // Image content
                    AsyncImage(url: URL(string: material.materialUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Placeholder while loading
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: material.type.systemIconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 172, height: 306)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                } else {
                    // Video or Audio content - show thumbnail with play button
                    if let thumbnailUrl = material.thumbnailUrl, !thumbnailUrl.isEmpty {
                        // Use thumbnail if available
                        AsyncImage(url: URL(string: thumbnailUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: material.type.systemIconName)
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 172, height: 306)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    } else {
                        // Fallback to placeholder if no thumbnail, this should never happen because every video should have a thumbnail generated on backend
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 172, height: 306)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: material.type.systemIconName)
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                }
            }
        }
        .frame(width: 172, height: 306)
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
