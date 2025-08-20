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

// MARK: - FeedbackView

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FeedbackViewModel
    @State private var selectedTab: FeedbackTab = .aiRefined
    @Binding var showFeedbackView: Bool
    @State private var expandedCards: Set<UUID> = []

    // For session viewing mode
    let session: SessionDisplayItem?

    // For normal feedback mode
    let selectedImage: UIImage?
    let audioData: Data?
    let mediaType: MediaType?

    // Default initializer for normal use
    init(showFeedbackView: Binding<Bool>, selectedImage: UIImage, audioData: Data, mediaType: MediaType) {
        _showFeedbackView = showFeedbackView
        session = nil
        self.selectedImage = selectedImage
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel())
    }

    // Initializer for previews with fake data
    init(showFeedbackView: Binding<Bool>, selectedImage: UIImage, audioData: Data, mediaType: MediaType, previewData: FeedbackResponse) {
        _showFeedbackView = showFeedbackView
        session = nil
        self.selectedImage = selectedImage
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(previewData: previewData))
    }

    // New initializer for session viewing
    init(showFeedbackView: Binding<Bool>, session: SessionDisplayItem) {
        _showFeedbackView = showFeedbackView
        self.session = session
        selectedImage = nil
        audioData = nil
        mediaType = nil
        _viewModel = StateObject(wrappedValue: FeedbackViewModel())
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
                    // Session viewing mode - show session data directly
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
            // Only load feedback if we don't already have preview data and we're in normal mode
            if session == nil && viewModel.feedbackResponse == nil {
                guard let selectedImage = selectedImage, let audioData = audioData, let mediaType = mediaType else { return }
                viewModel.loadFeedback(image: selectedImage, audioData: audioData, mediaType: mediaType)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Text Comparison Section

    private func textComparisonSection(_ feedback: FeedbackResponse, scrollProxy: @escaping (UUID, UnitPoint?) -> Void) -> some View {
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

            // Text Content
            VStack(alignment: .leading, spacing: 12) {
                if selectedTab == .mine {
                    if feedback.originalText.isEmpty {
                        // Show skeleton placeholders for original text
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonPlaceholder(width: 200, height: 16)
                            SkeletonPlaceholder(width: 230, height: 16)
                            SkeletonPlaceholder(width: 180, height: 16)
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
                            // Show skeleton placeholders for refined text
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonPlaceholder(width: 200, height: 16)
                                SkeletonPlaceholder(width: 230, height: 16)
                                SkeletonPlaceholder(width: 180, height: 16)
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
            if let chosenKeyTerms = feedback.chosenKeyTerms, let chosenRefinements = feedback.chosenRefinements,
               !chosenKeyTerms.isEmpty || !chosenRefinements.isEmpty
            {
                // State 2 or 3: Either chosen items or full items are loaded
                Text("Key Expressions")
                    .appTitle()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            } else if feedback.keyTerms.isEmpty && feedback.suggestions.isEmpty {
                // State 1: Nothing loaded - show skeleton placeholder for title
                SkeletonPlaceholder(width: 200, height: 24)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            } else {
                // State 3: Full items loaded - show title
                Text("Key Expressions")
                    .appTitle()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 12) {
                // Calculate total chosen items for skeleton count
                let chosenKeyTermsCount = feedback.chosenKeyTerms?.count ?? 0
                let chosenRefinementsCount = feedback.chosenRefinements?.count ?? 0
                let totalChosenItems = chosenKeyTermsCount + chosenRefinementsCount

                // Key Terms - show chosenKeyTerms if available, otherwise show skeleton
                if let chosenKeyTerms = feedback.chosenKeyTerms {
                    if feedback.keyTerms.isEmpty {
                        // State 2: Chosen items loaded but full items not ready
                        // Show chosen terms with skeleton placeholders for missing fields
                        ForEach(Array(chosenKeyTerms.enumerated()), id: \.offset) { index, chosenTerm in
                            // Create a temporary KeyTerm with chosen data and skeleton placeholders
                            let tempKeyTerm = KeyTerm(
                                term: chosenTerm, // This should be the chosen term string
                                translation: "", // Will show skeleton
                                example: "", // Will show skeleton
                                id: UUID() // Generate new UUID for this session
                            )
                            KeyTermCard(
                                keyTerm: tempKeyTerm,
                                isExpanded: false, // Always start collapsed for chosen items
                                onToggle: {
                                    // For chosen items, we don't need to track expansion state
                                    // since they only show basic info
                                }
                            )
                            .id("chosen-keyterm-\(index)") // Use string ID for ForEach
                        }
                    } else {
                        // State 3: Full items loaded - show actual key terms with no skeletons
                        ForEach(feedback.keyTerms) { keyTerm in
                            KeyTermCard(
                                keyTerm: keyTerm,
                                isExpanded: expandedCards.contains(keyTerm.id),
                                onToggle: {
                                    if expandedCards.contains(keyTerm.id) {
                                        expandedCards.remove(keyTerm.id)
                                    } else {
                                        expandedCards.insert(keyTerm.id)
                                    }
                                }
                            )
                            .id(keyTerm.id)
                        }
                    }
                } else if feedback.keyTerms.isEmpty {
                    // State 1: Nothing loaded - show skeleton placeholders
                    ForEach(0 ..< 4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonPlaceholder(width: 100, height: 16)
                                    SkeletonPlaceholder(width: 150, height: 14)
                                }

                                Spacer()

                                SkeletonPlaceholder(width: 16, height: 16)
                            }
                            .padding(16)
                        }
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    // This case should never happen since if keyTerms are loaded, chosenKeyTerms are also loaded
                    // But keeping it as a fallback for safety
                    ForEach(feedback.keyTerms) { keyTerm in
                        KeyTermCard(
                            keyTerm: keyTerm,
                            isExpanded: expandedCards.contains(keyTerm.id),
                            onToggle: {
                                if expandedCards.contains(keyTerm.id) {
                                    expandedCards.remove(keyTerm.id)
                                } else {
                                    expandedCards.insert(keyTerm.id)
                                }
                            }
                        )
                        .id(keyTerm.id)
                    }
                }

                // Suggestions - show chosenRefinements if available, otherwise show skeleton
                if let chosenRefinements = feedback.chosenRefinements {
                    if feedback.suggestions.isEmpty {
                        // State 2: Chosen items loaded but full items not ready
                        // Show chosen refinements with skeleton placeholders for missing fields
                        ForEach(Array(chosenRefinements.enumerated()), id: \.offset) { index, chosenRefinement in
                            // Create a temporary Suggestion with chosen data and skeleton placeholders
                            let tempSuggestion = Suggestion(
                                term: "", // Will show skeleton
                                refinement: chosenRefinement, // This should be the chosen refinement string
                                translation: "", // Will show skeleton
                                reason: "", // Will show skeleton
                                id: UUID() // Generate new UUID for this session
                            )
                            SuggestionCard(
                                suggestion: tempSuggestion,
                                isExpanded: false, // Always start collapsed for chosen items
                                onToggle: {
                                    // For chosen items, we don't need to track expansion state
                                    // since they only show basic info
                                }
                            )
                            .id("chosen-suggestion-\(index)") // Use string ID for ForEach
                        }
                    } else {
                        // State 3: Full items loaded - show actual suggestions with no skeletons
                        ForEach(feedback.suggestions) { suggestion in
                            SuggestionCard(
                                suggestion: suggestion,
                                isExpanded: expandedCards.contains(suggestion.id),
                                onToggle: {
                                    if expandedCards.contains(suggestion.id) {
                                        expandedCards.remove(suggestion.id)
                                    } else {
                                        expandedCards.insert(suggestion.id)
                                    }
                                }
                            )
                            .id(suggestion.id)
                        }
                    }
                } else if feedback.suggestions.isEmpty {
                    // State 1: Nothing loaded - show skeleton placeholders
                    ForEach(0 ..< 4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonPlaceholder(width: 100, height: 16)
                                    SkeletonPlaceholder(width: 150, height: 14)
                                }

                                Spacer()

                                SkeletonPlaceholder(width: 16, height: 16)
                            }
                            .padding(16)
                        }
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    // This case should never happen since if suggestions are loaded, chosenRefinements are also loaded
                    // But keeping it as a fallback for safety
                    ForEach(feedback.suggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            isExpanded: expandedCards.contains(suggestion.id),
                            onToggle: {
                                if expandedCards.contains(suggestion.id) {
                                    expandedCards.remove(suggestion.id)
                                } else {
                                    expandedCards.insert(suggestion.id)
                                }
                            }
                        )
                        .id(suggestion.id)
                    }
                }
            }
        }
    }

    // MARK: - Session Viewing Mode Methods

    private func textComparisonSectionForSession(_ session: SessionDisplayItem, scrollProxy _: @escaping (UUID, UnitPoint?) -> Void) -> some View {
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

    private func suggestionsAndKeyTermsSectionForSession(_ session: SessionDisplayItem) -> some View {
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
                showFeedbackView = false
                dismiss()
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

        // Only use chosen key terms for highlighting
        if let chosenKeyTerms = feedback.chosenKeyTerms {
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

        // Only use chosen refinements for highlighting
        if let chosenRefinements = feedback.chosenRefinements {
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

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header - always visible
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onToggle()
                    }
                }) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Show term -> refinement when expanded, only refinement when collapsed
                            if suggestion.refinement.isEmpty {
                                SkeletonPlaceholder(width: 100, height: 16)
                            } else {
                                HighlightedSuggestionText(
                                    term: isExpanded ? suggestion.term : nil,
                                    refinement: suggestion.refinement
                                )
                            }

                            // Only show translation if we have it (not empty)
                            if suggestion.translation.isEmpty {
                                SkeletonPlaceholder(width: 150, height: 14)
                            } else {
                                Text(suggestion.translation)
                                    .appCardText()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Only show chevron if card can be expanded
                        if suggestion.term.isEmpty || suggestion.reason.isEmpty {
                            SkeletonPlaceholder(width: 16, height: 16)
                        } else {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 2)
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

    // MARK: - Key Term Card

    struct KeyTermCard: View {
        let keyTerm: KeyTerm
        let isExpanded: Bool
        let onToggle: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header - always visible
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onToggle()
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if keyTerm.term.isEmpty {
                                SkeletonPlaceholder(width: 100, height: 16)
                            } else {
                                HighlightedKeyTermText(term: keyTerm.term)
                            }

                            if keyTerm.translation.isEmpty {
                                SkeletonPlaceholder(width: 150, height: 14)
                            } else {
                                Text(keyTerm.translation)
                                    .appCardText()
                            }
                        }

                        Spacer()

                        if keyTerm.term.isEmpty || keyTerm.translation.isEmpty {
                            SkeletonPlaceholder(width: 16, height: 16)
                        } else {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
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
            showFeedbackView: .constant(true),
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "",
                refinedText: "",
                suggestions: [],
                keyTerms: [],
                chosenKeyTerms: ["Hello", "World"],
                chosenRefinements: ["Hi", "Earth"]
            )
        )
    }
}

#Preview("Loading State - No Data") {
    NavigationView {
        FeedbackView(
            showFeedbackView: .constant(true),
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "",
                refinedText: "",
                suggestions: [],
                keyTerms: [],
                chosenKeyTerms: nil,
                chosenRefinements: nil
            )
        )
    }
}

#Preview("Loading State - Chosen Items Only") {
    NavigationView {
        FeedbackView(
            showFeedbackView: .constant(true),
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "This is some sample text",
                refinedText: "This is some improved sample text",
                suggestions: [],
                keyTerms: [],
                chosenKeyTerms: ["sample", "text"],
                chosenRefinements: ["improved", "better"]
            )
        )
    }
}

#Preview("Fully Loaded") {
    NavigationView {
        FeedbackView(
            showFeedbackView: .constant(true),
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            audioData: Data(),
            mediaType: .image,
            previewData: FeedbackResponse(
                originalText: "This is the original text that needs improvement.",
                refinedText: "This is the refined and improved text version.",
                suggestions: [
                    Suggestion(term: "text", refinement: "content", translation: "内容", reason: "More specific term", id: UUID()),
                    Suggestion(term: "needs", refinement: "requires", translation: "需要", reason: "More formal", id: UUID()),
                ],
                keyTerms: [
                    KeyTerm(term: "original", translation: "原始的", example: "This is the original version", id: UUID()),
                    KeyTerm(term: "improvement", translation: "改进", example: "We need to make improvements", id: UUID()),
                ],
                chosenKeyTerms: ["original", "improvement"],
                chosenRefinements: ["content", "requires"]
            )
        )
    }
}
