//
//  ChangePasswordView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isCurrentPasswordVisible: Bool = false
    @State private var isNewPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    private var isPasswordValid: Bool {
        return newPassword.count >= 8
    }

    private var doPasswordsMatch: Bool {
        return !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    private var isResetButtonEnabled: Bool {
        return !currentPassword.isEmpty && isPasswordValid && doPasswordsMatch && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 24) {
                // Title and subtitle
                VStack(spacing: 12) {
                    Text("onboarding.newPassword.title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text("onboarding.newPassword.subtitle")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                        .multilineTextAlignment(.center)
                }

                // Input fields card
                VStack(spacing: 20) {
                    // Current Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("auth.password")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        HStack {
                            if isCurrentPasswordVisible {
                                TextField("auth.enterPassword", text: $currentPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            } else {
                                SecureField("auth.enterPassword", text: $currentPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }

                            Button(action: {
                                isCurrentPasswordVisible.toggle()
                            }) {
                                Image(systemName: isCurrentPasswordVisible ? "eye.slash" : "eye")
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
                                        .stroke(Color(red: 0, green: 0, blue: 0, opacity: 15 / 255), lineWidth: 1)
                                )
                        )

                        // Forgot Password Link
                        HStack {
                            Button(action: {
                                handleForgotPassword()
                            }) {
                                Text("auth.forgotPassword")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(AppTheme.primaryBlue)
                            }
                            Spacer()
                        }
                    }

                    // New Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("onboarding.newPassword.new")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        HStack {
                            if isNewPasswordVisible {
                                TextField("onboarding.newPassword.placeholder.new", text: $newPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            } else {
                                SecureField("onboarding.newPassword.placeholder.new", text: $newPassword)
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
                                        .stroke(Color(red: 0, green: 0, blue: 0, opacity: 15 / 255), lineWidth: 1)
                                )
                        )
                    }

                    // Confirm Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("onboarding.newPassword.confirm")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        HStack {
                            if isConfirmPasswordVisible {
                                TextField("onboarding.newPassword.placeholder.confirm", text: $confirmPassword)
                                    .textFieldStyle(PlainTextFieldStyle())
                            } else {
                                SecureField("onboarding.newPassword.placeholder.confirm", text: $confirmPassword)
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
                                        .stroke(Color(red: 0, green: 0, blue: 0, opacity: 15 / 255), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.02), radius: 16, x: 0, y: 1)
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

                        Text("onboarding.newPassword.requirement.length")
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

                        Text("onboarding.newPassword.requirement.match")
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
                    .padding(.top, 16)
            }

            Spacer()

            // Reset password button
            Button(action: {
                handleChangePassword()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .scaleEffect(0.8)
                    }

                    Text("auth.resetPassword")
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
        .background(AppTheme.backgroundGradient)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    router.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Actions

    private func handleForgotPassword() {
        guard let email = contentViewModel.userInfo.user?.email else {
            errorMessage = "Email not found. Please sign in again."
            return
        }

        // Navigate to verification code view immediately
        router.goTo(.verificationCode(email: email, flowType: .resetPassword, fullName: nil))

        // Send verification code in the background (fire and forget)
        Task {
            do {
                try await VerificationCodeService.shared.sendVerificationCode(
                    targetType: .EMAIL,
                    targetValue: email,
                    flowType: .resetPassword
                )
            } catch {
                // Error handling in background - user is already on verification code screen
                print("❌ Failed to send verification code: \(error.localizedDescription)")
            }
        }
    }

    private func handleChangePassword() {
        guard isResetButtonEnabled else { return }

        guard let authToken = contentViewModel.authToken else {
            errorMessage = "You must be logged in to change your password"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Call change password API
                let authResponse = try await AuthService.shared.changePassword(
                    authToken: authToken,
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )

                // Reload auth token and user info from keychain
                await contentViewModel.readAuthTokenFromKeychain()
                await contentViewModel.loadUserInfo()

                await MainActor.run {
                    isLoading = false
                    // Navigate back to manage account view after successful password change
                    router.goBack()
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
    NavigationStack {
        ChangePasswordView()
            .environmentObject(Router())
            .environmentObject(ContentViewModel())
    }
}
