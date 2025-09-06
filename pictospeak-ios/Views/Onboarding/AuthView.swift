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
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isSignUpMode: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation
            HStack {
                // Only show back button if onboarding is not completed
                if !contentViewModel.hasOnboardingCompleted {
                    Button(action: {
                        onboardingRouter.goBack()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Main content
            VStack(spacing: 32) {
                // Title and subtitle
                VStack(spacing: 8) {
                    Text(isSignUpMode ? "Create account" : "Sign in")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(isSignUpMode ? "Save your words and sessions" : "Welcome back")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                // Input fields card
                VStack(spacing: 24) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)

                        TextField("Enter your email", text: $email)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)

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
                                    .foregroundColor(.gray)
                            }
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 20)

                // Account status and toggle
                HStack(spacing: 4) {
                    Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                        .font(.system(size: 16))
                        .foregroundColor(.black)

                    Button(action: {
                        isSignUpMode.toggle()
                        errorMessage = nil
                    }) {
                        Text(isSignUpMode ? "Sign in" : "Sign up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                // Sign up/Sign in button
                Button(action: {
                    handleAuthAction()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Text(isSignUpMode ? "Sign up" : "Sign in")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.purple.opacity(0.05), Color.blue.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationBarHidden(true)
    }

    // MARK: - Actions

    private func handleAuthAction() {
        guard !email.isEmpty, !password.isEmpty else { return }

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
                nickname: email.components(separatedBy: "@").first ?? "",
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
