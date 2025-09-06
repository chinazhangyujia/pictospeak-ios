import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    // MARK: - Token Management

    /// Saves a token to the keychain
    /// - Parameters:
    ///   - token: The token string to save
    ///   - key: The key to associate with the token (defaults to "auth_token")
    /// - Returns: True if successful, false otherwise
    func saveToken(_ token: String, forKey key: String = "auth_token") -> Bool {
        // Delete any existing token first
        deleteToken(forKey: key)

        guard let data = token.data(using: .utf8) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves a token from the keychain
    /// - Parameter key: The key associated with the token (defaults to "auth_token")
    /// - Returns: The token string if found, nil otherwise
    func getToken(forKey key: String = "auth_token") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return token
    }

    /// Deletes a token from the keychain
    /// - Parameter key: The key associated with the token (defaults to "auth_token")
    /// - Returns: True if successful, false otherwise
    func deleteToken(forKey key: String = "auth_token") -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Checks if a token exists in the keychain
    /// - Parameter key: The key to check (defaults to "auth_token")
    /// - Returns: True if token exists, false otherwise
    func hasToken(forKey key: String = "auth_token") -> Bool {
        return getToken(forKey: key) != nil
    }
}
