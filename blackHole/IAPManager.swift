//
//  IAPManager.swift
//  blackHole
//
//  Manages in-app purchases for removing ads using StoreKit 2
//

import Foundation
import StoreKit

class IAPManager {
    static let shared = IAPManager()
    
    // Product ID for Remove Ads (non-consumable)
    private let removeAdsProductID = "com.yourcompany.blackhole.removeads"  // TODO: Replace with actual product ID
    
    // UserDefaults key for purchase status
    private let hasPurchasedRemoveAdsKey = "hasPurchasedRemoveAds"
    
    // StoreKit 2 product
    private var removeAdsProduct: Product?
    
    // Transaction listener task
    private var transactionListenerTask: Task<Void, Never>?
    
    private init() {
        // Start listening for transaction updates
        listenForTransactions()
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - Purchase Status
    
    /// Check if ads are removed (checks UserDefaults + Transaction.currentEntitlements)
    func checkPurchaseStatus() -> Bool {
        // First check UserDefaults (fast)
        if UserDefaults.standard.bool(forKey: hasPurchasedRemoveAdsKey) {
            return true
        }
        
        // Also check current entitlements (for restoration across devices)
        // This is async, so we'll update UserDefaults when we find it
        Task {
            await updatePurchaseStatusFromEntitlements()
        }
        
        return false
    }
    
    /// Update purchase status from Transaction.currentEntitlements
    @MainActor
    private func updatePurchaseStatusFromEntitlements() async {
        var hasEntitlement = false
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    hasEntitlement = true
                    break
                }
            }
        }
        
        if hasEntitlement {
            UserDefaults.standard.set(true, forKey: hasPurchasedRemoveAdsKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - Product Loading
    
    /// Fetch available products from App Store
    func loadProducts() async throws -> [Product] {
        do {
            let products = try await Product.products(for: [removeAdsProductID])
            
            // Find and store the remove ads product
            if let product = products.first(where: { $0.id == removeAdsProductID }) {
                self.removeAdsProduct = product
                print("✅ IAPManager: Loaded product: \(product.displayName) - \(product.displayPrice)")
            } else {
                print("⚠️ IAPManager: Product not found in App Store: \(removeAdsProductID)")
            }
            
            return products
        } catch {
            print("❌ IAPManager: Failed to load products: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Initiate purchase of Remove Ads
    func purchaseRemoveAds() async throws -> Bool {
        // Ensure product is loaded
        if removeAdsProduct == nil {
            _ = try await loadProducts()
        }
        
        guard let product = removeAdsProduct else {
            throw IAPError.productNotAvailable
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Transaction verified, complete purchase
                    await transaction.finish()
                    handlePurchaseSuccess()
                    print("✅ IAPManager: Purchase successful")
                    return true
                    
                case .unverified(_, let error):
                    print("❌ IAPManager: Transaction verification failed: \(error.localizedDescription)")
                    throw IAPError.verificationFailed
                }
                
            case .userCancelled:
                print("ℹ️ IAPManager: User cancelled purchase")
                throw IAPError.userCancelled
                
            case .pending:
                print("⚠️ IAPManager: Purchase pending (requires approval)")
                throw IAPError.pendingApproval
                
            @unknown default:
                print("❌ IAPManager: Unknown purchase result")
                throw IAPError.unknownError
            }
        } catch {
            print("❌ IAPManager: Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    func restorePurchases() async throws -> Bool {
        var foundPurchase = false
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == removeAdsProductID {
                    foundPurchase = true
                    handlePurchaseSuccess()
                    print("✅ IAPManager: Restored purchase: \(transaction.productID)")
                    break
                }
            }
        }
        
        if !foundPurchase {
            print("ℹ️ IAPManager: No previous purchases found to restore")
        }
        
        return foundPurchase
    }
    
    // MARK: - Purchase Handling
    
    /// Handle successful purchase
    private func handlePurchaseSuccess() {
        UserDefaults.standard.set(true, forKey: hasPurchasedRemoveAdsKey)
        UserDefaults.standard.synchronize()
        
        // Post notification so UI can update
        NotificationCenter.default.post(name: NSNotification.Name("RemoveAdsPurchased"), object: nil)
        
        print("✅ IAPManager: Purchase status saved to UserDefaults")
    }
    
    // MARK: - Transaction Listener
    
    /// Monitor Transaction.updates for purchase events
    private func listenForTransactions() {
        transactionListenerTask = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Check if this is our Remove Ads product
                    if transaction.productID == removeAdsProductID {
                        // Complete the transaction
                        await transaction.finish()
                        
                        // Handle purchase success
                        handlePurchaseSuccess()
                        
                        print("✅ IAPManager: Transaction update received and processed")
                    }
                }
            }
        }
    }
    
    // MARK: - Error Types
    
    enum IAPError: LocalizedError {
        case productNotAvailable
        case verificationFailed
        case userCancelled
        case pendingApproval
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .productNotAvailable:
                return "Product not available"
            case .verificationFailed:
                return "Transaction verification failed"
            case .userCancelled:
                return "Purchase cancelled"
            case .pendingApproval:
                return "Purchase pending approval"
            case .unknownError:
                return "Unknown error occurred"
            }
        }
    }
}

