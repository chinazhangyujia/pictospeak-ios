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
    
    static let primaryBlue = Color(red: 0.247, green: 0.388, blue: 0.910)
    static let backButtonGray = Color(red: 0.471, green: 0.471, blue: 0.502).opacity(0.16)

    static let feedbackCardBackground = Color(red: 0.961, green: 0.961, blue: 0.961, opacity: 0.6)
    static let feedbackCardTextColor = Color(red: 0.549, green: 0.549, blue: 0.549, opacity: 1.0)
    
    // MARK: - Letter Spacing (Kerning)

    static let defaultKerning: CGFloat = 0.3
    static let titleKerning: CGFloat = 0.5
    static let captionKerning: CGFloat = 0.2
    static let cardTextKerning: CGFloat = 0.4

    // MARK: - Line Spacing

    static let defaultLineSpacing: CGFloat = 2
    static let bodyLineSpacing: CGFloat = 4

    // MARK: - Font Sizes (Optional - customize if needed)

    static let titleFontSize: CGFloat = 28
    static let bodyFontSize: CGFloat = 17
    static let cardTextSize: CGFloat = 15 // Custom size for card text
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

    /// Card text styling (custom 15pt, medium weight, between black and gray)
    func appCardText() -> some View {
        font(.system(size: AppTheme.cardTextSize, weight: .medium))
            .kerning(AppTheme.cardTextKerning)
            .foregroundColor(Color(.label).opacity(0.5)) // Darker than gray, lighter than black
    }

    /// Card text styling with custom font size override
    func appCardText(fontSize: CGFloat) -> some View {
        font(.system(size: fontSize, weight: .medium))
            .kerning(AppTheme.cardTextKerning)
            .foregroundColor(Color(.label).opacity(0.5))
    }
    
    /// Card text styling with custom font size, weight, and color
    func appCardText(fontSize: CGFloat, weight: Font.Weight, color: Color) -> some View {
        font(.system(size: fontSize, weight: weight))
            .kerning(AppTheme.cardTextKerning)
            .foregroundColor(color)
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
