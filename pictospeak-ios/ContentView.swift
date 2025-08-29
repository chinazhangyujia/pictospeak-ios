//
//  ContentView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = Router()
    @StateObject private var onboardingRouter = OnboardingRouter()
    @StateObject private var contentViewModel = ContentViewModel()

    var body: some View {
        Group {
            if contentViewModel.isLoading {
                LoadingView()
            } else if contentViewModel.hasUserSettings {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .home:
                                HomeView()
                            case .capture:
                                CaptureView()
                            case let .speak(selectedImage, mediaType):
                                SpeakView(selectedImage: selectedImage, mediaType: mediaType)
                            case let .feedbackFromSession(sessionId, pastSessionsViewModel):
                                FeedbackView(sessionId: sessionId, pastSessionsViewModel: pastSessionsViewModel)
                            case let .feedbackFromSpeak(selectedImage, audioData, mediaType):
                                FeedbackView(selectedImage: selectedImage, audioData: audioData, mediaType: mediaType)
                            case .onboardingTargetLanguage:
                                OnboardingTargetLanguageView()
                            case let .onboardingNativeLanguage(selectedTargetLanguage):
                                OnboardingNativeLanguageView(selectedTargetLanguage: selectedTargetLanguage)
                            }
                        }
                }
            } else {
                NavigationStack(path: $onboardingRouter.path) {
                    OnboardingTargetLanguageView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .onboardingTargetLanguage:
                                OnboardingTargetLanguageView()
                            case let .onboardingNativeLanguage(selectedTargetLanguage):
                                OnboardingNativeLanguageView(selectedTargetLanguage: selectedTargetLanguage)
                            default:
                                EmptyView()
                            }
                        }
                }
            }
        }
        .environmentObject(router)
        .environmentObject(onboardingRouter)
        .environmentObject(contentViewModel)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    ContentView()
        .environmentObject(Router())
}
