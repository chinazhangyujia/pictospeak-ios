//
//  AuthService.swift
//  pictospeak-ios
//
//  Created by AI Assistant.
//

import Foundation

class AuthService {
    private let baseURL = "http://127.0.0.1:8000" // Local FastAPI server
    private let keychainManager = KeychainManager.shared

    // MARK: - Singleton

    static let shared = AuthService()
    private init() {}

    // MARK: - Public Methods

    /// Signs up a new user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - nickname: User's display name
    /// - Returns: AuthResponse containing access token and token type
    func signUp(email: String, password: String, nickname: String, userSetting: UserSetting) async throws -> AuthResponse {
        guard let url = URL(string: baseURL + "/auth/sign_up") else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        let signUpRequest = UserSignUpRequest(email: email, password: password, nickname: nickname, targetLanguage: userSetting.targetLanguage, nativeLanguage: userSetting.nativeLanguage)

        do {
            urlRequest.httpBody = try JSONEncoder().encode(signUpRequest)
        } catch {
            throw AuthError.encodingError
        }

        print("🌐 Making sign up request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw AuthError.serverError
            }

            print("📡 Sign up response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                print("❌ Sign up API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw AuthError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)

                // Save the access token to keychain
                let tokenSaved = keychainManager.saveToken(authResponse.accessToken)
                if tokenSaved {
                    print("✅ Successfully signed up and saved token for user: \(email)")
                } else {
                    print("⚠️ Signed up successfully but failed to save token")
                }

                return authResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw AuthError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw AuthError.networkError
        } catch {
            print("❌ Unexpected error during sign up: \(error)")
            throw AuthError.unknownError
        }
    }

    /// Signs in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: AuthResponse containing access token and token type
    func signIn(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: baseURL + "/auth/sign_in") else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        // Create form data for FastAPI
        let formData = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        urlRequest.httpBody = formData.data(using: .utf8)

        print("🌐 Making sign in request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw AuthError.serverError
            }

            print("📡 Sign in response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Sign in API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw AuthError.authenticationFailed
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)

                // Save the access token to keychain
                let tokenSaved = keychainManager.saveToken(authResponse.accessToken)
                if tokenSaved {
                    print("✅ Successfully signed in and saved token for user: \(email)")
                } else {
                    print("⚠️ Signed in successfully but failed to save token")
                }

                return authResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw AuthError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw AuthError.networkError
        } catch {
            print("❌ Unexpected error during sign in: \(error)")
            throw AuthError.unknownError
        }
    }

    /// Refreshes the access token using the current token
    /// - Returns: AuthResponse containing new access token
    func refreshToken(authToken _: String) async throws -> AuthResponse {
        // Get current token from keychain
        guard let currentToken = keychainManager.getToken() else {
            throw AuthError.noTokenFound
        }

        guard let url = URL(string: baseURL + "/auth/refresh_access_token") else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30

        print("🌐 Making token refresh request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw AuthError.serverError
            }

            print("📡 Token refresh response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Token refresh API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw AuthError.tokenRefreshFailed
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)

                // Save the new access token to keychain
                let tokenSaved = keychainManager.saveToken(authResponse.accessToken)
                if tokenSaved {
                    print("✅ Successfully refreshed and saved new token")
                } else {
                    print("⚠️ Token refreshed successfully but failed to save new token")
                }

                return authResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw AuthError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw AuthError.networkError
        } catch {
            print("❌ Unexpected error during token refresh: \(error)")
            throw AuthError.unknownError
        }
    }

    /// Signs out the current user by removing the token from keychain
    func signOut() {
        let tokenDeleted = keychainManager.deleteToken()
        if tokenDeleted {
            print("✅ Successfully signed out and removed token")
        } else {
            print("⚠️ Failed to remove token during sign out")
        }
    }

    /// Checks if user is currently signed in (has a valid token)
    /// - Returns: True if user has a token, false otherwise
    func isSignedIn() -> Bool {
        return keychainManager.hasToken()
    }

    /// Gets the current access token from keychain
    /// - Returns: Current access token if available, nil otherwise
    func getCurrentToken() -> String? {
        return keychainManager.getToken()
    }

    /// Resets the user's password using verification code
    /// - Parameters:
    ///   - targetType: The target type (e.g., EMAIL)
    ///   - targetValue: The email address
    ///   - newPassword: The new password
    ///   - verificationCodeId: The verification code ID from verification response
    ///   - verificationCode: The verification code
    /// - Returns: AuthResponse containing access token and token type
    func resetPassword(targetType: TargetType, targetValue: String, newPassword: String, verificationCodeId: String, verificationCode: String) async throws -> AuthResponse {
        guard let url = URL(string: baseURL + "/auth/reset_password") else {
            throw AuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        let resetRequest = ResetPasswordRequest(
            targetType: targetType,
            targetValue: targetValue,
            newPassword: newPassword,
            verificationCodeId: verificationCodeId,
            verificationCode: verificationCode
        )

        do {
            urlRequest.httpBody = try JSONEncoder().encode(resetRequest)
        } catch {
            throw AuthError.encodingError
        }

        print("🌐 Making password reset request to: \(url)")
        print("📤 Resetting password for: \(targetValue)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw AuthError.serverError
            }

            print("📡 Password reset response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Password reset API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw AuthError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)

                // Save the access token to keychain
                let tokenSaved = keychainManager.saveToken(authResponse.accessToken)
                if tokenSaved {
                    print("✅ Password reset successful and saved token for user: \(targetValue)")
                } else {
                    print("⚠️ Password reset successful but failed to save token")
                }

                return authResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw AuthError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw AuthError.networkError
        } catch {
            print("❌ Unexpected error during password reset: \(error)")
            throw AuthError.unknownError
        }
    }
}

// MARK: - Error Types

enum AuthError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case serverError
    case networkError
    case authenticationFailed
    case tokenRefreshFailed
    case noTokenFound
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .serverError:
            return "Server error occurred"
        case .networkError:
            return "Network error occurred"
        case .authenticationFailed:
            return "Authentication failed - invalid credentials"
        case .tokenRefreshFailed:
            return "Token refresh failed"
        case .noTokenFound:
            return "No authentication token found"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
