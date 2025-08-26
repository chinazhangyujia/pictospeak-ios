//
//  FeedbackView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

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
    let audioData: Data?
    let mediaType: MediaType?

    // Default initializer for normal use
    init(selectedImage: UIImage, audioData: Data, mediaType: MediaType) {
        self.selectedImage = selectedImage
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel())
        sessionId = nil
        _pastSessionsViewModel = ObservedObject(wrappedValue: PastSessionsViewModel())
    }

    // Initializer for previews with fake data
    init(selectedImage: UIImage, audioData: Data, mediaType: MediaType, previewData: FeedbackResponse) {
        self.selectedImage = selectedImage
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(previewData: previewData))
        sessionId = nil
        _pastSessionsViewModel = ObservedObject(wrappedValue: PastSessionsViewModel())
    }

    // Initializer for session viewing mode (without showFeedbackView binding)
    init(sessionId: UUID, pastSessionsViewModel: PastSessionsViewModel) {
        self.sessionId = sessionId
        selectedImage = nil
        audioData = nil
        mediaType = nil
        _viewModel = StateObject(wrappedValue: FeedbackViewModel())
        _pastSessionsViewModel = ObservedObject(wrappedValue: pastSessionsViewModel)
    }

    enum FeedbackTab {
        case mine, aiRefined
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            customHeader

            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                if let session = session {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 30) {
                                textComparisonSectionForSession(session, scrollProxy: proxy.scrollTo)
                                suggestionsAndKeyTermsSectionForSession(session)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                        .background(Color(.systemGray6))
                    }
                } else {
                    // Normal feedback mode - always show content with progressive skeleton loading
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 30) {
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
                        .background(Color(.systemGray6))
                    }
                }
            }
        }
        .onAppear {
            startThinkingAnimation()

            // Only load feedback if we don't already have preview data and we're in normal mode
            if session == nil && viewModel.feedbackResponse == nil {
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
        VStack(spacing: 20) {
            // Tab Selector
            HStack(spacing: 5) {
                Button(action: {
                    selectedTab = .mine
                }) {
                    Group {
                        if feedback.refinedText.isEmpty {
                            SkeletonPlaceholder(width: 60, height: 20)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Mine")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTab == .mine ? .primary : .gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(
                        selectedTab == .mine ? Color(.systemGray6) : Color(.systemGray5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                }

                Button(action: {
                    selectedTab = .aiRefined
                }) {
                    Group {
                        if feedback.refinedText.isEmpty {
                            SkeletonPlaceholder(width: 80, height: 20)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("AI Refined")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTab == .aiRefined ? .primary : .gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(
                        selectedTab == .aiRefined ? Color(.systemGray6) : Color(.systemGray5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                }
            }

            // Text Content
            VStack(alignment: .leading, spacing: 12) {
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
                            .foregroundColor(Color(.label))
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    // AI Refined text with clickable matches
                    let clickableMatches = getClickableMatches(from: feedback)

                    HStack(alignment: .top, spacing: 2) {
                        // Speaker icon at the beginning of the text block
                        if let pronunciationUrl = feedback.pronunciationUrl, !pronunciationUrl.isEmpty {
                            AudioPlayerButton(audioUrl: pronunciationUrl)
                        }

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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Suggestions and Key Terms Section

    private func suggestionsAndKeyTermsSection(_ feedback: FeedbackResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title - show waving placeholder if no chosen items loaded yet
            let chosenItemsGenerated = feedback.chosenItemsGenerated
            if !chosenItemsGenerated {
                SkeletonPlaceholder(width: 200, height: 24)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            } else if let chosenKeyTerms = feedback.chosenKeyTerms, let chosenRefinements = feedback.chosenRefinements, chosenKeyTerms.isEmpty && chosenRefinements.isEmpty {
                // don't show anything
            } else {
                Text("Key Expressions")
                    .appTitle()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 12) {
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

    private func textComparisonSectionForSession(_ session: SessionItem, scrollProxy _: @escaping (UUID, UnitPoint?) -> Void) -> some View {
        VStack(spacing: 20) {
            // Tab Selector
            HStack(spacing: 0) {
                Button(action: {
                    selectedTab = .mine
                }) {
                    Text("Mine")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == .mine ? .primary : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedTab == .mine ? Color(.systemGray5) : Color.clear
                        )
                }

                Button(action: {
                    selectedTab = .aiRefined
                }) {
                    Text("AI Refined")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == .aiRefined ? .primary : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedTab == .aiRefined ? Color(.systemGray5) : Color.clear
                        )
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Text Content - always show actual data from session
            VStack(alignment: .leading, spacing: 12) {
                if selectedTab == .mine {
                    Text(session.userDescription)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(.label))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // AI Refined text with pronunciation button if available
                    HStack(alignment: .top, spacing: 8) {
                        if let pronunciationUrl = session.pronunciationUrl, !pronunciationUrl.isEmpty {
                            AudioPlayerButton(audioUrl: pronunciationUrl)
                        }

                        Text(session.standardDescription)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(.label))
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func suggestionsAndKeyTermsSectionForSession(_ session: SessionItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title - always show since session data is already loaded
            Text("Key Expressions")
                .appTitle()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 12) {
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

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack {
            Button(action: {
                router.resetToHome()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            Spacer()

            Text("AI Feedback")
                .appTitle()

            Spacer()

            Button(action: {
                // Save or share feedback
            }) {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.green)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 20)
        .background(Color(.systemGray6))
    }

    // MARK: - Helper Methods

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
                attributedString.addAttribute(.underlineColor, value: UIColor.systemGreen, range: range)

                // Add small vertical gap between text and underline
                attributedString.addAttribute(.baselineOffset, value: 2, range: range)

                // Make it look clickable
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: range)
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

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header - always visible
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onToggle()
                    }
                }) {
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: Content (Term/Refinement + Translation)
                        VStack(alignment: .leading, spacing: 10) {
                            // Row 1: Term/Refinement
                            if suggestion.refinement.isEmpty {
                                SkeletonPlaceholder(width: 100, height: 16)
                            } else {
                                HighlightedSuggestionText(
                                    term: isExpanded ? suggestion.term : nil,
                                    refinement: suggestion.refinement
                                )
                            }

                            // Row 2: Translation
                            if suggestion.translation.isEmpty {
                                SkeletonPlaceholder(width: 150, height: 14)
                            } else {
                                Text(suggestion.translation)
                                    .appCardText()
                            }
                        }

                        // Right side: Controls (Star + Chevron)
                        VStack(spacing: 10) {
                            // Star button with waving effect when refinement is empty
                            if suggestion.refinement.isEmpty {
                                SkeletonPlaceholder(width: 16, height: 16)
                                    .modifier(ShimmerEffect())
                            } else {
                                Button(action: {
                                    onFavoriteToggle(suggestion.id, !suggestion.favorite)
                                }) {
                                    Image(systemName: suggestion.favorite ? "star.fill" : "star")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(suggestion.favorite ? .yellow : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 20, height: 20)
                                .disabled(suggestion.term.isEmpty || suggestion.reason.isEmpty)
                            }

                            // Chevron
                            if suggestion.term.isEmpty || suggestion.refinement.isEmpty || suggestion.translation.isEmpty || suggestion.reason.isEmpty {
                                SkeletonPlaceholder(width: 20, height: 16)
                            } else {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(16)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(suggestion.term.isEmpty || suggestion.reason.isEmpty) // Disable if no full data

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .padding(.horizontal, 16)

                        if suggestion.reason.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonPlaceholder(width: .infinity, height: 14)
                                SkeletonPlaceholder(width: 280, height: 14)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } else {
                            Text(suggestion.reason)
                                .appCardText(fontSize: 14)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header - always visible
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onToggle()
                    }
                }) {
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: Content (Term + Translation)
                        VStack(alignment: .leading, spacing: 10) {
                            // Row 1: Term
                            if keyTerm.term.isEmpty {
                                SkeletonPlaceholder(width: 100, height: 16)
                            } else {
                                HighlightedKeyTermText(term: keyTerm.term)
                            }

                            // Row 2: Translation
                            if keyTerm.translation.isEmpty {
                                SkeletonPlaceholder(width: 150, height: 14)
                            } else {
                                Text(keyTerm.translation)
                                    .appCardText()
                            }
                        }

                        // Right side: Controls (Star + Chevron)
                        VStack(spacing: 10) {
                            // Star button with waving effect when term is empty
                            if keyTerm.term.isEmpty {
                                SkeletonPlaceholder(width: 16, height: 16)
                                    .modifier(ShimmerEffect())
                            } else {
                                Button(action: {
                                    onFavoriteToggle(keyTerm.id, !keyTerm.favorite)
                                }) {
                                    Image(systemName: keyTerm.favorite ? "star.fill" : "star")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(keyTerm.favorite ? .yellow : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 20, height: 20)
                            }

                            // Chevron
                            if keyTerm.term.isEmpty || keyTerm.translation.isEmpty || keyTerm.example.isEmpty {
                                SkeletonPlaceholder(width: 20, height: 16)
                            } else {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(16)
                }
                .buttonStyle(PlainButtonStyle())

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .padding(.horizontal, 16)

                        if keyTerm.example.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonPlaceholder(width: .infinity, height: 14)
                                SkeletonPlaceholder(width: 250, height: 14)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } else {
                            Text(keyTerm.example)
                                .appCardText(fontSize: 14)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    NavigationView {
        FeedbackView(
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
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
