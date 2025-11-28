//
//  AdManager.swift
//  blackHole
//
//  Manages AdMob interstitial ads for game over
//

import Foundation
import GoogleMobileAds
import UIKit

class AdManager: NSObject {
    static let shared = AdManager()
    
    private var interstitialAd: InterstitialAd?
    private var isLoading = false
    private var sdkInitialized = false
    private var loadTimeoutFired = false  // Track if timeout occurred
    
    // Production ad unit ID
    private let adUnitID = "ca-app-pub-6046236506206156/7271704137"
    
    private override init() {
        super.init()
        
        print("📱 AdManager initialized")
        
        // Listen for SDK initialization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAdMobSDKInitialized),
            name: NSNotification.Name("AdMobSDKInitialized"),
            object: nil
        )
    }
    
    @objc private func handleAdMobSDKInitialized() {
        print("✅ AdMob SDK ready")
        sdkInitialized = true
        // DON'T load ad here - wait until game over
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Load an interstitial ad
    /// Called AFTER game over, not during gameplay
    private func loadInterstitial(completion: @escaping (Bool) -> Void) {
        // Check if ads are removed
        if IAPManager.shared.checkPurchaseStatus() {
            print("ℹ️ Ads removed - skipping ad load")
            completion(false)
            return
        }
        
        guard sdkInitialized else {
            print("⚠️ SDK not initialized")
            completion(false)
            return
        }
        
        guard !isLoading else {
            print("ℹ️ Already loading")
            completion(false)
            return
        }
        
        if interstitialAd != nil {
            print("✅ Ad already loaded")
            completion(true)
            return
        }
        
        isLoading = true
        loadTimeoutFired = false
        print("📱 Loading ad NOW (game over)...")
        
        // Prepare request on current thread (can be background)
        let request = Request()
        
        // Configure for non-personalized ads
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        
        // Timeout after 3 seconds (game over screen visible, user can wait a bit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if self.isLoading && !self.loadTimeoutFired {
                self.loadTimeoutFired = true
                print("⏱️ Ad load timeout")
                self.isLoading = false
                completion(false)
            }
        }
        
        // AdMob requires InterstitialAd.load() to be called on main thread
        // But we dispatch it asynchronously so it doesn't block current main thread work
        // This allows WebKit initialization to happen without blocking the UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            InterstitialAd.load(with: self.adUnitID, request: request) { [weak self] ad, error in
                guard let self = self else { return }
                
                // Prevent completion if timeout already fired
                if self.loadTimeoutFired {
                    return
                }
                
                self.isLoading = false
                
                if let error = error {
                    print("⚠️ Ad failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let ad = ad else {
                    print("⚠️ Ad returned nil")
                    completion(false)
                    return
                }
                
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                print("✅ Ad loaded")
                completion(true)
            }
        }
    }
    
    /// Show ad with loading
    /// Call this at game over
    /// - Shows loading for up to 3 seconds
    /// - If ad loads: shows ad
    /// - If ad doesn't load: calls completion immediately
    func showInterstitialWithLoading(
        from viewController: UIViewController,
        onAdDismissed: @escaping () -> Void,
        onNoAd: @escaping () -> Void
    ) {
        // Check if ads are removed
        if IAPManager.shared.checkPurchaseStatus() {
            print("ℹ️ Ads removed - skipping ad display")
            onNoAd()
            return
        }
        
        print("🎬 Game over - loading ad...")
        
        // If ad already loaded, show it immediately
        // Ensure we're on main thread for UI operations
        if let ad = interstitialAd {
            print("✅ Ad ready, showing now")
            self.adDismissalCompletion = onAdDismissed
            // Ensure presentation happens on main thread
            if Thread.isMainThread {
                ad.present(from: viewController)
            } else {
                DispatchQueue.main.async {
                    ad.present(from: viewController)
                }
            }
            return
        }
        
        // Load ad (with 3 second timeout)
        // Completion may be called from background thread, so dispatch UI updates to main
        loadInterstitial { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success, let ad = self.interstitialAd {
                    print("✅ Ad loaded, showing now")
                    self.adDismissalCompletion = onAdDismissed
                    ad.present(from: viewController)  // Must be on main thread
                } else {
                    print("ℹ️ No ad available")
                    onNoAd()  // UI callback, ensure on main thread
                }
            }
        }
    }
    
    /// Check if ad is ready
    func isAdReady() -> Bool {
        return interstitialAd != nil
    }
    
    /// Called by the Loading Screen *after* the SDK is confirmed ready.
    /// This is the new "first load" trigger.
    func preloadFirstAd(completion: @escaping (Bool) -> Void) {
        // Check if ads are removed
        if IAPManager.shared.checkPurchaseStatus() {
            print("ℹ️ Ads removed - skipping ad preload")
            completion(false) // Fire completion immediately
            return
        }
        
        guard sdkInitialized else {
            print("⚠️ AdManager: preloadFirstAd called but SDK not ready.")
            completion(false) // Fire completion immediately
            return
        }
        
        guard interstitialAd == nil, !isLoading else {
            print("ℹ️ AdManager: preloadFirstAd called but ad is already loaded or loading.")
            completion(false) // Fire completion immediately
            return
        }
        
        print("📱 AdManager: Pre-loading first ad (triggered by LoadingScene)...")
        
        // Pass the completion handler from LoadingScene
        // straight to the internal loadInterstitial function.
        loadInterstitial { success in
            if success {
                print("✅ First ad pre-loaded and ready.")
            } else {
                print("⚠️ Pre-load of first ad failed.")
            }
            // This is the crucial link:
            // We call the completion handler to tell LoadingScene it's done.
            completion(success)
        }
    }
    
    // Store completion handler
    private var adDismissalCompletion: (() -> Void)?
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ Ad dismissed")
        
        // Clear ad
        interstitialAd = nil
        
        // Execute completion
        adDismissalCompletion?()
        adDismissalCompletion = nil
        
        // PRE-LOAD THE NEXT AD!
        print("📱 Ad dismissed. Pre-loading next ad...")
        loadInterstitial { success in
            print(success ? "✅ Next ad pre-loaded." : "⚠️ Next ad pre-load failed.")
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("⚠️ Ad failed to present: \(error.localizedDescription)")
        
        // Clear failed ad
        interstitialAd = nil
        
        // Execute completion anyway
        adDismissalCompletion?()
        adDismissalCompletion = nil
    }
}
