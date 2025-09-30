import SwiftUI

struct LanguageSelectionRow: View {
    let flag: String
    let language: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Flag icon
                Text(flag)
                    .frame(width: 36, height: 36)
                    .font(.system(size: 24))

                // Language text
                Text(language)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.black)

                Spacer()

                // Checkmark
                Image(systemName: "checkmark")
                    .frame(width: 44, height: 44)
                    .background(isSelected ? AppTheme.lightBlueBackground : Color(red: 0xCC / 255, green: 0xCC / 255, blue: 0xCC / 255, opacity: 0.05))
                    .clipShape(Circle())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? AppTheme.primaryBlue : Color(red: 0x8C / 255, green: 0x8C / 255, blue: 0x8C / 255))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
