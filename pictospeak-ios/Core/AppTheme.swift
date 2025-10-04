//
//  AppTheme.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import SwiftUI

// MARK: - Global App Theme Configuration

enum AppTheme {
    // MARK: - Colors

    static let viewBackgroundGray = Color(red: 0.965, green: 0.969, blue: 0.984)

    static let primaryBlue = Color(red: 0.247, green: 0.388, blue: 0.910)
    static let lightBlueBackground = Color(red: 0.914, green: 0.933, blue: 1.0, opacity: 0.6)
    static let backButtonGray = Color(red: 0.471, green: 0.471, blue: 0.502).opacity(0.16)

    static let feedbackCardBackground = Color(.white)
    static let feedbackCardTextColor = Color(red: 0.549, green: 0.549, blue: 0.549, opacity: 1.0)

    static let gray3c3c3c60 = Color(red: 0x3c/255, green: 0x3c/255, blue: 0x3c/255).opacity(0.6)
    static let grayf8f9fa = Color(red: 0xf8/255, green: 0xf9/255, blue: 0xfa/255)
    static let gray333333 = Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)
    static let gray3c3c4360 = Color(red: 0x3c/255, green: 0x3c/255, blue: 0x43/255).opacity(0.6)
    static let grayd9d9d9 = Color(red: 0xd9/255, green: 0xd9/255, blue: 0xd9/255)

    // MARK: - Letter Spacing (Kerning)

    static let defaultKerning: CGFloat = 0.3
    static let titleKerning: CGFloat = 0.5
    static let captionKerning: CGFloat = 0.2

    // MARK: - Line Spacing

    static let defaultLineSpacing: CGFloat = 2
    static let bodyLineSpacing: CGFloat = 4

    // MARK: - Font Sizes (Optional - customize if needed)

    static let titleFontSize: CGFloat = 28
    static let bodyFontSize: CGFloat = 17
    static let cardDetailTextKerning: CGFloat = -0.23
    static let cardDetailTextLineSpacing: CGFloat = 5
    static let cardDetailTextSize: CGFloat = 15 // Custom size for card text
}

// MARK: - Text Extensions for Global Styling

extension Text {
    /// Apply default app styling to any text
    func appStyle() -> some View {
        kerning(AppTheme.defaultKerning)
            .lineSpacing(AppTheme.defaultLineSpacing)
    }

    /// Title text styling
    func appTitle() -> some View {
        font(.title2)
            .fontWeight(.bold)
            .kerning(AppTheme.titleKerning)
    }

    /// Body text styling
    func appBody() -> some View {
        font(.body)
            .kerning(AppTheme.defaultKerning)
            .lineSpacing(AppTheme.bodyLineSpacing)
    }

    func appCardHeaderText(color: Color) -> some View {
        font(.subheadline.weight(.regular))
            .foregroundColor(color)
    }

    /// Card text styling (custom 15pt, medium weight, between black and gray)
    func appCardDetailText() -> some View {
        font(.system(size: AppTheme.cardDetailTextSize, weight: .regular))
            .kerning(AppTheme.cardDetailTextKerning)
            .lineSpacing(AppTheme.cardDetailTextLineSpacing)
            .foregroundColor(Color(.label).opacity(0.5)) // Darker than gray, lighter than black
    }
}

// MARK: - View Modifier for Advanced Styling

struct AppTextStyle: ViewModifier {
    let kerning: CGFloat
    let lineSpacing: CGFloat

    init(kerning: CGFloat = AppTheme.defaultKerning, lineSpacing: CGFloat = AppTheme.defaultLineSpacing) {
        self.kerning = kerning
        self.lineSpacing = lineSpacing
    }

    func body(content: Content) -> some View {
        content
            .kerning(kerning)
            .lineSpacing(lineSpacing)
    }
}

extension View {
    /// Apply custom text styling with optional parameters
    func appTextStyle(kerning: CGFloat = AppTheme.defaultKerning, lineSpacing: CGFloat = AppTheme.defaultLineSpacing) -> some View {
        modifier(AppTextStyle(kerning: kerning, lineSpacing: lineSpacing))
    }
}
