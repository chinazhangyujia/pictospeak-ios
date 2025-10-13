//
//  VerificationCodeView.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import SwiftUI

struct VerificationCodeView: View {
    @EnvironmentObject private var onboardingRouter: OnboardingRouter
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @EnvironmentObject private var router: Router
    
    @State private var verificationCode: [String] = Array(repeating: "", count: 6)
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    
    let email: String
    
    init(email: String) {
        self.email = email
    }
    
    // MARK: - Computed Properties
    
    private var isCodeComplete: Bool {
        return verificationCode.allSatisfy { !$0.isEmpty }
    }
    
    private var isButtonDisabled: Bool {
        return isVerifying || !isCodeComplete
    }
    
    private var verificationCodeString: String {
        return verificationCode.joined()
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 24) {
                // Title and subtitle
                VStack(spacing: 12) {
                    Text("Enter verification code")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text("6-digit code to \(email)")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                        .multilineTextAlignment(.center)
                }

                // Verification code input section
                VStack() {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verification code")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.gray333333)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { index in
                                VerificationCodeDigitField(
                                    text: $verificationCode[index],
                                    isFirstResponder: index == 0
                                )
                                .onChange(of: verificationCode[index]) { newValue in
                                    handleDigitInput(at: index, newValue: newValue)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                
                // Resend code section
                HStack(spacing: 10) {
                    Text("Didn't receive the code?")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c4360)
                    
                    Button(action: {
                        resendVerificationCode()
                    }) {
                        Text("Resend")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.primaryBlue)
                    }
                }
            }
            .padding(.top, 24)

            Spacer()

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Verify button
            Button(action: {
                verifyCode()
            }) {
                HStack {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .scaleEffect(0.8)
                    }

                    Text("Verify code")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isButtonDisabled ? AppTheme.grayd9d9d9 : .white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 100)
                        .fill(isButtonDisabled ? .white : AppTheme.primaryBlue)
                )
            }
            .disabled(isButtonDisabled)
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
        .background(AppTheme.viewBackgroundGray)
    }
    
    // MARK: - Actions
    
    private func handleDigitInput(at index: Int, newValue: String) {
        // Only allow single digit
        if newValue.count > 1 {
            verificationCode[index] = String(newValue.prefix(1))
        }
        
        // Move to next field if digit entered
        if !verificationCode[index].isEmpty && index < 5 {
            // Focus next field logic would go here if using UIKit
        }
        
        // Auto-verify if all fields are filled
        if isCodeComplete && !isVerifying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                verifyCode()
            }
        }
    }
    
    private func verifyCode() {
        guard isCodeComplete else { return }
        
        isVerifying = true
        errorMessage = nil
        
        Task {
            do {
                // TODO: Implement actual verification API call
                // let result = try await AuthService.shared.verifyCode(email: email, code: verificationCodeString)
                
                // Simulate API call for now
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    isVerifying = false
                    // Navigate to next screen or complete onboarding
                    // For now, just show success
                    onboardingRouter.goTo(.createNewPassword(verificationCode: verificationCodeString, email: email))
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func resendVerificationCode() {
        Task {
            do {
                // TODO: Implement actual resend API call
                // try await AuthService.shared.resendVerificationCode(email: email)
                
                // Simulate API call
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    print("✅ Verification code resent to \(email)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to resend code. Please try again."
                }
            }
        }
    }
}

// MARK: - Verification Code Digit Field

struct VerificationCodeDigitField: View {
    @Binding var text: String
    let isFirstResponder: Bool
    
    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 24, weight: .semibold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .frame(width: 44, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.grayf8f9fa)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.03), lineWidth: 1)
                    )
            )
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)) { notification in
                if let textField = notification.object as? UITextField {
                    let newValue = textField.text ?? ""
                    if newValue.count > 1 {
                        textField.text = String(newValue.prefix(1))
                        text = String(newValue.prefix(1))
                    }
                }
            }
    }
}

#Preview {
    NavigationView {
        VerificationCodeView(email: "johndoe@gmail.com")
            .environmentObject(OnboardingRouter())
            .environmentObject(ContentViewModel())
            .environmentObject(Router())
    }
}
