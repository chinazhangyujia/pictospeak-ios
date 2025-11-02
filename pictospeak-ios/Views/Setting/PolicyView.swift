//
//  PolicyView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

enum PolicyType {
    case termsOfUse
    case privacyPolicy

    var title: String {
        switch self {
        case .termsOfUse:
            return "Terms of Use"
        case .privacyPolicy:
            return "Privacy Policy"
        }
    }
}

struct PolicyView: View {
    let policyType: PolicyType
    @Environment(\.dismiss) private var dismiss
    @State private var policyResponse: PolicyResponse?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryBlue))
                        Text("Loading...")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(AppTheme.gray8c8c8c)
                            .padding(.top, 8)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.gray8c8c8c)
                        Text("Failed to load content")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                        Text(error)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppTheme.gray8c8c8c)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Retry") {
                            loadPolicy()
                        }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .background(AppTheme.primaryBlue)
                        .cornerRadius(100)
                    }
                } else if let response = policyResponse {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                Divider()
                                // Render each policy item with title and content
                                ForEach(Array(response.policies.enumerated()), id: \.offset) { index, policyItem in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(policyItem.title)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text(policyItem.content)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.primary)
                                            .lineSpacing(4)
                                    }
                                    .id(index == 0 ? "top" : nil)
                                }

                                // Footer
                                Text(response.footer)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                        }
                        .onAppear {
                            scrollProxy = proxy
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Text(policyResponse?.title ?? policyType.title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                loadPolicy()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadPolicy() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await policyType == .termsOfUse
                    ? PolicyService.shared.fetchTermsOfUse()
                    : PolicyService.shared.fetchPrivacyPolicy()

                await MainActor.run {
                    self.policyResponse = response
                    self.isLoading = false
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
    PolicyView(policyType: .termsOfUse)
}
