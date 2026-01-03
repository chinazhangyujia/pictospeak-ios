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

    // Teaching Overlay State
    @State private var showTeachingOverlay = false
    @State private var teachingOverlayRect: CGRect = .zero
    @State private var isOverlayCardExpanded = false

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
            .coordinateSpace(name: "feedbackSheet")
            .overlay(
                Group {
                    if showTeachingOverlay {
                        GeometryReader { proxy in
                            ZStack(alignment: .topLeading) {
                                Color.black.opacity(0.2)
                                    .edgesIgnoringSafeArea(.all)
                                    .onTapGesture { showTeachingOverlay = false }

                                // Unified Card Logic to prevent jumping
                                let keyTermToDisplay: KeyTerm = viewModel.keyTermTeachingResponse?.keyTerm ?? KeyTerm(
                                    term: "",
                                    translations: [],
                                    reason: TermReason(reason: "", reasonTranslation: ""),
                                    example: TermExample(sentence: "", sentenceTranslation: ""),
                                    favorite: false
                                )

                                // Convert the teaching rect (in global coords) into this overlay's local space
                                let overlayTop = teachingOverlayRect.maxY + 12 - proxy.frame(in: .global).minY

                                KeyTermCard(
                                    isReviewCard: false,
                                    keyTerm: keyTermToDisplay,
                                    isExpanded: isOverlayCardExpanded,
                                    onToggle: {
                                        withAnimation {
                                            isOverlayCardExpanded.toggle()
                                        }
                                    },
                                    onFavoriteToggle: { _, isFavorite in
                                        guard isFavorite else { return }

                                        Task {
                                            do {
                                                // Determine the correct ID to use for descriptionGuidanceId
                                                let guidanceId: UUID?
                                                if let currentSession = session {
                                                    guidanceId = currentSession.id
                                                } else {
                                                    guidanceId = viewModel.feedbackResponse?.id
                                                }

                                                guard let descriptionGuidanceId = guidanceId else { return }

                                                let createdKeyTerm = try await FavoriteService.shared.createKeyTerm(
                                                    authToken: contentViewModel.authToken!,
                                                    descriptionGuidanceId: descriptionGuidanceId.uuidString,
                                                    term: keyTermToDisplay.term,
                                                    translations: keyTermToDisplay.translations,
                                                    reason: keyTermToDisplay.reason,
                                                    example: keyTermToDisplay.example,
                                                    favorite: true,
                                                    phoneticSymbol: keyTermToDisplay.phoneticSymbol
                                                )

                                                await MainActor.run {
                                                    if let currentSession = session {
                                                        pastSessionsViewModel.addKeyTerm(to: currentSession.id, keyTerm: createdKeyTerm)
                                                        viewModel.updateTeachingResponse(with: createdKeyTerm)
                                                    } else {
                                                        viewModel.addKeyTerm(createdKeyTerm)
                                                    }

                                                    // Dismiss the overlay
                                                    withAnimation {
                                                        showTeachingOverlay = false
                                                    }
                                                }
                                                print("✅ Successfully created and favorited new key term")
                                            } catch {
                                                print("❌ Failed to create and favorite key term: \(error)")
                                            }
                                        }
                                    },
                                    languageCode: targetLanguageCode,
                                    isUserChosen: true
                                )
                                .frame(width: proxy.size.width - 48) // Match padding (24 left + 24 right)
                                .shadow(radius: 10)
                                .offset(
                                    x: 24, // Left align with 24pt padding
                                    y: overlayTop // Position 12pt below the segment in local overlay space
                                )
                            }
                        }
                    }
                }
            )
        }
        .onAppear {
            configureBackgroundVideoIfNeeded()

            viewModel.contentViewModel = contentViewModel
            pastSessionsViewModel.contentViewModel = contentViewModel

            // Only load feedback if we don't already have preview data and we're in normal mode
            if session == nil && viewModel.feedbackResponse == nil {
                guard let mediaType = mediaType else { return }
                viewModel.loadFeedback(
                    image: selectedImage,
                    videoURL: selectedVideo,
                    audioData: audioData,
                    mediaType: mediaType
                )
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
                        Text("feedback.tab.mine")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == .mine ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .onTapGesture { selectedTab = .mine }

                        Text("feedback.tab.aiRefined")
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
                if selectedTab == .aiRefined {
                    AudioPlayerButton(
                        audioUrl: feedback.pronunciationUrl ?? "",
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
                            ProgressProcessView(currentStatus: viewModel.currentStatus)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)
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
                            ProgressProcessView(currentStatus: viewModel.currentStatus)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)
                        }
                    } else {
                        ClickableHighlightedTextView(
                            text: feedback.refinedText,
                            clickableMatches: clickableMatches,
                            segments: feedback.standardDescriptionSegments
                        ) { match, globalRect in
                            if match.isSegment {
                                handleSegmentTap(match: match, globalRect: globalRect)
                            } else {
                                handleTextTap(match: match, feedback: feedback, scrollProxy: scrollProxy)
                            }
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
                Text("review.section.vocabulary")
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
                    ForEach(Array(chosenKeyTerms.enumerated()), id: \.offset) { _, chosenTerm in
                        // Find matching real keyTerm if available
                        let matchingKeyTerm = feedback.keyTerms.first { $0.term == chosenTerm }

                        // Create a card with chosen data + real data if available
                        let displayKeyTerm = KeyTerm(
                            term: chosenTerm, // Always use chosen term
                            translations: matchingKeyTerm?.translations ?? [], // Real translations or empty for skeleton
                            reason: matchingKeyTerm?.reason ?? TermReason(reason: "", reasonTranslation: ""),
                            example: matchingKeyTerm?.example ?? TermExample(sentence: "", sentenceTranslation: ""),
                            favorite: matchingKeyTerm?.favorite ?? false,
                            phoneticSymbol: matchingKeyTerm?.phoneticSymbol,
                            id: matchingKeyTerm?.id ?? UUID() // Use real ID if available
                        )

                        KeyTermCard(
                            isReviewCard: false,
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
                                guard !displayKeyTerm.term.isEmpty, !(displayKeyTerm.translations.first?.translation.isEmpty ?? true), !displayKeyTerm.example.sentence.isEmpty else {
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
                        .id(displayKeyTerm.id)
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
                    ForEach(Array(chosenRefinements.enumerated()), id: \.offset) { _, chosenRefinement in
                        // Find matching real suggestion if available
                        let matchingSuggestion = feedback.suggestions.first {
                            $0.term + $0.refinement == chosenRefinement || $0.refinement == chosenRefinement
                        }

                        // Create a card with chosen data + real data if available
                        let displaySuggestion = Suggestion(
                            term: matchingSuggestion?.term ?? "", // Real term or empty for skeleton
                            refinement: chosenRefinement, // Always use chosen refinement
                            translations: matchingSuggestion?.translations ?? [], // Real translations or empty for skeleton
                            reason: matchingSuggestion?.reason ?? TermReason(reason: "", reasonTranslation: ""), // Real reason or empty for skeleton
                            example: matchingSuggestion?.example ?? TermExample(sentence: "", sentenceTranslation: ""),
                            favorite: matchingSuggestion?.favorite ?? false, // Real favorite status or false for skeleton
                            phoneticSymbol: matchingSuggestion?.phoneticSymbol,
                            id: matchingSuggestion?.id ?? UUID() // Use real ID if available
                        )

                        SuggestionCard(
                            isReviewCard: false,
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
                                guard !displaySuggestion.term.isEmpty, !displaySuggestion.refinement.isEmpty, !(displaySuggestion.translations.first?.translation.isEmpty ?? true), !displaySuggestion.reason.reason.isEmpty else {
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
                        .id(displaySuggestion.id)
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
                        Text("feedback.tab.mine")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == .mine ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .onTapGesture { selectedTab = .mine }

                        Text("feedback.tab.aiRefined")
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
                        clickableMatches: clickableMatches,
                        segments: session.standardDescriptionSegments
                    ) { match, globalRect in
                        if match.isSegment {
                            handleSegmentTap(match: match, globalRect: globalRect)
                        } else {
                            handleTextTap(match: match, session: session, scrollProxy: scrollProxy)
                        }
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

            Text("feedback.title")
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
            Text("review.section.vocabulary")
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 22)
                .padding(.top, 5)
                .padding(.bottom, 10)

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 20) {
                // Key Terms - always show actual data from session
                ForEach(session.keyTerms) { keyTerm in
                    KeyTermCard(
                        isReviewCard: false,
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
                            guard !keyTerm.term.isEmpty, !(keyTerm.translations.first?.translation.isEmpty ?? true), !keyTerm.example.sentence.isEmpty else {
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
                        isReviewCard: false,
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
                            guard !suggestion.term.isEmpty, !suggestion.refinement.isEmpty, !(suggestion.translations.first?.translation.isEmpty ?? true), !suggestion.reason.reason.isEmpty else {
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
                                cardId: keyTerm.id,
                                isSegment: false
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
                                cardId: suggestion.id,
                                isSegment: false
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
                            cardId: keyTerm.id,
                            isSegment: false
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
                            cardId: suggestion.id,
                            isSegment: false
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
        if let cardType = match.cardType {
            switch cardType {
            case .keyTerm:
                cardExists = feedback.keyTerms.contains { $0.id == match.cardId }
            case .suggestion:
                cardExists = feedback.suggestions.contains { $0.id == match.cardId }
            }
        } else {
            cardExists = false
        }

        // Only respond if the card exists
        guard cardExists, let cardId = match.cardId else {
            return
        }

        // Expand the corresponding card
        expandedCards.insert(cardId)

        // Scroll to the card with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            scrollProxy(cardId, UnitPoint.center)
        }
    }

    private func handleTextTap(match: ClickableTextMatch, session: SessionItem, scrollProxy: @escaping (UUID, UnitPoint?) -> Void) {
        // Verify that the corresponding card actually exists
        let cardExists: Bool
        if let cardType = match.cardType {
            switch cardType {
            case .keyTerm:
                cardExists = session.keyTerms.contains { $0.id == match.cardId }
            case .suggestion:
                cardExists = session.suggestions.contains { $0.id == match.cardId }
            }
        } else {
            cardExists = false
        }

        // Only respond if the card exists
        guard cardExists, let cardId = match.cardId else {
            return
        }

        // Expand the corresponding card
        expandedCards.insert(cardId)

        // Scroll to the card with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            scrollProxy(cardId, UnitPoint.center)
        }
    }

    private func handleSegmentTap(match: ClickableTextMatch, globalRect: CGRect) {
        teachingOverlayRect = globalRect

        // Determine the correct ID to use
        let guidanceId: UUID?
        if let currentSession = session {
            guidanceId = currentSession.id
        } else {
            guidanceId = viewModel.feedbackResponse?.id
        }

        // Trigger teaching
        viewModel.teachSingleTerm(term: match.text, descriptionGuidanceId: guidanceId)

        isOverlayCardExpanded = false
        withAnimation {
            showTeachingOverlay = true
        }
    }

    // MARK: - Thinking Process View

    struct ProgressProcessView: View {
        let currentStatus: FeedbackStatus

        // Define steps in order
        private let steps: [FeedbackStatus] = [
            .uploadingMedia,
            .understandingContent,
            .writingAiRefinedParagraph,
        ]

        private func iconName(for step: FeedbackStatus) -> String {
            switch step {
            case .uploadingMedia:
                return "arrow.up"
            case .understandingContent:
                return "brain"
            case .writingAiRefinedParagraph:
                return "pencil.tip" // Pen-style icon
            case .completed:
                return "checkmark"
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps, id: \.self) { step in
                    HStack(spacing: 14) {
                        // Icon
                        ZStack {
                            if step.order < currentStatus.order {
                                // Completed
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(red: 0 / 255, green: 166 / 255, blue: 62 / 255)) // #00A63E
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 240 / 255, green: 253 / 255, blue: 244 / 255)) // #F0FDF4
                                    .clipShape(Circle())
                            } else if step.order == currentStatus.order && currentStatus != .completed {
                                // In Progress - keep step icon, blue on light blue background
                                Image(systemName: iconName(for: step))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.primaryBlue)
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 239 / 255, green: 246 / 255, blue: 255 / 255)) // #EFF6FF
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                Color(red: 43 / 255, green: 127 / 255, blue: 255 / 255).opacity(0.3), // #2B7FFF4D
                                                lineWidth: 2
                                            )
                                    )
                                    .clipShape(Circle())
                            } else if currentStatus == .completed {
                                // All completed
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(red: 0 / 255, green: 166 / 255, blue: 62 / 255)) // #00A63E
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 240 / 255, green: 253 / 255, blue: 244 / 255)) // #F0FDF4
                                    .clipShape(Circle())
                            } else {
                                // Pending
                                Image(systemName: iconName(for: step))
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255)) // #F9FAFB
                                    .clipShape(Circle())
                            }
                        }

                        // Text
                        Text(NSLocalizedString(step.rawValue, comment: ""))
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(7) // Target line height 21px
                            .kerning(-0.15)
                            .foregroundColor(step.order <= currentStatus.order || currentStatus == .completed ? .primary : .secondary.opacity(0.5))
                            .fontWeight(step.order == currentStatus.order && currentStatus != .completed ? .semibold : .regular)
                    }

                    // Connecting line (except for last item)
                    if step != steps.last {
                        Rectangle()
                            .fill(Color(red: 220 / 255, green: 252 / 255, blue: 231 / 255)) // #DCFCE7
                            .frame(width: 2, height: 18)
                            .padding(.leading, 16) // center-align with 32pt circle
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Thinking Animation Methods

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
        let segments: [String]?
        let onTap: (ClickableTextMatch, CGRect) -> Void

        func makeUIView(context: Context) -> UITextView {
            // Create text stack with custom layout manager for dotted underlines
            let textStorage = NSTextStorage()
            let layoutManager = DottedLayoutManager()
            textStorage.addLayoutManager(layoutManager)

            let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(textContainer)

            // Use specific frame to avoid auto-constraints issues initially
            let textView = SelfSizingTextView(frame: .zero, textContainer: textContainer)
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.backgroundColor = UIColor.clear
            textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 6, right: 0) // Add bottom padding for underlines
            textView.clipsToBounds = false // Allow drawing outside bounds (prevent last line underline clipping)
            textView.delegate = context.coordinator

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
            var allMatches = clickableMatches

            if let segments = segments {
                let nsString = NSString(string: text)
                var searchRange = NSRange(location: 0, length: nsString.length)

                for segment in segments {
                    let foundRange = nsString.range(of: segment, options: [], range: searchRange)
                    if foundRange.location != NSNotFound {
                        // Check for overlap with existing matches
                        let overlaps = clickableMatches.contains { existingMatch in
                            NSIntersectionRange(existingMatch.range, foundRange).length > 0
                        }

                        if !overlaps {
                            allMatches.append(ClickableTextMatch(
                                range: foundRange,
                                text: segment,
                                cardType: nil,
                                cardId: nil,
                                isSegment: true
                            ))
                        }

                        // Move search range forward
                        let newLocation = foundRange.location + foundRange.length
                        if newLocation < nsString.length {
                            searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
                        } else {
                            break
                        }
                    }
                }
            }

            allMatches.sort { $0.range.location < $1.range.location }

            let attributedString = createAttributedString(matches: allMatches)
            uiView.attributedText = attributedString

            // Store matches in coordinator for tap handling
            context.coordinator.clickableMatches = allMatches
            context.coordinator.onTap = onTap

            // Update intrinsic content size after setting text
            uiView.invalidateIntrinsicContentSize()
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        private func createAttributedString(matches: [ClickableTextMatch]) -> NSAttributedString {
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
                .baselineOffset: 1, // Move all text up slightly to create gap for underlines while keeping alignment
            ]
            attributedString.addAttributes(baseAttributes, range: NSRange(location: 0, length: text.count))

            // Add styling for clickable matches
            for (index, match) in matches.enumerated() {
                let range = match.range

                // Add visual separation (kerning) to the last character of the match
                // This creates a gap between this segment and the next content (text or segment)
                if range.length > 0 {
                    let lastCharIndex = range.location + range.length - 1
                    let extraSpacing: CGFloat = 4.0 // set spacing between segments
                    let currentKern: CGFloat = -0.43
                    attributedString.addAttribute(.kern, value: currentKern + extraSpacing, range: NSRange(location: lastCharIndex, length: 1))
                }

                if match.isSegment {
                    // Dotted underline for segments matching Figma specs
                    // Style: Dotted
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.rawValue | NSUnderlineStyle.single.rawValue, range: range)

                    // Color: #8C8C8C
                    attributedString.addAttribute(.underlineColor, value: UIColor(red: 0.549, green: 0.549, blue: 0.549, alpha: 1.0), range: range)

                    // Use a tiny unique baseline offset to force NSLayoutManager to treat each segment as a separate run.
                    // This ensures drawUnderline is called separately for each segment, allowing us to add gaps.
                    let uniqueOffset = 0.0 + (Double(index) * 0.0001)
                    attributedString.addAttribute(.baselineOffset, value: NSNumber(value: uniqueOffset), range: range)

                    // Keep original text color (black) and font (regular)
                } else {
                    // Similar dot lines for keyTerms/suggestions as requested
                    // Style: Dotted
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.rawValue | NSUnderlineStyle.single.rawValue, range: range)

                    // Color: primaryBlue
                    attributedString.addAttribute(.underlineColor, value: UIColor(AppTheme.primaryBlue), range: range)

                    // Unique baseline offset for run separation
                    let uniqueOffset = 0.0 + (Double(index) * 0.0001)
                    attributedString.addAttribute(.baselineOffset, value: NSNumber(value: uniqueOffset), range: range)

                    // Make it look clickable
                    attributedString.addAttribute(.foregroundColor, value: UIColor(AppTheme.primaryBlue), range: range)
                    attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .medium), range: range)
                }
            }

            return attributedString
        }

        class Coordinator: NSObject, UITextViewDelegate {
            var clickableMatches: [ClickableTextMatch] = []
            var onTap: ((ClickableTextMatch, CGRect) -> Void)?
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
                        // Get the rect of the match
                        let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: match.range, actualCharacterRange: nil)
                        let boundingRect = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
                        // boundingRect is in text container coordinates.
                        // Add textContainerInset, then convert to global coordinates
                        let rect = boundingRect.offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)
                        let globalRect = textView.convert(rect, to: nil)

                        onTap?(match, globalRect)
                        break
                    }
                }
            }
        }

        // Custom Layout Manager to draw round dots instead of squares for patternDot
        class DottedLayoutManager: NSLayoutManager {
            override func drawUnderline(forGlyphRange glyphRange: NSRange, underlineType: NSUnderlineStyle, baselineOffset: CGFloat, lineFragmentRect: CGRect, lineFragmentGlyphRange: NSRange, containerOrigin: CGPoint) {
                if underlineType.contains(.patternDot) {
                    guard let container = textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil),
                          let context = UIGraphicsGetCurrentContext()
                    else {
                        super.drawUnderline(forGlyphRange: glyphRange, underlineType: underlineType, baselineOffset: baselineOffset, lineFragmentRect: lineFragmentRect, lineFragmentGlyphRange: lineFragmentGlyphRange, containerOrigin: containerOrigin)
                        return
                    }

                    context.saveGState()

                    // Get bounds of the glyphs to determine where to draw
                    let boundingRect = self.boundingRect(forGlyphRange: glyphRange, in: container)
                    let rect = boundingRect.offsetBy(dx: containerOrigin.x, dy: containerOrigin.y)

                    // Add horizontal padding to create gaps between adjacent segments
                    // We only apply trimming to the RIGHT side at the end of a segment to clear the kerning gap.
                    // We do NOT inset the left side, to ensure alignment with the text start (fixing the "shift right" issue).

                    var insetLeft: CGFloat = 0
                    var insetRight: CGFloat = 0
                    let gapTrimming: CGFloat = 4.0 // set spacing between dots lines of segments

                    // Find the full range of the segment by looking for the continuous run of our unique baselineOffset attribute
                    if let textStorage = textStorage {
                        var effectiveRange = NSRange(location: NSNotFound, length: 0)

                        // We use baselineOffset attribute because we made it unique per segment
                        textStorage.attribute(.baselineOffset, at: glyphRange.location, longestEffectiveRange: &effectiveRange, in: NSRange(location: 0, length: textStorage.length))

                        // We don't inset left (0) to keep alignment with text start

                        if glyphRange.upperBound == effectiveRange.upperBound {
                            // End of the segment: trim right to clear the kerned whitespace
                            insetRight = gapTrimming
                        }
                    } else {
                        // Fallback
                        insetRight = gapTrimming
                    }

                    // Apply calculated insets
                    var drawRect = rect
                    drawRect.origin.x += insetLeft
                    drawRect.size.width -= (insetLeft + insetRight)

                    if drawRect.size.width <= 0 {
                        context.restoreGState()
                        return
                    }

                    // Get color from attributes
                    let attributes = textStorage?.attributes(at: glyphRange.location, effectiveRange: nil)
                    let color = (attributes?[.underlineColor] as? UIColor) ?? .black
                    context.setFillColor(color.cgColor)

                    // Dot configuration
                    // Larger dots for keyTerms/suggestions (Primary Blue), smaller for segments (Gray)
                    let isPrimaryBlue = color.isEqual(UIColor(AppTheme.primaryBlue))
                    let dotDiameter: CGFloat = isPrimaryBlue ? 2.5 : 1.5
                    let dotSpacing: CGFloat = 3.0 // Center to center spacing

                    // Calculate Y position based on baseline for consistent alignment
                    // lineFragmentRect is in container coords.
                    // Baseline Y in container coords = lineFragmentRect.maxY - baselineOffset
                    // Add containerOrigin.y for drawing context coords
                    let baselineY = lineFragmentRect.maxY - baselineOffset + containerOrigin.y

                    // Draw dots slightly below the baseline
                    // Adjust this offset to control distance from text.
                    // Baseline is where text sits. Text is shifted up by 1.0 (base attribute).
                    // So we put dots just below the line baseline.
                    let yPos = baselineY + 5

                    var x = drawRect.minX
                    // Adjust starting X to align nicely

                    while x < drawRect.maxX {
                        let dotRect = CGRect(x: x, y: yPos, width: dotDiameter, height: dotDiameter)
                        context.fillEllipse(in: dotRect)
                        x += dotSpacing
                    }

                    context.restoreGState()
                } else {
                    super.drawUnderline(forGlyphRange: glyphRange, underlineType: underlineType, baselineOffset: baselineOffset, lineFragmentRect: lineFragmentRect, lineFragmentGlyphRange: lineFragmentGlyphRange, containerOrigin: containerOrigin)
                }
            }
        }
    }

    // MARK: - Helper Types

    struct ViewOffsetKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
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
                    Suggestion(
                        term: "text",
                        refinement: "content",
                        translations: [TermTranslation(pos: "noun", translation: "内容")],
                        reason: TermReason(reason: "More specific term", reasonTranslation: "更具体的词"),
                        example: TermExample(sentence: "The content of the email", sentenceTranslation: "邮件的内容"),
                        favorite: false,
                        id: UUID()
                    ),
                    Suggestion(
                        term: "needs",
                        refinement: "requires",
                        translations: [TermTranslation(pos: "verb", translation: "需要")],
                        reason: TermReason(reason: "More formal", reasonTranslation: "更正式"),
                        example: TermExample(sentence: "This task requires attention", sentenceTranslation: "这个任务需要注意"),
                        favorite: false,
                        id: UUID()
                    ),
                ],
                keyTerms: [
                    KeyTerm(
                        term: "original",
                        translations: [TermTranslation(pos: "adj", translation: "原始的")],
                        reason: TermReason(reason: "reason", reasonTranslation: "reason translation"),
                        example: TermExample(sentence: "This is the original version", sentenceTranslation: ""),
                        favorite: false,
                        id: UUID()
                    ),
                    KeyTerm(
                        term: "improvement",
                        translations: [TermTranslation(pos: "noun", translation: "改进")],
                        reason: TermReason(reason: "reason", reasonTranslation: "reason translation"),
                        example: TermExample(sentence: "We need to make improvements", sentenceTranslation: ""),
                        favorite: false,
                        id: UUID()
                    ),
                ],
                chosenKeyTerms: ["original", "improvement"],
                chosenRefinements: ["content", "requires"],
                chosenItemsGenerated: true
            ),
        )
    }
}

#Preview("Progress Process States") {
    VStack(alignment: .leading, spacing: 24) {
        FeedbackView.ProgressProcessView(currentStatus: .understandingContent)
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
