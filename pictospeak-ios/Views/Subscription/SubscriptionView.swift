//
//  SubscriptionView.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contentViewModel: ContentViewModel
    @StateObject private var storeKitManager = StoreKitManager.shared
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var policyData: SubscriptionPolicyResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPurchasing = false
    @State private var showPurchaseSuccess = false
    @State private var showPurchaseError = false
    @State private var purchaseErrorMessage: String?

    enum SubscriptionPlan: CaseIterable {
        case monthly, yearly

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        func price(from policyData: SubscriptionPolicyResponse?) -> String {
            guard let policyData = policyData else {
                switch self {
                case .monthly: return "$7.99"
                case .yearly: return "$69.99"
                }
            }

            switch self {
            case .monthly: return String(format: "$%.2f", policyData.price.monthly)
            case .yearly: return String(format: "$%.2f", policyData.price.yearly)
            }
        }

        var period: String {
            switch self {
            case .monthly: return "per month"
            case .yearly: return "per year"
            }
        }

        func monthlyEquivalent(from policyData: SubscriptionPolicyResponse?) -> String? {
            guard let policyData = policyData else {
                switch self {
                case .monthly: return nil
                case .yearly: return "≈ $5.83 / month"
                }
            }

            switch self {
            case .monthly: return nil
            case .yearly:
                let monthlyPrice = policyData.price.yearly / 12.0
                return String(format: "≈ $%.2f / month", monthlyPrice)
            }
        }

        func savings(from policyData: SubscriptionPolicyResponse?) -> String? {
            guard let policyData = policyData else {
                switch self {
                case .monthly: return nil
                case .yearly: return "Save 27%"
                }
            }

            switch self {
            case .monthly: return nil
            case .yearly:
                let yearlyMonthly = policyData.price.yearly / 12.0
                let savingsPercent = ((policyData.price.monthly - yearlyMonthly) / policyData.price.monthly) * 100
                return String(format: "Save %.0f%%", savingsPercent)
            }
        }

        var isRecommended: Bool {
            switch self {
            case .monthly: return false
            case .yearly: return true
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading subscription details...")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error loading subscription")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    Text(errorMessage)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.gray3c3c3c60)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button(action: {
                        Task {
                            await loadSubscriptionPolicy()
                        }
                    }) {
                        Text("Try Again")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 52)
                            .background(AppTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 12) {
                            Text("Learn faster with AI feedback")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)

                            Text("Get quick, useful feedback with image-based practice.")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.gray3c3c4360)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)

                        // Pricing Cards Section
                        HStack(spacing: 16) {
                            // Monthly Card
                            SubscriptionPlanCard(
                                plan: .monthly,
                                isSelected: selectedPlan == .monthly,
                                policyData: policyData,
                                onTap: { selectedPlan = .monthly }
                            )

                            // Yearly Card
                            SubscriptionPlanCard(
                                plan: .yearly,
                                isSelected: selectedPlan == .yearly,
                                policyData: policyData,
                                onTap: { selectedPlan = .yearly }
                            )
                        }

                        // CTA Button Section
                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await handlePurchase()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isPurchasing ? "Processing..." : trialButtonText)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(isPurchasing ? AppTheme.primaryBlue.opacity(0.7) : AppTheme.primaryBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 100))
                            }
                            .disabled(isPurchasing)
                            .padding(.horizontal, 20)

                            Text(subscriptionDetailsText)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.primaryBlue)
                                .multilineTextAlignment(.center)
                        }

                        // What's Included Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What's included:")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.black)

                            VStack(alignment: .leading, spacing: 12) {
                                if let features = policyData?.featuresIncluded.features {
                                    ForEach(features, id: \.self) { feature in
                                        FeatureRow(text: feature)
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 26))

                        // Usage Limits Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Usage limits:")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.black)

                            VStack(alignment: .leading, spacing: 8) {
                                if let limits = policyData?.usageLimits.usageLimits {
                                    ForEach(limits, id: \.self) { limit in
                                        Text(limit)
                                            .font(.system(size: 15))
                                            .lineSpacing(22 - 15)
                                            .foregroundColor(AppTheme.gray3c3c4360)
                                    }
                                }

                                Divider()

                                if let clauses = policyData?.usageLimits.additionalClauses {
                                    ForEach(clauses, id: \.self) { clause in
                                        Text(clause)
                                            .font(.system(size: 15))
                                            .lineSpacing(22 - 15)
                                            .foregroundColor(AppTheme.gray3c3c4360)
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 26))

                        // Footer Section
                        Button(action: {
                            Task {
                                await handleRestorePurchases()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryBlue))
                                        .scaleEffect(0.8)
                                }
                                Text("Restore Purchases")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(AppTheme.primaryBlue)
                            }
                        }
                        .disabled(isPurchasing)

                        HStack(spacing: 24) {
                            Button(action: {
                                // Handle terms of use
                            }) {
                                Text("Terms of Use")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.primaryBlue)
                            }

                            Button(action: {
                                // Handle privacy policy
                            }) {
                                Text("Privacy Policy")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.primaryBlue)
                            }
                        }

                        Text(policyData?.purchasePolicy.policy ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.gray3c3c4360)
                            .multilineTextAlignment(.center)
                            .lineSpacing(14 - 11)
                            .padding(.horizontal, 24)
                    }
                }
                .toolbar(content: {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                })
            }
        }
        .padding(.horizontal, 16)
        .background(AppTheme.viewBackgroundGray)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Purchase Successful", isPresented: $showPurchaseSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your subscription has been activated. Enjoy unlimited access!")
        }
        .alert("Purchase Failed", isPresented: $showPurchaseError) {
            Button("OK") {}
        } message: {
            Text(purchaseErrorMessage ?? "An error occurred during purchase. Please try again.")
        }
        .onAppear {
            Task {
                await loadSubscriptionPolicy()
            }
        }
    }

    // MARK: - Helper Properties

    var trialButtonText: String {
        guard let trialDays = policyData?.freeTrial.days else {
            return "Start 7-day free trial"
        }
        return "Start \(trialDays)-day free trial"
    }

    var subscriptionDetailsText: String {
        guard let policyData = policyData else {
            return "Then $69.99/year, cancel anytime."
        }

        let price = selectedPlan == .yearly ? policyData.price.yearly : policyData.price.monthly
        let period = selectedPlan == .yearly ? "year" : "month"
        return String(format: "Then $%.2f/%@, cancel anytime.", price, period)
    }

    // MARK: - Helper Methods

    func loadSubscriptionPolicy() async {
        isLoading = true
        errorMessage = nil

        do {
            let policy = try await SubscriptionService.shared.fetchSubscriptionPolicy()
            policyData = policy
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func handlePurchase() async {
        guard !isPurchasing else { return }

        isPurchasing = true
        purchaseErrorMessage = nil

        do {
            // Get the selected product
            let product: Product?
            if selectedPlan == .monthly {
                product = storeKitManager.monthlyProduct
            } else {
                product = storeKitManager.yearlyProduct
            }

            guard let selectedProduct = product else {
                purchaseErrorMessage = "Product not available. Please try again later."
                showPurchaseError = true
                isPurchasing = false
                return
            }

            // Start the purchase
            let transaction = try await storeKitManager.purchase(selectedProduct, authToken: contentViewModel.authToken)

            if transaction != nil {
                // Purchase successful
                showPurchaseSuccess = true
            } else {
                // Purchase was cancelled or is pending
                purchaseErrorMessage = "Purchase was cancelled or is pending approval."
                showPurchaseError = true
            }

        } catch {
            purchaseErrorMessage = error.localizedDescription
            showPurchaseError = true
        }

        isPurchasing = false
    }

    func handleRestorePurchases() async {
        guard !isPurchasing else { return }

        isPurchasing = true
        purchaseErrorMessage = nil

        do {
            try await storeKitManager.restorePurchases(authToken: contentViewModel.authToken)

            if storeKitManager.hasActiveSubscription {
                purchaseErrorMessage = "Purchases restored successfully!"
                showPurchaseSuccess = true
            } else {
                purchaseErrorMessage = "No active subscriptions found to restore."
                showPurchaseError = true
            }
        } catch {
            purchaseErrorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            showPurchaseError = true
        }

        isPurchasing = false
    }
}

// MARK: - Subscription Plan Card

struct SubscriptionPlanCard: View {
    let plan: SubscriptionView.SubscriptionPlan
    let isSelected: Bool
    let policyData: SubscriptionPolicyResponse?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main card content
                VStack(spacing: 8) {
                    Spacer()

                    // Price and period
                    VStack(spacing: 4) {
                        Text(plan.price(from: policyData))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isSelected ? .white : .black)

                        Text(plan.period)
                            .font(.system(size: 17))
                            .foregroundColor(isSelected ? .white : .black)

                        if let monthlyEquivalent = plan.monthlyEquivalent(from: policyData) {
                            Text(monthlyEquivalent)
                                .font(.system(size: 14))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .black)
                        }

                        if let savings = plan.savings(from: policyData) {
                            Text(savings)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isSelected ? .white : .black)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 156)
                .background(isSelected ? AppTheme.primaryBlue : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? AppTheme.primaryBlue : Color.clear, lineWidth: 2)
                )

                // Floating recommended badge
                if plan.isRecommended {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Recommended")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 89, height: 24)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                .shadow(color: Color.black.opacity(0.1), radius: 7.5, x: 0, y: 5)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, -12)
                }

                // Floating checkmark indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.primaryBlue)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.white)
                .frame(width: 20, height: 20)
                .background(Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15))
                .lineSpacing(22 - 15)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

#Preview {
    SubscriptionView()
}
