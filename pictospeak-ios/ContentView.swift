//
//  ContentView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = Router()
    @StateObject private var contentViewModel = ContentViewModel()
    @StateObject private var pastSessionsViewModel = PastSessionsViewModel(contentViewModel: ContentViewModel())
    @StateObject private var reviewViewModel = ReviewViewModel(contentViewModel: ContentViewModel())

    var body: some View {
        VStack {
            if contentViewModel.isLoading {
                LoadingView()
            } else {
                TabView(selection: $router.selectedTab) {
                    Tab("Home", systemImage: "house", value: NavTab.home) {
                        NavigationStack(path: $router.homePath) {
                            HomeView()
                                .navigationDestination(for: AppRoute.self) { route in
                                    switch route {
                                    case .home:
                                        HomeView()
                                    case .capture:
                                        guarded(CaptureView())
                                    case let .speakFromImage(selectedImage):
                                        guarded(SpeakView(selectedImage: selectedImage))
                                    case let .speakFromVideo(selectedVideo):
                                        guarded(SpeakView(selectedVideo: selectedVideo))
                                    case let .speakFromMaterials(materialsModel):
                                        guarded(SpeakView(materialsModel: materialsModel))
                                    case let .feedbackFromSession(sessionId, pastSessionsViewModel):
                                        guarded(FeedbackView(sessionId: sessionId, pastSessionsViewModel: pastSessionsViewModel))
                                    case let .feedbackFromSpeak(selectedImage, selectedVideo, audioData, mediaType, materialId):
                                        guarded(FeedbackView(selectedImage: selectedImage, selectedVideo: selectedVideo, audioData: audioData, mediaType: mediaType, materialId: materialId))
                                    case let .review(initialTab):
                                        guarded(ReviewView(initialTab: initialTab ?? .vocabulary))
                                    case .auth:
                                        AuthView()
                                    case let .onboardingTargetLanguage(sourceView):
                                        OnboardingTargetLanguageView(sourceView: sourceView)
                                    case let .onboardingNativeLanguage(selectedTargetLanguage, sourceView):
                                        OnboardingNativeLanguageView(selectedTargetLanguage: selectedTargetLanguage, sourceView: sourceView)
                                    case let .verificationCode(email, flowType, fullName):
                                        VerificationCodeView(email: email, flowType: flowType, fullName: fullName)
                                    case let .createNewPassword(verificationId, verificationCode, email, fullName):
                                        CreateNewPasswordView(verificationId: verificationId, verificationCode: verificationCode, email: email, fullName: fullName)
                                    case .subscription:
                                        guarded(SubscriptionView())
                                    case .settings:
                                        SettingView()
                                    case .editProfile:
                                        guarded(EditProfileView())
                                    case .manageAccount:
                                        guarded(ManageAccountView())
                                    case .changePassword:
                                        guarded(ChangePasswordView())
                                    default:
                                        EmptyView()
                                    }
                                }
                        }
                    }

                    Tab("Review", systemImage: "book", value: NavTab.review) {
                        NavigationStack(path: $router.reviewPath) {
                            guarded(ReviewView())
                                .navigationDestination(for: AppRoute.self) { route in
                                    switch route {
                                    case let .review(initialTab):
                                        guarded(ReviewView(initialTab: initialTab ?? .vocabulary))
                                    case let .feedbackFromSession(sessionId, pastSessionsViewModel):
                                        guarded(FeedbackView(sessionId: sessionId, pastSessionsViewModel: pastSessionsViewModel))
                                    case let .verificationCode(email, flowType, fullName):
                                        VerificationCodeView(email: email, flowType: flowType, fullName: fullName)
                                    case let .createNewPassword(verificationId, verificationCode, email, fullName):
                                        CreateNewPasswordView(verificationId: verificationId, verificationCode: verificationCode, email: email, fullName: fullName)
                                    case let .onboardingNativeLanguage(selectedTargetLanguage, sourceView):
                                        OnboardingNativeLanguageView(selectedTargetLanguage: selectedTargetLanguage, sourceView: sourceView)
                                    case let .auth(initialMode):
                                        AuthView(initialMode: initialMode)
                                    default:
                                        EmptyView()
                                    }
                                }
                        }
                    }

                    Tab("Capture", systemImage: "camera", value: NavTab.capture, role: .search) {
                        NavigationStack(path: $router.capturePath) {
                            guarded(CaptureView())
                                .navigationDestination(for: AppRoute.self) { route in
                                    switch route {
                                    case .capture:
                                        guarded(CaptureView())
                                    case let .speakFromImage(selectedImage):
                                        guarded(SpeakView(selectedImage: selectedImage))
                                    case let .speakFromVideo(selectedVideo):
                                        guarded(SpeakView(selectedVideo: selectedVideo))
                                    case let .feedbackFromSpeak(selectedImage, selectedVideo, audioData, mediaType, materialId):
                                        guarded(FeedbackView(selectedImage: selectedImage, selectedVideo: selectedVideo, audioData: audioData, mediaType: mediaType, materialId: materialId))
                                    case let .verificationCode(email, flowType, fullName):
                                        VerificationCodeView(email: email, flowType: flowType, fullName: fullName)
                                    case let .createNewPassword(verificationId, verificationCode, email, fullName):
                                        CreateNewPasswordView(verificationId: verificationId, verificationCode: verificationCode, email: email, fullName: fullName)
                                    case let .onboardingNativeLanguage(selectedTargetLanguage, sourceView):
                                        OnboardingNativeLanguageView(selectedTargetLanguage: selectedTargetLanguage, sourceView: sourceView)
                                    case let .auth(initialMode):
                                        AuthView(initialMode: initialMode)
                                    default:
                                        EmptyView()
                                    }
                                }
                        }
                    }
                }
                .tint(AppTheme.primaryBlue)
            }
        }
        .environmentObject(router)
        .environmentObject(contentViewModel)
        .environmentObject(pastSessionsViewModel)
        .environmentObject(reviewViewModel)
        .onAppear {
            // Inject contentViewModel into pastSessionsViewModel
            // We do this here to ensure they share the same state, although creating a new one above
            // was temporary. Since contentViewModel is @StateObject here, we can just update the reference.
            pastSessionsViewModel.contentViewModel = contentViewModel
            reviewViewModel.contentViewModel = contentViewModel
            pastSessionsViewModel.reviewViewModel = reviewViewModel
        }
    }

    @ViewBuilder
    private func guarded<Content: View>(_ content: Content) -> some View {
        if contentViewModel.authToken != nil {
            content
        } else if contentViewModel.hasOnboardingCompleted {
            AuthView(initialMode: .signIn)
        } else {
            OnboardingTargetLanguageView()
        }
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
