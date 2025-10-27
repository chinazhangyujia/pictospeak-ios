//
//  CreateNewPasswordView.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import SwiftUI

struct CreateNewPasswordView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @EnvironmentObject private var router: Router
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isNewPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    let verificationId: String
    let verificationCode: String
    let email: String
    let fullName: String?

    init(verificationId: String, verificationCode: String, email: String, fullName: String?) {
        self.verificationId = verificationId
        self.verificationCode = verificationCode
        self.email = email
        self.fullName = fullName
    }

    // MARK: - Computed Properties

    private var isSignUpFlow: Bool {
        return fullName != nil
    }

    private var isPasswordValid: Bool {
        return newPassword.count >= 8
    }

    private var doPasswordsMatch: Bool {
        return !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    private var isResetButtonEnabled: Bool {
        return isPasswordValid && doPasswordsMatch && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 24) {
                // Title and subtitle
                VStack(spacing: 12) {
                    Text("Create new password")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text("Enter a new password for your account")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Input fields card
                VStack(spacing: 20) {
                    // New Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New password")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        HStack {
                            if isNewPasswordVisible {
                                TextField("Enter new password", text: $newPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            } else {
                                SecureField("Enter new password", text: $newPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }

                            Button(action: {
                                isNewPasswordVisible.toggle()
                            }) {
                                Image(systemName: isNewPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.gray3c3c3c60)
                            }
                        }
                        .font(.system(size: 16))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.grayf8f9fa)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                )
                        )
                    }

                    // Confirm Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm password")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        HStack {
                            if isConfirmPasswordVisible {
                                TextField("Confirm new password", text: $confirmPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            } else {
                                SecureField("Confirm new password", text: $confirmPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }

                            Button(action: {
                                isConfirmPasswordVisible.toggle()
                            }) {
                                Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.gray3c3c3c60)
                            }
                        }
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.grayf8f9fa)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )

                // Password requirements
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isPasswordValid ? Color.green : Color(red: 0xD1 / 255, green: 0xD5 / 255, blue: 0xDC / 255))
                                .frame(width: 16, height: 16)

                            if isPasswordValid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                        }

                        Text("At least 8 characters")
                            .font(.system(size: 16))
                            .foregroundColor(isPasswordValid ? Color.green : AppTheme.gray3c3c4360)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(doPasswordsMatch ? Color.green : Color(red: 0xD1 / 255, green: 0xD5 / 255, blue: 0xDC / 255))
                                .frame(width: 16, height: 16)

                            if doPasswordsMatch {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                        }

                        Text("Passwords match")
                            .font(.system(size: 16))
                            .foregroundColor(doPasswordsMatch ? Color.green : AppTheme.gray3c3c4360)

                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
            }

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Reset password button
            Button(action: {
                handleResetPassword()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .scaleEffect(0.8)
                    }

                    Text("Set password")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isResetButtonEnabled ? .white : AppTheme.grayd9d9d9)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 100)
                        .fill(isResetButtonEnabled ? AppTheme.primaryBlue : .white)
                )
            }
            .disabled(!isResetButtonEnabled)
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
        .background(AppTheme.viewBackgroundGray)
    }

    // MARK: - Actions

    private func handleResetPassword() {
        guard isResetButtonEnabled else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUpFlow {
                    // Sign-up flow - create new account
                    guard let fullName = fullName else {
                        await MainActor.run {
                            self.errorMessage = "Full name is required"
                            self.isLoading = false
                        }
                        return
                    }

                    // Get pre-signup user settings if available
                    let userSetting: UserSetting
                    if let contentUserSetting = contentViewModel.userInfo.userSetting {
                        userSetting = contentUserSetting
                        print("✅ Using user setting from ContentViewModel")
                    } else if let preSignUpUserSetting = UserDefaultManager.shared.getPreSignUpUserSetting() {
                        userSetting = preSignUpUserSetting
                        print("✅ Using user setting from UserDefaultManager")
                    } else {
                        print("❌ No user setting found in ContentViewModel or UserDefaultManager. This should not happen.")
                        await MainActor.run {
                            self.errorMessage = "User settings not found"
                            self.isLoading = false
                        }
                        return
                    }

                    // Call sign-up API with verification data
                    let authResponse = try await AuthService.shared.signUp(
                        email: email,
                        password: newPassword,
                        nickname: fullName,
                        userSetting: userSetting,
                        verificationCodeId: verificationId,
                        verificationCode: verificationCode
                    )

                    // Clear pre-signup settings after successful signup
                    UserDefaultManager.shared.deletePreSignUpUserSetting()
                    UserDefaultManager.shared.delete(forKey: UserDefaultKeys.hasOnboardingCompleted)

                    await contentViewModel.readAuthTokenFromKeychain()
                    await contentViewModel.loadUserInfo()

                    await MainActor.run {
                        isLoading = false
                        UserDefaultManager.shared.saveValue(true, forKey: UserDefaultKeys.hasOnboardingCompleted)
                        contentViewModel.hasOnboardingCompleted = true

                        // Reset navigation to home after successful sign-up
                        router.resetToHome()
                    }
                } else {
                    // Reset password flow
                    let authResponse = try await AuthService.shared.resetPassword(
                        targetType: .EMAIL,
                        targetValue: email,
                        newPassword: newPassword,
                        verificationCodeId: verificationId,
                        verificationCode: verificationCode
                    )

                    // Load auth token and user info into content view model
                    await contentViewModel.readAuthTokenFromKeychain()
                    await contentViewModel.loadUserInfo()

                    await MainActor.run {
                        isLoading = false
                        // Reset navigation to home after successful reset password
                        router.resetToHome()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    CreateNewPasswordView(verificationId: "test-id", verificationCode: "123456", email: "test@test.com", fullName: nil)
        .environmentObject(OnboardingRouter())
        .environmentObject(ContentViewModel())
        .environmentObject(Router())
}
