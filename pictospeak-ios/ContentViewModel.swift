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
    @Published var authToken: String?
    @Published var userSetting: UserSetting?
    @Published var hasOnboardingCompleted: Bool = false
    @Published var isLoading = false
    @Published var error: String?

    private let userSettingService = UserSettingService.shared
    private let authService = AuthService.shared

    init() {
        Task {
            await readAuthTokenFromKeychain()
            await loadUserSettings()
            loadOnboardingCompleted()
        }
    }

    func loadOnboardingCompleted() {
        if authToken != nil {
            hasOnboardingCompleted = true
            print("✅ Onboarding completed because auth token is not nil")
        } else {
            hasOnboardingCompleted = UserDefaultManager.shared.getValue(Bool.self, forKey: UserDefaultKeys.hasOnboardingCompleted) ?? false
            print("✅ Got onboarding completed from UserDefaults \(hasOnboardingCompleted)")
        }
    }

    func readAuthTokenFromKeychain() async {
        authToken = KeychainManager.shared.getToken()
    }

    /// Loads user settings from backend or UserDefaults based on auth token
    func loadUserSettings() async {
        isLoading = true
        error = nil

        // If no auth token, try to fetch from UserDefaults (pre-signup settings)
        if authToken == nil {
            if let preSignUpUserSetting = UserDefaultManager.shared.getPreSignUpUserSetting() {
                userSetting = preSignUpUserSetting
                print("✅ User settings loaded from UserDefaults (pre-signup)")
            } else {
                print("📝 No pre-signup user settings found in UserDefaults")
            }
        } else {
            // User is authenticated, fetch from backend
            do {
                userSetting = try await userSettingService.getUserSettings(authToken: authToken!)
                print("✅ User settings loaded successfully from backend")
            } catch {
                self.error = error.localizedDescription
                print("❌ Failed to load user settings from backend: \(error)")
            }
        }

        isLoading = false
    }

    func signOut() {
        authToken = nil
        userSetting = nil
        authService.signOut()
        let hasOnboardingCompleted = UserDefaultManager.shared.getValue(Bool.self, forKey: UserDefaultKeys.hasOnboardingCompleted) ?? false
        print("✅ Got onboarding completed from UserDefaults when sign out \(hasOnboardingCompleted)")
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
}
