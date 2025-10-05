//
//  OnboardingNativeLanguageView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct OnboardingNativeLanguageView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @EnvironmentObject private var contentViewModel: ContentViewModel
    let selectedTargetLanguage: String
    @State private var selectedNativeLanguage: String = "Chinese"

    init(selectedTargetLanguage: String) {
        self.selectedTargetLanguage = selectedTargetLanguage
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
                .padding(.bottom, 48)

                // Language selection options
                VStack(spacing: 20) {
                    // Chinese option
                    LanguageSelectionRow(
                        flag: "🇨🇳",
                        language: "中文 (简体)",
                        isSelected: selectedNativeLanguage == "Chinese",
                        action: { toggleLanguage("Chinese") }
                    )

                    // English option
                    LanguageSelectionRow(
                        flag: "🇺🇸",
                        language: "English",
                        isSelected: selectedNativeLanguage == "English",
                        action: { toggleLanguage("English") }
                    )
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
                onboardingRouter.goTo(.auth(initialMode: .signUp))
            }) {
                Text("Get Started")
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
        }
        .background(AppTheme.viewBackgroundGray)
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
                    try await UserSettingService.shared.createUserSettings(authToken: contentViewModel.authToken!, userSetting: userSetting)
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
