//
//  OnboardingTargetLanguageView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct OnboardingTargetLanguageView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @EnvironmentObject private var router: Router
    let sourceView: SourceView?

    @State private var selectedLanguage: String = "English"
    @State private var targetLanguages: [BackendLanguage] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    init(sourceView: SourceView? = nil) {
        self.sourceView = sourceView
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(maxHeight: 120)

            // Main content
            VStack {
                // Title and subtitle
                VStack(spacing: 12) {
                    Text("What language do you want to learn?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(12)
                        .tracking(0.38)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("You can change this later in Settings")
                        .font(.body)
                        .foregroundColor(Color(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255).opacity(0.6))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 24)

                if isLoading {
                    ProgressView()
                        .padding(.vertical, 20)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await fetchLanguages() }
                    }
                } else {
                    // Language selection box
                    VStack(spacing: 20) {
                        ForEach(targetLanguages, id: \.code) { language in
                            LanguageSelectionRow(
                                flag: getFlagEmoji(for: language.code),
                                language: language.name,
                                isSelected: selectedLanguage.lowercased() == language.name.lowercased(),
                                action: { toggleLanguage(language.name) }
                            )
                        }
                    }
                }

                // Coming soon text
                Text("More languages coming soon")
                    .font(.body)
                    .foregroundColor(Color(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255).opacity(0.6))
                    .padding(.top, 20)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Continue button
            Button(action: {
                if sourceView == .settings {
                    router.goTo(.onboardingNativeLanguage(selectedTargetLanguage: selectedLanguage, sourceView: .settings))
                } else {
                    onboardingRouter.goTo(.onboardingNativeLanguage(selectedTargetLanguage: selectedLanguage, sourceView: nil))
                }
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 100)
                            .fill(AppTheme.primaryBlue)
                    )
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
            .disabled(isLoading || errorMessage != nil)
            .opacity(isLoading || errorMessage != nil ? 0.6 : 1.0)
        }
        .background(AppTheme.backgroundGradient)
        .navigationBarHidden(sourceView == nil)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchLanguages()
        }
    }

    private func fetchLanguages() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await LanguageService.shared.fetchSupportedLanguages()
            targetLanguages = response.targetLanguages

            // Set initial selection if available, or default to first one
            if !targetLanguages.isEmpty {
                if !targetLanguages.contains(where: { $0.name.lowercased() == selectedLanguage.lowercased() }) {
                    if let firstLanguage = targetLanguages.first {
                        selectedLanguage = firstLanguage.name
                    }
                }
            } else {
                // Should keep loading if no languages, but typically we'd expect at least one
                // For safety, we'll just stop loading so user isn't stuck, or you can choose to keep spinning
                // isLoading = true; return // if you want strict "must have data" behavior
            }
            isLoading = false
        } catch {
            print("❌ Failed to fetch supported target languages: \(error)")
            errorMessage = "Failed to load languages. Please check your connection."
            isLoading = false
        }
    }

    private func getFlagEmoji(for code: String) -> String {
        // Map language codes to flag emojis
        switch code.lowercased() {
        case "zh": return "🇨🇳"
        case "en": return "🇺🇸"
        case "es": return "🇪🇸"
        case "ja": return "🇯🇵"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "it": return "🇮🇹"
        case "pt": return "🇵🇹"
        case "ru": return "🇷🇺"
        case "ko": return "🇰🇷"
        default: return "🏳️"
        }
    }

    private func toggleLanguage(_ language: String) {
        selectedLanguage = language
    }
}

#Preview {
    OnboardingTargetLanguageView()
        .environmentObject(Router())
}
