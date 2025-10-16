//
//  SubscriptionService.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import Foundation

class SubscriptionService {
    private let baseURL = "http://127.0.0.1:8000" // Local FastAPI server
    
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
}

// MARK: - Error Types

enum SubscriptionError: Error, LocalizedError {
    case invalidURL
    case decodingError
    case serverError
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .decodingError:
            return "Failed to decode response"
        case .serverError:
            return "Server error occurred"
        case .networkError:
            return "Network error occurred"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
