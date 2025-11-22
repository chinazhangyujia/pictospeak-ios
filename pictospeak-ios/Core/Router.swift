import SwiftUI

enum AuthMode {
    case signUp
    case signIn
    case resetPassword
}

enum NavTab: Hashable {
    case home
    case review
    case capture
}

enum SourceView: Hashable {
    case settings
}

enum AppRoute: Hashable {
    case home
    case review
    case capture
    case speakFromImage(selectedImage: UIImage)
    case speakFromVideo(selectedVideo: URL, frames: [Data])
    case speakFromMaterials(materialsModel: InternalUploadedMaterialsViewModel)
    case feedbackFromSession(sessionId: UUID, pastSessionsViewModel: PastSessionsViewModel)
    case feedbackFromSpeak(selectedImage: UIImage?, selectedVideo: URL?, frames: [Data], audioData: Data, mediaType: MediaType)
    case onboardingTargetLanguage(sourceView: SourceView?)
    case onboardingNativeLanguage(selectedTargetLanguage: String, sourceView: SourceView?)
    case auth(initialMode: AuthMode)
    case verificationCode(email: String, flowType: FlowType, fullName: String?)
    case createNewPassword(verificationId: String, verificationCode: String, email: String, fullName: String?)
    case subscription
    case settings
    case editProfile
    case manageAccount
    case changePassword

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
        case let .speakFromVideo(selectedVideo, frames):
            hasher.combine(4)
            hasher.combine(selectedVideo.hashValue)
            hasher.combine(frames.count) // Approximate hash for frames
        case let .speakFromMaterials(materialsModel):
            hasher.combine(5)
            hasher.combine(ObjectIdentifier(materialsModel))
        case let .feedbackFromSession(sessionId, pastSessionsViewModel):
            hasher.combine(6)
            hasher.combine(sessionId)
            hasher.combine(ObjectIdentifier(pastSessionsViewModel))
        case let .feedbackFromSpeak(selectedImage, selectedVideo, frames, audioData, mediaType):
            hasher.combine(7)
            hasher.combine(selectedImage?.hashValue ?? 0)
            hasher.combine(selectedVideo?.hashValue ?? 0)
            hasher.combine(frames.count) // Approximate hash for frames
            hasher.combine(audioData.hashValue)
            hasher.combine(mediaType)
        case let .onboardingTargetLanguage(sourceView):
            hasher.combine(8)
            hasher.combine(sourceView.hashValue)
        case let .onboardingNativeLanguage(selectedTargetLanguage, sourceView):
            hasher.combine(9)
            hasher.combine(selectedTargetLanguage)
            hasher.combine(sourceView.hashValue)
        case let .auth(initialMode):
            hasher.combine(10)
            hasher.combine(initialMode)
        case let .verificationCode(email, flowType, fullName):
            hasher.combine(11)
            hasher.combine(email)
            hasher.combine(flowType)
            hasher.combine(fullName)
        case let .createNewPassword(verificationId, verificationCode, email, fullName):
            hasher.combine(12)
            hasher.combine(verificationId)
            hasher.combine(verificationCode)
            hasher.combine(email)
            hasher.combine(fullName)
        case .subscription:
            hasher.combine(13)
        case .settings:
            hasher.combine(14)
        case .editProfile:
            hasher.combine(15)
        case .manageAccount:
            hasher.combine(16)
        case .changePassword:
            hasher.combine(17)
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
        case let (.speakFromVideo(lhsVideo, lhsFrames), .speakFromVideo(rhsVideo, rhsFrames)):
            return lhsVideo.hashValue == rhsVideo.hashValue && lhsFrames == rhsFrames
        case let (.speakFromMaterials(lhsMaterialsModel), .speakFromMaterials(rhsMaterialsModel)):
            return lhsMaterialsModel === rhsMaterialsModel
        case let (.feedbackFromSession(lhsSessionId, lhsPastSessionsViewModel), .feedbackFromSession(rhsSessionId, rhsPastSessionsViewModel)):
            return lhsSessionId == rhsSessionId && lhsPastSessionsViewModel === rhsPastSessionsViewModel
        case let (.feedbackFromSpeak(lhsImage, lhsVideo, lhsFrames, lhsAudioData, lhsMediaType), .feedbackFromSpeak(rhsImage, rhsVideo, rhsFrames, rhsAudioData, rhsMediaType)):
            return lhsImage?.hashValue == rhsImage?.hashValue && lhsVideo?.hashValue == rhsVideo?.hashValue && lhsFrames == rhsFrames && lhsAudioData.hashValue == rhsAudioData.hashValue && lhsMediaType == rhsMediaType
        case let (.onboardingTargetLanguage(lhsSourceView), .onboardingTargetLanguage(rhsSourceView)):
            return lhsSourceView == rhsSourceView
        case let (.onboardingNativeLanguage(lhsSelectedTargetLanguage, lhsSourceView), .onboardingNativeLanguage(rhsSelectedTargetLanguage, rhsSourceView)):
            return lhsSelectedTargetLanguage == rhsSelectedTargetLanguage && lhsSourceView == rhsSourceView
        case let (.auth(lhsInitialMode), .auth(rhsInitialMode)):
            return lhsInitialMode == rhsInitialMode
        case let (.verificationCode(lhsEmail, lhsFlowType, lhsFullName), .verificationCode(rhsEmail, rhsFlowType, rhsFullName)):
            return lhsEmail == rhsEmail && lhsFlowType == rhsFlowType && lhsFullName == rhsFullName
        case let (.createNewPassword(lhsVerificationId, lhsVerificationCode, lhsEmail, lhsFullName), .createNewPassword(rhsVerificationId, rhsVerificationCode, rhsEmail, rhsFullName)):
            return lhsVerificationId == rhsVerificationId && lhsVerificationCode == rhsVerificationCode && lhsEmail == rhsEmail && lhsFullName == rhsFullName
        case (.subscription, .subscription):
            return true
        case (.settings, .settings):
            return true
        case (.editProfile, .editProfile):
            return true
        case (.manageAccount, .manageAccount):
            return true
        case (.changePassword, .changePassword):
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
