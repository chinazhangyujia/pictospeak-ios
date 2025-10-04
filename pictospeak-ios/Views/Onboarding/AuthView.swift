//
//  AuthView.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @EnvironmentObject private var router: Router
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isSignUpMode: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 24) {
                // Title and subtitle
                VStack(spacing: 12) {
                    Text(isSignUpMode ? "Create account" : "Welcome back")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(isSignUpMode ? "Save your words and sessions" : "Sign in to continue your learning journey")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                        .multilineTextAlignment(.center)
                }

                // Input fields card
                VStack(spacing: 20) {
                    // Full Name field (only for sign-up)
                    if isSignUpMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.gray333333)

                            TextField("Enter your full name", text: $fullName)
                                .textFieldStyle(PlainTextFieldStyle())
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
                                .autocapitalization(.words)
                        }
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        TextField("Enter your email", text: $email)
                            .textFieldStyle(PlainTextFieldStyle())
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
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        HStack {
                            if isPasswordVisible {
                                TextField("Enter your password", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                            } else {
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }

                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
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

                    // Confirm Password field (only for sign-up)
                    if isSignUpMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.gray333333)

                            HStack {
                                if isConfirmPasswordVisible {
                                    TextField("Confirm your password", text: $confirmPassword)
                                        .textFieldStyle(PlainTextFieldStyle())
                                } else {
                                    SecureField("Confirm your password", text: $confirmPassword)
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
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )

                if !isSignUpMode {
                    // Forgot password text
                    Text("Forgot password?")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppTheme.primaryBlue)
                        .onTapGesture {
                            print("Forgot password")
                        }
                }

                // Account status and toggle
                HStack(spacing: 10) {
                    Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c4360)

                    Button(action: {
                        isSignUpMode.toggle()
                        errorMessage = nil
                        // Clear form fields when switching modes
                        fullName = ""
                        email = ""
                        password = ""
                        confirmPassword = ""
                        isPasswordVisible = false
                        isConfirmPasswordVisible = false
                    }) {
                        Text(isSignUpMode ? "Sign in" : "Sign up")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.primaryBlue)
                    }
                }

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            
            Button(action: {
                handleAuthAction()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .scaleEffect(0.8)
                    }

                    Text(isSignUpMode ? "Sign up" : "Sign in")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(showDisableSignInUpButton() ? AppTheme.grayd9d9d9 : .white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 100)
                        .fill(showDisableSignInUpButton() ? .white : AppTheme.primaryBlue)
                )
            }
            .disabled(showDisableSignInUpButton())
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
        .background(AppTheme.viewBackgroundGray)

    }

    private func showDisableSignInUpButton() -> Bool {
        return isLoading || email.isEmpty || password.isEmpty || (isSignUpMode && (fullName.isEmpty || confirmPassword.isEmpty))
    }

    // MARK: - Actions

    private func handleAuthAction() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        if isSignUpMode {
            guard !fullName.isEmpty, !confirmPassword.isEmpty else { return }
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match"
                return
            }
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUpMode {
                    await handleSignUp()
                } else {
                    await handleSignIn()
                }
            }
        }
    }

    private func handleSignUp() async {
        do {
            // Get pre-signup user settings if available
            // Get user setting from ContentViewModel first, then fall back to UserDefaultManager
            let userSetting: UserSetting
            if let contentUserSetting = contentViewModel.userSetting {
                userSetting = contentUserSetting
                print("✅ Using user setting from ContentViewModel")
            } else if let preSignUpUserSetting = UserDefaultManager.shared.getPreSignUpUserSetting() {
                userSetting = preSignUpUserSetting
                print("✅ Using user setting from UserDefaultManager")
            } else {
                print("❌ No user setting found in ContentViewModel or UserDefaultManager. This should not happen.")
                return
            }

            let authResponse = try await AuthService.shared.signUp(
                email: email,
                password: password,
                nickname: fullName,
                userSetting: userSetting
            )

            // Clear pre-signup settings after successful signup
            UserDefaultManager.shared.deletePreSignUpUserSetting()
            UserDefaultManager.shared.delete(forKey: UserDefaultKeys.hasOnboardingCompleted)

            await contentViewModel.readAuthTokenFromKeychain()
            await contentViewModel.loadUserSettings()

            // Update ContentViewModel with auth token
            await MainActor.run {
                isLoading = false
                UserDefaultManager.shared.saveValue(true, forKey: UserDefaultKeys.hasOnboardingCompleted)
                contentViewModel.hasOnboardingCompleted = true

                // Reset navigation to home after successful sign-up
                router.resetToHome()
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func handleSignIn() async {
        do {
            let authResponse = try await AuthService.shared.signIn(
                email: email,
                password: password
            )

            await contentViewModel.readAuthTokenFromKeychain()
            await contentViewModel.loadUserSettings()
            print("✅ auth token: \(contentViewModel.authToken)")

            await MainActor.run {
                print("✅ auth token: \(contentViewModel.authToken)")
                isLoading = false
                UserDefaultManager.shared.saveValue(true, forKey: UserDefaultKeys.hasOnboardingCompleted)
                contentViewModel.hasOnboardingCompleted = true

                // Reset navigation to home after successful sign-in
                router.resetToHome()
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(OnboardingRouter())
        .environmentObject(ContentViewModel())
}
