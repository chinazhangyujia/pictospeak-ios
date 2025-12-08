//
//  AuthView.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import SwiftUI

struct AuthView: View {
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
    @State private var authMode: AuthMode

    init(initialMode: AuthMode = .signUp) {
        _authMode = State(initialValue: initialMode)
    }

    // MARK: - Computed Properties

    private var titleText: LocalizedStringKey {
        switch authMode {
        case .signUp:
            return "auth.createAccount"
        case .signIn:
            return "auth.welcomeBack"
        case .resetPassword:
            return "auth.resetPassword"
        }
    }

    private var subtitleText: LocalizedStringKey {
        switch authMode {
        case .signUp:
            return "auth.subtitle.signup"
        case .signIn:
            return "auth.subtitle.signin"
        case .resetPassword:
            return "auth.subtitle.reset"
        }
    }

    private var buttonText: LocalizedStringKey {
        switch authMode {
        case .signUp:
            return "common.continue"
        case .signIn:
            return "auth.login"
        case .resetPassword:
            return "auth.sendResetLink"
        }
    }

    private func showDisableButton() -> Bool {
        switch authMode {
        case .signUp:
            return isLoading || email.isEmpty || fullName.isEmpty || !isValidEmail(email)
        case .signIn:
            return isLoading || email.isEmpty || password.isEmpty
        case .resetPassword:
            return isLoading || email.isEmpty || !isValidEmail(email)
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func clearForm() {
        fullName = ""
        email = ""
        password = ""
        confirmPassword = ""
        isPasswordVisible = false
        isConfirmPasswordVisible = false
        errorMessage = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 24) {
                // Title and subtitle
                VStack(spacing: 12) {
                    Text(titleText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(subtitleText)
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                        .multilineTextAlignment(.center)
                }

                // Input fields card
                VStack(spacing: 20) {
                    // Full Name field (only for sign-up)
                    if authMode == .signUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("auth.fullName")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.gray333333)

                            TextField("auth.enterFullName", text: $fullName)
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
                        Text("auth.email")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)

                        TextField("auth.enterEmail", text: $email)
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

                    // Password field (only for sign in)
                    if authMode == .signIn {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("auth.password")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.gray333333)

                            HStack {
                                if isPasswordVisible {
                                    TextField("auth.enterPassword", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                } else {
                                    SecureField("auth.enterPassword", text: $password)
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
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )

                if authMode == .signIn {
                    // Forgot password text
                    Text("auth.forgotPassword")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppTheme.primaryBlue)
                        .onTapGesture {
                            authMode = .resetPassword
                            clearForm()
                        }
                }

                // Account status and toggle (only for sign up and sign in)
                if authMode != .resetPassword {
                    HStack(spacing: 10) {
                        Text(authMode == .signUp ? "auth.haveAccount" : "auth.noAccount")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.gray3c3c4360)

                        Button(action: {
                            authMode = authMode == .signUp ? .signIn : .signUp
                            errorMessage = nil
                            clearForm()
                        }) {
                            Text(authMode == .signUp ? "auth.login" : "auth.signup")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.primaryBlue)
                        }
                    }
                } else {
                    // Sign up link for reset password mode
                    HStack(spacing: 10) {
                        Text("auth.noAccount")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.gray3c3c4360)

                        Button(action: {
                            authMode = .signUp
                            clearForm()
                        }) {
                            Text("auth.signup")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.primaryBlue)
                        }
                    }
                }
            }

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Action button (only show if not in success state)
            Button(action: {
                handleAuthAction()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .scaleEffect(0.8)
                    }

                    Text(buttonText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(showDisableButton() ? AppTheme.grayd9d9d9 : .white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 100)
                        .fill(showDisableButton() ? .white : AppTheme.primaryBlue)
                )
            }
            .disabled(showDisableButton())
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
        .background(AppTheme.backgroundGradient)
        .navigationBarBackButtonHidden(contentViewModel.hasOnboardingCompleted)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    router.resetToHome()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
        })
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Actions

    private func handleAuthAction() {
        switch authMode {
        case .signUp:
            guard !email.isEmpty, !fullName.isEmpty, isValidEmail(email) else { return }
        case .signIn:
            guard !email.isEmpty, !password.isEmpty else { return }
        case .resetPassword:
            guard !email.isEmpty, isValidEmail(email) else { return }
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch authMode {
                case .signUp:
                    await handleSignUpSendCode()
                case .signIn:
                    await handleSignIn()
                case .resetPassword:
                    await handleResetPassword()
                }
            }
        }
    }

    private func handleSignUpSendCode() async {
        do {
            // Send verification code to user's email
            try await VerificationCodeService.shared.sendVerificationCode(
                targetType: .EMAIL,
                targetValue: email,
                flowType: .signUp
            )

            await MainActor.run {
                isLoading = false
                // Navigate to verification code view for sign-up flow
                router.goTo(.verificationCode(email: email, flowType: .signUp, fullName: fullName))
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
            await contentViewModel.loadUserInfo()
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

    private func handleResetPassword() async {
        do {
            // Send verification code to user's email
            try await VerificationCodeService.shared.sendVerificationCode(
                targetType: .EMAIL,
                targetValue: email,
                flowType: .resetPassword
            )

            await MainActor.run {
                isLoading = false
                // Navigate to verification code view after successful send
                router.goTo(.verificationCode(email: email, flowType: .resetPassword, fullName: nil))
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
        .environmentObject(ContentViewModel())
}
