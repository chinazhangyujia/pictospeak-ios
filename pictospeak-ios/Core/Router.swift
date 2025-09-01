import SwiftUI

enum AppRoute: Hashable {
    case home
    case capture
    case speakFromImage(selectedImage: UIImage)
    case speakFromVideo(selectedVideo: URL)
    case speakFromMaterials(materialsModel: InternalUploadedMaterialsModel)
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
        case let .speakFromImage(selectedImage):
            hasher.combine(2)
            hasher.combine(selectedImage.hashValue)
        case let .speakFromVideo(selectedVideo):
            hasher.combine(3)
            hasher.combine(selectedVideo.hashValue)
        case let .speakFromMaterials(materialsModel):
            hasher.combine(3)
            hasher.combine(ObjectIdentifier(materialsModel))
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
        case let (.speakFromImage(lhsImage), .speakFromImage(rhsImage)):
            return lhsImage.hashValue == rhsImage.hashValue
        case let (.speakFromVideo(lhsVideo), .speakFromVideo(rhsVideo)):
            return lhsVideo.hashValue == rhsVideo.hashValue
        case let (.speakFromMaterials(lhsMaterialsModel), .speakFromMaterials(rhsMaterialsModel)):
            return lhsMaterialsModel === rhsMaterialsModel
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
