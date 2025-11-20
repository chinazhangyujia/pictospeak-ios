//
//  OnboardingNativeLanguageView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct OnboardingNativeLanguageView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    let selectedTargetLanguage: String
    let sourceView: SourceView?

    @State private var selectedNativeLanguage: String = "English"
    @State private var nativeLanguages: [BackendLanguage] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    init(selectedTargetLanguage: String, sourceView: SourceView? = nil) {
        self.selectedTargetLanguage = selectedTargetLanguage
        self.sourceView = sourceView
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(maxHeight: 80)

            // Main content
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("What language do you want to learn in?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(12)
                        .tracking(0.38)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Select the language for explanations and translations")
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
                    // Language selection options
                    VStack(spacing: 20) {
                        ForEach(nativeLanguages, id: \.code) { language in
                            LanguageSelectionRow(
                                flag: getFlagEmoji(for: language.code),
                                language: language.name,
                                isSelected: selectedNativeLanguage.lowercased() == language.name.lowercased(),
                                action: { toggleLanguage(language.name) }
                            )
                        }
                    }
                }

                // Request other languages link
                Button(action: {}) {
                    Text("Request other languages")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppTheme.primaryBlue)
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            Button(action: {
                completeUserSetting()
                if sourceView == .settings {
                    // Go back to settings after updating
                    router.goBack()
                    router.goBack()
                } else {
                    onboardingRouter.goTo(.auth(initialMode: .signUp))
                }
            }) {
                Text(sourceView == .settings ? "Save" : "Get Started")
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
        .task {
            await fetchLanguages()
        }
    }

    private func fetchLanguages() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await LanguageService.shared.fetchSupportedLanguages()

            // Filter out the selected target language from the native languages list
            let filteredLanguages = response.nativeLanguages.filter { language in
                language.name.lowercased() != selectedTargetLanguage.lowercased()
            }

            nativeLanguages = filteredLanguages

            if nativeLanguages.isEmpty {
                // If list is empty (should be impossible), keep loading state
                isLoading = true
                return
            }

            // Set initial selection if available, or default to first one
            if !nativeLanguages.contains(where: { $0.name.lowercased() == selectedNativeLanguage.lowercased() }) {
                if let firstLanguage = nativeLanguages.first {
                    selectedNativeLanguage = firstLanguage.name
                }
            }

            isLoading = false
        } catch {
            print("❌ Failed to fetch supported languages: \(error)")
            errorMessage = "Failed to load languages. Please check your connection."
            isLoading = false
        }
    }

    private func getFlagEmoji(for code: String) -> String {
        // Map language codes to flag emojis
        // This is a simple mapping, you might want to expand this or move to a utility
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
        selectedNativeLanguage = language
    }

    private func completeUserSetting() {
        // Create user setting from selected languages
        let userSetting = UserSetting(
            targetLanguage: selectedTargetLanguage.uppercased(),
            nativeLanguage: selectedNativeLanguage.uppercased()
        )

        // Check if user is authenticated
        if contentViewModel.authToken == nil {
            // User is not authenticated, save to UserDefaults for later use during signup
            let saved = UserDefaultManager.shared.savePreSignUpUserSetting(userSetting)
            if saved {
                print("✅ User settings saved to UserDefaults (pre-signup)")
            } else {
                print("❌ Failed to save user settings to UserDefaults")
            }
        } else {
            // User is authenticated, update user settings on the backend
            Task {
                do {
                    try await UserSettingService.shared.upsertUserSettings(authToken: contentViewModel.authToken!, userSetting: userSetting)
                    print("✅ User settings updated successfully on backend")
                } catch {
                    print("❌ Failed to update user settings on backend: \(error)")
                    // Continue with onboarding even if backend update fails
                }
            }
        }

        // Set the user setting in ContentViewModel
        contentViewModel.setUserSetting(userSetting)
    }
}

#Preview {
    OnboardingNativeLanguageView(selectedTargetLanguage: "English")
        .environmentObject(Router())
        .environmentObject(ContentViewModel())
}
