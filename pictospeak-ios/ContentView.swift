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
        VStack {
            if contentViewModel.isLoading {
                LoadingView()
            } else if contentViewModel.hasOnboardingCompleted {
                TabView(selection: $router.selectedTab) {
                    Tab("Home", systemImage: "house", value: NavTab.home) {
                        NavigationStack(path: $router.homePath) {
                            HomeView()
                                .navigationDestination(for: AppRoute.self) { route in
                                    switch route {
                                    case .home:
                                        HomeView()
                                    case .capture:
                                        CaptureView()
                                    case let .speakFromImage(selectedImage):
                                        SpeakView(selectedImage: selectedImage)
                                    case let .speakFromVideo(selectedVideo):
                                        SpeakView(selectedVideo: selectedVideo)
                                    case let .speakFromMaterials(materialsModel):
                                        SpeakView(materialsModel: materialsModel)
                                    case let .feedbackFromSession(sessionId, pastSessionsViewModel):
                                        FeedbackView(sessionId: sessionId, pastSessionsViewModel: pastSessionsViewModel)
                                    case let .feedbackFromSpeak(selectedImage, selectedVideo, audioData, mediaType):
                                        FeedbackView(selectedImage: selectedImage, selectedVideo: selectedVideo, audioData: audioData, mediaType: mediaType)
                                    case .auth:
                                        AuthView()
                                    default:
                                        EmptyView()
                                    }
                                }
                        }
                    }

                    Tab("Review", systemImage: "book", value: NavTab.review) {
                        NavigationStack(path: $router.reviewPath) {
                            ReviewView()
                                .navigationDestination(for: AppRoute.self) { route in
                                    switch route {
                                    case .review:
                                        ReviewView()
                                    default:
                                        EmptyView()
                                    }
                                }
                        }
                    }

                    Tab("Capture", systemImage: "camera", value: NavTab.capture, role: .search) {
                        NavigationStack(path: $router.capturePath) {
                            CaptureView()
                                .navigationDestination(for: AppRoute.self) { route in
                                    switch route {
                                    case .capture:
                                        CaptureView()
                                    default:
                                        EmptyView()
                                    }
                                }
                        }
                    }
                }
                .tint(Color(red: 0.247, green: 0.388, blue: 0.910))
            } else {
                NavigationStack(path: $onboardingRouter.path) {
                    OnboardingTargetLanguageView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .onboardingTargetLanguage:
                                OnboardingTargetLanguageView()
                            case let .onboardingNativeLanguage(selectedTargetLanguage):
                                OnboardingNativeLanguageView(selectedTargetLanguage: selectedTargetLanguage)
                            case .auth:
                                AuthView()
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
