//
//  StoreKitManager.swift
//  pictospeak-ios
//
//  Created by AI Assistant
//

import Foundation
import StoreKit

/// Manager class for handling Apple in-app purchases
@MainActor
class StoreKitManager: ObservableObject {
    
    // MARK: - Product Identifiers
    
    // TODO: Replace these with your actual product IDs from App Store Connect
    static let monthlySubscriptionID = "com.pictospeak.monthly"
    static let yearlySubscriptionID = "com.pictospeak.yearly"
    
    // MARK: - Published Properties
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Singleton
    
    static let shared = StoreKitManager()
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Load products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = [
                StoreKitManager.monthlySubscriptionID,
                StoreKitManager.yearlySubscriptionID
            ]
            
            products = try await Product.products(for: productIDs)
            print("✅ Loaded \(products.count) products from App Store")
            
            for product in products {
                print("📦 Product: \(product.displayName) - \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Purchase a subscription product
    /// - Parameters:
    ///   - product: The product to purchase
    ///   - authToken: Optional authentication token for backend sync
    /// - Returns: Transaction if successful
    func purchase(_ product: Product, authToken: String?) async throws -> Transaction? {
        print("🛒 Starting purchase for: \(product.displayName)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)
            
            // Update purchased products
            await updatePurchasedProducts()
            
            // Finish the transaction
            await transaction.finish()
            
            print("✅ Purchase successful: \(product.displayName)")
            
            // Sync with backend if authToken is available
            if let authToken = authToken {
                // Pass the verification result to get the JWS representation
                await syncPurchaseWithBackend(authToken: authToken, transaction: transaction, verification: verification)
            } else {
                print("⚠️ No auth token available, skipping backend sync")
            }
            
            return transaction
            
        case .userCancelled:
            print("⚠️ User cancelled purchase")
            return nil
            
        case .pending:
            print("⏳ Purchase is pending")
            return nil
            
        @unknown default:
            print("❌ Unknown purchase result")
            return nil
        }
    }
    
    /// Restore previous purchases
    /// - Parameter authToken: Optional authentication token for backend sync
    func restorePurchases(authToken: String?) async throws {
        print("🔄 Restoring purchases...")
        
        try await AppStore.sync()
        await updatePurchasedProducts()
        
        print("✅ Purchases restored")
        
        // Sync with backend if authToken is available
        if let authToken = authToken {
            // Sync all current entitlements with backend
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    if transaction.revocationDate == nil {
                        // Pass the verification result to get JWS representation
                        await syncPurchaseWithBackend(authToken: authToken, transaction: transaction, verification: result)
                    }
                } catch {
                    print("❌ Failed to sync restored purchase: \(error)")
                }
            }
        } else {
            print("⚠️ No auth token available, skipping backend sync")
        }
    }
    
    /// Check if user has an active subscription
    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    /// Get product by ID
    func product(for identifier: String) -> Product? {
        products.first { $0.id == identifier }
    }
    
    /// Get monthly product
    var monthlyProduct: Product? {
        product(for: StoreKitManager.monthlySubscriptionID)
    }
    
    /// Get yearly product
    var yearlyProduct: Product? {
        product(for: StoreKitManager.yearlySubscriptionID)
    }
    
    // MARK: - Private Methods
    
    /// Listen for transaction updates
    /// Note: This listener handles transactions from other devices, renewals, etc.
    /// Backend sync should be handled by the UI layer which has access to authToken
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Update purchased products
                    await self.updatePurchasedProducts()
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                    print("✅ Transaction processed: \(transaction.productID)")
                    print("ℹ️  Note: Backend sync should be triggered from UI layer with authToken")
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /// Update the set of purchased products
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if subscription is still active
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }
        
        purchasedProductIDs = purchased
        print("📊 Updated purchased products: \(purchased)")
    }
    
    /// Verify a transaction
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Sync purchase with backend server
    private func syncPurchaseWithBackend(authToken: String, transaction: Transaction, verification: VerificationResult<Transaction>) async {
        do {
            // Extract the JWS representation from the verification result
            // This is the Apple-signed JWS token that can be verified on the backend
            let jwsRepresentation = verification.jwsRepresentation
            
            print("📤 Sending JWS transaction to backend for verification")
            print("   Transaction ID: \(transaction.id)")
            print("   Product ID: \(transaction.productID)")
            print("   Environment: \(transaction.environment)")
            print("   JWS length: \(jwsRepresentation.count) characters")
            
            // Send the JWS to backend for verification
            // The backend can verify this with Apple's public keys
            try await SubscriptionService.shared.verifyPurchase(
                authToken: authToken,
                transactionId: String(transaction.id),
                productId: transaction.productID,
                receiptData: jwsRepresentation
            )
            
            print("✅ Purchase synced with backend")
        } catch {
            print("❌ Failed to sync purchase with backend: \(error)")
            // Note: The purchase is still valid locally, but we should retry later
        }
    }
}

// MARK: - StoreKit Error Extensions

extension StoreKitError {
    var localizedDescription: String {
        switch self {
        case .unknown:
            return "An unknown error occurred"
        case .userCancelled:
            return "Purchase was cancelled"
        case .networkError:
            return "Network error occurred"
        case .notAvailableInStorefront:
            return "This product is not available in your region"
        case .notEntitled:
            return "You are not entitled to this product"
        @unknown default:
            return "An error occurred"
        }
    }
}
