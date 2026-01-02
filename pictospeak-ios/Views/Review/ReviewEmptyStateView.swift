//
//  ReviewEmptyStateView.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import SwiftUI

struct ReviewEmptyStateView: View {
    let iconName: String
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        Spacer()

        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(LocalizedStringKey(titleKey))
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.95)
                .lineSpacing(10) // 30px line height - 20px font size
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            Text(LocalizedStringKey(subtitleKey))
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.23)
                .lineSpacing(9.38) // 24.38px line height - 15px font size
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)

        Spacer()
    }
}
