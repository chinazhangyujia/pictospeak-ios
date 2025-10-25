//
//  Configuration.swift
//  pictospeak-ios
//
//  Centralized configuration for API endpoints and app settings.
//

import Foundation

// MARK: - App Environment

enum AppEnvironment {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
            return .development
        #else
            return .production
        #endif
    }
}

// MARK: - API Configuration

enum APIConfiguration {
    /// Base URL for API requests
    /// - For Simulator: Uses localhost (127.0.0.1)
    /// - For Physical Device (Development): Uses your Mac's local network IP
    /// - For Production: Uses production server URL
    static var baseURL: String {
        #if targetEnvironment(simulator)
            // Simulator can use localhost
            return "http://127.0.0.1:8000"
        #else
            // Physical device configuration
            switch AppEnvironment.current {
            case .development:
                // TODO: Update this with your Mac's IP address when testing on device
                // To find your Mac's IP: Open Terminal and run: ipconfig getifaddr en0
                // Example: "http://192.168.1.5:8000"
                return "http://192.168.0.12:8000"
            case .staging:
                // TODO: Add your staging server URL when ready
                return "https://staging-api.pictospeak.com"
            case .production:
                // TODO: Add your production server URL when ready
                return "https://api.pictospeak.com"
            }
        #endif
    }

    /// Timeout interval for API requests (in seconds)
    static let timeoutInterval: TimeInterval = 30
}
