//
//  FeedbackView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import AVFoundation
import AVKit
import SwiftUI

// MARK: - FeedbackView

struct FeedbackView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var viewModel: FeedbackViewModel
    @State private var selectedTab: FeedbackTab = .aiRefined
    @State private var expandedCards: Set<UUID> = []
    @State private var backgroundVideoPlayer: AVPlayer?
    @State private var backgroundVideoObserver: NSObjectProtocol?
    let sessionId: UUID?
    var session: SessionItem? {
        pastSessionsViewModel.sessions.first { $0.id == sessionId }
    }

    @ObservedObject private var pastSessionsViewModel: PastSessionsViewModel

    // Thinking process animation
    @State private var currentThinkingStep = 0
    @State private var thinkingTimer: Timer?
    private let thinkingSteps = [
        "Organizing your input…",
        "Distilling key ideas…",
        "Polishing for natural phrasing…",
        "Picking & highlighting keywords…",
        "Almost ready…",
    ]

    // For normal feedback mode
    let selectedImage: UIImage?
    let selectedVideo: URL?
    let audioData: Data?
    let mediaType: MediaType?

    // Default initializer for normal use
    init(selectedImage: UIImage?, selectedVideo: URL?, audioData: Data?, mediaType: MediaType) {
        self.selectedImage = selectedImage
        self.selectedVideo = selectedVideo
        self.audioData = audioData
        self.mediaType = mediaType
        if let selectedVideo {
            _backgroundVideoPlayer = State(initialValue: FeedbackView.makeBackgroundPlayer(for: selectedVideo))
        } else {
            _backgroundVideoPlayer = State(initialValue: nil)
        }
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(contentViewModel: ContentViewModel()))
        sessionId = nil
        _pastSessionsViewModel = ObservedObject(wrappedValue: PastSessionsViewModel(contentViewModel: ContentViewModel()))
    }

    // Initializer for previews with fake data
    init(selectedImage: UIImage?, selectedVideo: URL?, audioData: Data?, mediaType: MediaType, previewData: FeedbackResponse) {
        self.selectedImage = selectedImage
        self.selectedVideo = selectedVideo
        self.audioData = audioData
        self.mediaType = mediaType
        if let selectedVideo {
            _backgroundVideoPlayer = State(initialValue: FeedbackView.makeBackgroundPlayer(for: selectedVideo))
        } else {
            _backgroundVideoPlayer = State(initialValue: nil)
        }
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(contentViewModel: ContentViewModel(), previewData: previewData))
        sessionId = nil
        _pastSessionsViewModel = ObservedObject(wrappedValue: PastSessionsViewModel(contentViewModel: ContentViewModel()))
    }

    init(sessionId: UUID, pastSessionsViewModel: PastSessionsViewModel) {
        self.sessionId = sessionId
        selectedImage = nil
        selectedVideo = nil
        audioData = nil
        mediaType = nil
        _backgroundVideoPlayer = State(initialValue: nil)
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(contentViewModel: ContentViewModel()))
        _pastSessionsViewModel = ObservedObject(wrappedValue: pastSessionsViewModel)
    }

    enum FeedbackTab {
        case mine, aiRefined
    }

    private enum PendingNavigation {
        case goBack
        case goHome
    }

    @State private var showSheet = true
    @State private var selectedDetent: PresentationDetent = .fraction(0.5)
    @State private var pendingNavigation: PendingNavigation?

    private var targetLanguageCode: String {
        let languageName = contentViewModel.userInfo.userSetting?.targetLanguage ?? "English"
        return LanguageService.getBCP47Code(for: languageName)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background Media
                if let selectedImage = selectedImage {
                    // Show directly passed image as background
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                } else if let player = backgroundVideoPlayer {
                    // Show video as background from either a directly selected video or a session material
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .disabled(true)
                        .onAppear {
                            player.play()
                        }
                } else if let session = session, let materialUrl = URL(string: session.materialUrl) {
                    // Show session's material as background - detect type from URL
                    let materialType = detectMaterialType(from: materialUrl)

                    if materialType == .image {
                        // Load session image asynchronously
                        AsyncImage(url: materialUrl) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .ignoresSafeArea()
                        } placeholder: {
                            // Placeholder while loading
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .ignoresSafeArea()
                        }
                    } else if materialType == .video {
                        // Placeholder while the background video player is being prepared
                        Rectangle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .ignoresSafeArea()
                    } else {
                        // Unknown material type - show placeholder
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .ignoresSafeArea()
                    }
                } else {
                    // No media available - show placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 0) {
                customHeader
                // Sheet Content
                if let session = session {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                                textComparisonSectionForSession(session, scrollProxy: proxy.scrollTo)
                                suggestionsAndKeyTermsSectionForSession(session)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                    }

                } else {
                    // Normal feedback mode - always show content with progressive skeleton loading
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                                // Always show the sections - they will handle their own skeleton loading
                                if let feedback = viewModel.feedbackResponse {
                                    textComparisonSection(feedback, scrollProxy: proxy.scrollTo)
                                    suggestionsAndKeyTermsSection(feedback)
                                } else {
                                    // Create empty feedback response for skeleton loading
                                    let emptyFeedback = FeedbackResponse(
                                        originalText: "",
                                        refinedText: "",
                                        suggestions: [],
                                        keyTerms: [],
                                        chosenKeyTerms: nil,
                                        chosenRefinements: nil,
                                        chosenItemsGenerated: false,
                                        pronunciationUrl: nil
                                    )
                                    textComparisonSection(emptyFeedback, scrollProxy: proxy.scrollTo)
                                    suggestionsAndKeyTermsSection(emptyFeedback)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                        // .background(Color(.systemGray6).opacity(0.95))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.fraction(0.15), .fraction(0.5), .fraction(0.95)], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .onDisappear {
                handlePendingNavigation()
            }
        }
        .onAppear {
            configureBackgroundVideoIfNeeded()

            viewModel.contentViewModel = contentViewModel
            pastSessionsViewModel.contentViewModel = contentViewModel

            // Only load feedback if we don't already have preview data and we're in normal mode
            if session == nil && viewModel.feedbackResponse == nil {
                startThinkingAnimation()
                guard let mediaType = mediaType else { return }
                viewModel.loadFeedback(
                    image: selectedImage,
                    videoURL: selectedVideo,
                    audioData: audioData,
                    mediaType: mediaType
                )
            }
        }
        .onChange(of: viewModel.feedbackResponse?.refinedText) { newValue in
            // Stop thinking animation when refined text is loaded
            if let newValue = newValue, !newValue.isEmpty {
                stopThinkingAnimation()
            }
        }
        .onChange(of: session?.materialUrl) { newValue in
            guard let urlString = newValue,
                  let url = URL(string: urlString)
            else {
                backgroundVideoPlayer?.pause()
                if let observer = backgroundVideoObserver {
                    NotificationCenter.default.removeObserver(observer)
                    backgroundVideoObserver = nil
                }
                backgroundVideoPlayer = nil
                return
            }

            let materialType = detectMaterialType(from: url)

            guard materialType == .video else {
                backgroundVideoPlayer?.pause()
                if let observer = backgroundVideoObserver {
                    NotificationCenter.default.removeObserver(observer)
                    backgroundVideoObserver = nil
                }
                backgroundVideoPlayer = nil
                return
            }

            if let existingAsset = backgroundVideoPlayer?.currentItem?.asset as? AVURLAsset,
               existingAsset.url == url
            {
                backgroundVideoPlayer?.play()
                return
            }

            backgroundVideoPlayer?.pause()
            if let observer = backgroundVideoObserver {
                NotificationCenter.default.removeObserver(observer)
                backgroundVideoObserver = nil
            }

            let player = FeedbackView.makeBackgroundPlayer(for: url)
            backgroundVideoPlayer = player
            backgroundVideoObserver = makeLoopObserver(for: player)
            player.play()
        }
        .onDisappear {
            // Stop thinking animation timer
            stopThinkingAnimation()
            backgroundVideoPlayer?.pause()
            if let observer = backgroundVideoObserver {
                NotificationCenter.default.removeObserver(observer)
                backgroundVideoObserver = nil
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Text Comparison Section

    private func textComparisonSection(_ feedback: FeedbackResponse, scrollProxy: @escaping (UUID, UnitPoint?) -> Void) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    // Background pill always full width
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color(red: 0.463, green: 0.463, blue: 0.502, opacity: 0.12))

                    // Content sits inside with padding
                    HStack(spacing: 0) {
                        Group {
                            if feedback.refinedText.isEmpty {
                                SkeletonPlaceholder(width: 60, height: 20)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Mine")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedTab == .mine ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 100))
                        .onTapGesture { selectedTab = .mine }

                        Group {
                            if feedback.refinedText.isEmpty {
                                SkeletonPlaceholder(width: 80, height: 20)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("AI Refined")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedTab == .aiRefined ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 100))
                        .onTapGesture { selectedTab = .aiRefined }
                    }
                    .padding(4)
                }
                .frame(maxWidth: .infinity)

                // Speaker Icon
                if selectedTab == .aiRefined, let pronunciationUrl = feedback.pronunciationUrl, !pronunciationUrl.isEmpty {
                    AudioPlayerButton(
                        audioUrl: pronunciationUrl,
                        foregroundColorPlaying: AppTheme.primaryBlue,
                        foregroundColorNotPlaying: Color(red: 0.549, green: 0.549, blue: 0.549), // #8c8c8c 100%
                        backgroundColorPlaying: AppTheme.lightBlueBackground, // #E9EEFF 60%
                        backgroundColorNotPlaying: .clear
                    )
                }
            }
            .frame(maxWidth: .infinity)

            // Text Content
            VStack(alignment: .leading, spacing: 0) {
                if selectedTab == .mine {
                    if feedback.refinedText.isEmpty {
                        // Show animated thinking process and skeleton placeholders when refinedText is empty
                        VStack(alignment: .leading, spacing: 12) {
                            // Animated thinking process step
                            ThinkingProcessView(
                                currentStep: currentThinkingStep,
                                thinkingSteps: thinkingSteps
                            )
                            .padding(.bottom, 8)

                            // Skeleton placeholders
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonPlaceholder(width: 200, height: 16)
                                SkeletonPlaceholder(width: 230, height: 16)
                                SkeletonPlaceholder(width: 180, height: 16)
                            }
                        }
                    } else {
                        Text(feedback.originalText)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                            .lineSpacing(7)
                            .kerning(-0.43) // Letter spacing -0.43px
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    // AI Refined text with clickable matches
                    let clickableMatches = getClickableMatches(from: feedback)

                    if feedback.refinedText.isEmpty {
                        // Show animated thinking process and skeleton placeholders when refinedText is empty
                        VStack(alignment: .leading, spacing: 12) {
                            // Animated thinking process step
                            ThinkingProcessView(
                                currentStep: currentThinkingStep,
                                thinkingSteps: thinkingSteps
                            )
                            .padding(.bottom, 8)

                            // Skeleton placeholders
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonPlaceholder(width: 200, height: 16)
                                SkeletonPlaceholder(width: 230, height: 16)
                                SkeletonPlaceholder(width: 180, height: 16)
                            }
                        }
                    } else {
                        ClickableHighlightedTextView(
                            text: feedback.refinedText,
                            clickableMatches: clickableMatches
                        ) { match in
                            handleTextTap(match: match, feedback: feedback, scrollProxy: scrollProxy)
                        }
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                        .lineSpacing(7)
                        .kerning(-0.43) // Letter spacing -0.43px
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(red: 0.961, green: 0.961, blue: 0.961, opacity: 0.6))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Suggestions and Key Terms Section

    private func suggestionsAndKeyTermsSection(_ feedback: FeedbackResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section title - show waving placeholder if no chosen items loaded yet
            if let chosenKeyTerms = feedback.chosenKeyTerms, let chosenRefinements = feedback.chosenRefinements, chosenKeyTerms.isEmpty && chosenRefinements.isEmpty {
                // don't show anything
            } else {
                Text("Vocabulary")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.top, 5)
                    .padding(.bottom, 10)
            }

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 20) {
                // Key Terms - show chosenKeyTerms if available and generated, otherwise show skeleton
                if let chosenKeyTerms = feedback.chosenKeyTerms {
                    // Show cards based on chosen items when they are generated
                    ForEach(Array(chosenKeyTerms.enumerated()), id: \.offset) { index, chosenTerm in
                        // Find matching real keyTerm if available
                        let matchingKeyTerm = feedback.keyTerms.first { $0.term == chosenTerm }

                        // Create a card with chosen data + real data if available
                        let displayKeyTerm = KeyTerm(
                            term: chosenTerm, // Always use chosen term
                            translation: matchingKeyTerm?.translation ?? "", // Real translation or empty for skeleton
                            example: matchingKeyTerm?.example ?? "", // Real example or empty for skeleton
                            favorite: matchingKeyTerm?.favorite ?? false,
                            id: matchingKeyTerm?.id ?? UUID() // Use real ID if available
                        )

                        KeyTermCard(
                            keyTerm: displayKeyTerm,
                            isExpanded: matchingKeyTerm != nil ? expandedCards.contains(displayKeyTerm.id) : false,
                            onToggle: {
                                if let realKeyTerm = matchingKeyTerm {
                                    // Only allow expansion if we have real data
                                    if expandedCards.contains(displayKeyTerm.id) {
                                        expandedCards.remove(displayKeyTerm.id)
                                    } else {
                                        expandedCards.insert(displayKeyTerm.id)
                                    }
                                }
                            },
                            onFavoriteToggle: { termId, isFavorite in
                                // Only proceed if the keyTerm is fully loaded (has all required data)
                                guard !displayKeyTerm.term.isEmpty, !displayKeyTerm.translation.isEmpty, !displayKeyTerm.example.isEmpty else {
                                    return
                                }

                                viewModel.updateKeyTermFavoriteLocally(termId: termId, isFavorite: isFavorite)

                                // Update server-side favorite status
                                Task {
                                    do {
                                        try await FavoriteService.shared.updateKeyTermFavorite(
                                            authToken: contentViewModel.authToken!,
                                            termId: termId.uuidString,
                                            favorite: isFavorite
                                        )
                                        print("✅ Successfully updated key term favorite on server: \(termId) -> \(isFavorite)")
                                    } catch {
                                        print("❌ Failed to update key term favorite on server: \(error)")
                                    }
                                }
                            },
                            languageCode: targetLanguageCode
                        )
                        .id("chosen-keyterm-\(index)")
                    }
                } else {
                    // Show fake waving cards when chosen items are not generated
                    ForEach(0 ..< 2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 10) {
                                    SkeletonPlaceholder(width: 100, height: 16)
                                    SkeletonPlaceholder(width: 150, height: 14)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                VStack(spacing: 10) {
                                    SkeletonPlaceholder(width: 16, height: 16)
                                    SkeletonPlaceholder(width: 16, height: 16)
                                }
                            }
                            .padding(16)
                        }
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Suggestions - show chosenRefinements if available and generated, otherwise show skeleton
                if let chosenRefinements = feedback.chosenRefinements {
                    // Show cards based on chosen items when they are generated
                    ForEach(Array(chosenRefinements.enumerated()), id: \.offset) { index, chosenRefinement in
                        // Find matching real suggestion if available
                        let matchingSuggestion = feedback.suggestions.first {
                            $0.term + $0.refinement == chosenRefinement || $0.refinement == chosenRefinement
                        }

                        // Create a card with chosen data + real data if available
                        let displaySuggestion = Suggestion(
                            term: matchingSuggestion?.term ?? "", // Real term or empty for skeleton
                            refinement: chosenRefinement, // Always use chosen refinement
                            translation: matchingSuggestion?.translation ?? "", // Real translation or empty for skeleton
                            reason: matchingSuggestion?.reason ?? "", // Real reason or empty for skeleton
                            favorite: matchingSuggestion?.favorite ?? false, // Real favorite status or false for skeleton
                            id: matchingSuggestion?.id ?? UUID() // Use real ID if available
                        )

                        SuggestionCard(
                            suggestion: displaySuggestion,
                            isExpanded: matchingSuggestion != nil ? expandedCards.contains(displaySuggestion.id) : false,
                            onToggle: {
                                if let realSuggestion = matchingSuggestion {
                                    // Only allow expansion if we have real data
                                    if expandedCards.contains(displaySuggestion.id) {
                                        expandedCards.remove(displaySuggestion.id)
                                    } else {
                                        expandedCards.insert(displaySuggestion.id)
                                    }
                                }
                            },
                            onFavoriteToggle: { suggestionId, isFavorite in
                                // Only proceed if the suggestion is fully loaded (has all required data)
                                guard !displaySuggestion.term.isEmpty, !displaySuggestion.refinement.isEmpty, !displaySuggestion.translation.isEmpty, !displaySuggestion.reason.isEmpty else {
                                    return
                                }

                                viewModel.updateSuggestionFavoriteLocally(suggestionId: suggestionId, isFavorite: isFavorite)

                                // Update server-side favorite status
                                Task {
                                    do {
                                        try await FavoriteService.shared.updateSuggestionFavorite(
                                            authToken: contentViewModel.authToken!,
                                            suggestionId: suggestionId.uuidString,
                                            favorite: isFavorite
                                        )
                                        print("✅ Successfully updated suggestion favorite on server: \(suggestionId) -> \(isFavorite)")
                                    } catch {
                                        print("❌ Failed to update suggestion favorite on server: \(error)")
                                    }
                                }
                            },
                            languageCode: targetLanguageCode
                        )
                        .id("chosen-suggestion-\(index)")
                    }
                } else {
                    // Show fake waving cards when chosen items are not generated
                    ForEach(0 ..< 2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonPlaceholder(width: 100, height: 16)
                                    SkeletonPlaceholder(width: 150, height: 14)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                VStack(spacing: 10) {
                                    SkeletonPlaceholder(width: 16, height: 16)
                                    SkeletonPlaceholder(width: 16, height: 16)
                                }
                            }
                            .padding(16)
                        }
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Session Viewing Mode Methods

    private func textComparisonSectionForSession(_ session: SessionItem, scrollProxy: @escaping (UUID, UnitPoint?) -> Void) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    // Background pill always full width
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color(red: 0.463, green: 0.463, blue: 0.502, opacity: 0.12))

                    // Content sits inside with padding
                    HStack(spacing: 0) {
                        Text("Mine")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == .mine ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .onTapGesture { selectedTab = .mine }

                        Text("AI Refined")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == .aiRefined ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .onTapGesture { selectedTab = .aiRefined }
                    }
                    .padding(4)
                }
                .frame(maxWidth: .infinity)

                // Speaker Icon
                if selectedTab == .aiRefined, let pronunciationUrl = session.pronunciationUrl, !pronunciationUrl.isEmpty {
                    AudioPlayerButton(
                        audioUrl: pronunciationUrl,
                        foregroundColorPlaying: AppTheme.primaryBlue,
                        foregroundColorNotPlaying: Color(red: 0.549, green: 0.549, blue: 0.549), // #8c8c8c 100%
                        backgroundColorPlaying: AppTheme.lightBlueBackground, // #E9EEFF 60%
                        backgroundColorNotPlaying: .clear
                    )
                }
            }
            .frame(maxWidth: .infinity)

            let clickableMatches = getClickableMatches(from: session)

            // Text Content - always show actual data from session
            VStack(alignment: .leading, spacing: 0) {
                if selectedTab == .mine {
                    Text(session.userDescription)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                        .lineSpacing(7)
                        .kerning(-0.43) // Letter spacing -0.43px
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ClickableHighlightedTextView(
                        text: session.standardDescription,
                        clickableMatches: clickableMatches
                    ) { match in
                        handleTextTap(match: match, session: session, scrollProxy: scrollProxy)
                    }
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.black)
                    .lineSpacing(7)
                    .kerning(-0.43) // Letter spacing -0.43px
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(AppTheme.feedbackCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var customHeader: some View {
        HStack {
            Image(systemName: "xmark")
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .glassEffect(.clear.tint(AppTheme.backButtonGray))
                .blendMode(.multiply)
                .onTapGesture {
                    pendingNavigation = .goBack
                    withAnimation {
                        showSheet = false
                    }
                }

            Spacer()

            Text("AI feedback")
                .font(.headline)
                .fontWeight(.regular)

            Spacer()

            Image(systemName: "checkmark")
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .glassEffect(.clear.tint(AppTheme.primaryBlue))
                .onTapGesture {
                    pendingNavigation = .goHome
                    withAnimation {
                        showSheet = false
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, 30)
    }

    private func handlePendingNavigation() {
        guard let action = pendingNavigation else { return }
        pendingNavigation = nil

        DispatchQueue.main.async {
            switch action {
            case .goBack:
                router.goBack()
            case .goHome:
                router.resetToHome()
            }
        }
    }

    private func suggestionsAndKeyTermsSectionForSession(_ session: SessionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section title - always show since session data is already loaded
            Text("Vocabulary")
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 22)
                .padding(.top, 5)
                .padding(.bottom, 10)

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 20) {
                // Key Terms - always show actual data from session
                ForEach(session.keyTerms) { keyTerm in
                    KeyTermCard(
                        keyTerm: keyTerm,
                        isExpanded: expandedCards.contains(keyTerm.id),
                        onToggle: {
                            if expandedCards.contains(keyTerm.id) {
                                expandedCards.remove(keyTerm.id)
                            } else {
                                expandedCards.insert(keyTerm.id)
                            }
                        },
                        onFavoriteToggle: { termId, isFavorite in
                            // Only proceed if the keyTerm is fully loaded (has all required data)
                            guard !keyTerm.term.isEmpty, !keyTerm.translation.isEmpty, !keyTerm.example.isEmpty else {
                                return
                            }

                            pastSessionsViewModel.updateKeyTermFavorite(
                                sessionId: session.id,
                                termId: termId,
                                favorite: isFavorite
                            )

                            // Update server-side favorite status
                            Task {
                                do {
                                    try await FavoriteService.shared.updateKeyTermFavorite(
                                        authToken: contentViewModel.authToken!,
                                        termId: termId.uuidString,
                                        favorite: isFavorite
                                    )
                                    print("✅ Successfully updated key term favorite on server: \(termId) -> \(isFavorite)")
                                } catch {
                                    print("❌ Failed to update key term favorite on server: \(error)")
                                }
                            }
                        },
                        languageCode: targetLanguageCode
                    )
                    .id(keyTerm.id)
                }

                // Suggestions - always show actual data from session
                ForEach(session.suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        isExpanded: expandedCards.contains(suggestion.id),
                        onToggle: {
                            if expandedCards.contains(suggestion.id) {
                                expandedCards.remove(suggestion.id)
                            } else {
                                expandedCards.insert(suggestion.id)
                            }
                        },
                        onFavoriteToggle: { suggestionId, isFavorite in
                            // Only proceed if the suggestion is fully loaded (has all required data)
                            guard !suggestion.term.isEmpty, !suggestion.refinement.isEmpty, !suggestion.translation.isEmpty, !suggestion.reason.isEmpty else {
                                return
                            }

                            pastSessionsViewModel.updateSuggestionFavorite(
                                sessionId: session.id,
                                suggestionId: suggestionId,
                                favorite: isFavorite
                            )

                            // Update server-side favorite status
                            Task {
                                do {
                                    try await FavoriteService.shared.updateSuggestionFavorite(
                                        authToken: contentViewModel.authToken!,
                                        suggestionId: suggestionId.uuidString,
                                        favorite: isFavorite
                                    )
                                    print("✅ Successfully updated suggestion favorite on server: \(suggestionId) -> \(isFavorite)")
                                } catch {
                                    print("❌ Failed to update suggestion favorite on server: \(error)")
                                }
                            }
                        },
                        languageCode: targetLanguageCode
                    )
                    .id(suggestion.id)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func detectMaterialType(from url: URL) -> MediaType {
        let pathExtension = url.pathExtension.lowercased()

        // Common image extensions
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"]
        // Common video extensions
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "3gp"]

        if imageExtensions.contains(pathExtension) {
            return .image
        } else if videoExtensions.contains(pathExtension) {
            return .video
        } else {
            return .image // Default to image if unknown
        }
    }

    private static func makeBackgroundPlayer(for url: URL) -> AVPlayer {
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        return player
    }

    private func configureBackgroundVideoIfNeeded() {
        if let player = backgroundVideoPlayer {
            if backgroundVideoObserver == nil {
                backgroundVideoObserver = makeLoopObserver(for: player)
            }
            player.play()
            return
        }

        if let selectedVideo {
            if let observer = backgroundVideoObserver {
                NotificationCenter.default.removeObserver(observer)
                backgroundVideoObserver = nil
            }
            let player = FeedbackView.makeBackgroundPlayer(for: selectedVideo)
            backgroundVideoPlayer = player
            backgroundVideoObserver = makeLoopObserver(for: player)
            player.play()
        } else if let session,
                  let materialUrl = URL(string: session.materialUrl),
                  detectMaterialType(from: materialUrl) == .video
        {
            if let observer = backgroundVideoObserver {
                NotificationCenter.default.removeObserver(observer)
                backgroundVideoObserver = nil
            }
            let player = FeedbackView.makeBackgroundPlayer(for: materialUrl)
            backgroundVideoPlayer = player
            backgroundVideoObserver = makeLoopObserver(for: player)
            player.play()
        }
    }

    private func makeLoopObserver(for player: AVPlayer) -> NSObjectProtocol? {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    private func getClickableMatches(from feedback: FeedbackResponse) -> [ClickableTextMatch] {
        var matches: [ClickableTextMatch] = []
        let refinedText = feedback.refinedText
        let nsString = NSString(string: refinedText)

        // Check if chosen items are generated
        let chosenItemsGenerated = feedback.chosenItemsGenerated

        // Only use chosen key terms for highlighting when they are generated
        if let chosenKeyTerms = feedback.chosenKeyTerms, chosenItemsGenerated {
            for chosenTerm in chosenKeyTerms {
                var searchRange = NSRange(location: 0, length: nsString.length)

                while searchRange.location < nsString.length {
                    let foundRange = nsString.range(of: chosenTerm, options: [.caseInsensitive], range: searchRange)
                    if foundRange.location != NSNotFound {
                        // Find the corresponding keyTerm to get its ID
                        if let keyTerm = feedback.keyTerms.first(where: { $0.term == chosenTerm }) {
                            matches.append(ClickableTextMatch(
                                range: foundRange,
                                text: chosenTerm,
                                cardType: .keyTerm,
                                cardId: keyTerm.id
                            ))
                        }

                        // Move search range past this match
                        searchRange.location = foundRange.location + foundRange.length
                        searchRange.length = nsString.length - searchRange.location
                    } else {
                        break
                    }
                }
            }
        }

        // Only use chosen refinements for highlighting when they are generated
        if let chosenRefinements = feedback.chosenRefinements, chosenItemsGenerated {
            for chosenRefinement in chosenRefinements {
                var searchRange = NSRange(location: 0, length: nsString.length)

                while searchRange.location < nsString.length {
                    let foundRange = nsString.range(of: chosenRefinement, options: [.caseInsensitive], range: searchRange)
                    if foundRange.location != NSNotFound {
                        // Find the corresponding suggestion to get its ID
                        if let suggestion = feedback.suggestions.first(where: { $0.refinement == chosenRefinement }) {
                            matches.append(ClickableTextMatch(
                                range: foundRange,
                                text: chosenRefinement,
                                cardType: .suggestion,
                                cardId: suggestion.id
                            ))
                        }

                        // Move search range past this match
                        searchRange.location = foundRange.location + foundRange.length
                        searchRange.length = nsString.length - searchRange.location
                    } else {
                        break
                    }
                }
            }
        }

        // Sort matches by their position in the text to handle overlaps properly
        return matches.sorted { $0.range.location < $1.range.location }
    }

    private func getClickableMatches(from session: SessionItem) -> [ClickableTextMatch] {
        var matches: [ClickableTextMatch] = []
        let refinedText = session.standardDescription
        let nsString = NSString(string: refinedText)

        // Only use chosen key terms for highlighting when they are generated
        for chosenTerm in session.keyTerms {
            var searchRange = NSRange(location: 0, length: nsString.length)

            while searchRange.location < nsString.length {
                let foundRange = nsString.range(of: chosenTerm.term, options: [.caseInsensitive], range: searchRange)
                if foundRange.location != NSNotFound {
                    // Find the corresponding keyTerm to get its ID
                    if let keyTerm = session.keyTerms.first(where: { $0.term == chosenTerm.term }) {
                        matches.append(ClickableTextMatch(
                            range: foundRange,
                            text: chosenTerm.term,
                            cardType: .keyTerm,
                            cardId: keyTerm.id
                        ))
                    }

                    // Move search range past this match
                    searchRange.location = foundRange.location + foundRange.length
                    searchRange.length = nsString.length - searchRange.location
                } else {
                    break
                }
            }
        }

        // Only use chosen refinements for highlighting when they are generated
        for chosenSuggestion in session.suggestions {
            var searchRange = NSRange(location: 0, length: nsString.length)

            while searchRange.location < nsString.length {
                let foundRange = nsString.range(of: chosenSuggestion.refinement, options: [.caseInsensitive], range: searchRange)
                if foundRange.location != NSNotFound {
                    // Find the corresponding suggestion to get its ID
                    if let suggestion = session.suggestions.first(where: { $0.refinement == chosenSuggestion.refinement }) {
                        matches.append(ClickableTextMatch(
                            range: foundRange,
                            text: chosenSuggestion.refinement,
                            cardType: .suggestion,
                            cardId: suggestion.id
                        ))
                    }

                    // Move search range past this match
                    searchRange.location = foundRange.location + foundRange.length
                    searchRange.length = nsString.length - searchRange.location
                } else {
                    break
                }
            }
        }

        // Sort matches by their position in the text to handle overlaps properly
        return matches.sorted { $0.range.location < $1.range.location }
    }

    private func handleTextTap(match: ClickableTextMatch, feedback: FeedbackResponse, scrollProxy: @escaping (UUID, UnitPoint?) -> Void) {
        // Verify that the corresponding card actually exists
        let cardExists: Bool
        switch match.cardType {
        case .keyTerm:
            cardExists = feedback.keyTerms.contains { $0.id == match.cardId }
        case .suggestion:
            cardExists = feedback.suggestions.contains { $0.id == match.cardId }
        }

        // Only respond if the card exists
        guard cardExists else {
            return
        }

        // Expand the corresponding card
        expandedCards.insert(match.cardId)

        // Scroll to the card with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            scrollProxy(match.cardId, UnitPoint.center)
        }
    }

    private func handleTextTap(match: ClickableTextMatch, session: SessionItem, scrollProxy: @escaping (UUID, UnitPoint?) -> Void) {
        // Verify that the corresponding card actually exists
        let cardExists: Bool
        switch match.cardType {
        case .keyTerm:
            cardExists = session.keyTerms.contains { $0.id == match.cardId }
        case .suggestion:
            cardExists = session.suggestions.contains { $0.id == match.cardId }
        }

        // Only respond if the card exists
        guard cardExists else {
            return
        }

        // Expand the corresponding card
        expandedCards.insert(match.cardId)

        // Scroll to the card with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            scrollProxy(match.cardId, UnitPoint.center)
        }
    }

    // MARK: - Thinking Process View

    struct ThinkingProcessView: View {
        let currentStep: Int
        let thinkingSteps: [String]

        var body: some View {
            Text(thinkingSteps[currentStep])
                .font(.system(size: 16, weight: .regular, design: .default))
                .italic()
                .foregroundColor(.secondary)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
    }

    // MARK: - Thinking Animation Methods

    private func startThinkingAnimation() {
        // Stop any existing timer
        stopThinkingAnimation()

        // Start new timer that cycles through thinking steps every 1.5 seconds
        thinkingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentThinkingStep = (currentThinkingStep + 1) % thinkingSteps.count
            }
        }
    }

    private func stopThinkingAnimation() {
        thinkingTimer?.invalidate()
        thinkingTimer = nil
    }

    // MARK: - Self-Sizing Text View

    private class SelfSizingTextView: UITextView {
        override var intrinsicContentSize: CGSize {
            let size = sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            invalidateIntrinsicContentSize()
        }
    }

    // MARK: - Clickable Highlighted Text View

    struct ClickableHighlightedTextView: UIViewRepresentable {
        let text: String
        let clickableMatches: [ClickableTextMatch]
        let onTap: (ClickableTextMatch) -> Void

        func makeUIView(context: Context) -> UITextView {
            let textView = SelfSizingTextView()
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.backgroundColor = UIColor.clear
            textView.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            textView.textContainerInset = UIEdgeInsets.zero
            textView.textContainer.lineFragmentPadding = 0
            textView.delegate = context.coordinator

            // Set proper text container constraints
            textView.textContainer.widthTracksTextView = true
            textView.textContainer.maximumNumberOfLines = 0
            textView.textContainer.lineBreakMode = .byWordWrapping

            // Ensure the text view doesn't expand beyond its container
            textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            // Add tap gesture recognizer
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
            textView.addGestureRecognizer(tapGesture)
            context.coordinator.textView = textView

            return textView
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            let attributedString = createAttributedString()
            uiView.attributedText = attributedString

            // Store matches in coordinator for tap handling
            context.coordinator.clickableMatches = clickableMatches
            context.coordinator.onTap = onTap

            // Update intrinsic content size after setting text
            uiView.invalidateIntrinsicContentSize()
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        private func createAttributedString() -> NSAttributedString {
            let attributedString = NSMutableAttributedString(string: text)

            // Create paragraph style for line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 7

            // Set base attributes matching the SwiftUI Text configuration
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle,
                .kern: -0.43,
            ]
            attributedString.addAttributes(baseAttributes, range: NSRange(location: 0, length: text.count))

            // Add styling for clickable matches
            for match in clickableMatches {
                let range = match.range

                // Add underline with vertical gap
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                attributedString.addAttribute(.underlineColor, value: UIColor(AppTheme.primaryBlue), range: range)

                // Add small vertical gap between text and underline
                attributedString.addAttribute(.baselineOffset, value: 2, range: range)

                // Make it look clickable
                attributedString.addAttribute(.foregroundColor, value: UIColor(AppTheme.primaryBlue), range: range)
                attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .medium), range: range)
            }

            return attributedString
        }

        class Coordinator: NSObject, UITextViewDelegate {
            var clickableMatches: [ClickableTextMatch] = []
            var onTap: ((ClickableTextMatch) -> Void)?
            weak var textView: UITextView?

            // iOS 17+ text item delegate methods
            @available(iOS 17.0, *)
            func textView(_: UITextView, primaryActionFor _: UITextItem, defaultAction _: UIAction) -> UIAction? {
                return nil
            }

            @available(iOS 17.0, *)
            func textView(_: UITextView, menuConfigurationFor _: UITextItem, defaultMenu _: UIMenu) -> UITextItem.MenuConfiguration? {
                return nil
            }

            // Fallback for older iOS versions
            func textView(_: UITextView, shouldInteractWith _: URL, in _: NSRange) -> Bool {
                return false
            }

            @objc func textViewDidChangeSelection(_ textView: UITextView) {
                // Prevent text selection - we want taps instead
                textView.selectedTextRange = nil
            }

            func textView(_: UITextView, shouldChangeTextIn _: NSRange, replacementText _: String) -> Bool {
                return false
            }

            @objc func handleTap(_ gesture: UITapGestureRecognizer) {
                guard let textView = textView else { return }

                let location = gesture.location(in: textView)
                let characterIndex = textView.layoutManager.characterIndex(for: location, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

                // Find if the tap is within any clickable match
                for match in clickableMatches {
                    if NSLocationInRange(characterIndex, match.range) {
                        onTap?(match)
                        break
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        FeedbackView(
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            selectedVideo: nil,
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "",
                refinedText: "",
                suggestions: [],
                keyTerms: [],
                chosenKeyTerms: ["Hello", "World"],
                chosenRefinements: ["Hi", "Earth"],
                chosenItemsGenerated: true
            ),
        )
    }
}

#Preview("Loading State - No Data") {
    NavigationView {
        FeedbackView(
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            selectedVideo: nil,
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "",
                refinedText: "",
                suggestions: [],
                keyTerms: [],
                chosenKeyTerms: nil,
                chosenRefinements: nil,
                chosenItemsGenerated: false
            ),
        )
    }
}

#Preview("Loading State - Chosen Items Only") {
    NavigationView {
        FeedbackView(
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            selectedVideo: nil,
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "This is some sample text",
                refinedText: "This is some improved sample text",
                suggestions: [],
                keyTerms: [],
                chosenKeyTerms: ["sample", "text"],
                chosenRefinements: ["improved", "better"],
                chosenItemsGenerated: true
            ),
        )
    }
}

#Preview("Fully Loaded") {
    NavigationView {
        FeedbackView(
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            selectedVideo: nil,
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "This is the original text that needs improvement.",
                refinedText: "This is the refined and improved text version.",
                suggestions: [
                    Suggestion(term: "text", refinement: "content", translation: "内容", reason: "More specific term", favorite: false, id: UUID()),
                    Suggestion(term: "needs", refinement: "requires", translation: "需要", reason: "More formal", favorite: false, id: UUID()),
                ],
                keyTerms: [
                    KeyTerm(term: "original", translation: "原始的", example: "This is the original version", favorite: false, id: UUID()),
                    KeyTerm(term: "improvement", translation: "改进", example: "We need to make improvements", favorite: false, id: UUID()),
                ],
                chosenKeyTerms: ["original", "improvement"],
                chosenRefinements: ["content", "requires"],
                chosenItemsGenerated: true
            ),
        )
    }
}
