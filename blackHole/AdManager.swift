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
    private var hasReceivedSDKReadyNotification = false
    
    // REPLACE WITH YOUR REAL AD UNIT ID BEFORE PRODUCTION
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"  // Test ID
    
        private override init() {
        super.init()
        
        // Listen for AdMob SDK initialization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAdMobSDKInitialized),
            name: NSNotification.Name("AdMobSDKInitialized"),
            object: nil
        )
    }
    
    @objc private func handleAdMobSDKInitialized() {
        print("📢 AdMob SDK initialization notification received")
        hasReceivedSDKReadyNotification = true
        loadInterstitial()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
        /// Load an interstitial ad
    func loadInterstitial() {
        guard !isLoading else {
            print("🔄 Ad already loading, skipping")
            return
        }
        
        // Don't load if we already have an ad ready
        if interstitialAd != nil {
            print("✅ Ad already loaded, skipping")
            return
        }
        
        isLoading = true
        print("🔄 Starting to load interstitial ad...")
        
        let request = Request()
        
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in                                                                        
            self?.isLoading = false
            
            if let error = error {
                print("❌ Failed to load interstitial ad: \(error.localizedDescription)")                                                                       
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            print("✅ Interstitial ad loaded successfully")
        }
    }
    
        /// Show the interstitial ad if available
    /// Returns true if ad was shown, false if ad wasn't ready
    func showInterstitial(from viewController: UIViewController, completion: @escaping () -> Void) -> Bool {
        guard let interstitialAd = interstitialAd else {
            print("⚠️ Ad wasn't ready, skipping ad display")
            // Don't call completion - let the caller handle showing UI immediately
            return false
        }
        
        print("📺 Showing interstitial ad")
        interstitialAd.present(from: viewController)
        
        // Store completion for when ad dismisses
        self.adDismissalCompletion = completion
        return true
    }
    
    /// Check if ad is ready to show
    func isAdReady() -> Bool {
        return interstitialAd != nil
    }
    
    // Store completion handler
    private var adDismissalCompletion: (() -> Void)?
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    
    /// Called when the ad is dismissed
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ Ad dismissed")
        
        // Clear the ad and load a new one for next time
        interstitialAd = nil
        loadInterstitial()
        
        // Execute completion (restart game)
        adDismissalCompletion?()
        adDismissalCompletion = nil
    }
    
    /// Called when ad fails to present
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Ad failed to present: \(error.localizedDescription)")
        
        // Clear failed ad and load new one
        interstitialAd = nil
        loadInterstitial()
        
        // Execute completion anyway (restart game)
        adDismissalCompletion?()
        adDismissalCompletion = nil
    }
}


