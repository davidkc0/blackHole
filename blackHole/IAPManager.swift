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
    private let removeAdsProductID = "dkc.blackHole2025.removeads2"
    
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
    @MainActor
    func loadProducts() async throws -> [Product] {
        print("🛒 IAPManager.loadProducts() called for product ID: \(removeAdsProductID)")
        do {
            let products = try await Product.products(for: [removeAdsProductID])
            print("🛒 IAPManager: Product.products() returned \(products.count) products")
            
            // Find and store the remove ads product
            if let product = products.first(where: { $0.id == removeAdsProductID }) {
                self.removeAdsProduct = product
                print("✅ IAPManager: Loaded product: \(product.displayName) - \(product.displayPrice)")
                print("✅ IAPManager: Product ID matches: \(product.id == removeAdsProductID)")
            } else {
                print("⚠️ IAPManager: Product not found in App Store: \(removeAdsProductID)")
                print("⚠️ IAPManager: Available product IDs: \(products.map { $0.id })")
            }
            
            return products
        } catch {
            print("❌ IAPManager: Failed to load products: \(error)")
            print("❌ IAPManager: Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ IAPManager: NSError domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ IAPManager: NSError userInfo: \(nsError.userInfo)")
            }
            throw error
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Initiate purchase of Remove Ads
    @MainActor
    func purchaseRemoveAds() async throws -> Bool {
        print("🛒 IAPManager.purchaseRemoveAds() called on main thread")
        // Ensure product is loaded
        if removeAdsProduct == nil {
            print("🛒 Product not loaded, loading now...")
            _ = try await loadProducts()
        }
        
        guard let product = removeAdsProduct else {
            print("❌ IAPManager: Product still nil after loading attempt")
            throw IAPError.productNotAvailable
        }
        
        print("🛒 IAPManager: Product available: \(product.id)")
        print("🛒 IAPManager: Product displayName: \(product.displayName)")
        print("🛒 IAPManager: Product price: \(product.displayPrice)")
        print("🛒 IAPManager: Calling product.purchase() on main thread...")
        print("🛒 IAPManager: Current thread is main: \(Thread.isMainThread)")
        
        do {
            // StoreKit 2 purchase() automatically presents the purchase UI
            // It must be called from main thread (we're @MainActor so this is guaranteed)
            let result = try await product.purchase()
            print("🛒 IAPManager: Purchase result received: \(result)")
            
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
            print("❌ IAPManager: Purchase failed with error")
            print("❌ IAPManager: Error type: \(type(of: error))")
            print("❌ IAPManager: Error description: \(error.localizedDescription)")
            if let storeKitError = error as? StoreKitError {
                print("❌ IAPManager: StoreKitError: \(storeKitError)")
            }
            if let nsError = error as NSError? {
                print("❌ IAPManager: NSError domain: \(nsError.domain)")
                print("❌ IAPManager: NSError code: \(nsError.code)")
                print("❌ IAPManager: NSError userInfo: \(nsError.userInfo)")
            }
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

