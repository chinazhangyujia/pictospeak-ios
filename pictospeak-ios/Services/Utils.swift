//
//  Utils.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

enum Utils {
    /// Parses a cursor string from the backend into URLQueryItem array
    /// - Parameter cursorString: The cursor string from backend (e.g., "last_favorite=False&last_updated_at=2025-08-24 01:51:30.509506+00:00&last_id=24a4f763-4203-46cb-bbe6-690932ae16aa")
    /// - Returns: Array of URLQueryItem objects for use in URLComponents
    static func parseCursorString(_ cursorString: String) -> [URLQueryItem] {
        let queryParams = cursorString.components(separatedBy: "&")
        var queryItems: [URLQueryItem] = []

        for param in queryParams {
            let components = param.components(separatedBy: "=")
            if components.count == 2 {
                let name = components[0]
                let value = components[1]
                queryItems.append(URLQueryItem(name: name, value: value))
            }
        }

        return queryItems
    }
}
