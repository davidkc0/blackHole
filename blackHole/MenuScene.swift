//
//  MenuScene.swift
//  blackHole
//
//  Main menu scene with static game background
//

import SpriteKit
import GameplayKit
import CoreImage
import UIKit
import StoreKit

class MenuScene: SKScene {
    
    
    // MARK: - Properties
    
    // Background elements (reused from game)
    private var backgroundLayers: [[SKSpriteNode]] = [[], [], []]
    private var decorativeStars: [Star] = []
    
    // UI Elements
    private var playButton: MenuButton!
    private var timedModeButton: MenuButton!
    private var settingsIconButton: IconButton!
    private var statsIconButton: IconButton!
    
    // Animation state
    private var isTransitioning = false
    private var statsModalOpen = false
    private var statsModalContainer: SKNode?
    var statsCloseButton: MenuButton?  // Made internal for ModalScene access
    private var statsBlurView: UIVisualEffectView?
    private var statsModalView: SKView?
    
    // Settings modal state
    private var settingsModalOpen = false
    private var settingsModalContainer: SKNode?
    var settingsCloseButton: MenuButton?
    private var settingsBlurView: UIVisualEffectView?
    private var settingsModalView: SKView?
    
    // Settings controls (made internal for SettingsModalScene access)
    var soundMuteButton: IconButton?
    var musicMuteButton: IconButton?
    var soundVolumeSlider: VolumeSlider?
    var musicVolumeSlider: VolumeSlider?
    var removeAdsButton: MenuButton?
    var hapticsToggleButton: IconButton?
    var restorePurchasesButton: MenuButton?
    var privacyPolicyButton: MenuButton?
    private var isRestoringPurchases = false
    private var isPurchasingRemoveAds = false
    
    // Audio settings state
    private var soundVolume: Float {
        get { UserDefaults.standard.float(forKey: "soundVolume") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "soundVolume") }
        set { UserDefaults.standard.set(newValue, forKey: "soundVolume") }
    }
    
    private var musicVolume: Float {
        get { UserDefaults.standard.float(forKey: "musicVolume") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "musicVolume") }
        set { UserDefaults.standard.set(newValue, forKey: "musicVolume") }
    }
    
    private var soundMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "soundMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "soundMuted") }
    }
    
    private var musicMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "musicMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "musicMuted") }
    }
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        // CENTER THE COORDINATE SYSTEM - THIS IS CRITICAL!
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // ✅ Only setup essential UI immediately - buttons must be tappable
        backgroundColor = UIColor(white: 0.02, alpha: 1.0)
        setupMenuUI()
        
        // ✅ Defer ALL node creation after first frame
        run(SKAction.wait(forDuration: 0.016)) { [weak self] in
            guard let self = self else { return }
            // Now safe to create nodes - menu is already visible and responsive                                                                                
            self.setupBackground()  // 25 background stars (deferred)                                                                                           
            self.setupStaticStars()  // 8 decorative stars
            self.startAmbientAnimations()
            
            // Add retro effects synchronously (textures are already preloaded)
            self.addRetroEffects()
            
            // Wait a bit longer to ensure all animations have started and scene is fully interactive
            // This ensures stars are twinkling, ambient animations are running, and buttons are responsive
            self.run(SKAction.wait(forDuration: 0.1)) { [weak self] in
                guard let self = self else { return }
                // ✅ POST READY ONLY AFTER ALL WORK IS DONE, ANIMATIONS STARTED, AND SCENE IS INTERACTIVE!
                print("✅ MenuScene fully initialized, dismissing loading screen")
                NotificationCenter.default.post(
                    name: NSNotification.Name("MenuSceneReady"),
                    object: nil
                )
            }
        }
        
        // ❌ Avoid touching AdManager here; we'll load later when game starts                                                                               
        // _ = AdManager.shared  // remove
        
        // Switch to menu music and play (ensures correct buffers are used and music starts)
        // Apply persisted audio settings before starting playback
        AudioManager.shared.setMusicVolume(musicVolume)
        AudioManager.shared.setSoundVolume(soundVolume)
        AudioManager.shared.setMusicMuted(musicMuted)
        AudioManager.shared.setSoundMuted(soundMuted)
        AudioManager.shared.switchToMenuMusic()
        AudioManager.shared.playBackgroundMusic()
        
        // Show Game Center access point
        GameCenterManager.shared.setAccessPointVisible(true, context: .menu)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        print("🖐 Touch began at: \(location)")
        
        // Check for modal close buttons first
        if statsModalOpen {
            if let closeButton = statsCloseButton {
                let buttonLocation = convert(location, to: closeButton.parent!)
                if closeButton.contains(point: buttonLocation) {
                    closeButton.animatePress()
                    return
                }
            }
            return
        }
        
        if settingsModalOpen {
            if let closeButton = settingsCloseButton {
                let buttonLocation = convert(location, to: closeButton.parent!)
                if closeButton.contains(point: buttonLocation) {
                    closeButton.animatePress()
                    return
                }
            }
            return
        }
        
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
        } else if statsIconButton.contains(point: location) {
            statsIconButton.animatePress()
            print("✅ STATS button pressed")
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        print("🖐 Touch ended at: \(location)")
        
        // Check for modal close buttons first
        if statsModalOpen {
            if let closeButton = statsCloseButton {
                let buttonLocation = convert(location, to: closeButton.parent!)
                if closeButton.contains(point: buttonLocation) {
                    closeButton.animateRelease()
                    closeStatsModal()
                    return
                }
            }
            return
        }
        
        if settingsModalOpen {
            if let closeButton = settingsCloseButton {
                let buttonLocation = convert(location, to: closeButton.parent!)
                if closeButton.contains(point: buttonLocation) {
                    closeButton.animateRelease()
                    closeSettingsModal()
                    return
                }
            }
            return
        }
        
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
        } else if statsIconButton.contains(point: location) {
            statsIconButton.animateRelease()
            print("📊 STATS button tapped")
            statsIconButton.onTap?()
        }
    }
    
    // MARK: - Background Setup (Reuse from GameScene)
    
    private func setupBackground() {
        // Background color is already set in didMove()
        // Nebula removed - just add background starfield
        // Add background starfield (25 stars in visible area only)
        createStaticStarfield()
    }
    
    private func createStaticStarfield() {
        // ✅ Create 25 background stars synchronously - not enough to cause freeze
        // This ensures they're all created before MenuSceneReady is posted
        let count = 25
        let sizeRange: ClosedRange<CGFloat> = 1.0...2.5
        let alphaRange: ClosedRange<CGFloat> = 0.4...0.7
        let zPosition: CGFloat = -25
        
        let screenSize = UIScreen.main.bounds.size
        let visibleWidth = screenSize.width * 0.5
        let visibleHeight = screenSize.height * 0.5
        
        for _ in 0..<count {
            let starSize = CGFloat.random(in: sizeRange)
            let position = CGPoint(
                x: CGFloat.random(in: -visibleWidth...visibleWidth),
                y: CGFloat.random(in: -visibleHeight...visibleHeight)
            )
            let alpha = CGFloat.random(in: alphaRange)
            
            let star = SKSpriteNode(color: .white, size: CGSize(width: starSize, height: starSize))
            star.position = position
            star.alpha = alpha
            star.zPosition = zPosition
            star.isUserInteractionEnabled = false
            addChild(star)
            
            // Start twinkle animation immediately
            let twinkleDuration = Double.random(in: 2...5)
            let fadeOut = SKAction.fadeAlpha(to: alphaRange.lowerBound, duration: twinkleDuration)
            let fadeIn = SKAction.fadeAlpha(to: alpha, duration: twinkleDuration)
            let delay = SKAction.wait(forDuration: Double.random(in: 0...2))
            star.run(SKAction.sequence([delay, SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn]))]))
        }
    }
    
    private func createStarLayerBatched(count: Int, sizeRange: ClosedRange<CGFloat>,
                                       alphaRange: ClosedRange<CGFloat>, zPosition: CGFloat,
                                       twinkle: Bool, startDelay: TimeInterval, batchSize: Int) {
        let screenSize = UIScreen.main.bounds.size
        
        // ✅ FIX: Only spread stars across VISIBLE menu area
        // Since anchorPoint is (0.5, 0.5), visible area is:
        let visibleWidth = screenSize.width * 0.5   // -width/2 to +width/2
        let visibleHeight = screenSize.height * 0.5  // -height/2 to +height/2
        let spreadX = visibleWidth
        let spreadY = visibleHeight
        
        // Pre-generate all star properties to avoid blocking during animation                                                                              
        var starProperties: [(size: CGFloat, position: CGPoint, alpha: CGFloat)] = []                                                                       
        for _ in 0..<count {
            let starSize = CGFloat.random(in: sizeRange)
            // ✅ Use visible area bounds only
            let position = CGPoint(
                x: CGFloat.random(in: -spreadX...spreadX),
                y: CGFloat.random(in: -spreadY...spreadY)
            )
            let alpha = CGFloat.random(in: alphaRange)
            starProperties.append((size: starSize, position: position, alpha: alpha))
        }
        
        // Create stars in batches across multiple frames
        var batchIndex = 0
        let totalBatches = (count + batchSize - 1) / batchSize
        
        func createBatch() {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, count)
            
            for i in startIndex..<endIndex {
                let props = starProperties[i]
                let star = SKSpriteNode(color: .white, size: CGSize(width: props.size, height: props.size))
                
                star.position = props.position
                star.alpha = props.alpha
                star.zPosition = zPosition
                star.isUserInteractionEnabled = false  // Don't block touches
                addChild(star)
                
                if twinkle {
                    let twinkleDuration = Double.random(in: 2...5)
                    let fadeOut = SKAction.fadeAlpha(to: alphaRange.lowerBound, duration: twinkleDuration)
                    let fadeIn = SKAction.fadeAlpha(to: props.alpha, duration: twinkleDuration)
                    let delay = SKAction.wait(forDuration: Double.random(in: 0...2))
                    star.run(SKAction.sequence([delay, SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn]))]))
                }
            }
            
            batchIndex += 1
            
            // Schedule next batch if there are more to create
            if batchIndex < totalBatches {
                run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.016), // ~1 frame at 60fps
                    SKAction.run(createBatch)
                ]))
            }
        }
        
        // Start creating batches after initial delay
        if startDelay > 0 {
            run(SKAction.sequence([
                SKAction.wait(forDuration: startDelay),
                SKAction.run(createBatch)
            ]))
        } else {
            createBatch()
        }
    }
    
    // MARK: - Static Game Stars (Synchronous creation - only 8 stars)

    private func setupStaticStars() {
        // Create all 8 decorative stars synchronously - not enough to cause freeze
        let screenSize = UIScreen.main.bounds.size
        let scale = min(screenSize.width, screenSize.height) / 400.0

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

                // Create all stars immediately - ensures they exist before MenuSceneReady
        for (type, position, size) in starConfigurations {
            createDecorativeStar(type: type, position: position, size: size)
        }
    }

    /// Helper for creating a single decorative star
    private func createDecorativeStar(type: StarType, position: CGPoint, size: CGFloat) {
        let star = Star(type: type)
        star.size = CGSize(width: size, height: size)
        star.position = position
        star.zPosition = 5

        // Disable physics for static display
        star.physicsBody = nil

        // Don't block button touches!
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
        applyInitialAnimations()
        addVersionLabel()
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
        let logoScale = min(widthScale, heightScale) * 1.21  // 10% larger (1.1 * 1.1)
        
        logo.setScale(logoScale)
        
        addChild(logo)
        
        // Add retro glow effect to the logo
        addLogoGlow(to: logo)
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
        
        // Settings button (top-left) - positioned to match Game Center icon distance from top
        settingsIconButton = IconButton(iconName: "settings")
        let topLeftX = -screenSize.width / 2 + 24 + 20  // margin + half button size (40pt/2)
        // Match Game Center icon distance from top (top-right position) + 50pt lower
        let topRightY = screenSize.height / 2 - 24 - 20 - 20 - 50  // margin + half button size + 20pt down + 50pt lower
        settingsIconButton.position = CGPoint(x: topLeftX, y: topRightY)
        settingsIconButton.zPosition = 100
        settingsIconButton.onTap = { [weak self] in
            self?.showSettingsModal()
        }
        addChild(settingsIconButton)
        
        // Stats button (to the right of settings button) - same Y as settings to match Game Center
        statsIconButton = IconButton(iconName: "chart")
        let statsX = topLeftX + 64  // 40pt button + 24pt spacing
        statsIconButton.position = CGPoint(x: statsX, y: topRightY)
        statsIconButton.zPosition = 100
        statsIconButton.onTap = { [weak self] in
            self?.showStatsModal()
        }
        addChild(statsIconButton)
    }
    
    private func applyInitialAnimations() {
        // Fade in the play button
        playButton.alpha = 0
        playButton.setScale(0.9)
        let fadeInPlay = SKAction.fadeIn(withDuration: 0.3)
        let scaleUpPlay = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUpPlay.timingMode = .easeOut
        playButton.run(SKAction.group([fadeInPlay, scaleUpPlay]))
        
        // Fade in the timed mode button
        timedModeButton.alpha = 0
        timedModeButton.setScale(0.9)
        let fadeInTimedMode = SKAction.fadeIn(withDuration: 0.3)
        let scaleUpTimedMode = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUpTimedMode.timingMode = .easeOut
        timedModeButton.run(SKAction.group([fadeInTimedMode, scaleUpTimedMode]))
        
        // Fade in the settings button
        settingsIconButton.alpha = 0
        settingsIconButton.setScale(0.9)
        let fadeInSettings = SKAction.fadeIn(withDuration: 0.3)
        let scaleUpSettings = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUpSettings.timingMode = .easeOut
        settingsIconButton.run(SKAction.group([fadeInSettings, scaleUpSettings]))
        
        // Fade in the stats button
        statsIconButton.alpha = 0
        statsIconButton.setScale(0.9)
        let fadeInStats = SKAction.fadeIn(withDuration: 0.3)
        let scaleUpStats = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUpStats.timingMode = .easeOut
        statsIconButton.run(SKAction.group([fadeInStats, scaleUpStats]))
    }
    
    private func addVersionLabel() {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty else { return }
        let label = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        label.text = "v \(version)"
        label.fontSize = 14
        label.fontColor = UIColor.white.withAlphaComponent(0.6)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        let inset: CGFloat = 20
        label.position = CGPoint(x: -size.width/2 + inset, y: -size.height/2 + inset)
        label.zPosition = 5
        label.alpha = 0
        addChild(label)
        
        let fade = SKAction.fadeIn(withDuration: 0.4)
        fade.timingMode = .easeIn
        label.run(SKAction.sequence([SKAction.wait(forDuration: 0.3), fade]))
    }
    
    // MARK: - Retro Effects
    
    private func addRetroEffects() {
        // Textures are already preloaded, so this is fast and safe on main thread
        if let grainTexture = RetroAestheticManager.shared.getMenuGrainTexture() {
            let grainOverlay = SKSpriteNode(texture: grainTexture)
            let screenSize = UIScreen.main.bounds.size
            grainOverlay.size = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
            grainOverlay.position = CGPoint.zero
            grainOverlay.alpha = 0.08
            grainOverlay.blendMode = .screen
            grainOverlay.zPosition = 150
            grainOverlay.isUserInteractionEnabled = false
            addChild(grainOverlay)
        }
        
        if let vignetteTexture = RetroAestheticManager.shared.getVignetteTexture() {
            let vignetteOverlay = SKSpriteNode(texture: vignetteTexture)
            let screenSize = UIScreen.main.bounds.size
            vignetteOverlay.size = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
            vignetteOverlay.position = CGPoint.zero
            vignetteOverlay.alpha = RetroAestheticManager.Config.vignetteIntensity
            vignetteOverlay.blendMode = .alpha
            vignetteOverlay.zPosition = 149
            vignetteOverlay.isUserInteractionEnabled = false
            addChild(vignetteOverlay)
        }
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
        AudioManager.shared.playCorrectSound(on: self)
        
        // Transition immediately - no delay to show loading screen instantly
        transitionToGame()
    }
    
    private func transitionToGame() {
        // Stop menu music
        AudioManager.shared.stopBackgroundMusic()
        
        // Hide Game Center access point
        GameCenterManager.shared.setAccessPointVisible(false, context: .gameplay)

        // Go to game loading scene (handles haptics and texture preloading)
        let nextScene = GameLoadingScene(size: size)
        nextScene.scaleMode = .aspectFill

        // Use instant transition so loading screen appears immediately (no frozen screen)
        let transition = SKTransition.crossFade(withDuration: 0.1)
        view?.presentScene(nextScene, transition: transition)
    }
    
    private func showComingSoon() {
        // Play sound
        AudioManager.shared.playPowerUpSound(on: self)
        
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
    
    // MARK: - Modal Background Blur
    
    /// Creates a reusable blurred background overlay for modals
    /// Uses Apple's native UIVisualEffectView for efficient blur rendering
    /// - Returns: A UIVisualEffectView configured with dark blur effect
    private func createBlurredBackgroundOverlay() -> UIVisualEffectView {
        // Create blur effect with dark style
        let blurEffect = UIBlurEffect(style: .dark)
        
        // Create visual effect view with the blur effect
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view?.bounds ?? CGRect.zero
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return blurView
    }
    
    private func showStatsModal() {
        guard !statsModalOpen else { return }
        statsModalOpen = true
        
        guard let skView = self.view else { return }
        
        // Step 1: Add blur view to blur the main menu UI
        statsBlurView = createBlurredBackgroundOverlay()
        if let blurView = statsBlurView {
            skView.addSubview(blurView)
        }
        
        // Step 2: Create a separate SKView for the modal content above the blur
        let modalSKView = SKView(frame: skView.bounds)
        modalSKView.allowsTransparency = true
        modalSKView.backgroundColor = .clear
        modalSKView.isUserInteractionEnabled = true  // Need interaction for close button
        skView.addSubview(modalSKView)
        statsModalView = modalSKView
        
        // Step 3: Create a temporary scene for the modal content
        let modalScene = ModalScene(size: skView.bounds.size)
        modalScene.menuScene = self
        modalScene.backgroundColor = .clear
        modalScene.scaleMode = .aspectFill
        modalScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        modalSKView.presentScene(modalScene)
        
        // Step 4: Create modal container in the modal scene
        statsModalContainer = SKNode()
        statsModalContainer!.name = "statsModal"
        statsModalContainer!.zPosition = 200
        modalScene.addChild(statsModalContainer!)
        
        // Modal dimensions
        let modalWidth: CGFloat = 320
        let topPadding: CGFloat = 14  // Distance from modal top to title top
        let bottomPadding: CGFloat = 20
        let rowHeight: CGFloat = 30
        let titleBottomSpacing: CGFloat = 43  // 28pt to row top + 15pt to row center (rowHeight=30)
        let rowSpacing: CGFloat = 25  // Keep for spacing between stat rows
        
        // Calculate content height
        let titleHeight: CGFloat = 40
        let statsCount = 8  // Total Play Time, High Score, Total Stars, 5 star types
        let statsHeight = CGFloat(statsCount) * (rowHeight + rowSpacing)
        let buttonHeight: CGFloat = 49
        let buttonSpacing: CGFloat = 20
        
        let modalHeight = topPadding + titleHeight + titleBottomSpacing + statsHeight + buttonSpacing + buttonHeight + bottomPadding
        
        // Create modal background
        let modalRect = CGRect(x: -modalWidth/2, y: -modalHeight/2, width: modalWidth, height: modalHeight)
        let modalBackground = SKShapeNode(rect: modalRect, cornerRadius: 8)
        modalBackground.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.24)
        modalBackground.strokeColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.5)
        modalBackground.lineWidth = 1.5
        modalBackground.zPosition = 0
        statsModalContainer!.addChild(modalBackground)
        
        // Title
        let titleLabel = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        titleLabel.text = "STATISTICS"
        titleLabel.fontSize = 32
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: modalHeight/2 - topPadding - titleHeight/2)
        titleLabel.zPosition = 1
        statsModalContainer!.addChild(titleLabel)
        
        // Stats list
        var currentY = modalHeight/2 - topPadding - titleHeight - titleBottomSpacing
        // Use same padding as button (20pt on each side)
        let leftPadding: CGFloat = 20
        let rightPadding: CGFloat = 20
        let valueWidth: CGFloat = 80
        
        // Add each stat row
        addStatRow(label: "Total Play Time", value: GameStats.shared.formatPlayTime(), y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "High Score", value: "\(GameStats.shared.highScore)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "Total Stars Absorbed", value: "\(GameStats.shared.totalStarsAbsorbed)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "White Dwarfs", value: "\(GameStats.shared.whiteDwarfsAbsorbed)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "Yellow Dwarfs", value: "\(GameStats.shared.yellowDwarfsAbsorbed)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "Blue Giants", value: "\(GameStats.shared.blueGiantsAbsorbed)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "Orange Giants", value: "\(GameStats.shared.orangeGiantsAbsorbed)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        currentY -= (rowHeight + rowSpacing)
        
        addStatRow(label: "Red Supergiants", value: "\(GameStats.shared.redSupergiantsAbsorbed)", y: currentY, modalWidth: modalWidth, valueWidth: valueWidth, leftPadding: leftPadding, rightPadding: rightPadding)
        
        // Close button
        let buttonWidth = modalWidth - 40
        statsCloseButton = MenuButton(text: "CLOSE", size: .medium, fixedWidth: buttonWidth)
        statsCloseButton!.position = CGPoint(x: 0, y: -modalHeight/2 + bottomPadding + buttonHeight/2)
        statsCloseButton!.zPosition = 1
        statsModalContainer!.addChild(statsCloseButton!)
        
        // Fade in animation
        statsModalContainer!.alpha = 0
        statsModalContainer!.setScale(0.95)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUp.timingMode = .easeOut
        statsModalContainer!.run(SKAction.group([fadeIn, scaleUp]))
    }
    
    private func addStatRow(label: String, value: String, y: CGFloat, modalWidth: CGFloat, valueWidth: CGFloat, leftPadding: CGFloat, rightPadding: CGFloat) {
        
        // Label (left side)
        let labelNode = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        labelNode.text = label
        labelNode.fontSize = 18
        labelNode.fontColor = UIColor.white.withAlphaComponent(0.7)
        labelNode.horizontalAlignmentMode = .left
        labelNode.verticalAlignmentMode = .center
        labelNode.position = CGPoint(x: -modalWidth/2 + leftPadding, y: y)
        labelNode.zPosition = 1
        statsModalContainer!.addChild(labelNode)
        
        // Value (right side) with background
        let valueBgWidth = valueWidth + 12  // extra padding
        let valueBgRect = CGRect(x: modalWidth/2 - rightPadding - valueBgWidth, y: y - 15, width: valueBgWidth, height: 30)
        let valueBg = SKShapeNode(rect: valueBgRect, cornerRadius: 4)
        valueBg.fillColor = UIColor(hex: "#346174")
        valueBg.strokeColor = .clear
        valueBg.zPosition = 0
        statsModalContainer!.addChild(valueBg)
        
        let valueNode = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        valueNode.text = value
        valueNode.fontSize = 18
        valueNode.fontColor = .white
        valueNode.horizontalAlignmentMode = .right
        valueNode.verticalAlignmentMode = .center
        valueNode.position = CGPoint(x: modalWidth/2 - rightPadding - 6, y: y)
        valueNode.zPosition = 1
        statsModalContainer!.addChild(valueNode)
    }
    
    func closeStatsModal() {  // Made internal for ModalScene access
        guard statsModalOpen else { return }
        statsModalOpen = false
        
        // Fade out animation for modal
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.2)
        statsModalContainer!.run(SKAction.group([fadeOut, scaleDown])) {
            self.statsModalContainer?.removeFromParent()
            self.statsModalContainer = nil
            self.statsCloseButton = nil
        }
        
        // Fade out and remove modal view
        if let modalView = statsModalView {
            UIView.animate(withDuration: 0.2, animations: {
                modalView.alpha = 0
            }) { _ in
                modalView.removeFromSuperview()
            }
            statsModalView = nil
        }
        
        // Fade out and remove blur view
        if let blurView = statsBlurView {
            UIView.animate(withDuration: 0.2, animations: {
                blurView.alpha = 0
            }) { _ in
                blurView.removeFromSuperview()
            }
            statsBlurView = nil
        }
    }
    
    // MARK: - Settings Modal
    
    private func showSettingsModal() {
        guard !settingsModalOpen else { return }
        settingsModalOpen = true
        
        guard let skView = self.view else { return }
        
        // Step 1: Add blur view to blur the main menu UI
        settingsBlurView = createBlurredBackgroundOverlay()
        if let blurView = settingsBlurView {
            skView.addSubview(blurView)
        }
        
        // Step 2: Create a separate SKView for the modal content above the blur
        let modalSKView = SKView(frame: skView.bounds)
        modalSKView.allowsTransparency = true
        modalSKView.backgroundColor = .clear
        modalSKView.isUserInteractionEnabled = true
        skView.addSubview(modalSKView)
        settingsModalView = modalSKView
        
        // Step 3: Create a temporary scene for the modal content
        let modalScene = SettingsModalScene(size: skView.bounds.size)
        modalScene.menuScene = self
        modalScene.backgroundColor = .clear
        modalScene.scaleMode = .aspectFill
        modalScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        modalSKView.presentScene(modalScene)
        
        // Step 4: Create modal container in the modal scene
        settingsModalContainer = SKNode()
        settingsModalContainer!.name = "settingsModal"
        settingsModalContainer!.zPosition = 200
        modalScene.addChild(settingsModalContainer!)
        
        // Modal dimensions
        let modalWidth: CGFloat = 320
        let topPadding: CGFloat = 14  // Distance from modal top to title top
        let bottomPadding: CGFloat = 20
        let rowHeight: CGFloat = 40
        let titleBottomSpacing: CGFloat = 48  // 28pt to row top + 20pt to row center (rowHeight=40)
        let rowSpacing: CGFloat = 25  // Keep for spacing between settings rows
        
        // Calculate content height
        let titleHeight: CGFloat = 40
        let settingsRowsHeight = (rowHeight * 3) + (rowSpacing * 2) // Sound Effects + Music + Haptics
        let removeAdsButtonHeight: CGFloat = 49
        let hapticsToRemoveAdsSpacing: CGFloat = 36
        let closeButtonHeight: CGFloat = 49
        let buttonSpacing: CGFloat = 20
        
        // Calculate modal height so that bottom is 14pt from Close button outer border
        let bottomPaddingFromOuterBorder: CGFloat = 14 + 6  // 14pt visible + 6pt outer border extension
        
        let buttonStackHeight = removeAdsButtonHeight * 3 + closeButtonHeight + buttonSpacing * 3
        let modalHeight = topPadding + titleHeight + titleBottomSpacing + settingsRowsHeight + hapticsToRemoveAdsSpacing + buttonStackHeight + bottomPaddingFromOuterBorder
        
        // Create modal background
        let modalRect = CGRect(x: -modalWidth/2, y: -modalHeight/2, width: modalWidth, height: modalHeight)
        let modalBackground = SKShapeNode(rect: modalRect, cornerRadius: 8)
        modalBackground.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.24)
        modalBackground.strokeColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.5)
        modalBackground.lineWidth = 1.5
        modalBackground.zPosition = 0
        settingsModalContainer!.addChild(modalBackground)
        
        // Title
        let titleLabel = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        titleLabel.text = "SETTINGS"
        titleLabel.fontSize = 32
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: modalHeight/2 - topPadding - titleHeight/2)
        titleLabel.zPosition = 1
        settingsModalContainer!.addChild(titleLabel)
        
        // Settings rows
        var currentY = modalHeight/2 - topPadding - titleHeight - titleBottomSpacing
        let leftPadding: CGFloat = 20
        let rightPadding: CGFloat = 20
        let labelSpacing: CGFloat = 20
        let sliderWidth: CGFloat = 100
        
        // Sound Effects row
        addSettingsRow(
            label: "Sound Effects",
            y: currentY,
            modalWidth: modalWidth,
            leftPadding: leftPadding,
            rightPadding: rightPadding,
            buttonSpacing: buttonSpacing,
            labelSpacing: labelSpacing,
            sliderWidth: sliderWidth,
            isMusic: false
        )
        currentY -= (rowHeight + rowSpacing)
        
        // Music row
        addSettingsRow(
            label: "Music",
            y: currentY,
            modalWidth: modalWidth,
            leftPadding: leftPadding,
            rightPadding: rightPadding,
            buttonSpacing: buttonSpacing,
            labelSpacing: labelSpacing,
            sliderWidth: sliderWidth,
            isMusic: true
        )
        currentY -= (rowHeight + rowSpacing)
        addHapticsRow(
            y: currentY,
            modalWidth: modalWidth,
            leftPadding: leftPadding,
            rightPadding: rightPadding,
            buttonSpacing: buttonSpacing
        )
        currentY -= (rowHeight + hapticsToRemoveAdsSpacing)
        
        let removeAdsButtonWidth = modalWidth - 40
        if GameConstants.enableIAPButtons {
            // Remove Ads button
            let hasPurchased = IAPManager.shared.checkPurchaseStatus()
            let buttonText = hasPurchased ? "ADS REMOVED ✓" : "REMOVE ADS"
            
            let removeAdsButton = MenuButton(text: buttonText, size: .medium, fixedWidth: removeAdsButtonWidth)
            removeAdsButton.position = CGPoint(x: 0, y: currentY)
            removeAdsButton.zPosition = 1
            
            if hasPurchased {
                removeAdsButton.alpha = 0.6
                removeAdsButton.isUserInteractionEnabled = false
                removeAdsButton.onTap = nil
            } else {
                removeAdsButton.alpha = 1.0
                removeAdsButton.isUserInteractionEnabled = true
                removeAdsButton.onTap = { [weak self] in
                    print("🛒 REMOVE ADS tapped")
                    self?.handleRemoveAdsPurchase()
                }
            }
            
            self.removeAdsButton = removeAdsButton
            settingsModalContainer!.addChild(removeAdsButton)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePurchaseSuccessNotification),
                name: NSNotification.Name("RemoveAdsPurchased"),
                object: nil
            )
            
            currentY -= (removeAdsButtonHeight + buttonSpacing)
            let restoreButton = MenuButton(text: "RESTORE PURCHASES", size: .medium, fixedWidth: removeAdsButtonWidth)
            restoreButton.position = CGPoint(x: 0, y: currentY)
            restoreButton.zPosition = 1
            restoreButton.onTap = { [weak self] in
                guard let self = self, let button = self.restorePurchasesButton, !self.isRestoringPurchases else { return }
                self.handleRestorePurchases(button: button)
            }
            self.restorePurchasesButton = restoreButton
            settingsModalContainer!.addChild(restoreButton)
            currentY -= (removeAdsButtonHeight + buttonSpacing)
        }

        let privacyButton = MenuButton(text: "PRIVACY POLICY", size: .medium, fixedWidth: removeAdsButtonWidth)
        privacyButton.position = CGPoint(x: 0, y: currentY)
        privacyButton.zPosition = 1
        privacyButton.onTap = { [weak self] in
            self?.openPrivacyPolicy()
        }
        self.privacyPolicyButton = privacyButton
        settingsModalContainer!.addChild(privacyButton)
        currentY -= (removeAdsButtonHeight + buttonSpacing)
        
        let buttonWidth = modalWidth - 40
        let closeButtonY = -modalHeight/2 + (bottomPaddingFromOuterBorder - 6) + closeButtonHeight/2
        settingsCloseButton = MenuButton(text: "CLOSE", size: .medium, fixedWidth: buttonWidth)
        settingsCloseButton!.position = CGPoint(x: 0, y: closeButtonY)
        settingsCloseButton!.zPosition = 1
        settingsModalContainer!.addChild(settingsCloseButton!)
        
        // Fade in animation
        settingsModalContainer!.alpha = 0
        settingsModalContainer!.setScale(0.95)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUp.timingMode = .easeOut
        settingsModalContainer!.run(SKAction.group([fadeIn, scaleUp]))
    }
    
    private func addSettingsRow(
        label: String,
        y: CGFloat,
        modalWidth: CGFloat,
        leftPadding: CGFloat,
        rightPadding: CGFloat,
        buttonSpacing: CGFloat,
        labelSpacing: CGFloat,
        sliderWidth: CGFloat,
        isMusic: Bool
    ) {
        let buttonX = -modalWidth/2 + leftPadding + 20 // 20pt is half button size
        let sliderX = modalWidth/2 - rightPadding - sliderWidth/2
        
        // Calculate available space for label
        let buttonEnd = buttonX + 20 + buttonSpacing
        let sliderStart = sliderX - sliderWidth/2
        let availableWidth = sliderStart - buttonEnd - labelSpacing
        let labelX = buttonEnd
        
        // Mute button
        let iconName = isMusic ? (musicMuted ? "music-off" : "music-on") : (soundMuted ? "sound-off" : "sound-on")
        let muteButton = IconButton(iconName: iconName, size: 40, cornerRadius: 5)
        muteButton.position = CGPoint(x: buttonX, y: y)
        muteButton.zPosition = 1
        
        // Store reference and set up tap handler
        if isMusic {
            musicMuteButton = muteButton
            muteButton.onTap = { [weak self] in
                self?.toggleMusicMute()
            }
        } else {
            soundMuteButton = muteButton
            muteButton.onTap = { [weak self] in
                self?.toggleSoundMute()
            }
        }
        
        settingsModalContainer!.addChild(muteButton)
        
        // Label - constrained to available width to prevent overlap
        let labelNode = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        labelNode.text = label
        labelNode.fontSize = 18
        labelNode.fontColor = UIColor.white.withAlphaComponent(0.7)
        labelNode.horizontalAlignmentMode = .left
        labelNode.verticalAlignmentMode = .center
        labelNode.position = CGPoint(x: labelX, y: y)
        labelNode.zPosition = 1
        settingsModalContainer!.addChild(labelNode)
        
        // Volume slider
        let sliderFrame = CGRect(x: 0, y: 0, width: sliderWidth, height: 20)
        let currentVolume = isMusic ? (musicMuted ? 0.0 : musicVolume) : (soundMuted ? 0.0 : soundVolume)
        let slider = VolumeSlider(frame: sliderFrame, initialValue: currentVolume)
        slider.position = CGPoint(x: sliderX, y: y)
        slider.zPosition = 1
        
        slider.onValueChanged = { [weak self] newValue in
            if isMusic {
                self?.musicMuted = false
                self?.musicVolume = newValue
                AudioManager.shared.setMusicVolume(newValue)
                // Update button icon
                if let button = self?.musicMuteButton {
                    let newIcon = newValue > 0 ? "music-on" : "music-off"
                    button.updateIcon(newIcon)
                }
            } else {
                self?.soundMuted = false
                self?.soundVolume = newValue
                AudioManager.shared.setSoundVolume(newValue)
                // Update button icon
                if let button = self?.soundMuteButton {
                    let newIcon = newValue > 0 ? "sound-on" : "sound-off"
                    button.updateIcon(newIcon)
                }
            }
        }
        
        if isMusic {
            musicVolumeSlider = slider
        } else {
            soundVolumeSlider = slider
        }
        
        settingsModalContainer!.addChild(slider)
    }
    
    private func toggleSoundMute() {
        soundMuted.toggle()
        
        if soundMuted {
            soundVolumeSlider?.updateValue(0.0)
            AudioManager.shared.setSoundVolume(0.0)
            soundMuteButton?.updateIcon("sound-off")
        } else {
            let volume = soundVolume > 0 ? soundVolume : 1.0
            soundVolume = volume
            soundVolumeSlider?.updateValue(volume)
            AudioManager.shared.setSoundVolume(volume)
            soundMuteButton?.updateIcon("sound-on")
        }
    }
    
    private func toggleMusicMute() {
        musicMuted.toggle()
        
        if musicMuted {
            musicVolumeSlider?.updateValue(0.0)
            AudioManager.shared.setMusicVolume(0.0)
            musicMuteButton?.updateIcon("music-off")
        } else {
            let volume = musicVolume > 0 ? musicVolume : 1.0
            musicVolume = volume
            musicVolumeSlider?.updateValue(volume)
            AudioManager.shared.setMusicVolume(volume)
            musicMuteButton?.updateIcon("music-on")
        }
    }

    private func addHapticsRow(
        y: CGFloat,
        modalWidth: CGFloat,
        leftPadding: CGFloat,
        rightPadding: CGFloat,
        buttonSpacing: CGFloat
    ) {
        let buttonX = -modalWidth/2 + leftPadding + 20
        let enabled = HapticManager.shared.areHapticsEnabled()
        let iconName = enabled ? "haptic" : "haptic-off"
        let toggleButton = IconButton(iconName: iconName, size: 40, cornerRadius: 5)
        toggleButton.position = CGPoint(x: buttonX, y: y)
        toggleButton.zPosition = 1
        toggleButton.onTap = { [weak self] in
            self?.toggleHaptics()
        }
        hapticsToggleButton = toggleButton
        settingsModalContainer!.addChild(toggleButton)
        
        let labelNode = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        labelNode.text = "Haptics"
        labelNode.fontSize = 18
        labelNode.fontColor = UIColor.white.withAlphaComponent(0.7)
        labelNode.horizontalAlignmentMode = .left
        labelNode.verticalAlignmentMode = .center
        let labelX = buttonX + 20 + buttonSpacing
        labelNode.position = CGPoint(x: labelX, y: y)
        labelNode.zPosition = 1
        settingsModalContainer!.addChild(labelNode)
    }

    private func toggleHaptics() {
        let newValue = !HapticManager.shared.areHapticsEnabled()
        HapticManager.shared.setHapticsEnabled(newValue)
        hapticsToggleButton?.updateIcon(newValue ? "haptic" : "haptic-off")
    }
    
    @objc private func handlePurchaseSuccessNotification() {
        // Update button state when purchase succeeds
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.removeAdsButton else { return }
            button.updateText("ADS REMOVED ✓")
            button.alpha = 0.6
            button.isUserInteractionEnabled = false
            button.onTap = nil
            button.removeAllActions()
        }
    }
    
    private func handleRemoveAdsPurchase() {
        guard let button = removeAdsButton else { return }
        guard !isPurchasingRemoveAds else { return }
        isPurchasingRemoveAds = true
        
        let originalText = button.text
        button.updateText("LOADING...")
        button.isUserInteractionEnabled = false
        
        Task {
            do {
                print("🔎 Fetching products in handleRemoveAdsPurchase")
                let success = try await IAPManager.shared.purchaseRemoveAds()
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let button = self.removeAdsButton else { return }
                    self.isPurchasingRemoveAds = false
                    
                    if success {
                        print("✅ Purchase successful!")
                    } else {
                        button.updateText(originalText.isEmpty ? "REMOVE ADS" : originalText)
                        button.isUserInteractionEnabled = true
                        print("❌ Purchase failed")
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let button = self.removeAdsButton else { return }
                    self.isPurchasingRemoveAds = false
                    
                    button.updateText(originalText.isEmpty ? "REMOVE ADS" : originalText)
                    button.isUserInteractionEnabled = true
                    
                    if let iapError = error as? IAPManager.IAPError {
                        print("❌ Purchase error: \(iapError.localizedDescription)")
                    } else {
                        print("❌ Purchase error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func handleRestorePurchases(button: MenuButton) {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        let originalText = button.text
        button.updateText("RESTORING...")
        button.isUserInteractionEnabled = false
        
        Task {
            do {
                let restored = try await IAPManager.shared.restorePurchases()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isRestoringPurchases = false
                    if restored {
                        button.updateText("RESTORED ✓")
                        button.alpha = 0.6
                        button.onTap = nil
                    } else {
                        button.updateText(originalText.isEmpty ? "RESTORE PURCHASES" : originalText)
                        button.isUserInteractionEnabled = true
                        print("ℹ️ Restore purchases: nothing to restore")
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isRestoringPurchases = false
                    button.updateText(originalText.isEmpty ? "RESTORE PURCHASES" : originalText)
                    button.isUserInteractionEnabled = true
                    print("❌ Restore purchases failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func closeSettingsModal() {
        guard settingsModalOpen else { return }
        settingsModalOpen = false
        
        // Remove purchase notification observer
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RemoveAdsPurchased"), object: nil)
        
        // Fade out animation for modal
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.2)
        settingsModalContainer!.run(SKAction.group([fadeOut, scaleDown])) {
            self.settingsModalContainer?.removeFromParent()
            self.settingsModalContainer = nil
            self.settingsCloseButton = nil
            self.soundMuteButton = nil
            self.musicMuteButton = nil
            self.soundVolumeSlider = nil
            self.musicVolumeSlider = nil
            self.removeAdsButton = nil
            self.hapticsToggleButton = nil
            self.restorePurchasesButton = nil
            self.privacyPolicyButton = nil
            self.isRestoringPurchases = false
            self.isPurchasingRemoveAds = false
        }
        
        // Fade out and remove modal view
        if let modalView = settingsModalView {
            UIView.animate(withDuration: 0.2, animations: {
                modalView.alpha = 0
            }) { _ in
                modalView.removeFromSuperview()
            }
            settingsModalView = nil
        }
        
        // Fade out and remove blur view
        if let blurView = settingsBlurView {
            UIView.animate(withDuration: 0.2, animations: {
                blurView.alpha = 0
            }) { _ in
                blurView.removeFromSuperview()
            }
            settingsBlurView = nil
        }
    }

    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://atreidesgames.com/privacy") else { return }
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                print("❌ Unable to open privacy policy URL")
            }
        }
    }
}

// Helper scene class for settings modal content
private class SettingsModalScene: SKScene {
    weak var menuScene: MenuScene?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Forward touches to child nodes (sliders can handle their own touches)
        // But we need to handle button animations
        guard let touch = touches.first, let menuScene = menuScene else { return }
        let location = touch.location(in: self)
        
        // Check sliders first - if they handle the touch, let them
        if let soundSlider = menuScene.soundVolumeSlider {
            let sliderLocation = convert(location, to: soundSlider.parent!)
            let sliderBounds = CGRect(x: soundSlider.position.x - 70, y: soundSlider.position.y - 20, width: 140, height: 40)
            if sliderBounds.contains(sliderLocation) {
                soundSlider.touchesBegan(touches, with: event)
                return
            }
        }
        
        if let musicSlider = menuScene.musicVolumeSlider {
            let sliderLocation = convert(location, to: musicSlider.parent!)
            let sliderBounds = CGRect(x: musicSlider.position.x - 70, y: musicSlider.position.y - 20, width: 140, height: 40)
            if sliderBounds.contains(sliderLocation) {
                musicSlider.touchesBegan(touches, with: event)
                return
            }
        }
        
        // Check for close button
        if let closeButton = menuScene.settingsCloseButton {
            let buttonLocation = convert(location, to: closeButton.parent!)
            if closeButton.contains(point: buttonLocation) {
                closeButton.animatePress()
                return
            }
        }
        
        // Check for mute buttons
        if let soundButton = menuScene.soundMuteButton {
            let buttonLocation = convert(location, to: soundButton.parent!)
            if soundButton.contains(point: buttonLocation) {
                soundButton.animatePress()
                return
            }
        }
        
        if let musicButton = menuScene.musicMuteButton {
            let buttonLocation = convert(location, to: musicButton.parent!)
            if musicButton.contains(point: buttonLocation) {
                musicButton.animatePress()
                return
            }
        }

        if let hapticsButton = menuScene.hapticsToggleButton {
            let buttonLocation = convert(location, to: hapticsButton.parent!)
            if hapticsButton.contains(point: buttonLocation) {
                hapticsButton.animatePress()
                return
            }
        }

        if let removeButton = menuScene.removeAdsButton {
            let buttonLocation = convert(location, to: removeButton.parent!)
            if removeButton.contains(point: buttonLocation) {
                removeButton.animatePress()
                return
            }
        }

        if let restoreButton = menuScene.restorePurchasesButton {
            let buttonLocation = convert(location, to: restoreButton.parent!)
            if restoreButton.contains(point: buttonLocation) {
                restoreButton.animatePress()
                return
            }
        }

        if let privacyButton = menuScene.privacyPolicyButton {
            let buttonLocation = convert(location, to: privacyButton.parent!)
            if privacyButton.contains(point: buttonLocation) {
                privacyButton.animatePress()
                return
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let menuScene = menuScene else { return }
        
        // Always forward to sliders - they'll check if they're being dragged
        if let soundSlider = menuScene.soundVolumeSlider {
            soundSlider.touchesMoved(touches, with: event)
        }
        
        if let musicSlider = menuScene.musicVolumeSlider {
            musicSlider.touchesMoved(touches, with: event)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let menuScene = menuScene else { return }
        let location = touch.location(in: self)
        
        // Check for close button
        if let closeButton = menuScene.settingsCloseButton {
            let buttonLocation = convert(location, to: closeButton.parent!)
            if closeButton.contains(point: buttonLocation) {
                closeButton.animateRelease()
                menuScene.closeSettingsModal()
                return
            }
        }
        
        // Check for mute buttons
        if let soundButton = menuScene.soundMuteButton {
            let buttonLocation = convert(location, to: soundButton.parent!)
            if soundButton.contains(point: buttonLocation) {
                soundButton.animateRelease()
                soundButton.onTap?()
                return
            }
        }
        
        if let musicButton = menuScene.musicMuteButton {
            let buttonLocation = convert(location, to: musicButton.parent!)
            if musicButton.contains(point: buttonLocation) {
                musicButton.animateRelease()
                musicButton.onTap?()
                return
            }
        }

        if let hapticsButton = menuScene.hapticsToggleButton {
            let buttonLocation = convert(location, to: hapticsButton.parent!)
            if hapticsButton.contains(point: buttonLocation) {
                hapticsButton.animateRelease()
                hapticsButton.onTap?()
                return
            }
        }

        if let removeButton = menuScene.removeAdsButton {
            let buttonLocation = convert(location, to: removeButton.parent!)
            if removeButton.contains(point: buttonLocation) {
                removeButton.animateRelease()
                removeButton.onTap?()
                return
            }
        }

        if let restoreButton = menuScene.restorePurchasesButton {
            let buttonLocation = convert(location, to: restoreButton.parent!)
            if restoreButton.contains(point: buttonLocation) {
                restoreButton.animateRelease()
                restoreButton.onTap?()
                return
            }
        }

        if let privacyButton = menuScene.privacyPolicyButton {
            let buttonLocation = convert(location, to: privacyButton.parent!)
            if privacyButton.contains(point: buttonLocation) {
                privacyButton.animateRelease()
                privacyButton.onTap?()
                return
            }
        }
        
        // Forward to sliders
        if let soundSlider = menuScene.soundVolumeSlider {
            soundSlider.touchesEnded(touches, with: event)
        }
        
        if let musicSlider = menuScene.musicVolumeSlider {
            musicSlider.touchesEnded(touches, with: event)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let menuScene = menuScene else { return }
        
        // Forward to sliders
        if let soundSlider = menuScene.soundVolumeSlider {
            soundSlider.touchesCancelled(touches, with: event)
        }
        
        if let musicSlider = menuScene.musicVolumeSlider {
            musicSlider.touchesCancelled(touches, with: event)
        }
    }
}

// Helper scene class for modal content
private class ModalScene: SKScene {
    weak var menuScene: MenuScene?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let menuScene = menuScene else { return }
        let location = touch.location(in: self)
        
        // Check for close button in modal scene
        if let closeButton = menuScene.statsCloseButton {
            let buttonLocation = convert(location, to: closeButton.parent!)
            if closeButton.contains(point: buttonLocation) {
                closeButton.animatePress()
                return
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let menuScene = menuScene else { return }
        let location = touch.location(in: self)
        
        // Check for close button in modal scene
        if let closeButton = menuScene.statsCloseButton {
            let buttonLocation = convert(location, to: closeButton.parent!)
            if closeButton.contains(point: buttonLocation) {
                closeButton.animateRelease()
                menuScene.closeStatsModal()
                return
            }
        }
    }
}
