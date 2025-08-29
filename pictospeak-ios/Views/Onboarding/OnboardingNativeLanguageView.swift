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
            // Top navigation
            HStack {
                Button(action: {
                    onboardingRouter.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Main content
            VStack(spacing: 32) {
                // Title
                Text("Choose learning language")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Description
                Text("Used for explanations and translations. You can change this in Settings.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)

                // Language selection options
                VStack(spacing: 16) {
                    // Chinese option
                    LanguageOptionView(
                        flag: "🇨🇳",
                        language: "中文 (简体)",
                        isSelected: selectedNativeLanguage == "Chinese",
                        action: { selectedNativeLanguage = "Chinese" }
                    )

                    // English option
                    LanguageOptionView(
                        flag: "🇺🇸",
                        language: "English",
                        isSelected: selectedNativeLanguage == "English",
                        action: { selectedNativeLanguage = "English" }
                    )
                }

                // Request other languages link
                Button(action: {
                    print("🔐 Requesting other languages")
                }) {
                    Text("Request other languages")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .underline()
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Get Started button
            Button(action: {
                completeOnboarding()
            }) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationBarHidden(true)
    }

    private func completeOnboarding() {
        // Create user setting from selected languages
        let userSetting = UserSetting(
            targetLanguage: selectedTargetLanguage.uppercased(),
            nativeLanguage: selectedNativeLanguage.uppercased()
        )
        
        // Set the user setting in ContentViewModel
        contentViewModel.setUserSetting(userSetting)

    }
    

}

struct LanguageOptionView: View {
    let flag: String
    let language: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }

                // Flag icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Text(flag)
                        .font(.system(size: 20))
                }

                // Language text
                Text(language)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OnboardingNativeLanguageView(selectedTargetLanguage: "English")
        .environmentObject(Router())
        .environmentObject(ContentViewModel())
}
