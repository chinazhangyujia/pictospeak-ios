//
//  UserDefaultManager.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

enum UserDefaultKeys {
    static let preSignUpUserSetting = "preSignUpUserSetting"
    static let hasOnboardingCompleted = "hasOnboardingCompleted"
}

class UserDefaultManager {
    static let shared = UserDefaultManager()

    private let userDefaults = UserDefaults.standard

    private init() {}

    // MARK: - UserSetting Management

    /// Saves a UserSetting to UserDefaults with the key "preSignUpUserSetting"
    /// - Parameter userSetting: The UserSetting to save
    /// - Returns: True if successful, false otherwise
    func savePreSignUpUserSetting(_ userSetting: UserSetting) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .useDefaultKeys
            let data = try encoder.encode(userSetting)
            userDefaults.set(data, forKey: UserDefaultKeys.preSignUpUserSetting)
            print("✅ Successfully saved pre-signup user setting to UserDefaults")
            return true
        } catch {
            print("❌ Failed to save pre-signup user setting: \(error)")
            return false
        }
    }

    /// Retrieves a UserSetting from UserDefaults with the key "preSignUpUserSetting"
    /// - Returns: The UserSetting if found, nil otherwise
    func getPreSignUpUserSetting() -> UserSetting? {
        guard let data = userDefaults.data(forKey: UserDefaultKeys.preSignUpUserSetting) else {
            print("📝 No pre-signup user setting found in UserDefaults")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let userSetting = try decoder.decode(UserSetting.self, from: data)
            print("✅ Successfully retrieved pre-signup user setting from UserDefaults")
            return userSetting
        } catch {
            print("❌ Failed to decode pre-signup user setting: \(error)")
            return nil
        }
    }

    /// Deletes the pre-signup UserSetting from UserDefaults
    /// - Returns: True if successful, false otherwise
    func deletePreSignUpUserSetting() -> Bool {
        userDefaults.removeObject(forKey: UserDefaultKeys.preSignUpUserSetting)
        print("✅ Successfully deleted pre-signup user setting from UserDefaults")
        return true
    }

    // MARK: - Generic UserDefaults Methods

    /// Saves any Codable object to UserDefaults
    /// - Parameters:
    ///   - object: The Codable object to save
    ///   - key: The key to use for storage
    /// - Returns: True if successful, false otherwise
    func save<T: Codable>(_ object: T, forKey key: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .useDefaultKeys
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            print("✅ Successfully saved object for key: \(key)")
            return true
        } catch {
            print("❌ Failed to save object for key \(key): \(error)")
            return false
        }
    }

    /// Retrieves any Codable object from UserDefaults
    /// - Parameters:
    ///   - type: The type of object to retrieve
    ///   - key: The key used for storage
    /// - Returns: The object if found, nil otherwise
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            print("📝 No data found for key: \(key)")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let object = try decoder.decode(type, from: data)
            print("✅ Successfully retrieved object for key: \(key)")
            return object
        } catch {
            print("❌ Failed to decode object for key \(key): \(error)")
            return nil
        }
    }

    /// Saves a simple value (Bool, String, Int, etc.) to UserDefaults
    /// - Parameters:
    ///   - value: The value to save
    ///   - key: The key to use for storage
    func saveValue<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
        print("✅ Successfully saved value for key: \(key)")
    }

    /// Retrieves a simple value from UserDefaults
    /// - Parameters:
    ///   - type: The type of value to retrieve
    ///   - key: The key used for storage
    /// - Returns: The value if found, nil otherwise
    func getValue<T>(_: T.Type, forKey key: String) -> T? {
        let value = userDefaults.object(forKey: key) as? T
        if value != nil {
            print("✅ Successfully retrieved value for key: \(key)")
        } else {
            print("📝 No value found for key: \(key)")
        }
        return value
    }

    /// Deletes an object from UserDefaults
    /// - Parameter key: The key to delete
    /// - Returns: True if successful, false otherwise
    func delete(forKey key: String) -> Bool {
        userDefaults.removeObject(forKey: key)
        print("✅ Successfully deleted object for key: \(key)")
        return true
    }
}
