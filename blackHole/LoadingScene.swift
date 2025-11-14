//
//  LoadingScene.swift
//  blackHole
//
//  Loading scene that coordinates AdMob SDK and menu texture preloading
//

import SpriteKit

class LoadingScene: SKScene {
    
    // --- New Property ---
    private var loadingLabel: SKLabelNode?
    private weak var dotsOverlay: LoadingDotsView?
    // --------------------
    
    private var isAdMobReady = false
    private var isMenuTexturesReady = false
    private var isMenuMusicReady = false
    private var isTransitioning = false
    
    override func didMove(to view: SKView) {
        // CENTER THE COORDINATE SYSTEM
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        backgroundColor = .black
        
        // 1. Create and store the loading label (kept for status text updates)
        let label = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        label.text = "LOADING" // Set initial text (will be animated)
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 0) // Anchor point is (0.5, 0.5)
        label.alpha = 0 // Hide actual SKLabel; UIKit overlay handles visuals
        addChild(label)
        self.loadingLabel = label
        attachDotsOverlay(text: "LOADING", animated: true)
        
        // Check if ads are removed
        if IAPManager.shared.checkPurchaseStatus() {
            print("✅ LoadingScene: Ads removed - skipping AdMob initialization")
            // Mark AdMob as ready immediately (we don't need it)
            isAdMobReady = true
        } else {
            // 2. Add observer for AdMob SDK initialization
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAdMobReady),
                name: NSNotification.Name("AdMobSDKInitialized"), // From AppDelegate
                object: nil
            )
            
            // 3. IMPORTANT: Make sure AdManager is initialized NOW
            //    so it can *catch* the "AdMobSDKInitialized" notification.
            _ = AdManager.shared
        }
        
        // Add observer for menu textures
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuTexturesReady),
            name: NSNotification.Name("MenuBootstrapReady"), // From AppDelegate
            object: nil
        )
        
        // Add observer for menu music
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuMusicReady),
            name: NSNotification.Name("MenuMusicReady"),
            object: nil
        )
    }
    
    // --- New Function ---
    /// Animates the loading label text in a 5-state, 5-second loop.
    private func animateLoadingText() {
        guard let label = loadingLabel else { return }
        
        // Each state will last 1.0 second (5 states / 5 seconds)
        let waitAction = SKAction.wait(forDuration: 1.0)
        
        // Define each state of the animation
        // Capture the label reference to avoid optional chaining issues
        let setText1 = SKAction.run { label.text = "LOADING" }
        let setText2 = SKAction.run { label.text = "LOADING." }
        let setText3 = SKAction.run { label.text = "LOADING.." }
        let setText4 = SKAction.run { label.text = "LOADING..." }
        let setText5 = SKAction.run { label.text = "LOADING." }
        
        // Create the sequence.
        // We start on "LOADING", so first wait, then change to "LOADING."
        let sequence = SKAction.sequence([
            waitAction, setText2, // Wait, then State 2
            waitAction, setText3, // Wait, then State 3
            waitAction, setText4, // Wait, then State 4
            waitAction, setText5, // Wait, then State 5
            waitAction, setText1  // Wait, then back to State 1
        ])
        
        // Run the sequence forever
        label.run(SKAction.repeatForever(sequence))
    }
    // --------------------
    
    @objc private func handleAdMobReady() {
        print("✅ LoadingScene: CHECKLIST Item 1 (AdMob SDK) is READY.")
        isAdMobReady = true
        checkIfReadyToProceed()
    }
    
    @objc private func handleMenuTexturesReady() {
        print("✅ LoadingScene: CHECKLIST Item 2 (Menu Textures) are READY.")
        isMenuTexturesReady = true
        checkIfReadyToProceed()
    }
    
    @objc private func handleMenuMusicReady() {
        print("✅ LoadingScene: CHECKLIST Item 3 (Menu Music) is READY.")
        isMenuMusicReady = true
        checkIfReadyToProceed()
    }
    
    private func checkIfReadyToProceed() {
        // If AdMob and textures are ready, start menu music loading if not already started
        if isAdMobReady && isMenuTexturesReady && !isMenuMusicReady {
            // Start menu music preloading (only once)
            print("🎵 LoadingScene: Preloading menu music...")
            DispatchQueue.global(qos: .userInitiated).async {
                AudioManager.shared.preloadMenuMusic()
                
                // Initialize audio engine on main thread (fast)
                DispatchQueue.main.async {
                    AudioManager.shared.initializeAudioEngine()
                    NotificationCenter.default.post(name: NSNotification.Name("MenuMusicReady"), object: nil)
                }
            }
            return // Wait for menu music ready notification
        }
        
        // 4. Check if all items are checked off AND we're not already transitioning
        guard isAdMobReady, isMenuTexturesReady, isMenuMusicReady, !isTransitioning else {
            return
        }
        
        // We are GO! Mark as transitioning so this only fires once.
        isTransitioning = true
        NotificationCenter.default.removeObserver(self) // Clean up observers
        
        // Check if ads are removed
        if IAPManager.shared.checkPurchaseStatus() {
            print("✅ LoadingScene: Ads removed - skipping ad preload, loading menu directly")
            // Skip ad preloading entirely, go straight to menu scene creation
            proceedToMenuScene()
        } else {
            print("🚀 LoadingScene: SDK, Textures, and Music ready. Now pre-loading ad (8s block)...")
            
            // 5. STEP 1: Load the ad FIRST. All the heavy lifting must wait for this.
            AdManager.shared.preloadFirstAd { [weak self] success in
                
                guard let self = self else { return }
                
                // --- ADMOB AD LOAD & INITIAL FREEZE IS OVER ---
                
                // Update UI before starting the next heavy task
                DispatchQueue.main.async {
                    self.loadingLabel?.text = "LOADING MENU ASSETS..."
                    self.dotsOverlay?.setText("LOADING MENU ASSETS...", animated: false)
                }
                
                // 6. STEP 2: Now that ad load is done, run the HEAVY texture load 
                //    on a background thread.
                DispatchQueue.global(qos: .userInitiated).async {
                    
                    // This is the 29-second operation:
                    let menuScene = MenuScene(size: self.size) 
                    menuScene.scaleMode = self.scaleMode
                    
                    // --- ALL BACKGROUND WORK IS DONE (Texture Load Complete) ---
                    
                    // Return to main thread for final transition
                    DispatchQueue.main.async {
                        
                        // Stop the loading text animation and set final feedback
                        self.loadingLabel?.removeAllActions()
                        self.loadingLabel?.text = "READY"
                        self.dotsOverlay?.setText("READY", animated: false)

                        // 7. STEP 3: Use a short buffer to absorb final SpriteKit/WebKit presentation overhead
                        let finalDelay: TimeInterval = 1.0 
                        self.run(SKAction.wait(forDuration: finalDelay)) {
                            
                            if success {
                                print("✅ LoadingScene: Ad pre-loaded. Transitioning to menu.")
                            } else {
                                print("⚠️ LoadingScene: Ad pre-load failed. Transitioning to menu anyway.")
                            }
                            
                            self.removeDotsOverlay()
                            let transition = SKTransition.fade(withDuration: 0.5)
                            self.view?.presentScene(menuScene, transition: transition)
                            
                            print("✅ LoadingScene: Transitioning to MenuScene. All heavy loading complete.")
                        }
                    }
                }
            }
        }
    }
    
    /// Proceed to menu scene creation (used when ads are removed)
    private func proceedToMenuScene() {
        // Update UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loadingLabel?.text = "LOADING MENU ASSETS..."
            self.dotsOverlay?.setText("LOADING MENU ASSETS...", animated: false)
        }
        
        // Load menu scene on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let menuScene = MenuScene(size: self.size) 
            menuScene.scaleMode = self.scaleMode
            
            // Return to main thread for transition
            DispatchQueue.main.async {
                self.loadingLabel?.removeAllActions()
                self.loadingLabel?.text = "READY"
                self.dotsOverlay?.setText("READY", animated: false)
                
                // Brief delay before transition
                self.run(SKAction.wait(forDuration: 0.5)) {
                    self.removeDotsOverlay()
                    let transition = SKTransition.fade(withDuration: 0.5)
                    self.view?.presentScene(menuScene, transition: transition)
                    
                    print("✅ LoadingScene: Transitioning to MenuScene (ads removed - faster load).")
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        dotsOverlay?.removeFromSuperviewAnimated()
    }

    private func attachDotsOverlay(text: String, animated: Bool) {
        guard let skView = view, dotsOverlay == nil else { return }
        let overlay = LoadingDotsView()
        skView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: skView.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: skView.centerYAnchor)
        ])
        overlay.setText(text, animated: animated)
        dotsOverlay = overlay
    }
    
    private func removeDotsOverlay() {
        dotsOverlay?.removeFromSuperviewAnimated()
        dotsOverlay = nil
    }
}

