//
//  EditProfileView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var viewModel = EditProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Picture Section (Display Only)
                profilePictureSection

                // Name Section
                nameSection

                // Info Text
                infoText

                Spacer()
            }
            .padding(.top, 32)
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

            ToolbarItem(placement: .principal) {
                Text("common.edit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
        .onAppear {
            viewModel.loadUserInfo(from: contentViewModel)
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                router.goBack()
            }
        }
        .alert("error.unknown", isPresented: $viewModel.showError) {
            Button("common.done", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Profile Picture Section

    private var profilePictureSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.lightBlueBackground)
                    .frame(width: 120, height: 120)

                Text(viewModel.userInitial)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(AppTheme.primaryBlue)
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("auth.fullName")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)

            TextField("auth.enterFullName", text: $viewModel.name)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(AppTheme.gray3c3c4360)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.grayf8f9fa)
                        )
                )
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(26)
        .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 1)
    }

    // MARK: - Info Text

    private var infoText: some View {
        Text("Your profile photo and name may be visible to other learners in the community.")
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(AppTheme.gray3c3c4360)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 269, alignment: .leading)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: {
            Task {
                await viewModel.updateProfile(contentViewModel: contentViewModel)
            }
        }) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("common.save")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 100)
                    .fill(AppTheme.primaryBlue)
            )
        }
        .disabled(viewModel.isLoading || viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity((viewModel.isLoading || viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.6 : 1.0)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color.white)
    }
}

// MARK: - ViewModel

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var userInitial: String = "U"
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var shouldDismiss: Bool = false
    @Published var errorMessage: String = ""

    private let userService = UserService.shared

    func loadUserInfo(from contentViewModel: ContentViewModel) {
        if let user = contentViewModel.userInfo.user {
            name = user.nickname
            userInitial = user.nickname.first.map { String($0).uppercased() } ?? "U"
        }
    }

    func updateProfile(contentViewModel: ContentViewModel) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = NSLocalizedString("onboarding.newPassword.error.fullName", comment: "Name cannot be empty")
            showError = true
            return
        }

        guard let authToken = contentViewModel.authToken else {
            errorMessage = NSLocalizedString("error.auth.noToken", comment: "Not logged in")
            showError = true
            return
        }

        isLoading = true

        do {
            let updatedUser = try await userService.updateUserProfile(authToken: authToken, nickname: name)

            // Update the userInfo in contentViewModel with the new nickname
            contentViewModel.userInfo = UserInfo(
                user: updatedUser,
                userSetting: contentViewModel.userInfo.userSetting
            )

            shouldDismiss = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(Router())
            .environmentObject(ContentViewModel())
    }
}
