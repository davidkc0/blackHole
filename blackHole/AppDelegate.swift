//
//  AppDelegate.swift
//  blackHole
//
//  Created by David Ciaffoni on 10/9/25.
//

import UIKit
import GoogleMobileAds

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {                                                                                           
        print("🚀 App launching - staged initialization...")
        
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
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
}
