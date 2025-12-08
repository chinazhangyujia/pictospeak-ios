//
//  FeedbackEmailView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import Darwin
import MessageUI
import SwiftUI

struct FeedbackEmailView: View {
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if MFMailComposeViewController.canSendMail() {
            MailComposeView(contentViewModel: contentViewModel, dismiss: dismiss)
        } else {
            MailNotAvailableView()
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let contentViewModel: ContentViewModel
    let dismiss: DismissAction

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator

        // Set recipient
        mailComposer.setToRecipients(["support@babelo.io"])

        // Set subject
        mailComposer.setSubject(NSLocalizedString("settings.feedback", comment: "Feedback"))

        // Get device information
        let deviceInfo = getDeviceInfo()

        // Create email body
        let emailBody = createEmailBody(deviceInfo: deviceInfo)
        mailComposer.setMessageBody(emailBody, isHTML: false)

        return mailComposer
    }

    func updateUIViewController(_: MFMailComposeViewController, context _: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith _: MFMailComposeResult, error _: Error?) {
            controller.dismiss(animated: true) {
                self.dismiss()
            }
        }
    }

    private struct DeviceInfo {
        let deviceModel: String
        let iosVersion: String
        let appVersion: String
        let appBuild: String
        let displayLanguage: String
        let learningLanguage: String?
        let teachingLanguage: String?
        let region: String
        let anonymousID: String
        let aiModel: String
    }

    private func getDeviceInfo() -> DeviceInfo {
        // Get device model with more specific name
        let deviceModel = getDeviceModelName()

        // Get iOS version
        let iosVersion = UIDevice.current.systemVersion

        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Get display language (system language)
        let displayLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let displayLanguageRegion = Locale.current.language.region?.identifier ?? ""
        let displayLanguageFull = "\(displayLanguage)-\(displayLanguageRegion)".uppercased()

        // Get learning language and teaching language from user settings
        let learningLanguage = contentViewModel.userInfo.userSetting?.targetLanguage.capitalized
        let teachingLanguage = contentViewModel.userInfo.userSetting?.nativeLanguage.capitalized

        // Get region from locale
        let region = Locale.current.language.region?.identifier ?? "Unknown"

        // Generate anonymous ID (using user ID if available, otherwise generate a new one)
        let anonymousID = contentViewModel.userInfo.user?.id ?? UUID().uuidString

        return DeviceInfo(
            deviceModel: deviceModel,
            iosVersion: iosVersion,
            appVersion: appVersion,
            appBuild: appBuild,
            displayLanguage: displayLanguageFull,
            learningLanguage: learningLanguage,
            teachingLanguage: teachingLanguage,
            region: region,
            anonymousID: anonymousID,
            aiModel: "OpenAI (GPT-4o-mini)"
        )
    }

    private func getDeviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(Character(UnicodeScalar(UInt8(value))))
        }

        switch identifier {
        case "iPhone15,3": return "iPhone 15 Pro Max"
        case "iPhone15,4": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        case "iPad13,1", "iPad13,2": return "iPad Air (5th generation)"
        case "iPad13,16", "iPad13,17": return "iPad Air (5th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"
        default:
            // For unknown models, return the generic model
            return UIDevice.current.model
        }
    }

    private func createEmailBody(deviceInfo: DeviceInfo) -> String {
        var body = "[Please describe your issue or feedback here]\n\n"
        body += "---\n\n"
        body += "**Device Info**\n"
        body += "• Device: \(deviceInfo.deviceModel)\n"
        body += "• iOS: \(deviceInfo.iosVersion)\n"
        body += "• App Version: \(deviceInfo.appVersion) (\(deviceInfo.appBuild))\n\n"

        body += "**User Context**\n"
        body += "• AI Model: \(deviceInfo.aiModel)\n"
        body += "• Region: \(deviceInfo.region)\n"
        body += "• Display Language: \(deviceInfo.displayLanguage)\n"
        if let learningLanguage = deviceInfo.learningLanguage {
            body += "• Learning Language: \(learningLanguage)\n"
        }
        if let teachingLanguage = deviceInfo.teachingLanguage {
            body += "• Teaching Language: \(teachingLanguage)\n"
        }
        body += "\n"

        body += "**Identifier**\n"
        body += "• Anonymous ID: \(deviceInfo.anonymousID)\n\n"
        body += "---\n\n"

        return body
    }
}

struct MailNotAvailableView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Mail Not Available")
                .font(.system(size: 24, weight: .semibold))

            Text("Please configure an email account in Settings to send feedback.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("common.dismiss") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient)
    }
}

// Note: MFMailComposeViewController.canSendMail() returns false in Simulator,
// so the preview will show MailNotAvailableView.
// To test the actual mail composer, run on a physical device with Mail configured.

#Preview {
    NavigationStack {
        FeedbackEmailView()
            .environmentObject(ContentViewModel())
    }
}
