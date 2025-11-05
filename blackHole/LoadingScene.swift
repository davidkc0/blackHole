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
    // --------------------
    
    private var isAdMobReady = false
    private var isMenuTexturesReady = false
    private var isTransitioning = false
    
    override func didMove(to view: SKView) {
        // CENTER THE COORDINATE SYSTEM
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        backgroundColor = .black
        
        // 1. Create and store the loading label
        let label = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        label.text = "LOADING" // Set initial text (will be animated)
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 0) // Anchor point is (0.5, 0.5)
        addChild(label)
        self.loadingLabel = label
        
        // --- New Function Call ---
        // Start the "..." animation after a tiny delay to ensure label is ready
        run(SKAction.wait(forDuration: 0.1)) { [weak self] in
            self?.animateLoadingText()
        }
        // -------------------------
        
        // 2. Add observers for our "checklist"
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAdMobReady),
            name: NSNotification.Name("AdMobSDKInitialized"), // From AppDelegate
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuTexturesReady),
            name: NSNotification.Name("MenuBootstrapReady"), // From AppDelegate
            object: nil
        )
        
        // 3. IMPORTANT: Make sure AdManager is initialized NOW
        //    so it can *catch* the "AdMobSDKInitialized" notification.
        _ = AdManager.shared
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
    
    private func checkIfReadyToProceed() {
        // 4. Check if both items are checked off AND we're not already loading
        guard isAdMobReady, isMenuTexturesReady, !isTransitioning else {
            return
        }
        
        // We are GO! Mark as transitioning so this only fires once.
        isTransitioning = true
        NotificationCenter.default.removeObserver(self) // Clean up observers
        
        print("🚀 LoadingScene: SDK and Textures ready. Now pre-loading ad (8s block)...")
        
        // 5. STEP 1: Load the ad FIRST. All the heavy lifting must wait for this.
        AdManager.shared.preloadFirstAd { [weak self] success in
            
            guard let self = self else { return }
            
            // --- ADMOB AD LOAD & INITIAL FREEZE IS OVER ---
            
            // Update UI before starting the next heavy task
            DispatchQueue.main.async {
                self.loadingLabel?.text = "LOADING MENU ASSETS..." 
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

                    // 7. STEP 3: Use a short buffer to absorb final SpriteKit/WebKit presentation overhead
                    let finalDelay: TimeInterval = 1.0 
                    self.run(SKAction.wait(forDuration: finalDelay)) {
                        
                        if success {
                            print("✅ LoadingScene: Ad pre-loaded. Transitioning to menu.")
                        } else {
                            print("⚠️ LoadingScene: Ad pre-load failed. Transitioning to menu anyway.")
                        }
                        
                        let transition = SKTransition.fade(withDuration: 0.5)
                        self.view?.presentScene(menuScene, transition: transition)
                        
                        print("✅ LoadingScene: Transitioning to MenuScene. All heavy loading complete.")
                    }
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

