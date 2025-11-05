//
//  GameLoadingScene.swift
//  blackHole
//
//  Loading scene that appears when user taps Play, handles game-specific initialization
//

import SpriteKit

class GameLoadingScene: SKScene {
    
    private var loadingLabel: SKLabelNode?
    private var isTransitioning = false
    
    override func didMove(to view: SKView) {
        // CENTER THE COORDINATE SYSTEM
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        backgroundColor = .black
        
        // 1. Create and store the loading label IMMEDIATELY (no delay)
        let label = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        label.text = "LOADING" // Set initial text (will be animated)
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 0) // Anchor point is (0.5, 0.5)
        addChild(label)
        self.loadingLabel = label
        
        // Start the "..." animation immediately
        animateLoadingText()
        
        // Wait 0.01s AFTER loading screen appears before starting heavy work
        // This ensures the loading screen is fully rendered first
        run(SKAction.wait(forDuration: 0.01)) { [weak self] in
            self?.loadGameAssets()
        }
    }
    
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
    
    /// Loads game assets sequentially: haptics first, then textures
    private func loadGameAssets() {
        guard !isTransitioning else { return }
        isTransitioning = true
        
        print("🎮 GameLoadingScene: Starting game asset loading...")
        
        // Step 1: Initialize HapticManager (main thread - UI framework requirement)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🎮 Initializing haptic feedback generators...")
            _ = HapticManager.shared
            print("✅ Haptics initialized")
            
            // Update UI to show we're loading textures
            self.loadingLabel?.text = "LOADING TEXTURES..."
            
            // Step 2: Load game textures on background thread (29s operation)
            DispatchQueue.global(qos: .userInitiated).async {
                print("🎮 Preloading game textures (29s operation)...")
                TextureCache.shared.preloadAllTextures()
                print("✅ Game textures preloaded")
                
                // Step 3: Return to main thread for transition
                DispatchQueue.main.async {
                    // Stop animation and set ready text
                    self.loadingLabel?.removeAllActions()
                    self.loadingLabel?.text = "READY"
                    
                    // Brief delay before transition
                    self.run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                        guard let self = self else { return }
                        self.transitionToGame()
                    }
                }
            }
        }
    }
    
    /// Transitions to GameScene
    private func transitionToGame() {
        print("🎮 GameLoadingScene: Transitioning to GameScene...")
        
        let gameScene = GameScene(size: self.size)
        gameScene.scaleMode = self.scaleMode
        
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
        
        print("✅ GameLoadingScene: Transitioned to GameScene")
    }
}

