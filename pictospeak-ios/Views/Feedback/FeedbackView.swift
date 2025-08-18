//
//  FeedbackView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FeedbackViewModel
    @State private var selectedTab: FeedbackTab = .aiRefined
    @Binding var showFeedbackView: Bool
    @State private var expandedCards: Set<UUID> = []

    let selectedImage: UIImage
    let audioData: Data
    let mediaType: MediaType

    // Default initializer for normal use
    init(showFeedbackView: Binding<Bool>, selectedImage: UIImage, audioData: Data, mediaType: MediaType) {
        _showFeedbackView = showFeedbackView
        self.selectedImage = selectedImage
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel())
    }

    // Initializer for previews with fake data
    init(showFeedbackView: Binding<Bool>, selectedImage: UIImage, audioData: Data, mediaType: MediaType, previewData: FeedbackResponse) {
        _showFeedbackView = showFeedbackView
        self.selectedImage = selectedImage
        self.audioData = audioData
        self.mediaType = mediaType
        _viewModel = StateObject(wrappedValue: FeedbackViewModel(previewData: previewData))
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

                if viewModel.isLoading {
                    ProgressView("Loading feedback...")
                        .font(.title2)
                        .foregroundColor(.gray)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let feedback = viewModel.feedbackResponse {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 30) {
                                textComparisonSection(feedback, scrollProxy: proxy.scrollTo)
                                suggestionsAndKeyTermsSection(feedback)
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
            // Only load feedback if we don't already have preview data
            if viewModel.feedbackResponse == nil {
                viewModel.loadFeedback(image: selectedImage, audioData: audioData, mediaType: mediaType)
            }
        }
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
                    Text(feedback.originalText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(.label))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // AI Refined text with clickable matches
                    let clickableMatches = getClickableMatches(from: feedback)

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
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Suggestions and Key Terms Section

    private func suggestionsAndKeyTermsSection(_ feedback: FeedbackResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !feedback.suggestions.isEmpty || !feedback.keyTerms.isEmpty {
                Text("Key Expressions")
                    .appTitle()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }

            // Combined section with key terms and suggestions
            VStack(alignment: .leading, spacing: 12) {
                // Key Terms
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

                // Suggestions
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
}

// MARK: - Self-Sizing Text View

class SelfSizingTextView: UITextView {
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
                        HighlightedSuggestionText(
                            term: suggestion.term,
                            refinement: suggestion.refinement
                        )

                        Text(suggestion.translation)
                            .appCardText()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)

                    Text(suggestion.reason)
                        .appCardText(fontSize: 14)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Highlighted Suggestion Text

struct HighlightedSuggestionText: View {
    let term: String
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

        // Add the term
        var termText = AttributedString(term)
        attributedString.append(termText)

        // Add the arrow
        var arrowText = AttributedString(" → ")
        attributedString.append(arrowText)

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
                        HighlightedKeyTermText(term: keyTerm.term)

                        Text(keyTerm.translation)
                            .appCardText()
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)

                    Text(keyTerm.example)
                        .appCardText(fontSize: 14)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showFeedbackView = true

        var body: some View {
            let sampleImage = UIImage(systemName: "photo") ?? UIImage()
            let sampleAudioData = Data()

            // Create fake data for preview
            let fakeFeedback = FeedbackResponse(
                originalText: "The children played happily in the park.",
                refinedText: "The children played joyfully in the park, demonstrating their carefree nature.",
                suggestions: [
                    Suggestion(
                        term: "played happily",
                        refinement: "played joyfully",
                        translation: "愉快地玩耍",
                        reason: "joyfully 比 happily 更生动地传达了孩子们在公园里玩耍时的开心情绪。"
                    ),
                ],
                keyTerms: [
                    KeyTerm(
                        term: "joyfully",
                        translation: "欢快地",
                        example: "She danced joyfully at the celebration. (她在庆祝活动中欢快地跳舞)"
                    ),
                    KeyTerm(
                        term: "carefree",
                        translation: "无忧无虑的",
                        example: "The carefree nature of childhood is precious. (童年无忧无虑的天性是珍贵的)"
                    ),
                ],
                score: 85
            )

            return FeedbackView(
                showFeedbackView: $showFeedbackView,
                selectedImage: sampleImage,
                audioData: sampleAudioData,
                mediaType: .image,
                previewData: fakeFeedback
            )
        }
    }

    return PreviewWrapper()
}
