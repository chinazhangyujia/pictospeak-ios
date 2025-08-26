//
//  ContentView.swift
//  pictospeak-ios
//
//  Created by Yujia Zhang on 8/4/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = Router()
    var body: some View {
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
                    }
                }
        }
        .environmentObject(router)
    }
}

#Preview {
    ContentView()
        .environmentObject(Router())
}
