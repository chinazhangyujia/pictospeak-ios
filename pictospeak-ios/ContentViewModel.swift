//
//  ContentViewModel.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var userSetting: UserSetting?
    @Published var isLoading = false
    @Published var error: String?

    private let userSettingService = UserSettingService.shared

    init() {
        Task {
            await loadUserSettings()
        }
    }

    // MARK: - Public Methods

    /// Loads user settings from the backend
    func loadUserSettings() async {
        isLoading = true
        error = nil

        do {
            userSetting = try await userSettingService.getUserSettings()
            print("✅ User settings loaded successfully")
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to load user settings: \(error)")
        }

        isLoading = false
    }

    /// Sets the user setting (called when user completes onboarding)
    /// - Parameter userSetting: The user setting to set
    func setUserSetting(_ userSetting: UserSetting) {
        self.userSetting = userSetting
        print("✅ User setting updated: \(userSetting.targetLanguage) -> \(userSetting.nativeLanguage)")
    }

    /// Clears the user setting (for testing or logout purposes)
    func clearUserSetting() {
        userSetting = nil
        print("✅ User setting cleared")
    }

    // MARK: - Computed Properties

    /// Returns true if user has completed onboarding and has settings
    var hasUserSettings: Bool {
        return userSetting != nil
    }

    /// Returns the initial route based on whether user has settings
    var initialRoute: AppRoute {
        return hasUserSettings ? .home : .onboardingTargetLanguage
    }
}
