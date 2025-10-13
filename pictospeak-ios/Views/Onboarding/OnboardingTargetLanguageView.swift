//
//  OnboardingTargetLanguageView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct OnboardingTargetLanguageView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @State private var selectedLanguage: String = "English"

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
                .padding(.bottom, 48)

                // Language selection box
                VStack(spacing: 20) {
                    // Flag icon
                    LanguageSelectionRow(
                        flag: "🇺🇸",
                        language: "English",
                        isSelected: selectedLanguage == "English",
                        action: { toggleLanguage("English") }
                    )
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
                onboardingRouter.goTo(.onboardingNativeLanguage(selectedTargetLanguage: selectedLanguage))
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
        }
        .background(AppTheme.viewBackgroundGray)
        .navigationBarHidden(true)
    }

    private func toggleLanguage(_ language: String) {
        selectedLanguage = language
    }
}

#Preview {
    OnboardingTargetLanguageView()
        .environmentObject(Router())
}
