//
//  ManageAccountView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct ManageAccountView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @State private var showDeleteAccountAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Account Information Section
                sectionGroup(title: NSLocalizedString("settings.account", comment: "")) {
                    // Email Row
                    emailRow

                    Divider()

                    // Change Password Row
                    changePasswordRow
                }

                // Danger Zone Section
                sectionGroup(title: "Danger Zone") {
                    // Delete Account Row
                    deleteAccountRow
                }
            }
            .padding(.top, 24)
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
                Text("settings.manageAccount")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .alert("common.delete", isPresented: $showDeleteAccountAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) {
                // Handle account deletion
                handleDeleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }

    // MARK: - Email Row

    private var emailRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(AppTheme.gray8c8c8c)
                .frame(width: 24, height: 24)

            Text("auth.email")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primary)

            Spacer()

            Text(userEmail)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppTheme.gray8c8c8c)
        }
        .padding(16)
    }

    // MARK: - Change Password Row

    private var changePasswordRow: some View {
        settingRow(
            icon: "lock",
            title: NSLocalizedString("auth.resetPassword", comment: ""),
            action: {
                handleChangePassword()
            }
        )
    }

    // MARK: - Delete Account Row

    private var deleteAccountRow: some View {
        settingRow(
            icon: "trash",
            title: NSLocalizedString("common.delete", comment: ""),
            iconColor: .red,
            textColor: .red,
            action: {
                showDeleteAccountAlert = true
            }
        )
    }

    // MARK: - Setting Row

    private func settingRow(
        icon: String,
        title: String,
        iconColor: Color = AppTheme.gray8c8c8c,
        textColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(textColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.grayc7c7cc)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Section Group

    private func sectionGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.gray3c3c4360)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(26)
            .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 1)
        }
    }

    // MARK: - Computed Properties

    private var userEmail: String {
        if let user = contentViewModel.userInfo.user {
            return user.email
        }
        return ""
    }

    // MARK: - Actions

    private func handleChangePassword() {
        router.goTo(.changePassword)
    }

    private func handleDeleteAccount() {
        // TODO: Implement account deletion
        print("Delete account action triggered")
    }
}

#Preview {
    NavigationStack {
        ManageAccountView()
            .environmentObject(Router())
            .environmentObject(ContentViewModel())
    }
}
