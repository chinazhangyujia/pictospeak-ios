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
                    ScrollView {
                        VStack(spacing: 30) {
                            textComparisonSection(feedback)
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
        .onAppear {
            // Only load feedback if we don't already have preview data
            if viewModel.feedbackResponse == nil {
                viewModel.loadFeedback(image: selectedImage, audioData: audioData, mediaType: mediaType)
            }
        }
    }

    // MARK: - Text Comparison Section

    private func textComparisonSection(_ feedback: FeedbackResponse) -> some View {
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
                let displayText = selectedTab == .mine ? feedback.originalText : feedback.refinedText
                let highlightedRanges = selectedTab == .mine ? [] : getHighlightedRanges(from: feedback)

                HighlightedTextView(
                    text: displayText,
                    highlightedRanges: highlightedRanges
                )
                .font(.body)
                .lineSpacing(4)
            }
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
                    KeyTermCard(keyTerm: keyTerm)
                }

                // Suggestions
                ForEach(feedback.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
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

    private func getHighlightedRanges(from feedback: FeedbackResponse) -> [TextRange] {
        var ranges: [TextRange] = []

        // Add ranges for refinements (highlighted in green)
        for suggestion in feedback.suggestions {
            // Find the refinement in the refined text and highlight it
            if let range = feedback.refinedText.range(of: suggestion.refinement) {
                let startIndex = feedback.refinedText.distance(from: feedback.refinedText.startIndex, to: range.lowerBound)
                let endIndex = feedback.refinedText.distance(from: feedback.refinedText.startIndex, to: range.upperBound)
                ranges.append(TextRange(startIndex: startIndex, endIndex: endIndex, color: .green))
            }
        }

        return ranges
    }
}

// MARK: - Highlighted Text View

struct HighlightedTextView: View {
    let text: String
    let highlightedRanges: [TextRange]

    var body: some View {
        Text(attributedString)
    }

    private var attributedString: AttributedString {
        // Start with NSAttributedString for easier range handling
        let nsAttributedString = NSMutableAttributedString(string: text)

        for range in highlightedRanges {
            // Ensure the range is within bounds
            guard range.startIndex >= 0 &&
                range.endIndex <= text.count &&
                range.startIndex < range.endIndex
            else {
                continue
            }

            // Add background color attribute
            let nsRange = NSRange(location: range.startIndex, length: range.endIndex - range.startIndex)
            nsAttributedString.addAttribute(.backgroundColor, value: colorFor(range.color), range: nsRange)
        }

        // Convert to AttributedString
        return AttributedString(nsAttributedString)
    }

    private func colorFor(_ color: HighlightColor) -> Color {
        switch color {
        case .purple:
            return Color.purple.opacity(0.3)
        case .blue:
            return Color.blue.opacity(0.3)
        case .green:
            return Color.green.opacity(0.3)
        case .orange:
            return Color.orange.opacity(0.3)
        }
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let suggestion: Suggestion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HighlightedSuggestionText(
                            term: suggestion.term,
                            refinement: suggestion.refinement
                        )

                        Text(suggestion.translation)
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
        // Create a flowing layout that wraps naturally
        FlowLayout {
            Text(term)
                .appCardText()
            Text(" → ")
                .appCardText()
            Text(refinement)
                .appCardText()
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// Custom FlowLayout that allows natural text wrapping
struct FlowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)

            if currentX + subviewSize.width > width && currentX > 0 {
                // Move to next line
                currentY += maxHeight
                currentX = 0
                maxHeight = 0
            }

            currentX += subviewSize.width
            maxHeight = max(maxHeight, subviewSize.height)
        }

        return CGSize(width: width, height: currentY + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineSubviews: [(subview: LayoutSubview, size: CGSize, x: CGFloat)] = []
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)

            if currentX + subviewSize.width > bounds.maxX, currentX > bounds.minX {
                // Place the current line with center alignment
                placeLineWithCenterAlignment(lineSubviews, at: currentY, maxHeight: maxHeight)

                // Move to next line
                currentY += maxHeight
                currentX = bounds.minX
                lineSubviews = []
                maxHeight = 0
            }

            lineSubviews.append((subview: subview, size: subviewSize, x: currentX))
            currentX += subviewSize.width
            maxHeight = max(maxHeight, subviewSize.height)
        }

        // Place the last line
        if !lineSubviews.isEmpty {
            placeLineWithCenterAlignment(lineSubviews, at: currentY, maxHeight: maxHeight)
        }
    }

    private func placeLineWithCenterAlignment(_ lineSubviews: [(subview: LayoutSubview, size: CGSize, x: CGFloat)], at y: CGFloat, maxHeight: CGFloat) {
        for item in lineSubviews {
            let centerY = y + (maxHeight - item.size.height) / 2
            item.subview.place(at: CGPoint(x: item.x, y: centerY), proposal: .unspecified)
        }
    }
}

// MARK: - Key Term Card

struct KeyTermCard: View {
    let keyTerm: KeyTerm
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(keyTerm.term)
                            .appCardText()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

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
                        term: "looking at the ground",
                        refinement: "looking ahead",
                        translation: "向前看",
                        reason: "looking at the ground 是低头看地；looking ahead 是向前看，更符合语境。"
                    ),
                    Suggestion(
                        term: "played happily",
                        refinement: "played joyfully",
                        translation: "愉快地玩耍",
                        reason: "joyfully 比 happily 更生动地传达了孩子们在公园里玩耍时的开心情绪。"
                    ),
                ],
                keyTerms: [
                    KeyTerm(
                        term: "happily",
                        translation: "愉快地",
                        example: "The children played happily in the park. (孩子们在公园里愉快地玩耍)"
                    ),
                    KeyTerm(
                        term: "joyfully",
                        translation: "欢快地",
                        example: "She danced joyfully at the celebration. (她在庆祝活动中欢快地跳舞)"
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
