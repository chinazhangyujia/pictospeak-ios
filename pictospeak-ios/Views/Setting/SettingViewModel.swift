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

        // Load user info from ContentViewModel
        let userInfo = contentViewModel.userInfo

        // Load user settings if available
        if let userSetting = userInfo.userSetting {
            targetLanguage = userSetting.targetLanguage.capitalized
            teachingLanguage = userSetting.nativeLanguage.capitalized

            // Set flag based on target language
            targetLanguageFlag = getLanguageFlag(for: userSetting.targetLanguage)
        }

        // Load user profile data if available
        if let user = userInfo.user {
            userName = user.nickname
            userInitial = user.nickname.first.map { String($0) } ?? "U"
            learningDays = calculateLearningDays(from: user.createdAt)
        } else {
            // Pre-auth state, use placeholder values
            userName = "User"
            userInitial = "U"
            learningDays = 0
        }

        systemLanguage = Locale.current.language.languageCode?.identifier.capitalized ?? "English"

        isLoading = false
    }

    private func loadAppVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = "v\(version)"
        }
    }

    private func calculateLearningDays(from createdAt: String) -> Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let createdDate = formatter.date(from: createdAt) else {
            print("❌ Failed to parse createdAt date: \(createdAt)")
            return 0
        }

        let calendar = Calendar.current
        let now = Date()

        let components = calendar.dateComponents([.day], from: createdDate, to: now)
        let days = components.day ?? 0

        // Return at least 0 (if account was created today) or the number of days
        return max(0, days)
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
