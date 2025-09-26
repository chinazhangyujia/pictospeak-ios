//
//  FeedbackView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI
import AVKit
import AVFoundation

// MARK: - Skeleton Loading Components

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear,
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2) * phase)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                phase = 1
            }
            .clipped()
    }
}

struct SkeletonPlaceholder: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray4))
            .frame(width: width, height: height)
            .modifier(ShimmerEffect())
    }
}

// MARK: - View Extensions

extension View {
    func appTitle() -> some View {
        font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
    }

    func appCardText(fontSize: CGFloat = 16) -> some View {
        font(.system(size: fontSize, weight: .regular))
            .foregroundColor(.primary)
            .lineSpacing(2)
    }
}

// MARK: - FeedbackView

struct FeedbackView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var viewModel: FeedbackViewModel
    @State private var selectedTab: FeedbackTab = .aiRefined
    @State private var expandedCards: Set<UUID> = []
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
    init(selectedImage: UIImage?, selectedVideo: URL?, audioData: Data, mediaType: MediaType) {
        self.selectedImage = selectedImage
        self.selectedVideo = selectedVideo
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(contentViewModel: ContentViewModel()))
        sessionId = nil
        _pastSessionsViewModel = ObservedObject(wrappedValue: PastSessionsViewModel(contentViewModel: ContentViewModel()))
    }

    // Initializer for previews with fake data
    init(selectedImage: UIImage?, selectedVideo: URL?, audioData: Data, mediaType: MediaType, previewData: FeedbackResponse) {
        self.selectedImage = selectedImage
        self.selectedVideo = selectedVideo
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(contentViewModel: ContentViewModel(), previewData: previewData))
        sessionId = nil
        _pastSessionsViewModel = ObservedObject(wrappedValue: PastSessionsViewModel(contentViewModel: ContentViewModel()))
    }

    // Initializer for session viewing mode (without showFeedbackView binding)
    init(sessionId: UUID, pastSessionsViewModel: PastSessionsViewModel) {
        self.sessionId = sessionId
        selectedImage = nil
        selectedVideo = nil
        audioData = nil
        mediaType = nil
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(contentViewModel: ContentViewModel()))
        _pastSessionsViewModel = ObservedObject(wrappedValue: pastSessionsViewModel)
    }

    enum FeedbackTab {
        case mine, aiRefined
    }
    
    @State private var showSheet = true
    @State private var selectedDetent: PresentationDetent = .fraction(0.5)

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
                } else if let selectedVideo = selectedVideo {
                    // Show directly passed video as background
                    VideoPlayer(player: AVPlayer(url: selectedVideo))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
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
                        // Show session video as background
                        VideoPlayer(player: AVPlayer(url: materialUrl))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
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
                        // .background(Color(.systemGray6).opacity(0.95))
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

            // test a long paragraph
            // Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
            // .presentationDetents([.fraction(0.15), .fraction(0.5), .large], selection: $selectedDetent)
        }
        .onAppear {
            viewModel.contentViewModel = contentViewModel
            pastSessionsViewModel.contentViewModel = contentViewModel

            // Only load feedback if we don't already have preview data and we're in normal mode
            if session == nil && viewModel.feedbackResponse == nil {
                startThinkingAnimation()
                guard let selectedImage = selectedImage, let audioData = audioData, let mediaType = mediaType else { return }
                viewModel.loadFeedback(image: selectedImage, audioData: audioData, mediaType: mediaType)
            }
        }
        .onChange(of: viewModel.feedbackResponse?.refinedText) { newValue in
            // Stop thinking animation when refined text is loaded
            if let newValue = newValue, !newValue.isEmpty {
                stopThinkingAnimation()
            }
        }
        .onDisappear {
            // Stop thinking animation timer
            stopThinkingAnimation()
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
                        backgroundColorPlaying: Color(red: 0.914, green: 0.933, blue: 1.0, opacity: 0.6), // #E9EEFF 60%
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
                            .lineSpacing(10) // 27 - 17 = 10pt line spacing for 27px line height
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
                        .lineSpacing(10) // 27 - 17 = 10pt line spacing for 27px line height
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
            let chosenItemsGenerated = feedback.chosenItemsGenerated
            if !chosenItemsGenerated {
                SkeletonPlaceholder(width: 200, height: 24)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            } else if let chosenKeyTerms = feedback.chosenKeyTerms, let chosenRefinements = feedback.chosenRefinements, chosenKeyTerms.isEmpty && chosenRefinements.isEmpty {
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
                // Check if chosen items are generated
                let chosenItemsGenerated = feedback.chosenItemsGenerated

                // Key Terms - show chosenKeyTerms if available and generated, otherwise show skeleton
                if let chosenKeyTerms = feedback.chosenKeyTerms, chosenItemsGenerated {
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
                            }
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
                if let chosenRefinements = feedback.chosenRefinements, chosenItemsGenerated {
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
                            }
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
                        backgroundColorPlaying: Color(red: 0.914, green: 0.933, blue: 1.0, opacity: 0.6), // #E9EEFF 60%
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
                        .lineSpacing(10) // 27 - 17 = 10pt line spacing for 27px line height
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
                        .lineSpacing(10) // 27 - 17 = 10pt line spacing for 27px line height
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
                    router.goBack()
                }

            Spacer()

            Text("AI feedback")
                .font(.headline)
                .fontWeight(.regular)
                .foregroundColor(.primary)
                .glassEffect(.clear)

            Spacer()

            
            Image(systemName: "checkmark")
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .glassEffect(.clear.tint(AppTheme.primaryBlue))
                .onTapGesture {
                    print("checkmark tapped")
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, 30)
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
                        }
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
                        }
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

            // Set base attributes
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: UIColor.label,
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

    // MARK: - Suggestion Card

    struct SuggestionCard: View {
        let suggestion: Suggestion
        let isExpanded: Bool
        let onToggle: () -> Void
        let onFavoriteToggle: (UUID, Bool) -> Void

        @State private var speechSynthesizer = AVSpeechSynthesizer()
        
        private func speakText(_ text: String) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            speechSynthesizer.speak(utterance)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                // Header - always visible
                VStack(spacing: 10) {
                    // Top row: Term/Refinement + star
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: Term/Refinement with blue background
                        HStack(alignment: .top, spacing: 8) {
                            // Term/Refinement
                            if suggestion.refinement.isEmpty {
                                SkeletonPlaceholder(width: 100, height: 18)
                            } else {
                                Text(suggestion.refinement)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(AppTheme.primaryBlue)
                            }

                            // Speaker icon
                            if suggestion.refinement.isEmpty {
                                SkeletonPlaceholder(width: 16, height: 16)
                                    .modifier(ShimmerEffect())
                            } else {
                                Button(action: {
                                    speakText(suggestion.refinement)
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.body.weight(.medium))
                                        .foregroundColor(Color(red: 0.247, green: 0.388, blue: 0.910, opacity: 1.0))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 6)
                        .background(Color(red: 0.914, green: 0.933, blue: 1.0, opacity: 0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                        
                        // Right side: Star button
                        if suggestion.refinement.isEmpty {
                            SkeletonPlaceholder(width: 16, height: 16)
                                .modifier(ShimmerEffect())
                        } else {
                            Button(action: {
                                onFavoriteToggle(suggestion.id, !suggestion.favorite)
                            }) {
                                Image(systemName: suggestion.favorite ? "star.fill" : "star")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(suggestion.favorite ? AppTheme.primaryBlue : AppTheme.feedbackCardTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 22, height: 22)
                            .disabled(suggestion.refinement.isEmpty)
                        }
                    }
                    
                    // Bottom row: Translation + chevron
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: Translation
                        if suggestion.translation.isEmpty {
                            SkeletonPlaceholder(width: 150, height: 14)
                        } else {
                            Text(suggestion.translation)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppTheme.feedbackCardTextColor)
                        }
                        
                        Spacer()
                        
                        // Right side: Chevron
                        if suggestion.term.isEmpty || suggestion.refinement.isEmpty || suggestion.translation.isEmpty || suggestion.reason.isEmpty {
                            SkeletonPlaceholder(width: 20, height: 16)
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    onToggle()
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.feedbackCardTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 22, height: 22)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, isExpanded ? 0 : 16)
                .padding(.horizontal, 22)
                .buttonStyle(PlainButtonStyle())

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()

                        if suggestion.reason.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonPlaceholder(width: .infinity, height: 14)
                                SkeletonPlaceholder(width: 280, height: 14)
                            }
                        } else {
                            Text(suggestion.reason)
                                .appCardText(fontSize: 14, weight: .regular, color: AppTheme.feedbackCardTextColor)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                }
            }
            .background(AppTheme.feedbackCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 26))
        }
    }

    // MARK: - Highlighted Key Term Text

    struct HighlightedKeyTermText: View {
        let term: String

        var body: some View {
            Text(createAttributedText())
                .appCardText()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func createAttributedText() -> AttributedString {
            var attributedString = AttributedString()

            // Add padding spaces with background
            var paddingStart = AttributedString(" ")
            paddingStart.backgroundColor = Color.green.opacity(0.3)

            // Add the highlighted term
            var termText = AttributedString(term)
            termText.backgroundColor = Color.green.opacity(0.3)

            // Add padding spaces with background
            var paddingEnd = AttributedString(" ")
            paddingEnd.backgroundColor = Color.green.opacity(0.3)

            attributedString.append(paddingStart)
            attributedString.append(termText)
            attributedString.append(paddingEnd)

            return attributedString
        }
    }

    // MARK: - Highlighted Suggestion Text

    struct HighlightedSuggestionText: View {
        let term: String?
        let refinement: String

        var body: some View {
            // Create attributed text that flows naturally
            Text(createAttributedText())
                .appCardText()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func createAttributedText() -> AttributedString {
            var attributedString = AttributedString()

            // If we have a term, show "term → refinement"
            if let term = term, !term.isEmpty {
                // Add the term
                var termText = AttributedString(term)
                attributedString.append(termText)

                // Add the arrow
                var arrowText = AttributedString(" → ")
                attributedString.append(arrowText)
            }

            // Add the highlighted refinement
            var refinementText = AttributedString(refinement)
            refinementText.backgroundColor = Color.green.opacity(0.3)

            // Add some padding effect by adding spaces with background
            var paddingStart = AttributedString(" ")
            paddingStart.backgroundColor = Color.green.opacity(0.3)
            var paddingEnd = AttributedString(" ")
            paddingEnd.backgroundColor = Color.green.opacity(0.3)

            attributedString.append(paddingStart)
            attributedString.append(refinementText)
            attributedString.append(paddingEnd)

            return attributedString
        }
    }

    // MARK: - Key Term Card

    struct KeyTermCard: View {
        let keyTerm: KeyTerm
        let isExpanded: Bool
        let onToggle: () -> Void
        let onFavoriteToggle: (UUID, Bool) -> Void
        
        @State private var speechSynthesizer = AVSpeechSynthesizer()
        
        private func speakText(_ text: String) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            speechSynthesizer.speak(utterance)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                // Header - always visible
                VStack(spacing: 10) {
                    // Top row: English word + speaker icon + star
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: English word + speaker icon
                        HStack(alignment: .top, spacing: 8) {
                            // English word
                            if keyTerm.term.isEmpty {
                                SkeletonPlaceholder(width: 100, height: 18)
                            } else {
                                Text(keyTerm.term)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(Color(red: 0.247, green: 0.388, blue: 0.910, opacity: 1.0))
                            }
                            
                            // Speaker icon
                            if keyTerm.term.isEmpty {
                                SkeletonPlaceholder(width: 16, height: 16)
                                    .modifier(ShimmerEffect())
                            } else {
                                Button(action: {
                                    speakText(keyTerm.term)
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.body.weight(.medium))
                                        .foregroundColor(Color(red: 0.247, green: 0.388, blue: 0.910, opacity: 1.0))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 6)
                        .background(Color(red: 0.914, green: 0.933, blue: 1.0, opacity: 0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                        
                        // Right side: Star button
                        if keyTerm.term.isEmpty {
                            SkeletonPlaceholder(width: 16, height: 16)
                                .modifier(ShimmerEffect())
                        } else {
                            Button(action: {
                                onFavoriteToggle(keyTerm.id, !keyTerm.favorite)
                            }) {
                                Image(systemName: keyTerm.favorite ? "star.fill" : "star")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(keyTerm.favorite ? AppTheme.primaryBlue : AppTheme.feedbackCardTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 22, height: 22)
                            .disabled(keyTerm.term.isEmpty)
                        }
                    }
                    
                    // Bottom row: Chinese translation + chevron
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: Chinese translation
                        if keyTerm.translation.isEmpty {
                            SkeletonPlaceholder(width: 150, height: 14)
                        } else {
                            Text(keyTerm.translation)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppTheme.feedbackCardTextColor)
                        }
                        
                        Spacer()
                        
                        // Right side: Chevron
                        if keyTerm.term.isEmpty || keyTerm.translation.isEmpty || keyTerm.example.isEmpty {
                            SkeletonPlaceholder(width: 20, height: 16)
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    onToggle()
                                }
                            }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.feedbackCardTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 22, height: 22)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, isExpanded ? 0 : 16)
                .padding(.horizontal, 22)
                .buttonStyle(PlainButtonStyle())

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()

                        if keyTerm.example.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonPlaceholder(width: .infinity, height: 14)
                                SkeletonPlaceholder(width: 250, height: 14)
                            }
                        } else {
                            Text(keyTerm.example)
                                .appCardText(fontSize: 14, weight: .regular, color: AppTheme.feedbackCardTextColor)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                }
            }
            .background(AppTheme.feedbackCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 26))
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
