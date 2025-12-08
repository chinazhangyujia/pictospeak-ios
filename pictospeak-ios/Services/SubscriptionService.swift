//
//  SubscriptionService.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import Foundation

class SubscriptionService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = SubscriptionService()
    private init() {}

    // MARK: - Public Methods

    /// Fetches the subscription policy from the server
    /// - Returns: SubscriptionPolicyResponse containing pricing, features, and policy information
    func fetchSubscriptionPolicy() async throws -> SubscriptionPolicyResponse {
        guard let url = URL(string: baseURL + "/subscription/policy") else {
            throw SubscriptionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        print("🌐 Making subscription policy request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw SubscriptionError.serverError
            }

            print("📡 Subscription policy response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Subscription policy API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw SubscriptionError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let policyResponse = try decoder.decode(SubscriptionPolicyResponse.self, from: data)
                print("✅ Successfully fetched subscription policy")
                return policyResponse
            } catch {
                print("❌ Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ Response body: \(jsonString)")
                }
                throw SubscriptionError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw SubscriptionError.networkError
        } catch {
            print("❌ Unexpected error during subscription policy fetch: \(error)")
            throw SubscriptionError.unknownError
        }
    }

    /// Verifies a purchase with the backend server
    /// - Parameters:
    ///   - authToken: User authentication token
    ///   - transactionId: The Apple transaction ID
    ///   - productId: The product identifier (e.g., io.babelo.peekspeak.monthly)
    ///   - receiptData: The JWS token from transaction.jwsRepresentation (cryptographically signed by Apple)
    func verifyPurchase(authToken: String, transactionId: String, productId: String, receiptData: String) async throws {
        guard let url = URL(string: baseURL + "/subscription/verify-purchase") else {
            throw SubscriptionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        // Add auth token if available
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "transaction_id": transactionId,
            "product_id": productId,
            "receipt_data": receiptData,
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🌐 Verifying purchase with backend: \(transactionId)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw SubscriptionError.serverError
            }

            print("📡 Purchase verification response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Purchase verification failed: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw SubscriptionError.serverError
            }

            print("✅ Purchase verified with backend")

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw SubscriptionError.networkError
        } catch {
            print("❌ Unexpected error during purchase verification: \(error)")
            throw SubscriptionError.unknownError
        }
    }
}

// MARK: - Error Types

enum SubscriptionError: Error, LocalizedError {
    case invalidURL
    case decodingError
    case serverError
    case networkError
    case unknownError
    case purchaseFailed
    case purchaseCancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error.invalidURL", comment: "Invalid URL")
        case .decodingError:
            return NSLocalizedString("error.decoding", comment: "Decoding error")
        case .serverError:
            return NSLocalizedString("error.server", comment: "Server error")
        case .networkError:
            return NSLocalizedString("error.network", comment: "Network error")
        case .unknownError:
            return NSLocalizedString("error.unknown", comment: "Unknown error")
        case .purchaseFailed:
            return NSLocalizedString("error.subscription.purchaseFailed", comment: "Purchase failed")
        case .purchaseCancelled:
            return NSLocalizedString("error.subscription.purchaseCancelled", comment: "Purchase cancelled")
        }
    }
}
