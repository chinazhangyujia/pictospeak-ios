import SwiftUI

enum NavTab: Hashable {
    case home
    case review
    case capture
}

enum AppRoute: Hashable {
    case home
    case review
    case capture
    case speakFromImage(selectedImage: UIImage)
    case speakFromVideo(selectedVideo: URL)
    case speakFromMaterials(materialsModel: InternalUploadedMaterialsViewModel)
    case feedbackFromSession(sessionId: UUID, pastSessionsViewModel: PastSessionsViewModel)
    case feedbackFromSpeak(selectedImage: UIImage?, selectedVideo: URL?, audioData: Data, mediaType: MediaType)
    case onboardingTargetLanguage
    case onboardingNativeLanguage(selectedTargetLanguage: String)
    case auth

    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine(0)
        case .review:
            hasher.combine(1)
        case .capture:
            hasher.combine(2)
        case let .speakFromImage(selectedImage):
            hasher.combine(3)
            hasher.combine(selectedImage.hashValue)
        case let .speakFromVideo(selectedVideo):
            hasher.combine(4)
            hasher.combine(selectedVideo.hashValue)
        case let .speakFromMaterials(materialsModel):
            hasher.combine(5)
            hasher.combine(ObjectIdentifier(materialsModel))
        case let .feedbackFromSession(sessionId, pastSessionsViewModel):
            hasher.combine(6)
            hasher.combine(sessionId)
            hasher.combine(ObjectIdentifier(pastSessionsViewModel))
        case let .feedbackFromSpeak(selectedImage, selectedVideo, audioData, mediaType):
            hasher.combine(7)
            hasher.combine(selectedImage?.hashValue ?? 0)
            hasher.combine(selectedVideo?.hashValue ?? 0)
            hasher.combine(audioData.hashValue)
            hasher.combine(mediaType)
        case .onboardingTargetLanguage:
            hasher.combine(8)
        case let .onboardingNativeLanguage(selectedTargetLanguage):
            hasher.combine(9)
            hasher.combine(selectedTargetLanguage)
        case .auth:
            hasher.combine(10)
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home):
            return true
        case (.review, .review):
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
        case let (.feedbackFromSpeak(lhsImage, lhsVideo, lhsAudioData, lhsMediaType), .feedbackFromSpeak(rhsImage, rhsVideo, rhsAudioData, rhsMediaType)):
            return lhsImage?.hashValue == rhsImage?.hashValue && lhsVideo?.hashValue == rhsVideo?.hashValue && lhsAudioData.hashValue == rhsAudioData.hashValue && lhsMediaType == rhsMediaType
        case (.onboardingTargetLanguage, .onboardingTargetLanguage):
            return true
        case let (.onboardingNativeLanguage(lhsSelectedTargetLanguage), .onboardingNativeLanguage(rhsSelectedTargetLanguage)):
            return lhsSelectedTargetLanguage == rhsSelectedTargetLanguage
        case (.auth, .auth):
            return true
        default:
            return false
        }
    }
}

final class Router: ObservableObject {
    @Published var selectedTab: NavTab = .home {
        didSet {
            print("🏠 Selected tab changed:")
            print("   Previous tab: \(oldValue)")
            print("   New tab: \(selectedTab)")
            print("---")
        }
    }

    @Published var homePath = NavigationPath() {
        didSet {
            print("🧭 Navigation stack changed:")
            print("   Previous count: \(oldValue.count)")
            print("   New count: \(homePath.count)")

            // Log the current routes in the stack
            if homePath.count > 0 {
                print("   Current routes:")
                // Note: NavigationPath doesn't expose individual routes easily
                // We can only see the count, but this is still useful for debugging
                print("     Stack contains \(homePath.count) route(s)")
            } else {
                print("   Stack is empty")
            }
            print("---")
        }
    }

    @Published var reviewPath = NavigationPath() {
        didSet {
            print("🧭 Navigation stack changed:")
            print("   Previous count: \(oldValue.count)")
            print("   New count: \(reviewPath.count)")
        }
    }

    @Published var capturePath = NavigationPath() {
        didSet {
            print("🧭 Navigation stack changed:")
            print("   Previous count: \(oldValue.count)")
            print("   New count: \(capturePath.count)")
        }
    }

    func resetToHome() {
        switch selectedTab {
        case .home:
            homePath = NavigationPath()
        case .review:
            reviewPath = NavigationPath()
            selectedTab = .home
            homePath = NavigationPath()
        case .capture:
            capturePath = NavigationPath()
            selectedTab = .home
            homePath = NavigationPath()
        }
    }

    func goTo(_ route: AppRoute) {
        switch selectedTab {
        case .home:
            homePath.append(route)
        case .review:
            reviewPath.append(route)
        case .capture:
            capturePath.append(route)
        }
    }

    func goBack() {
        switch selectedTab {
        case .home:
            homePath.removeLast()
        case .review:
            reviewPath.removeLast()
        case .capture:
            capturePath.removeLast()
        }
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
