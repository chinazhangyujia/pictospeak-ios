//
//  SubscriptionModels.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import Foundation

// MARK: - Subscription Policy Response

struct SubscriptionPolicyResponse: Codable {
    let price: PriceInfo
    let freeTrial: FreeTrialInfo
    let featuresIncluded: FeaturesInfo
    let usageLimits: UsageLimitsInfo
    let purchasePolicy: PurchasePolicyInfo
    
    enum CodingKeys: String, CodingKey {
        case price
        case freeTrial = "free_trial"
        case featuresIncluded = "features_included"
        case usageLimits = "usage_limits"
        case purchasePolicy = "purchase_policy"
    }
}

struct PriceInfo: Codable {
    let monthly: Double
    let yearly: Double
}

struct FreeTrialInfo: Codable {
    let days: Int
}

struct FeaturesInfo: Codable {
    let features: [String]
}

struct UsageLimitsInfo: Codable {
    let usageLimits: [String]
    let additionalClauses: [String]
    
    enum CodingKeys: String, CodingKey {
        case usageLimits = "usage_limits"
        case additionalClauses = "additional_clauses"
    }
}

struct PurchasePolicyInfo: Codable {
    let policy: String
}
