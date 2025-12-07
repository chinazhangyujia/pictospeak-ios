//
//  SettingView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @StateObject private var viewModel = SettingViewModel()
    @State private var showLogoutAlert = false
    @State private var showFeedbackEmail = false
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // User Profile Section
                userProfileSection

                // Currently Learning Section
                currentlyLearningSection

                // Account Section
                if contentViewModel.authToken != nil {
                    sectionGroup(title: "Account") {
                        settingRow(
                            icon: "person.circle",
                            title: "Manage Account",
                            action: {
                                router.goTo(.manageAccount)
                            }
                        )
                    }
                }

                // Language & Learning Section
                sectionGroup(title: "Language & Learning") {
                    settingRowWithValue(
                        icon: "globe",
                        title: "System Language",
                        value: viewModel.systemLanguage ?? (viewModel.isLoading ? "Loading..." : "Unknown"),
                        action: {
                            // Navigate to system language settings
                        }
                    )

                    Divider()
                        .padding(.leading, 52)

                    settingRowWithValue(
                        icon: "character.textbox",
                        title: "Teaching Language",
                        value: viewModel.teachingLanguage ?? (viewModel.isLoading ? "Loading..." : "Not set"),
                        action: {
                            router.goTo(.onboardingTargetLanguage(sourceView: .settings))
                        }
                    )
                }

                // Support Section
                sectionGroup(title: "Support") {
                    settingRow(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "Contact Support",
                        action: {
                            showFeedbackEmail = true
                        }
                    )

                    Divider()
                        .padding(.leading, 52)

                    settingRow(
                        icon: "questionmark.bubble",
                        title: "FAQ",
                        action: {
                            // Navigate to FAQ
                        }
                    )

                    Divider()
                        .padding(.leading, 52)

                    settingRow(
                        icon: "star.bubble",
                        title: "Feedback",
                        action: {
                            showFeedbackEmail = true
                        }
                    )
                }

                // Legal Section
                sectionGroup(title: "Legal") {
                    settingRow(
                        icon: "doc.text",
                        title: "Terms of Use",
                        action: {
                            showTermsOfUse = true
                        }
                    )

                    Divider()
                        .padding(.leading, 52)

                    settingRow(
                        icon: "shield.lefthalf.filled",
                        title: "Privacy Policy",
                        action: {
                            showPrivacyPolicy = true
                        }
                    )
                }

                // About Section
                sectionGroup(title: "About") {
                    settingRowWithValue(
                        icon: "info.circle",
                        title: "App Info",
                        value: viewModel.appVersion,
                        action: {
                            // Navigate to app info
                        }
                    )

                    Divider()
                        .padding(.leading, 52)

                    settingRow(
                        icon: "book",
                        title: "Our story",
                        action: {
                            // Navigate to our story
                        }
                    )
                }

                // Log out Button
                if contentViewModel.authToken != nil {
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        Text("Log out")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 100)
                                    .fill(AppTheme.logoutButtonGray)
                            )
                    }
                    .padding(.vertical, 6)
                }

                // Copyright Text
                Text("© 2025 Babelo")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(red: 0.235, green: 0.235, blue: 0.263, opacity: 0.6))
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .background(AppTheme.backgroundGradient)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    router.resetToHome()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .blendMode(.multiply)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                contentViewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .sheet(isPresented: $showFeedbackEmail) {
            FeedbackEmailView()
                .environmentObject(contentViewModel)
        }
        .sheet(isPresented: $showTermsOfUse) {
            PolicyView(policyType: .termsOfUse)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PolicyView(policyType: .privacyPolicy)
        }
        .onAppear {
            viewModel.loadUserInfo(from: contentViewModel)
        }
    }

    // MARK: - User Profile Section

    private var userProfileSection: some View {
        Button(action: {
            router.goTo(.editProfile)
        }) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.lightBlueBackground)
                        .frame(width: 70, height: 70)

                    if let userInitial = viewModel.userInitial {
                        Text(userInitial)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppTheme.primaryBlue)
                    } else {
                        // Loading placeholder
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryBlue))
                    }
                }

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if let userName = viewModel.userName {
                        Text(userName)
                            .font(.system(size: 20, weight: .semibold))
                            .kerning(0.38)
                            .foregroundColor(.primary)
                    } else {
                        // Loading placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 20)
                    }

                    if let learningDays = viewModel.learningDays {
                        Text("Learning for \(learningDays) days")
                            .font(.system(size: 15, weight: .regular))
                            .kerning(-0.24)
                            .foregroundColor(AppTheme.gray3c3c4360)
                    } else {
                        // Loading placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.gray3c3c4360)
                            .frame(width: 130, height: 15)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.grayc7c7cc)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(26)
            .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Currently Learning Section

    private var currentlyLearningSection: some View {
        Button(action: {
            router.goTo(.onboardingTargetLanguage(sourceView: .settings))
        }) {
            HStack(spacing: 10) {
                // Flag Icon
                if let flag = viewModel.targetLanguageFlag {
                    Text(flag)
                        .font(.system(size: 28, weight: .regular))
                } else if viewModel.targetLanguage == nil && !viewModel.isLoading {
                    // Placeholder when no language is set
                    Image(systemName: "globe")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.grayc7c7cc)
                } else {
                    // Loading placeholder
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                }

                // Learning Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currently Learning")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.gray3c3c4360)

                    if let targetLanguage = viewModel.targetLanguage {
                        Text(targetLanguage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    } else if !viewModel.isLoading {
                        Text("Select Language")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    } else {
                        // Loading placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 17)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.grayc7c7cc)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(26)
            .shadow(color: Color.black.opacity(0.02), radius: 16, x: 0, y: 1)
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

    // MARK: - Setting Row

    private func settingRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppTheme.gray8c8c8c)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)

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

    // MARK: - Setting Row with Value

    private func settingRowWithValue(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppTheme.gray8c8c8c)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)

                Spacer()

                Text(value)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.gray8c8c8c)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.grayc7c7cc)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        SettingView()
            .environmentObject(Router())
            .environmentObject(ContentViewModel())
    }
}
