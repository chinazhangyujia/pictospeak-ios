import SwiftUI

enum AppRoute: Hashable {
    case home
    case capture
    case speak(selectedImage: UIImage, mediaType: MediaType)
    case feedbackFromSession(session: SessionItem)
    case feedbackFromSpeak(selectedImage: UIImage, audioData: Data, mediaType: MediaType)

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
        case let .feedbackFromSession(session):
            hasher.combine(3)
            hasher.combine(session.id)
        case let .feedbackFromSpeak(selectedImage, audioData, mediaType):
            hasher.combine(4)
            hasher.combine(selectedImage.hashValue)
            hasher.combine(audioData.hashValue)
            hasher.combine(mediaType)
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
        case let (.feedbackFromSession(lhsSession), .feedbackFromSession(rhsSession)):
            return lhsSession.id == rhsSession.id
        case let (.feedbackFromSpeak(lhsImage, lhsAudioData, lhsMediaType), .feedbackFromSpeak(rhsImage, rhsAudioData, rhsMediaType)):
            return lhsImage.hashValue == rhsImage.hashValue && lhsAudioData.hashValue == rhsAudioData.hashValue && lhsMediaType == rhsMediaType
        default:
            return false
        }
    }
}

final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func resetToHome() {
        path = NavigationPath() // Pops everything to HomeView
    }

    func goTo(_ route: AppRoute) {
        path.append(route)
    }
}
