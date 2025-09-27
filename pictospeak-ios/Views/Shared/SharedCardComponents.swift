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
                Rectangle()
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
            .clipped()
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
            VStack(spacing: 26) {
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
                                .foregroundColor(AppTheme.primaryBlue)
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
                            .frame(width: 20, height: 20)
                        }
                    }

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
            VStack(spacing: 26) {
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
                                    .foregroundColor(AppTheme.primaryBlue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 20, height: 20)
                        }
                    }

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

// MARK: - Session Card

struct SessionCard: View {
    let session: SessionItem

    var body: some View {
        HStack(spacing: 10) {
            // AsyncImage for loading actual session image
            AsyncImage(url: URL(string: session.materialUrl)) { image in
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

                Text("Today")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))
                    .kerning(-0.1)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.02), radius: 16, x: 0, y: 1)
    }
}
