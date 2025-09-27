//
//  ReviewView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI
import AVFoundation

// MARK: - Visibility Preference Key

struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct ReviewView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var reviewViewModel: ReviewViewModel
    @State private var selectedTab: ReviewTab = .vocabulary
    @State private var expandedKeyTerms: Set<UUID> = []
    @State private var expandedSuggestions: Set<UUID> = []
    @State private var hasLoadedInitialData = false
    @State private var isLoadingMore = false
    @State private var hasUserScrolled = false
    
    enum ReviewTab: String, CaseIterable {
        case vocabulary = "Vocabulary"
        case sessions = "Sessions"
    }
    
    init() {
        // Initialize with a temporary ContentViewModel - will be replaced by environment object
        self._reviewViewModel = StateObject(wrappedValue: ReviewViewModel(contentViewModel: ContentViewModel()))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Segmented Control
                Picker("Review Tab", selection: $selectedTab) {
                    ForEach(ReviewTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .controlSize(.large)
                .padding(.top, 16)
                
                // Content based on selected tab
                if selectedTab == .vocabulary {
                    vocabularyContent
                } else {
                    sessionsContent
                }
            }
            .padding(.horizontal, 16)
            .background(AppTheme.viewBackgroundGray)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        router.resetToHome()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .blendMode(.multiply)
                    }
                }
            }
        }
        .onAppear {
            // Initialize ReviewViewModel with the environment ContentViewModel
            if reviewViewModel.contentViewModel !== contentViewModel {
                reviewViewModel.contentViewModel = contentViewModel
            }
            
            // Check if auth token is nil on initial load and redirect to auth
            if contentViewModel.authToken == nil {
                print("🔐 No auth token on initial load, navigating to auth view")
                router.goTo(.auth)
            } else if !hasLoadedInitialData {
                // Load review items only on first appearance
                hasLoadedInitialData = true
                Task {
                    await reviewViewModel.loadInitialReviewItems()
                }
            }
        }
    }

    // MARK: - Vocabulary Content
    
    private var vocabularyContent: some View {
        VStack(alignment: .leading, spacing: 1) {
                // Vocabulary Section Header
                Text("Vocabulary")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 5)
                    .padding(.bottom, 10)
                
                // Loading State
                if reviewViewModel.isLoading && reviewViewModel.reviewItems.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading review items...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                
                // Error State
                if let errorMessage = reviewViewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await reviewViewModel.refreshReviewItems()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 40)
                }
                
                // Review Items Cards
                if !reviewViewModel.reviewItems.isEmpty {
                    List {
                        ForEach(Array(reviewViewModel.reviewItems.enumerated()), id: \.element.id) { index, reviewItem in
                            switch reviewItem.type {
                            case .keyTerm:
                                let keyTerm = reviewItem.toKeyTerm()
                                KeyTermCard(
                                    keyTerm: keyTerm,
                                    isExpanded: expandedKeyTerms.contains(keyTerm.id),
                                    onToggle: {
                                        if expandedKeyTerms.contains(keyTerm.id) {
                                            expandedKeyTerms.remove(keyTerm.id)
                                        } else {
                                            expandedKeyTerms.insert(keyTerm.id)
                                        }
                                    },
                                    onFavoriteToggle: { _, favorite in
                                        reviewViewModel.updateReviewItemFavorite(itemId: reviewItem.id, favorite: favorite)
                                    }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                                .onAppear {
                                    loadMoreContentIfNeeded(currentItem: reviewItem)
                                }
                            case .suggestion:
                                let suggestion = reviewItem.toSuggestion()
                                SuggestionCard(
                                    suggestion: suggestion,
                                    isExpanded: expandedSuggestions.contains(suggestion.id),
                                    onToggle: {
                                        if expandedSuggestions.contains(suggestion.id) {
                                            expandedSuggestions.remove(suggestion.id)
                                        } else {
                                            expandedSuggestions.insert(suggestion.id)
                                        }
                                    },
                                    onFavoriteToggle: { _, favorite in
                                        reviewViewModel.updateReviewItemFavorite(itemId: reviewItem.id, favorite: favorite)
                                    }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                                .onAppear {
                                    loadMoreContentIfNeeded(currentItem: reviewItem)
                                }
                            }
                        }
                        
                        // Loading More Indicator
                        if (reviewViewModel.isLoading || isLoadingMore) && !reviewViewModel.reviewItems.isEmpty {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(PlainListStyle())
                    .listRowSpacing(12)
                    .scrollContentBackground(.hidden)
                }
                
                // Empty State
                if !reviewViewModel.isLoading && reviewViewModel.reviewItems.isEmpty && reviewViewModel.errorMessage == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No review items yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Complete some sessions to see your vocabulary and suggestions here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    
                    Spacer() // Push content to top
                }
            }
        .refreshable {
            await reviewViewModel.refreshReviewItems()
        }
        .onAppear {
            // Set a timer to detect user scrolling
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                hasUserScrolled = true
                print("🔍 User scroll detection enabled")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadMoreContentIfNeeded(currentItem: ReviewItem) {
        // Only load more if this is one of the last few items and user has scrolled
        let currentIndex = reviewViewModel.reviewItems.firstIndex(where: { $0.id == currentItem.id }) ?? 0
        let totalItems = reviewViewModel.reviewItems.count
        let isNearEnd = currentIndex >= totalItems - 1 // Load when within 1 items of the end
        
        print("🔍 Item appeared: index \(currentIndex)/\(totalItems), isNearEnd: \(isNearEnd), hasUserScrolled: \(hasUserScrolled)")
        
        if isNearEnd &&
           reviewViewModel.hasMorePages && 
           !reviewViewModel.isLoading && 
           !isLoadingMore {
            print("🔄 Near end of list, triggering auto-load more")
            isLoadingMore = true
            Task {
                await reviewViewModel.loadMoreReviewItems()
                isLoadingMore = false
            }
        }
    }
    
    // MARK: - Sessions Content
    
    private var sessionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sessions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                Text("Sessions content will be implemented here")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }
}


#Preview {
    ReviewView()
        .environmentObject(Router())
        .environmentObject(ContentViewModel())
}
