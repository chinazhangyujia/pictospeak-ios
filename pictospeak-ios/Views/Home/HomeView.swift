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
    @EnvironmentObject private var sessionsViewModel: PastSessionsViewModel
    @StateObject private var materialsModel: InternalUploadedMaterialsViewModel = .init()
    @State private var selectedMode: NavigationMode = .home
    @State private var hasLoadedInitialData = false
    @State private var isLoadingMoreSessions = false
    @State private var showDeleteToast = false

    enum NavigationMode {
        case home
        case review
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12:
            return NSLocalizedString("home.greeting.morning", comment: "Good morning")
        case 12 ..< 17:
            return NSLocalizedString("home.greeting.afternoon", comment: "Good afternoon")
        default:
            return NSLocalizedString("home.greeting.evening", comment: "Good evening")
        }
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
            .background(AppTheme.backgroundGradient)

            // Loading overlay for refresh
            if sessionsViewModel.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("home.loadingSessions")
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
        }
        .task {
            // Load internal materials if not yet loaded (public content)
            if materialsModel.materials.isEmpty && !materialsModel.isLoading {
                await materialsModel.loadInitialMaterials()
            }

            // Only load sessions if we have an auth token and haven't loaded initial data yet
            if contentViewModel.authToken != nil && !hasLoadedInitialData {
                sessionsViewModel.clearError() // Clear any stale errors
                await sessionsViewModel.loadInitialSessions()
                hasLoadedInitialData = true
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarRole(.browser)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(greeting)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .kerning(0.4)
                    .foregroundColor(.primary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    router.goTo(.settings)
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
            // When token becomes available, load data
            if oldValue == nil && newValue != nil {
                print("🔐 Auth token became available, loading data")
                Task {
                    sessionsViewModel.clearError()
                    await sessionsViewModel.loadInitialSessions()
                    await materialsModel.loadInitialMaterials()
                }
            }
        }
        .toast(isPresented: $showDeleteToast, message: NSLocalizedString("home.sessionDeleted", comment: "Session deleted"), icon: "trash.fill")
    }

    private var internalMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("home.startTalking")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .kerning(-0.45)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    materialsModel.setCurrentIndex(0)
                    router.goTo(.speakFromMaterials(materialsModel: materialsModel))
                }) {
                    HStack(spacing: 4) {
                        Text("common.seeAll")
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
                    Text("home.loadingMaterials")
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
                            .contentShape(Rectangle()) // Ensures the entire area is tappable
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
                    Text("home.review.title")
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundColor(.black)
                        .kerning(-0.4)

                    Text("home.review.subtitle")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))
                        .kerning(-0.1)
                }

                Spacer()

                Button("home.review.start") {
                    router.goTo(.review(initialTab: .vocabulary))
                }
                .font(.system(size: 15, weight: .semibold, design: .default))
                .kerning(-0.23)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(width: 115, height: 34)
                .background(AppTheme.primaryBlue)
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
                Text("home.recentSessions.title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    router.goTo(.review(initialTab: .sessions))
                }) {
                    HStack(spacing: 4) {
                        Text("common.seeAll")
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 19, weight: .semibold, design: .default))
                            .foregroundColor(Color(red: 0.0, green: 0.533, blue: 1.0))
                    }
                }
            }

            LazyVStack(spacing: 12) {
                ForEach(Array(sessionsViewModel.sessions.enumerated()), id: \.element.id) { _, session in
                    SwipeToDeleteContainer(cornerRadius: 26, onDelete: {
                        let success = await sessionsViewModel.deleteSession(sessionId: session.id)
                        if success {
                            withAnimation {
                                showDeleteToast = true
                            }
                        }
                    }, onTap: {
                        router.goTo(.feedbackFromSession(sessionId: session.id, pastSessionsViewModel: sessionsViewModel))
                    }) {
                        SessionCard(session: session)
                    }
                    .onAppear {
                        loadMoreSessionsIfNeeded(currentSession: session)
                    }
                }

                if (sessionsViewModel.isLoading || isLoadingMoreSessions) && !sessionsViewModel.sessions.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("home.loadingMore")
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

    private func loadMoreSessionsIfNeeded(currentSession: SessionItem) {
        guard let currentIndex = sessionsViewModel.sessions.firstIndex(where: { $0.id == currentSession.id }) else {
            return
        }

        let totalItems = sessionsViewModel.sessions.count
        let isNearEnd = currentIndex >= totalItems - 1

        guard isNearEnd,
              sessionsViewModel.hasMorePages,
              !sessionsViewModel.isLoading,
              !isLoadingMoreSessions
        else {
            return
        }

        isLoadingMoreSessions = true

        Task {
            await sessionsViewModel.loadMoreSessions()
            await MainActor.run {
                isLoadingMoreSessions = false
            }
        }
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
                    CachedAsyncImage(url: URL(string: material.materialUrl)) { image in
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
                        CachedAsyncImage(url: URL(string: thumbnailUrl)) { image in
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
        .environmentObject(ContentViewModel())
}
