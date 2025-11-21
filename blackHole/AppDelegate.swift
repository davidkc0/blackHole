//
//  AppDelegate.swift
//  blackHole
//
//  Created by David Ciaffoni on 10/9/25.
//

import UIKit
import GoogleMobileAds
import AVFoundation
import GameKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {                                                                                           
        print("🚀 App launching - staged initialization...")
        
        // Initialize Game Center
        GameCenterManager.shared.authenticatePlayer()

        // Configure audio session
        configureAudioSession()
        
        // Preload core audio assets early so later scenes don't need to spin up
        // the audio graph for the first time (which can cause pops/clips).
        AudioManager.shared.preloadMenuMusic()
        AudioManager.shared.preloadSoundEffects()
        
        // Initialize IAPManager and restore purchases (async, non-blocking)
        Task {
            do {
                _ = try await IAPManager.shared.restorePurchases()
            } catch {
                print("⚠️ Failed to restore purchases: \(error.localizedDescription)")
            }
        }
        
        // Check if ads are removed before initializing AdMob
        if IAPManager.shared.checkPurchaseStatus() {
            print("✅ Ads removed - skipping AdMob SDK initialization")
            // Post notification immediately so LoadingScene doesn't wait
            NotificationCenter.default.post(name: NSNotification.Name("AdMobSDKInitialized"), object: nil)
        } else {
            // 1) Initialize AdMob SDK early (Google's recommendation) but on background thread
            // This lets WebKit processes launch early and settle before menu is used
            DispatchQueue.global(qos: .utility).async {
                print("📱 Initializing AdMob SDK on background thread (early, non-blocking)...")
                MobileAds.shared.start(completionHandler: { initializationStatus in
                    print("✅ AdMob SDK initialized")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("AdMobSDKInitialized"), object: nil)
                    }
                })
            }
            
            // Timeout after 10 seconds (in case SDK initialization hangs)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AdMobSDKInitialized"),
                    object: nil
                )
            }
        }
        
        // 2) ✅ Only preload menu visuals up front
        DispatchQueue.global(qos: .userInitiated).async {
            print("🎨 Preloading menu textures...")
            RetroAestheticManager.shared.preloadMenuTextures()
            DispatchQueue.main.async {
                // Optional: tell the menu minimal textures are warmed
                NotificationCenter.default.post(name: NSNotification.Name("MenuBootstrapReady"), object: nil)
            }
        }
        
        // 3) ✅ Game textures will be loaded in GameLoadingScene when user taps Play
        // This reduces initial loading time from ~45s to ~15-20s
        
        return true
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use .ambient category so music mixes with other audio and respects silent switch
            try audioSession.setCategory(.ambient, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✅ AppDelegate: Audio session configured (.ambient category)")
        } catch {
            print("⚠️ AppDelegate: Failed to configure audio session: \(error)")
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Reactivate audio session after interruptions (ads, Game Center overlay, etc.)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session reactivated after app became active")
        } catch {
            print("⚠️ Failed to reactivate audio session: \(error)")
        }
    }
}
