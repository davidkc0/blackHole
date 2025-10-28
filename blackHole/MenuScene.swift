//
//  MenuScene.swift
//  blackHole
//
//  Main menu scene with static game background
//

import SpriteKit
import GameplayKit
import CoreImage

class MenuScene: SKScene {
    
    // MARK: - Properties
    
    // Background elements (reused from game)
    private var backgroundLayers: [[SKSpriteNode]] = [[], [], []]
    private var decorativeStars: [Star] = []
    private var nebulaNode: SKSpriteNode?
    
    // UI Elements
    private var playButton: MenuButton!
    private var timedModeButton: MenuButton!
    private var settingsIconButton: IconButton!
    private var discordIconButton: IconButton!
    
    // Animation state
    private var isTransitioning = false
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        // CENTER THE COORDINATE SYSTEM - THIS IS CRITICAL!
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        setupBackground()
        setupStaticStars()
        setupMenuUI()
        addRetroEffects()
        startAmbientAnimations()
        
        // Play menu music
        AudioManager.shared.playBackgroundMusic()
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        print("🖐 Touch began at: \(location)")
        
        // Check each button
        if playButton.contains(point: location) {
            playButton.animatePress()
            print("✅ PLAY button pressed")
        } else if timedModeButton.contains(point: location) {
            timedModeButton.animatePress()
            print("✅ TIMED MODE button pressed")
        } else if settingsIconButton.contains(point: location) {
            settingsIconButton.animatePress()
            print("✅ SETTINGS button pressed")
        } else if discordIconButton.contains(point: location) {
            discordIconButton.animatePress()
            print("✅ DISCORD button pressed")
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        print("🖐 Touch ended at: \(location)")
        
        // Check which button was tapped
        if playButton.contains(point: location) {
            playButton.animateRelease()
            print("🎮 PLAY button tapped - calling onTap!")
            playButton.onTap?()
        } else if timedModeButton.contains(point: location) {
            timedModeButton.animateRelease()
            print("⏱ TIMED MODE button tapped")
            timedModeButton.onTap?()
        } else if settingsIconButton.contains(point: location) {
            settingsIconButton.animateRelease()
            print("⚙️ SETTINGS button tapped")
            settingsIconButton.onTap?()
        } else if discordIconButton.contains(point: location) {
            discordIconButton.animateRelease()
            print("💬 DISCORD button tapped")
            discordIconButton.onTap?()
        }
    }
    
    // MARK: - Background Setup (Reuse from GameScene)
    
    private func setupBackground() {
        backgroundColor = UIColor(white: 0.02, alpha: 1.0)  // Match game
        
        // Add nebula (copy from GameScene)
        setupNebula()
        
        // Add parallax star layers (but static)
        createStaticStarfield()
    }
    
    private func setupNebula() {
        let nebulaTexture = createNebulaTexture()
        nebulaNode = SKSpriteNode(texture: nebulaTexture)
        nebulaNode?.size = CGSize(width: 3000, height: 3000)
        nebulaNode?.position = CGPoint.zero
        nebulaNode?.zPosition = -50
        nebulaNode?.alpha = 0.35
        nebulaNode?.blendMode = .alpha
        nebulaNode?.isUserInteractionEnabled = false  // Don't block touches
        addChild(nebulaNode!)
        
        // Slow rotation for subtle movement
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 300)
        nebulaNode?.run(SKAction.repeatForever(rotate))
    }
    
    private func createNebulaTexture() -> SKTexture {
        // Copy exact method from GameScene
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 0.1, green: 0.04, blue: 0.18, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.05, blue: 0.15, alpha: 0.8).cgColor,
                UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.4).cgColor,
                UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 0.0).cgColor
            ] as CFArray
            
            let locations: [CGFloat] = [0.0, 0.3, 0.6, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                return
            }
            
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            
            cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        
        return SKTexture(image: image)
    }
    
    private func createStaticStarfield() {
        // Layer 0: Distant stars
        createStarLayer(
            count: 200,
            sizeRange: 0.8...1.5,
            alphaRange: 0.3...0.5,
            zPosition: -30,
            twinkle: true
        )
        
        // Layer 1: Mid-distance stars
        createStarLayer(
            count: 100,
            sizeRange: 1.5...2.5,
            alphaRange: 0.5...0.7,
            zPosition: -20,
            twinkle: true
        )
        
        // Layer 2: Near stars
        createStarLayer(
            count: 50,
            sizeRange: 2.5...3.0,
            alphaRange: 0.7...0.9,
            zPosition: -10,
            twinkle: false
        )
    }
    
    private func createStarLayer(count: Int, sizeRange: ClosedRange<CGFloat>,
                                 alphaRange: ClosedRange<CGFloat>, zPosition: CGFloat,
                                 twinkle: Bool) {
        let screenSize = UIScreen.main.bounds.size
        let spread = max(screenSize.width, screenSize.height) * 0.6  // Scale to screen size
        
        for _ in 0..<count {
            let starSize = CGFloat.random(in: sizeRange)
            let star = SKSpriteNode(color: .white, size: CGSize(width: starSize, height: starSize))
            
            star.position = CGPoint(
                x: CGFloat.random(in: -spread...spread),
                y: CGFloat.random(in: -spread...spread)
            )
            
            star.alpha = CGFloat.random(in: alphaRange)
            star.zPosition = zPosition
            star.isUserInteractionEnabled = false  // Don't block touches
            addChild(star)
            
            if twinkle {
                let twinkleDuration = Double.random(in: 2...5)
                let fadeOut = SKAction.fadeAlpha(to: alphaRange.lowerBound, duration: twinkleDuration)
                let fadeIn = SKAction.fadeAlpha(to: star.alpha, duration: twinkleDuration)
                let delay = SKAction.wait(forDuration: Double.random(in: 0...2))
                star.run(SKAction.sequence([delay, SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn]))]))
            }
        }
    }
    
    // MARK: - Static Game Stars
    
    private func setupStaticStars() {
        // Create 8 decorative game stars at fixed positions (scaled to screen)
        let screenSize = UIScreen.main.bounds.size
        let scale = min(screenSize.width, screenSize.height) / 400.0  // Scale factor for phone screens
        
        let starConfigurations: [(StarType, CGPoint, CGFloat)] = [
            (.whiteDwarf, CGPoint(x: -200 * scale, y: 300 * scale), 22 * scale),
            (.yellowDwarf, CGPoint(x: 150 * scale, y: 250 * scale), 35 * scale),
            (.blueGiant, CGPoint(x: -100 * scale, y: -200 * scale), 65 * scale),
            (.orangeGiant, CGPoint(x: 200 * scale, y: -220 * scale), 140 * scale),
            // (.redSupergiant, CGPoint(x: -300 * scale, y: 50 * scale), 400 * scale),
            (.whiteDwarf, CGPoint(x: 180 * scale, y: 100 * scale), 20 * scale),
            (.yellowDwarf, CGPoint(x: -250 * scale, y: -250 * scale), 38 * scale),
            (.blueGiant, CGPoint(x: 0, y: 400 * scale), 70 * scale)
        ]
        
        for (type, position, size) in starConfigurations {
            let star = Star(type: type)
            star.size = CGSize(width: size, height: size)
            star.position = position
            star.zPosition = 5
            
            // Disable physics for static display
            star.physicsBody = nil
            
            // CRITICAL: Don't block button touches!
            star.isUserInteractionEnabled = false
            
            addChild(star)
            decorativeStars.append(star)
            
            // Gentle floating animation
            let floatUp = SKAction.moveBy(x: 0, y: 10, duration: Double.random(in: 3...5))
            let floatDown = SKAction.moveBy(x: 0, y: -10, duration: Double.random(in: 3...5))
            floatUp.timingMode = .easeInEaseOut
            floatDown.timingMode = .easeInEaseOut
            
            let floatSequence = SKAction.sequence([floatUp, floatDown])
            let delay = SKAction.wait(forDuration: Double.random(in: 0...2))
            star.run(SKAction.sequence([delay, SKAction.repeatForever(floatSequence)]))
        }
    }
    
    // MARK: - Menu UI
    
    private func setupMenuUI() {
        // Title: NEBULA
        setupTitle()
        
        // Play Button
        setupPlayButton()
        
        // Timed Mode Button
        setupTimedModeButton()
        
        // Icon Buttons
        setupIconButtons()
    }
    
    private func setupTitle() {
        let screenSize = UIScreen.main.bounds.size
        let scale = min(screenSize.width, screenSize.height) / 400.0  // Scale factor for phone screens
        
        // Logo image instead of text
        let logo = SKSpriteNode(imageNamed: "logo")
        logo.position = CGPoint(x: 0, y: 200 * scale)  // Scale position
        logo.zPosition = 100
        
        // Scale the logo to fit on screen properly
        // Set max dimensions based on screen size (use 60% of screen width max)
        let maxWidth = screenSize.width * 0.6
        let maxHeight: CGFloat = 80 * scale  // Slightly larger than old font size
        
        // Calculate scale to fit within both constraints
        let widthScale = maxWidth / logo.size.width
        let heightScale = maxHeight / logo.size.height
        let logoScale = min(widthScale, heightScale) * 1.1  // Increase by 10%
        
        logo.setScale(logoScale)
        
        addChild(logo)
        
        // Add retro glow effect to the logo
        addLogoGlow(to: logo)
        
        // Subtitle (optional)
        // let subtitle = SKLabelNode(fontNamed: "SFProDisplay-Regular")
        // subtitle.text = "CONSUME TO SURVIVE"
        // subtitle.fontSize = 16 * scale  // Scale font size
        // subtitle.fontColor = UIColor(white: 0.7, alpha: 1.0)
        // subtitle.position = CGPoint(x: 0, y: 160 * scale)  // Scale position
        // subtitle.zPosition = 100
        // subtitle.alpha = 0.8
        // addChild(subtitle)
    }
    
    private func addLogoGlow(to logo: SKSpriteNode) {
        // Create a duplicate for glow effect
        let glowLogo = SKSpriteNode(imageNamed: "logo")
        glowLogo.position = CGPoint.zero
        glowLogo.zPosition = -1
        glowLogo.blendMode = .add
        glowLogo.color = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        glowLogo.colorBlendFactor = 0.8
        
        // Add blur effect node
        let effectNode = SKEffectNode()
        effectNode.shouldEnableEffects = true
        effectNode.addChild(glowLogo)
        
        // Add gaussian blur
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(4.0, forKey: kCIInputRadiusKey)
        effectNode.filter = blurFilter
        
        logo.addChild(effectNode)
        
        // Pulsing animation removed to prevent flashing effect
    }
    
    private func setupPlayButton() {
        let screenSize = UIScreen.main.bounds.size
        let scale = min(screenSize.width, screenSize.height) / 400.0  // Scale factor for phone screens
        
        playButton = MenuButton(text: "PLAY", size: .large)
        playButton.position = CGPoint(x: 0, y: 0)
        playButton.zPosition = 100
        playButton.onTap = { [weak self] in
            self?.startGame()
        }
        addChild(playButton)
    }
    
    private func setupTimedModeButton() {
        let screenSize = UIScreen.main.bounds.size
        let scale = min(screenSize.width, screenSize.height) / 400.0  // Scale factor for phone screens
        
        timedModeButton = MenuButton(text: "TIMED MODE", size: .medium)
        timedModeButton.position = CGPoint(x: 0, y: -80 * scale)  // Scale position
        timedModeButton.zPosition = 100
        timedModeButton.alpha = 0.6  // Indicate not yet available
        timedModeButton.onTap = { [weak self] in
            self?.showComingSoon()
        }
        addChild(timedModeButton)
    }
    
    private func setupIconButtons() {
        let screenSize = UIScreen.main.bounds.size
        
        // Settings button (top-left)
        settingsIconButton = IconButton(iconName: "settings")
        let topLeftX = -screenSize.width / 2 + 24 + 20  // margin + half button size (40pt/2)
        let topLeftY = screenSize.height / 2 - 24 - 20 - 20  // margin + half button size + 20pt down
        settingsIconButton.position = CGPoint(x: topLeftX, y: topLeftY)
        settingsIconButton.zPosition = 100
        settingsIconButton.onTap = { [weak self] in
            self?.showComingSoon()
        }
        addChild(settingsIconButton)
        
        // Discord button (top-right)
        discordIconButton = IconButton(iconName: "discord")
        let topRightX = screenSize.width / 2 - 24 - 20  // margin + half button size (40pt/2)
        let topRightY = screenSize.height / 2 - 24 - 20 - 20  // margin + half button size + 20pt down
        discordIconButton.position = CGPoint(x: topRightX, y: topRightY)
        discordIconButton.zPosition = 100
        discordIconButton.onTap = {
            // Placeholder for future Discord integration
            print("Discord button tapped - feature coming soon")
        }
        addChild(discordIconButton)
    }
    
    // MARK: - Retro Effects
    
    private func addRetroEffects() {
        // Add film grain overlay (lighter than in-game)
        if let grainTexture = generateGrainTexture() {
            let grainOverlay = SKSpriteNode(texture: grainTexture)
            let screenSize = UIScreen.main.bounds.size
            grainOverlay.size = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)  // Use screen size
            grainOverlay.position = CGPoint.zero  // Centered
            grainOverlay.alpha = 0.08  // Subtle for menu
            grainOverlay.blendMode = .screen
            grainOverlay.zPosition = 150
            grainOverlay.isUserInteractionEnabled = false  // CRITICAL: Don't block touches!
            addChild(grainOverlay)
            
            // Grain animation removed to prevent flashing effect
        }
        
        // Add vignette
        addVignette()
    }
    
    private func generateGrainTexture() -> SKTexture? {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor(white: 0.5, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            for _ in 0..<Int(size.width * size.height * 0.02) {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let brightness = CGFloat.random(in: 0.3...0.7)
                
                UIColor(white: brightness, alpha: 1.0).setFill()
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
    
    private func addVignette() {
        // Reuse RetroAestheticManager's vignette texture
        let vignetteTexture = RetroAestheticManager.shared.generateVignetteTexture()
        let vignetteOverlay = SKSpriteNode(texture: vignetteTexture)
        let screenSize = UIScreen.main.bounds.size
        vignetteOverlay.size = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)  // Use screen size
        vignetteOverlay.position = CGPoint.zero  // Centered
        vignetteOverlay.alpha = RetroAestheticManager.Config.vignetteIntensity
        vignetteOverlay.blendMode = .alpha
        vignetteOverlay.zPosition = 149
        vignetteOverlay.isUserInteractionEnabled = false  // CRITICAL: Don't block touches!
        addChild(vignetteOverlay)
    }
    
    // MARK: - Animations
    
    private func startAmbientAnimations() {
        // Slowly drift some decorative stars
        for (index, star) in decorativeStars.enumerated() {
            let delay = TimeInterval(index) * 0.5
            let drift = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.moveBy(x: CGFloat.random(in: -20...20), 
                                   y: CGFloat.random(in: -20...20), 
                                   duration: Double.random(in: 8...12)),
                    SKAction.moveBy(x: CGFloat.random(in: -20...20), 
                                   y: CGFloat.random(in: -20...20), 
                                   duration: Double.random(in: 8...12))
                ]))
            ])
            drift.timingMode = .easeInEaseOut
            star.run(drift)
        }
    }
    
    // MARK: - Button Actions
    
    private func startGame() {
        guard !isTransitioning else { return }
        isTransitioning = true
        
        // Play selection sound
        AudioManager.shared.playCorrectSound()
        
        // Transition after brief delay
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.transitionToGame()
            }
        ]))
    }
    
    private func transitionToGame() {
        // Stop menu music
        AudioManager.shared.stopBackgroundMusic()

        // Go directly to game
        let nextScene = GameScene(size: size)
        nextScene.scaleMode = .aspectFill

        // Transition with fade
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(nextScene, transition: transition)
    }
    
    private func showComingSoon() {
        // Play sound
        AudioManager.shared.playPowerUpSound()
        
        // Show temporary message
        let message = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        message.text = "COMING SOON"
        message.fontSize = 24
        message.fontColor = UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        message.position = CGPoint(x: 0, y: -250)
        message.zPosition = 200
        message.alpha = 0
        addChild(message)
        
        let appear = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 1.5)
        let disappear = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        message.run(SKAction.sequence([appear, wait, disappear, remove]))
    }
}
