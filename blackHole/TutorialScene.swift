//
//  TutorialScene.swift
//  blackHole
//
//  Dedicated tutorial environment with controlled step-by-step progression
//

import SpriteKit

// MARK: - Tutorial Step Enum

enum TutorialPhase {
    case welcome           // Initial screen
    case movement          // Learn to move black hole
    case eating            // Eat first star
    case colorMatching     // Learn about color indicator
    case wrongColor        // See what happens with wrong color
    case shrinking         // Explain shrinking mechanic
    case danger            // Learn about too-large stars
    case powerUps          // Explain power-ups
    case complete          // Ready to play!
}

// MARK: - Tutorial Scene

class TutorialScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    
    private var currentPhase: TutorialPhase = .welcome
    private var blackHole: BlackHole!
    private var tutorialStar: Star?
    private var instructionBanner: SKShapeNode?
    private var instructionLabel: SKLabelNode?
    private var fingerIcon: SKShapeNode?
    
    private var tutorialPaused = true
    private var hasPlayerMoved = false
    private var starsEaten = 0
    
    // Tutorial tracking
    private var targetColorStarsEaten = 0
    private var wrongColorStarsEaten = 0
    
    // Starfield background
    private var backgroundLayers: [[SKShapeNode]] = [[], [], []]
    
    // MARK: - Setup
    
    override func didMove(to view: SKView) {
        // Setup scene
        backgroundColor = UIColor.spaceBackground
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        // Setup camera
        let camera = SKCameraNode()
        self.camera = camera
        addChild(camera)
        
        // Use same zoom calculation as the actual game
        let targetZoom = calculateCameraZoom(blackHoleSize: 40.0)
        camera.setScale(targetZoom)
        
        // Create black hole at center
        setupBlackHole()
        
        // Setup starfield background
        setupBackgroundStars()
        
        // Start tutorial
        showWelcomePhase()
    }
    
    private func setupBlackHole() {
        blackHole = BlackHole()
        blackHole.position = CGPoint(x: 0, y: 0)
        blackHole.zPosition = 100
        blackHole.currentDiameter = 40 // Start small
        addChild(blackHole)
        
        // Set initial target to white (matches game default)
        blackHole.updateTargetType(to: .whiteDwarf)
    }
    
    // MARK: - Tutorial Phases
    
    // Phase 0: Welcome
    private func showWelcomePhase() {
        currentPhase = .welcome
        showInstructionBanner(text: "Welcome to Black Hole!")
        
        // Auto-advance after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.advanceToNextPhase()
        }
    }
    
    // Phase 1: Movement
    private func showMovementPhase() {
        currentPhase = .movement
        hasPlayerMoved = false
        
        showInstructionBanner(text: "Drag anywhere to move")
        showFingerDragAnimation()
        // Advances automatically when player moves (in touchesMoved)
    }
    
    // Phase 2: Eating First Star
    private func showEatingPhase() {
        currentPhase = .eating
        // Position star below banner area to avoid overlap
        spawnTutorialStar(type: .whiteDwarf, position: CGPoint(x: 0, y: -100), size: 22)
        blackHole.targetType = .whiteDwarf
        blackHole.updateIndicatorRing()
        showInstructionBanner(text: "Drag to eat the star!")
        // Advances automatically on collision
    }
    
    // Phase 3: Color Matching
    private func showColorMatchingPhase() {
        currentPhase = .colorMatching
        showInstructionBanner(text: "Notice the colored ring? Eat matching colors!")
        
        // Auto-advance after 2 seconds to practice
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showColorMatchingPractice()
        }
    }
    
    private func showColorMatchingPractice() {
        // Change target to yellow
        blackHole.targetType = .yellowDwarf
        blackHole.updateIndicatorRing()
        
        // Spawn matching yellow star - position to avoid banner and stay on screen
        spawnTutorialStar(
            type: .yellowDwarf,
            position: CGPoint(x: 80, y: -50),
            size: 35
        )
        
        showInstructionBanner(text: "Now eat the YELLOW star to match your ring!")
        // Advances automatically on collision
    }
    
    // Phase 4: Wrong Color Consequence
    private func showWrongColorPhase() {
        currentPhase = .wrongColor
        showInstructionBanner(text: "Perfect! But what if you eat the WRONG color?")
        
        // Auto-advance after 2 seconds to practice
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showWrongColorPractice()
        }
    }
    
    private func showWrongColorPractice() {
        // Keep target as yellow
        blackHole.targetType = .yellowDwarf
        blackHole.updateIndicatorRing()
        
        // Spawn a WHITE star (wrong color) - position to avoid banner
        spawnTutorialStar(
            type: .whiteDwarf,
            position: CGPoint(x: -80, y: -50),
            size: 22
        )
        
        showInstructionBanner(text: "⚠️ Try eating the WHITE star (even though your ring is yellow)")
        // Advances automatically on collision
    }
    
    private func explainWrongColorResult() {
        currentPhase = .shrinking
        showInstructionBanner(text: "Wrong color = You SHRINK! Always match your ring color to grow bigger.")
        
        // Auto-advance after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.advanceToNextPhase()
        }
    }
    
    // Phase 5: Shrinking Over Time
    private func showShrinkingPhase() {
        currentPhase = .shrinking
        showInstructionBanner(text: "Black holes naturally shrink over time. Keep eating to maintain your size!")
        
        // Auto-advance after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.advanceToNextPhase()
        }
    }
    
    // Phase 6: Danger - Too Large Stars
    private func showDangerPhase() {
        currentPhase = .danger
        
        // Spawn a LARGE star that player can't eat - position to avoid banner and stay on screen
        let largeStar = Star(type: .blueGiant)
        largeStar.size = CGSize(width: 80, height: 80) // Much bigger than player
        largeStar.position = CGPoint(x: 60, y: -50)  // Closer to center to stay on screen
        largeStar.zPosition = 10
        
        // Setup physics
        largeStar.physicsBody = SKPhysicsBody(circleOfRadius: 40)
        largeStar.physicsBody?.isDynamic = false
        largeStar.physicsBody?.categoryBitMask = GameConstants.starCategory
        largeStar.physicsBody?.contactTestBitMask = GameConstants.blackHoleCategory
        
        // Add warning glow immediately
        addWarningGlow(to: largeStar)
        
        addChild(largeStar)
        tutorialStar = largeStar
        
        showInstructionBanner(text: "⚠️ RED GLOW = TOO BIG! If a star is larger than you, AVOID IT or you'll die!")
        
        // Auto-advance after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.advanceToNextPhase()
        }
        
        // Pulse haptic warning
        HapticManager.shared.playWarning()
    }
    
    // Phase 7: Power-Ups
    private func showPowerUpsPhase() {
        currentPhase = .powerUps
        
        // Clean up danger star
        tutorialStar?.removeFromParent()
        tutorialStar = nil
        
        // Show real power-up
        let tutorialPowerUp = createTutorialPowerUp()
        addChild(tutorialPowerUp)
        
        showInstructionBanner(text: "Colorful comets are POWER-UPS! 🌈 Rainbow = Eat any color ❄️ Freeze = Stars stop moving")
        
        // Auto-advance after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.advanceToNextPhase()
        }
    }
    
    // Phase 8: Complete
    private func showCompletePhase() {
        currentPhase = .complete
        
        // Clean up
        tutorialStar?.removeFromParent()
        children.filter { $0.name == "tutorialPowerUp" }.forEach { $0.removeFromParent() }
        
        showInstructionBanner(text: "You're ready! 🌟 Survive as long as possible and get the highest score!")
        
        // Auto-advance after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.transitionToGame()
        }
    }
    
    // MARK: - UI Creation
    
    private func showInstructionBanner(text: String) {
        // Remove old banner
        instructionBanner?.removeFromParent()
        instructionLabel?.removeFromParent()
        
        guard let camera = self.camera else { return }
        
        // Create banner background
        let bannerWidth: CGFloat = min(350, UIScreen.main.bounds.width - 40)
        let bannerHeight: CGFloat = 120
        
        let bannerBackground = SKShapeNode(rectOf: CGSize(width: bannerWidth, height: bannerHeight), cornerRadius: 12)
        bannerBackground.fillColor = UIColor.black.withAlphaComponent(0.8)
        bannerBackground.strokeColor = .white
        bannerBackground.lineWidth = 2
        // Position below Dynamic Island (same margin as score label)
        let topMargin: CGFloat = 70  // GameConstants.scoreLabelTopMargin
        bannerBackground.position = CGPoint(x: 0, y: UIScreen.main.bounds.height / 2 - topMargin - 60)
        bannerBackground.zPosition = 1000
        
        // Create text label with wrapping
        let label = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = bannerWidth - 40
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        label.zPosition = 1001
        
        bannerBackground.addChild(label)
        camera.addChild(bannerBackground)
        
        instructionBanner = bannerBackground
        instructionLabel = label
        
        // Fade in animation
        bannerBackground.alpha = 0
        bannerBackground.run(SKAction.fadeIn(withDuration: 0.3))
    }
    
    
    private func showFingerDragAnimation() {
        // Create finger icon
        let finger = SKShapeNode(circleOfRadius: 25)
        finger.fillColor = UIColor.white.withAlphaComponent(0.7)
        finger.strokeColor = UIColor.systemBlue
        finger.lineWidth = 3
        finger.position = CGPoint(x: blackHole.position.x, y: blackHole.position.y - 80)
        finger.zPosition = 999
        finger.name = "fingerIcon"
        
        // Add tip indicator
        let tip = SKShapeNode(circleOfRadius: 10)
        tip.fillColor = .systemBlue
        tip.position = .zero
        finger.addChild(tip)
        
        addChild(finger)
        fingerIcon = finger
        
        // Animation: drag up and down
        let moveUp = SKAction.moveBy(x: 0, y: 80, duration: 1.0)
        let moveDown = SKAction.moveBy(x: 0, y: -80, duration: 1.0)
        let wait = SKAction.wait(forDuration: 0.3)
        let sequence = SKAction.sequence([moveUp, wait, moveDown, wait])
        
        finger.run(SKAction.repeatForever(sequence))
    }
    
    private func addWarningGlow(to star: Star) {
        // Create red pulsing warning ring
        let warningRing = SKShapeNode(circleOfRadius: star.size.width / 2 + 10)
        warningRing.strokeColor = UIColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 0.8)
        warningRing.fillColor = .clear
        warningRing.lineWidth = 3
        warningRing.glowWidth = 8
        warningRing.zPosition = -1
        warningRing.name = "warningGlow"
        
        // Pulsing animation
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.3)
        let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: 0.3)
        warningRing.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
        
        star.addChild(warningRing)
    }
    
    private func createTutorialPowerUp() -> PowerUp {
        // Create a stationary rainbow power-up for demonstration
        let trajectory = CometTrajectory.topLeftToBottomRight  // Doesn't matter since it's stationary
        let powerUp = PowerUp(type: .rainbow, trajectory: trajectory)
        powerUp.position = CGPoint(x: 0, y: -100)  // Position below banner area
        powerUp.zPosition = 200
        powerUp.name = "tutorialPowerUp"
        return powerUp
    }
    
    // MARK: - Starfield Background
    
    private func setupBackgroundStars() {
        // Multi-layer parallax starfield for realistic depth
        
        // Layer 0: Distant stars (darkest, slowest parallax)
        createStarLayer(
            count: 400,  // DOUBLED for much richer starfield
            sizeRange: 0.5...1.0,  // Smaller for point-light appearance
            alphaRange: 0.3...0.5,  // Brighter for visibility
            useColorVariety: true,
            zPosition: -30,
            layerIndex: 0
        )
        
        // Layer 1: Mid-distance stars (moderate brightness and parallax)
        createStarLayer(
            count: 250,  // More than doubled for density
            sizeRange: 1.0...1.5,  // Smaller for point-light appearance
            alphaRange: 0.5...0.7,  // Brighter
            useColorVariety: true,
            zPosition: -20,
            layerIndex: 1
        )
        
        // Layer 2: Near stars (brightest, fastest parallax)
        createStarLayer(
            count: 150,  // Nearly doubled for better foreground
            sizeRange: 1.5...2.0,  // Smaller for point-light appearance
            alphaRange: 0.7...0.9,  // Much brighter for visibility
            useColorVariety: false,  // Near stars stay white for clarity
            zPosition: -10,
            layerIndex: 2
        )
    }
    
    private func createStarLayer(count: Int, sizeRange: ClosedRange<CGFloat>,
                                alphaRange: ClosedRange<CGFloat>, useColorVariety: Bool,
                                zPosition: CGFloat, layerIndex: Int) {
        let spread: CGFloat = 600  // Stars spawn within wrap zone for stable field
        
        // Realistic star color palette (mostly white, some tinted)
        let starColors: [(UIColor, CGFloat)] = [
            (.white, 0.65),                                                      // 65% white
            (UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0), 0.15),      // 15% blue-white
            (UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0), 0.12),     // 12% yellow-white
            (UIColor(red: 1.0, green: 0.85, blue: 0.7, alpha: 1.0), 0.05),     // 5% orange
            (UIColor(red: 1.0, green: 0.7, blue: 0.7, alpha: 1.0), 0.03)       // 3% red
        ]
        
        for _ in 0..<count {
            let starSize = CGFloat.random(in: sizeRange)
            let color = useColorVariety ? selectWeightedStarColor(colors: starColors) : .white
            
            // Create circular star with soft glow for point-light appearance
            let star = SKShapeNode(circleOfRadius: starSize / 2)
            star.fillColor = color
            star.strokeColor = .clear
            star.glowWidth = starSize * 0.3  // Soft glow effect
            star.blendMode = .add  // Additive blending for light effect
            
            // Store base position in userData for parallax calculation
            let baseX = CGFloat.random(in: -spread...spread)
            let baseY = CGFloat.random(in: -spread...spread)
            
            star.userData = [
                "baseX": baseX,
                "baseY": baseY
            ]
            
            star.position = CGPoint(x: baseX, y: baseY)
            star.alpha = CGFloat.random(in: alphaRange)
            star.zPosition = zPosition
            addChild(star)
            backgroundLayers[layerIndex].append(star)
            
            // Slower, subtler twinkle for background (won't distract)
            let twinkleDuration = Double.random(in: 2...5)
            let fadeOut = SKAction.fadeAlpha(to: alphaRange.lowerBound, duration: twinkleDuration)
            let fadeIn = SKAction.fadeAlpha(to: star.alpha, duration: twinkleDuration)
            star.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
        }
    }
    
    private func selectWeightedStarColor(colors: [(UIColor, CGFloat)]) -> UIColor {
        let random = CGFloat.random(in: 0...1)
        var cumulative: CGFloat = 0
        
        for (color, weight) in colors {
            cumulative += weight
            if random <= cumulative {
                return color
            }
        }
        
        return .white  // Fallback
    }
    
    private func updateParallaxBackground() {
        guard let camera = camera else { return }
        let cameraPos = camera.position
        
        // Different parallax speeds for each layer (slower = more distant)
        let parallaxSpeeds: [CGFloat] = [0.02, 0.05, 0.1]
        
        for (index, layer) in backgroundLayers.enumerated() {
            let speed = parallaxSpeeds[index]
            for star in layer {
                if let baseX = star.userData?["baseX"] as? CGFloat,
                   let baseY = star.userData?["baseY"] as? CGFloat {
                    star.position = CGPoint(
                        x: baseX - cameraPos.x * speed,
                        y: baseY - cameraPos.y * speed
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func spawnTutorialStar(type: StarType, position: CGPoint, size: CGFloat) {
        
        let star = Star(type: type)
        star.size = CGSize(width: size, height: size)
        star.position = position
        star.zPosition = 10
        
        // Setup physics
        star.physicsBody = SKPhysicsBody(circleOfRadius: size / 2)
        star.physicsBody?.isDynamic = false
        star.physicsBody?.categoryBitMask = GameConstants.starCategory
        star.physicsBody?.contactTestBitMask = GameConstants.blackHoleCategory
        star.physicsBody?.collisionBitMask = 0
        
        addChild(star)
        tutorialStar = star
        
        // Gentle pulsing to draw attention
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.8)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.8)
        star.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
    }
    
    private func removeTutorialStar() {
        tutorialStar?.removeFromParent()
        tutorialStar = nil
    }
    
    private func advanceToNextPhase() {
        // Remove finger icon if exists
        fingerIcon?.removeFromParent()
        fingerIcon = nil
        
        
        switch currentPhase {
        case .welcome:
            showMovementPhase()
            
        case .movement:
            if hasPlayerMoved {
                showEatingPhase()
            }
            
        case .eating:
            showColorMatchingPhase()
            
        case .colorMatching:
            showColorMatchingPractice()
            
        case .wrongColor:
            showWrongColorPractice()
            
        case .shrinking:
            showDangerPhase()
            
        case .danger:
            showPowerUpsPhase()
            
        case .powerUps:
            showCompletePhase()
            
        case .complete:
            transitionToGame()
        }
    }
    
    private func transitionToGame() {
        // Mark tutorial as complete
        UserDefaults.standard.set(true, forKey: "hasPlayedBefore")
        
        // Transition to main game
        let gameScene = GameScene(size: self.size)
        gameScene.scaleMode = .aspectFill
        
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        updateParallaxBackground()
    }
    
    // MARK: - Camera Zoom
    
    private func calculateCameraZoom(blackHoleSize: CGFloat) -> CGFloat {
        // Keep black hole at constant screen percentage (same as GameScene)
        let screenHeight = size.height
        let targetPercentage = GameConstants.cameraZoomTargetPercentage
        
        // Calculate required zoom to maintain size
        // In SpriteKit: scale > 1.0 = zoomed out (see more)
        let zoomFactor = blackHoleSize / (screenHeight * targetPercentage)
        
        // Clamp between min and max zoom
        // Min 0.5 = most zoomed in, Max 4.0 = most zoomed out
        return max(GameConstants.cameraMinZoom, min(GameConstants.cameraMaxZoom, zoomFactor))
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Movement is handled in touchesMoved
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Move black hole
        blackHole.position = location
        
        // Track first movement for tutorial progression
        if currentPhase == .movement && !hasPlayerMoved {
            hasPlayerMoved = true
            showInstructionBanner(text: "Great! ✓")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.advanceToNextPhase()
            }
        }
    }
    
    // MARK: - Physics Contact
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == GameConstants.blackHoleCategory | GameConstants.starCategory {
            let starBody = contact.bodyA.categoryBitMask == GameConstants.starCategory ? contact.bodyA : contact.bodyB
            
            guard let star = starBody.node as? Star else { return }
            guard star == tutorialStar else { return }
            
            handleStarCollision(star: star)
        }
    }
    
    private func handleStarCollision(star: Star) {
        let canEat = star.size.width < blackHole.currentDiameter
        let isCorrectColor = star.starType == blackHole.targetType
        
        
        guard canEat else {
            // This shouldn't happen in tutorial, but just in case
            return
        }
        
        if isCorrectColor {
            // Grow black hole
            let newDiameter = blackHole.currentDiameter + star.size.width * 0.15
            blackHole.updateSize(to: newDiameter)
            
            // Success feedback
            showParticleEffect(at: star.position, color: star.starType.uiColor)
            HapticManager.shared.playSuccess()
            AudioManager.shared.playCorrectSound()
            
            // Track progress
            targetColorStarsEaten += 1
            
            // Remove star
            star.removeFromParent()
            tutorialStar = nil
            
            // Handle phase progression
            handleSuccessfulEat()
            
        } else {
            // Shrink black hole
            let newDiameter = blackHole.currentDiameter - star.size.width * 0.1
            blackHole.updateSize(to: newDiameter)
            
            // Wrong color feedback
            showParticleEffect(at: star.position, color: .red)
            HapticManager.shared.playError()
            AudioManager.shared.playWrongSound()
            
            // Track
            wrongColorStarsEaten += 1
            
            // Remove star
            star.removeFromParent()
            tutorialStar = nil
            
            // Show explanation
            explainWrongColorResult()
        }
    }
    
    private func handleSuccessfulEat() {
        switch currentPhase {
        case .eating:
            showInstructionBanner(text: "Perfect! ✓")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.advanceToNextPhase()
            }
            
        case .colorMatching:
            showInstructionBanner(text: "Excellent! ✓")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showWrongColorPhase()
            }
            
        default:
            break
        }
    }
    
    private func showParticleEffect(at position: CGPoint, color: UIColor) {
        // Simple particle burst
        for _ in 0..<15 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 500
            
            addChild(particle)
            
            // Random direction
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 30...80)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.4)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            let remove = SKAction.removeFromParent()
            
            particle.run(SKAction.sequence([SKAction.group([move, fade]), remove]))
        }
    }
    
    // MARK: - Update
}
