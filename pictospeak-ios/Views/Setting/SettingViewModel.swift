//
//  SettingViewModel.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation
import SwiftUI

@MainActor
class SettingViewModel: ObservableObject {
    // Use optionals to avoid showing fake data
    @Published var userName: String?
    @Published var userInitial: String?
    @Published var learningDays: Int?
    @Published var targetLanguage: String?
    @Published var targetLanguageFlag: String?
    @Published var systemLanguage: String?
    @Published var teachingLanguage: String?
    @Published var appVersion: String = "v1.0.0" // This can have a default since it's app-level data
    @Published var isLoading: Bool = true

    init() {
        loadAppVersion()
    }

    func loadUserInfo(from contentViewModel: ContentViewModel) {
        isLoading = true

        // Load user settings from ContentViewModel
        if let userSetting = contentViewModel.userSetting {
            targetLanguage = userSetting.targetLanguage.capitalized
            teachingLanguage = userSetting.nativeLanguage.capitalized

            // Set flag based on target language
            targetLanguageFlag = getLanguageFlag(for: userSetting.targetLanguage)
        }

        // TODO: Load user profile data (name, learning days) from backend
        // For now, set placeholder values
        userName = "User" // Should come from API
        userInitial = userName?.first.map { String($0) } ?? "U"
        learningDays = 0 // Should come from API
        systemLanguage = Locale.current.language.languageCode?.identifier.capitalized ?? "English"

        isLoading = false
    }

    private func loadAppVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = "v\(version)"
        }
    }

    private func getLanguageFlag(for language: String) -> String {
        let languageLower = language.lowercased()

        switch languageLower {
        case "english":
            return "🇺🇸"
        case "chinese", "mandarin":
            return "🇨🇳"
        case "spanish":
            return "🇪🇸"
        case "french":
            return "🇫🇷"
        case "german":
            return "🇩🇪"
        case "italian":
            return "🇮🇹"
        case "japanese":
            return "🇯🇵"
        case "korean":
            return "🇰🇷"
        case "portuguese":
            return "🇵🇹"
        case "russian":
            return "🇷🇺"
        case "arabic":
            return "🇸🇦"
        case "hindi":
            return "🇮🇳"
        default:
            return "🌐"
        }
    }
}
