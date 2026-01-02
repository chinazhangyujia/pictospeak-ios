//
//  SharedCardComponents.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import AVFoundation
import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.3),
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
            )
            .onAppear {
                phase = 200
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Skeleton Placeholder

struct SkeletonPlaceholder: View {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
            .modifier(ShimmerEffect())
    }
}

struct ReviewMetadata: Codable {
    let descriptionTitle: String
    let standardDescription: String
}

// MARK: - Formatted Review Text

struct FormattedReviewText: View {
    let text: String
    let highlight: String
    let onClick: (() -> Void)?

    var body: some View {
        let fontRegular = Font.system(size: 15, weight: .regular)
        let fontHighlight = Font.system(size: 15, weight: .semibold)
        let colorHighlight = AppTheme.primaryBlue
        let colorRegular = Color.black
        let kerning: CGFloat = -0.23
        let lineSpacing: CGFloat = 9.38
        let icon = Image(systemName: "arrow.up.right.square")

        var combinedText: Text

        if !highlight.isEmpty, let range = text.range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive]) {
            let prefix = Text(text[..<range.lowerBound])
                .font(fontRegular)
                .foregroundColor(colorRegular)
                .kerning(kerning)

            let match = Text(text[range])
                .font(fontHighlight)
                .foregroundColor(colorHighlight)
                .kerning(kerning)

            let suffix = Text(text[range.upperBound...])
                .font(fontRegular)
                .foregroundColor(colorRegular)
                .kerning(kerning)

            combinedText = prefix + match + suffix
        } else {
            combinedText = Text(text)
                .font(fontRegular)
                .foregroundColor(colorRegular)
                .kerning(kerning)
        }

        // Add 4px padding-top equivalent (handled by layout if needed, but here we construct the text)
        return (combinedText + Text(" ") + Text(icon).font(fontRegular).foregroundColor(colorRegular))
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(.leading)
            .onTapGesture {
                onClick?()
            }
    }
}

// MARK: - Key Term Card

struct KeyTermCard: View {
    let isReviewCard: Bool
    let date: Date?
    let keyTerm: KeyTerm
    let isExpanded: Bool
    let onToggle: () -> Void
    let onFavoriteToggle: (UUID, Bool) -> Void
    let onClickDetailText: (() -> Void)?
    let languageCode: String
    let reviewMetadata: ReviewMetadata?
    let isUserChosen: Bool

    init(isReviewCard: Bool, date: Date? = nil, keyTerm: KeyTerm, isExpanded: Bool, onToggle: @escaping () -> Void, onFavoriteToggle: @escaping (UUID, Bool) -> Void, onClickDetailText: (() -> Void)? = nil, languageCode: String = "en-US", reviewMetadata: ReviewMetadata? = nil, isUserChosen: Bool = false) {
        self.isReviewCard = isReviewCard
        self.date = date
        self.keyTerm = keyTerm
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.onFavoriteToggle = onFavoriteToggle
        self.onClickDetailText = onClickDetailText
        self.languageCode = languageCode
        self.reviewMetadata = reviewMetadata
        self.isUserChosen = isUserChosen
    }

    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var showReasonTranslation = false

    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    private var formattedDateString: String {
        guard let date = date else { return "" }

        let now = Date()
        // Check if less than 24 hours
        if abs(now.timeIntervalSince(date)) < 24 * 60 * 60 {
            return NSLocalizedString("common.today", comment: "Today")
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)

        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if year == currentYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header - always visible
            VStack(spacing: 8) { // Reduced vertical spacing
                // Top row: Term + Speaker + Bookmark
                HStack(alignment: .center, spacing: 8) {
                    // Term
                    if keyTerm.term.isEmpty {
                        SkeletonPlaceholder(width: 100, height: 20)
                    } else {
                        Text(keyTerm.term)
                            .appCardHeaderText(color: AppTheme.primaryBlue, weight: .bold) // Using bold as per image
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
                                .foregroundColor(AppTheme.primaryBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 24, height: 24)
                    }

                    Spacer()

                    // Bookmark button
                    if keyTerm.term.isEmpty {
                        SkeletonPlaceholder(width: 16, height: 16)
                            .modifier(ShimmerEffect())
                    } else {
                        Button(action: {
                            onFavoriteToggle(keyTerm.id, !keyTerm.favorite)
                        }) {
                            Image(systemName: keyTerm.favorite ? "bookmark.fill" : "bookmark") // Using bookmark as per image
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(keyTerm.favorite ? AppTheme.primaryBlue : AppTheme.gray8c8c8c)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 22, height: 22)
                        .disabled(keyTerm.term.isEmpty || keyTerm.id == .zero && !isUserChosen)
                    }
                }

                // Phonetic Symbol Row
                if let phonetic = keyTerm.phoneticSymbol, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.gray8c8c8c)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Bottom row: POS + Translation + Chevron
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 8) {
                        // POS Tag
                        if let firstTranslation = keyTerm.translations.first, !firstTranslation.pos.isEmpty {
                            Text(firstTranslation.pos)
                                .font(.caption)
                                .italic()
                                .foregroundColor(.secondary)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .frame(minWidth: 24)
                                .frame(height: 24)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppTheme.grayE5E5EA, lineWidth: 1)
                                )
                        }

                        // Translation
                        if let translation = keyTerm.translations.first?.translation, !translation.isEmpty {
                            Text(translation)
                                .font(.system(size: 15, weight: .regular))
                                .lineSpacing(5) // Line height 20 - Font size 15 = 5
                                .foregroundColor(.primary)
                        } else if keyTerm.term.isEmpty {
                            SkeletonPlaceholder(width: 150, height: 14)
                        }
                    }

                    Spacer()

                    // Chevron
                    if keyTerm.term.isEmpty || (keyTerm.translations.first?.translation.isEmpty ?? true) || keyTerm.example.sentence.isEmpty {
                        SkeletonPlaceholder(width: 20, height: 16)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.gray)
                            .frame(width: 24, height: 24)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !(keyTerm.term.isEmpty || (keyTerm.translations.first?.translation.isEmpty ?? true) || keyTerm.example.sentence.isEmpty) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onToggle()
                        }
                    }
                }
            }
            .padding(16)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(AppTheme.graye6e6e6)
                        .frame(height: 1)

                    if let reviewMetadata = reviewMetadata {
                        // Review Detail Section
                        FormattedReviewText(
                            text: reviewMetadata.standardDescription,
                            highlight: keyTerm.term,
                            onClick: onClickDetailText
                        )
                        .padding(.top, 4)

                        // Date (For Review Card)
                        if let _ = date {
                            HStack(spacing: 4) {
                                Text(formattedDateString)
                                    .font(.system(size: 15, weight: .regular))
                                    .italic()
                                    .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3))
                                    .kerning(-0.23)
                                    .lineSpacing(5)

                                if !reviewMetadata.descriptionTitle.isEmpty {
                                    Text("•")
                                        .font(.system(size: 15, weight: .regular))
                                        .italic()
                                        .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3))
                                        .lineSpacing(5)

                                    Text(reviewMetadata.descriptionTitle)
                                        .font(.system(size: 15, weight: .regular))
                                        .italic()
                                        .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3))
                                        .kerning(-0.23)
                                        .lineSpacing(5)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        // Analysis Section (Hidden for Review Card)
                        if !keyTerm.reason.reason.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(NSLocalizedString("card.analysis", comment: "Analysis").uppercased())
                                        .font(.system(size: 12, weight: .medium))
                                        .kerning(0.61)
                                        .lineSpacing(4.5) // 16.5 - 12 = 4.5
                                        .foregroundColor(AppTheme.gray8c8c8c)

                                    Spacer()

                                    // Translate button placeholder - functional logic can be added later
                                    Button(action: {
                                        showReasonTranslation.toggle()
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "translate")
                                            Text(NSLocalizedString("card.translate", comment: "Translate"))
                                        }
                                        .font(.caption)
                                        .foregroundColor(showReasonTranslation ? .white : .secondary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(showReasonTranslation ? AppTheme.primaryBlue : AppTheme.grayF2F2F7)
                                        .cornerRadius(1000)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Text(showReasonTranslation && !keyTerm.reason.reasonTranslation.isEmpty ? keyTerm.reason.reasonTranslation : keyTerm.reason.reason)
                                    .font(.system(size: 15, weight: .regular))
                                    .kerning(-0.23)
                                    .lineSpacing(9.38) // 24.38 - 15 = 9.38
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .animation(.easeInOut, value: showReasonTranslation)
                            }
                        }

                        // Example Section
                        if !keyTerm.example.sentence.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("card.example", comment: "Example").uppercased())
                                    .font(.system(size: 12, weight: .medium))
                                    .kerning(0.61)
                                    .lineSpacing(4.5) // 16.5 - 12 = 4.5
                                    .foregroundColor(AppTheme.gray8c8c8c)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(keyTerm.example.sentence)
                                        .font(.system(size: 15, weight: .regular))
                                        .kerning(-0.23)
                                        .lineSpacing(9.38) // 24.38 - 15 = 9.38
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if !keyTerm.example.sentenceTranslation.isEmpty {
                                        Text(keyTerm.example.sentenceTranslation)
                                            .font(.system(size: 13, weight: .regular))
                                            .kerning(-0.08)
                                            .lineSpacing(6.5) // 19.5 - 13 = 6.5
                                            .foregroundColor(AppTheme.gray8c8c8c)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white) // Using white background as per image, assuming card background
        .clipShape(RoundedRectangle(cornerRadius: 16)) // Slightly reduced corner radius
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2) // Subtle shadow
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let isReviewCard: Bool
    let date: Date?
    let suggestion: Suggestion
    let isExpanded: Bool
    let onToggle: () -> Void
    let onFavoriteToggle: (UUID, Bool) -> Void
    let onClickDetailText: (() -> Void)?
    let languageCode: String
    let reviewMetadata: ReviewMetadata?

    init(isReviewCard: Bool = false, date: Date? = nil, suggestion: Suggestion, isExpanded: Bool, onToggle: @escaping () -> Void, onFavoriteToggle: @escaping (UUID, Bool) -> Void, onClickDetailText: (() -> Void)? = nil, languageCode: String = "en-US", reviewMetadata: ReviewMetadata? = nil) {
        self.isReviewCard = isReviewCard
        self.date = date
        self.suggestion = suggestion
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.onFavoriteToggle = onFavoriteToggle
        self.onClickDetailText = onClickDetailText
        self.languageCode = languageCode
        self.reviewMetadata = reviewMetadata
    }

    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var showReasonTranslation = false

    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    private var formattedDateString: String {
        guard let date = date else { return "" }

        let now = Date()
        // Check if less than 24 hours
        if abs(now.timeIntervalSince(date)) < 24 * 60 * 60 {
            return NSLocalizedString("common.today", comment: "Today")
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)

        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if year == currentYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header - always visible
            VStack(spacing: 8) {
                // Original Term (Only when expanded)
                if isExpanded {
                    HStack(spacing: 4) {
                        Text(suggestion.term)
                            .font(.subheadline)
                            .strikethrough()
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.turn.right.down")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Bookmark button (Moved here when expanded)
                        if !(suggestion.refinement.isEmpty) {
                            Button(action: {
                                onFavoriteToggle(suggestion.id, !suggestion.favorite)
                            }) {
                                Image(systemName: suggestion.favorite ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(suggestion.favorite ? AppTheme.primaryBlue : AppTheme.gray8c8c8c)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 22, height: 22)
                            .disabled(suggestion.refinement.isEmpty || suggestion.id == .zero)
                        }
                    }
                    .padding(.bottom, 4)
                }

                // Top row: Refinement + Speaker + Bookmark (if collapsed)
                HStack(alignment: .center, spacing: 8) {
                    // Refinement (Main Term)
                    if suggestion.refinement.isEmpty {
                        SkeletonPlaceholder(width: 100, height: 20)
                    } else {
                        Text(suggestion.refinement)
                            .appCardHeaderText(color: AppTheme.primaryBlue, weight: .bold)
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
                                .foregroundColor(AppTheme.primaryBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 24, height: 24)
                    }

                    Spacer()

                    // Bookmark button (Visible here only when NOT expanded)
                    if !isExpanded {
                        if suggestion.refinement.isEmpty || suggestion.id == .zero {
                            SkeletonPlaceholder(width: 16, height: 16)
                                .modifier(ShimmerEffect())
                        } else {
                            Button(action: {
                                onFavoriteToggle(suggestion.id, !suggestion.favorite)
                            }) {
                                Image(systemName: suggestion.favorite ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(suggestion.favorite ? AppTheme.primaryBlue : AppTheme.gray8c8c8c)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 22, height: 22)
                            .disabled(suggestion.refinement.isEmpty || suggestion.id == .zero)
                        }
                    }
                }

                // Phonetic Symbol Row
                if let phonetic = suggestion.phoneticSymbol, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.gray8c8c8c)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Bottom row: POS + Translation + Chevron
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 8) {
                        // POS Tag
                        if let firstTranslation = suggestion.translations.first, !firstTranslation.pos.isEmpty {
                            Text(firstTranslation.pos)
                                .font(.caption)
                                .italic()
                                .foregroundColor(.secondary)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .frame(minWidth: 24)
                                .frame(height: 24)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppTheme.grayE5E5EA, lineWidth: 1)
                                )
                        }

                        // Translation
                        if let translation = suggestion.translations.first?.translation, !translation.isEmpty {
                            Text(translation)
                                .font(.system(size: 15, weight: .regular))
                                .lineSpacing(5) // Line height 20 - Font size 15 = 5
                                .foregroundColor(.primary)
                        } else if suggestion.refinement.isEmpty {
                            SkeletonPlaceholder(width: 150, height: 14)
                        }
                    }

                    Spacer()

                    // Chevron
                    if suggestion.refinement.isEmpty || (suggestion.translations.first?.translation.isEmpty ?? true) || suggestion.reason.reason.isEmpty {
                        SkeletonPlaceholder(width: 20, height: 16)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.gray)
                            .frame(width: 24, height: 24)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !(suggestion.refinement.isEmpty || (suggestion.translations.first?.translation.isEmpty ?? true) || suggestion.reason.reason.isEmpty) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onToggle()
                        }
                    }
                }
            }
            .padding(16)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(Color(red: 0.902, green: 0.902, blue: 0.902))
                        .frame(height: 1)

                    if let reviewMetadata = reviewMetadata {
                        // Review Detail Section
                        FormattedReviewText(
                            text: reviewMetadata.standardDescription,
                            highlight: suggestion.refinement,
                            onClick: onClickDetailText
                        )
                        .padding(.top, 4)

                        // Date (For Review Card)
                        if let _ = date {
                            HStack(spacing: 4) {
                                Text(formattedDateString)
                                    .font(.system(size: 15, weight: .regular))
                                    .italic()
                                    .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3))
                                    .kerning(-0.23)
                                    .lineSpacing(5)

                                if !reviewMetadata.descriptionTitle.isEmpty {
                                    Text("•")
                                        .font(.system(size: 15, weight: .regular))
                                        .italic()
                                        .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3))
                                        .lineSpacing(5)

                                    Text(reviewMetadata.descriptionTitle)
                                        .font(.system(size: 15, weight: .regular))
                                        .italic()
                                        .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3))
                                        .kerning(-0.23)
                                        .lineSpacing(5)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        // Analysis Section (Hidden for Review Card)
                        if !suggestion.reason.reason.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(NSLocalizedString("card.analysis", comment: "Analysis").uppercased())
                                        .font(.system(size: 12, weight: .medium))
                                        .kerning(0.61)
                                        .lineSpacing(4.5) // 16.5 - 12 = 4.5
                                        .foregroundColor(AppTheme.gray8c8c8c)

                                    Spacer()

                                    Button(action: {
                                        showReasonTranslation.toggle()
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "translate")
                                            Text(NSLocalizedString("card.translate", comment: "Translate"))
                                        }
                                        .font(.caption)
                                        .foregroundColor(showReasonTranslation ? .white : .secondary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(showReasonTranslation ? AppTheme.primaryBlue : AppTheme.grayF2F2F7)
                                        .cornerRadius(1000)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Text(showReasonTranslation && !suggestion.reason.reasonTranslation.isEmpty ? suggestion.reason.reasonTranslation : suggestion.reason.reason)
                                    .font(.system(size: 15, weight: .regular))
                                    .kerning(-0.23)
                                    .lineSpacing(9.38) // 24.38 - 15 = 9.38
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .animation(.easeInOut, value: showReasonTranslation)
                            }
                        }

                        // Example Section
                        if !suggestion.example.sentence.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("card.example", comment: "Example").uppercased())
                                    .font(.system(size: 12, weight: .medium))
                                    .kerning(0.61)
                                    .lineSpacing(4.5) // 16.5 - 12 = 4.5
                                    .foregroundColor(AppTheme.gray8c8c8c)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.example.sentence)
                                        .font(.system(size: 15, weight: .regular))
                                        .kerning(-0.23)
                                        .lineSpacing(9.38) // 24.38 - 15 = 9.38
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if !suggestion.example.sentenceTranslation.isEmpty {
                                        Text(suggestion.example.sentenceTranslation)
                                            .font(.system(size: 13, weight: .regular))
                                            .kerning(-0.08)
                                            .lineSpacing(6.5) // 19.5 - 13 = 6.5
                                            .foregroundColor(AppTheme.gray8c8c8c)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            // Removed colored wrapper logic
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: SessionItem

    var body: some View {
        HStack(spacing: 10) {
            // CachedAsyncImage for loading actual session image
            CachedAsyncImage(url: URL(string: session.materialThumbnailUrl ?? session.materialUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 1) {
                Text(session.standardDescription)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .kerning(-0.4)

                Spacer()

                Text(dateString)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))
                    .kerning(-0.1)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.02), radius: 16, x: 0, y: 1)
    }

    private var dateString: String {
        let dateString = session.descriptionTeaching.createdAt

        guard let date = parseDate(dateString) else { return NSLocalizedString("common.unknown", comment: "Unknown") } // Or Today?

        let now = Date()
        // Check if less than 24 hours
        if abs(now.timeIntervalSince(date)) < 24 * 60 * 60 {
            return NSLocalizedString("common.today", comment: "Today")
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)

        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if year == currentYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }

    private func parseDate(_ string: String) -> Date? {
        // Try standard ISO8601 with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) { return date }

        // Try standard ISO8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: string) { return date }

        // Try custom formats (e.g. Python default string representation)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Python str() format: 2025-08-24 01:51:30.509506+00:00
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        if let date = dateFormatter.date(from: string) { return date }

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        if let date = dateFormatter.date(from: string) { return date }

        return nil
    }
}
