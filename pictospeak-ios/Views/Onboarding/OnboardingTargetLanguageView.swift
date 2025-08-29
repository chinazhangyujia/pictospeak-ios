//
//  OnboardingTargetLanguageView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct OnboardingTargetLanguageView: View {
    @EnvironmentObject private var router: Router
    @State private var selectedLanguage: String = "English"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // Main content
            VStack(spacing: 32) {
                // Title
                Text("What language do you\nwant to learn?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Language selection box
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        // Flag icon
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 40, height: 40)

                            Text("🇺🇸")
                                .font(.system(size: 20))
                        }

                        // Language text
                        Text("English")
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

                // Coming soon text
                Text("More languages coming soon")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)

            Spacer()

            // Continue button
            Button(action: {
                router.goTo(.onboardingNativeLanguage(selectedTargetLanguage: selectedLanguage))
            }) {
                Text("Continue")
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
}

#Preview {
    OnboardingTargetLanguageView()
        .environmentObject(Router())
}
