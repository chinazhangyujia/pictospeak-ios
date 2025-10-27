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
    @Published var userInfo: UserInfo = .init(user: nil, userSetting: nil)
    @Published var hasOnboardingCompleted: Bool = false
    @Published var isLoading = false
    @Published var error: String?

    private let userService = UserService.shared
    private let authService = AuthService.shared

    init() {
        Task {
            await readAuthTokenFromKeychain()
            await loadUserInfo()
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

    /// Loads user info from backend or UserDefaults based on auth token
    func loadUserInfo() async {
        isLoading = true
        error = nil

        // If no auth token, try to fetch from UserDefaults (pre-signup settings)
        if authToken == nil {
            if let preSignUpUserSetting = UserDefaultManager.shared.getPreSignUpUserSetting() {
                userInfo = UserInfo(user: nil, userSetting: preSignUpUserSetting)
                print("✅ User settings loaded from UserDefaults (pre-signup)")
            } else {
                print("📝 No pre-signup user settings found in UserDefaults")
            }
        } else {
            // User is authenticated, fetch from backend
            do {
                userInfo = try await userService.getUserInfo(authToken: authToken!)
                print("✅ User info loaded successfully from backend")
            } catch {
                self.error = error.localizedDescription
                print("❌ Failed to load user info from backend: \(error)")
            }
        }

        isLoading = false
    }

    func signOut() {
        authToken = nil
        userInfo = UserInfo(user: nil, userSetting: nil)
        authService.signOut()
        let hasOnboardingCompleted = UserDefaultManager.shared.getValue(Bool.self, forKey: UserDefaultKeys.hasOnboardingCompleted) ?? false
        print("✅ Got onboarding completed from UserDefaults when sign out \(hasOnboardingCompleted)")
    }

    /// Sets the user setting (called when user completes onboarding)
    /// - Parameter userSetting: The user setting to set
    func setUserSetting(_ userSetting: UserSetting) {
        userInfo = UserInfo(user: userInfo.user, userSetting: userSetting)
        print("✅ User setting updated: \(userSetting.targetLanguage) -> \(userSetting.nativeLanguage)")
    }

    /// Clears the user info (for testing or logout purposes)
    func clearUserSetting() {
        userInfo = UserInfo(user: nil, userSetting: nil)
        print("✅ User info cleared")
    }
}
