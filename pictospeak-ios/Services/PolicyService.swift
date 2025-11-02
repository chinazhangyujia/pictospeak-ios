//
//  PolicyService.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import Foundation

class PolicyService {
    private let baseURL = APIConfiguration.baseURL

    // MARK: - Singleton

    static let shared = PolicyService()
    private init() {}

    // MARK: - Public Methods

    /// Fetches privacy policy content from the backend
    /// - Returns: PolicyResponse containing the privacy policy content
    func fetchPrivacyPolicy() async throws -> PolicyResponse {
        guard let url = URL(string: baseURL + "/policy/privacy-policy") else {
            throw PolicyError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        print("🌐 Making privacy policy request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw PolicyError.serverError
            }

            print("📡 Privacy policy response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Privacy policy API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw PolicyError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let policyResponse = try decoder.decode(PolicyResponse.self, from: data)
                print("✅ Successfully fetched privacy policy")
                return policyResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw PolicyError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw PolicyError.networkError
        } catch {
            print("❌ Unexpected error during privacy policy fetch: \(error)")
            throw PolicyError.unknownError
        }
    }

    /// Fetches terms of use content from the backend
    /// - Returns: PolicyResponse containing the terms of use content
    func fetchTermsOfUse() async throws -> PolicyResponse {
        guard let url = URL(string: baseURL + "/policy/terms-of-use") else {
            throw PolicyError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        print("🌐 Making terms of use request to: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw PolicyError.serverError
            }

            print("📡 Terms of use response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ Terms of use API error: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response body: \(errorData)")
                }
                throw PolicyError.serverError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            do {
                let policyResponse = try decoder.decode(PolicyResponse.self, from: data)
                print("✅ Successfully fetched terms of use")
                return policyResponse
            } catch {
                print("❌ Decoding error: \(error)")
                throw PolicyError.decodingError
            }

        } catch let urlError as URLError {
            print("❌ URL Error: \(urlError.localizedDescription)")
            throw PolicyError.networkError
        } catch {
            print("❌ Unexpected error during terms of use fetch: \(error)")
            throw PolicyError.unknownError
        }
    }
}

// MARK: - Error Types

enum PolicyError: Error, LocalizedError {
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

// MARK: - Response Models

struct PolicyResponse: Codable {
    let version: String
    let lastUpdated: String
    let title: String
    let footer: String
    let policies: [PolicyItem]

    enum CodingKeys: String, CodingKey {
        case version
        case lastUpdated = "last_updated"
        case title
        case footer
        case policies
    }
}

struct PolicyItem: Codable {
    let title: String
    let content: String
}
