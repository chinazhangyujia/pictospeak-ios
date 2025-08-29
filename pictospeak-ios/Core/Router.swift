import SwiftUI

enum AppRoute: Hashable {
    case home
    case capture
    case speak(selectedImage: UIImage, mediaType: MediaType)
    case feedbackFromSession(sessionId: UUID, pastSessionsViewModel: PastSessionsViewModel)
    case feedbackFromSpeak(selectedImage: UIImage, audioData: Data, mediaType: MediaType)
    case onboardingTargetLanguage
    case onboardingNativeLanguage(selectedTargetLanguage: String)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine(0)
        case .capture:
            hasher.combine(1)
        case let .speak(selectedImage, mediaType):
            hasher.combine(2)
            hasher.combine(selectedImage.hashValue)
            hasher.combine(mediaType)
        case let .feedbackFromSession(sessionId, pastSessionsViewModel):
            hasher.combine(3)
            hasher.combine(sessionId)
            hasher.combine(ObjectIdentifier(pastSessionsViewModel))
        case let .feedbackFromSpeak(selectedImage, audioData, mediaType):
            hasher.combine(4)
            hasher.combine(selectedImage.hashValue)
            hasher.combine(audioData.hashValue)
            hasher.combine(mediaType)
        case .onboardingTargetLanguage:
            hasher.combine(5)
        case let .onboardingNativeLanguage(selectedTargetLanguage):
            hasher.combine(6)
            hasher.combine(selectedTargetLanguage)
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home):
            return true
        case (.capture, .capture):
            return true
        case let (.speak(lhsImage, lhsMediaType), .speak(rhsImage, rhsMediaType)):
            return lhsImage.hashValue == rhsImage.hashValue && lhsMediaType == rhsMediaType
        case let (.feedbackFromSession(lhsSessionId, lhsPastSessionsViewModel), .feedbackFromSession(rhsSessionId, rhsPastSessionsViewModel)):
            return lhsSessionId == rhsSessionId && lhsPastSessionsViewModel === rhsPastSessionsViewModel
        case let (.feedbackFromSpeak(lhsImage, lhsAudioData, lhsMediaType), .feedbackFromSpeak(rhsImage, rhsAudioData, rhsMediaType)):
            return lhsImage.hashValue == rhsImage.hashValue && lhsAudioData.hashValue == rhsAudioData.hashValue && lhsMediaType == rhsMediaType
        case (.onboardingTargetLanguage, .onboardingTargetLanguage):
            return true
        case let (.onboardingNativeLanguage(lhsSelectedTargetLanguage), .onboardingNativeLanguage(rhsSelectedTargetLanguage)):
            return lhsSelectedTargetLanguage == rhsSelectedTargetLanguage
        default:
            return false
        }
    }
}

final class Router: ObservableObject {
    @Published var path = NavigationPath() {
        didSet {
            print("🧭 Navigation stack changed:")
            print("   Previous count: \(oldValue.count)")
            print("   New count: \(path.count)")
            
            // Log the current routes in the stack
            if path.count > 0 {
                print("   Current routes:")
                // Note: NavigationPath doesn't expose individual routes easily
                // We can only see the count, but this is still useful for debugging
                print("     Stack contains \(path.count) route(s)")
            } else {
                print("   Stack is empty")
            }
            print("---")
        }
    }

    func resetToHome() {
        path = NavigationPath() // Pops everything to HomeView
    }

    func goTo(_ route: AppRoute) {
        path.append(route)
    }

    func goBack() {
        path.removeLast()
    }
}

final class OnboardingRouter: ObservableObject {
    @Published var path = NavigationPath() {
        didSet {
            print("🧭 Navigation stack changed:")
            print("   Previous count: \(oldValue.count)")
            print("   New count: \(path.count)")
        }
    }

    func goTo(_ route: AppRoute) {
        path.append(route)
    }

    func goBack() {
        path.removeLast()
    }
}
