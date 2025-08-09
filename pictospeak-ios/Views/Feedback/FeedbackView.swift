//
//  FeedbackView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedbackViewModel()
    @State private var selectedTab: FeedbackTab = .aiRefined
    @Binding var showFeedbackView: Bool

    let selectedImage: UIImage
    let audioData: Data
    let mediaType: MediaType

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
                        VStack(spacing: 20) {
                            textComparisonSection(feedback)
                            suggestionsAndKeyExpressionsSection(feedback)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .background(Color(.systemGray6))
                }
            }
        }
        .onAppear {
            viewModel.loadFeedback(image: selectedImage, audioData: audioData, mediaType: mediaType)
        }
    }

    // MARK: - Text Comparison Section

    private func textComparisonSection(_ feedback: FeedbackResponse) -> some View {
        VStack(spacing: 16) {
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
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Suggestions and Key Expressions Section

    private func suggestionsAndKeyExpressionsSection(_ feedback: FeedbackResponse) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !feedback.suggestions.isEmpty || !feedback.keyExpressions.isEmpty {
                Text("Fixes & Key Phrases")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
            }

            // Key Expressions
            if !feedback.keyExpressions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Expressions")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)

                    ForEach(feedback.keyExpressions) { expression in
                        KeyExpressionCard(expression: expression)
                    }
                }
            }

            // Suggestions
            if !feedback.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)

                    ForEach(feedback.suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
                    }
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
                .font(.title2)
                .fontWeight(.semibold)

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HighlightedSuggestionText(
                        expression: suggestion.expression,
                        refinement: suggestion.refinement
                    )
                    .font(.callout)
                    .fontWeight(.regular)
                }

                Spacer()
            }

            Text(suggestion.reason)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding(12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 20)
    }
}

// MARK: - Highlighted Suggestion Text

struct HighlightedSuggestionText: View {
    let expression: String
    let refinement: String

    var body: some View {
        Text(attributedString)
    }

    private var attributedString: AttributedString {
        let fullText = "\(expression) → \(refinement)"

        // Use NSAttributedString for easier range handling
        let nsAttributedString = NSMutableAttributedString(string: fullText)

        // Find the refinement part and highlight it
        if let range = fullText.range(of: refinement, options: .caseInsensitive) {
            let startIndex = fullText.distance(from: fullText.startIndex, to: range.lowerBound)
            let endIndex = fullText.distance(from: fullText.startIndex, to: range.upperBound)

            let nsRange = NSRange(location: startIndex, length: endIndex - startIndex)
            nsAttributedString.addAttribute(.backgroundColor, value: UIColor.systemGreen.withAlphaComponent(0.3), range: nsRange)
        } else {
            // Fallback: try to highlight the part after the arrow
            if let arrowRange = fullText.range(of: " → ") {
                let startIndex = fullText.distance(from: fullText.startIndex, to: arrowRange.upperBound)
                let nsRange = NSRange(location: startIndex, length: fullText.count - startIndex)
                nsAttributedString.addAttribute(.backgroundColor, value: UIColor.systemGreen.withAlphaComponent(0.3), range: nsRange)
            }
        }

        return AttributedString(nsAttributedString)
    }
}

// MARK: - Key Expression Card

struct KeyExpressionCard: View {
    let expression: KeyExpression

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expression.expression)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                }

                Spacer()
            }

            Text(expression.explanation)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding(12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 20)
    }
}

#Preview {
    let sampleImage = UIImage(systemName: "photo") ?? UIImage()
    let sampleAudioData = Data()
    FeedbackView(showFeedbackView: .constant(true), selectedImage: sampleImage, audioData: sampleAudioData, mediaType: .image)
}
