//
//  GameScene.swift
//  blackHole
//
//  Main gameplay scene
//

import SpriteKit
import GameplayKit
import UIKit
import AVFoundation

class ActivePowerUpState {
    var activeType: PowerUpType?
    var expirationTime: TimeInterval = 0
    var indicatorNode: SKNode?
    
    func activate(type: PowerUpType, currentTime: TimeInterval) {
        activeType = type
        expirationTime = currentTime + type.duration
    }
    
    func isActive() -> Bool {
        return activeType != nil
    }
    
    func getRemainingTime(currentTime: TimeInterval) -> TimeInterval {
        guard isActive() else { return 0 }
        return max(0, expirationTime - currentTime)
    }
    
    func checkExpiration(currentTime: TimeInterval) -> Bool {
        guard isActive() else { return false }
        
        if currentTime >= expirationTime {
            return true  // Don't deactivate yet - let handlePowerUpExpiration do it
        }
        return false
    }
    
    func deactivate() {
        activeType = nil
        expirationTime = 0
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    
    var blackHole: BlackHole!
    var stars: [Star] = []  // Internal access for StarFieldManager
    private var cameraNode: SKCameraNode!
    private var hudNode: SKNode!
    private var backgroundLayers: [[SKNode]] = [[], [], []]  // Far, mid, near layers
    private var nebulaNode: SKSpriteNode?  // Distant nebula gradient for atmosphere
    
    var powerUpManager: PowerUpManager!
    var activePowerUp = ActivePowerUpState()
    
    private let movementTracker = MovementTracker(historySize: GameConstants.movementHistorySize, 
                                                   speedThreshold: GameConstants.movementSpeedThreshold)
    private var starFieldManager: StarFieldManager!
    private var lastStarFieldSpawn: TimeInterval = 0
    
    private var starSpawnTimer: Timer?
    private var colorChangeTimer: Timer?
    private var colorChangeWarningTimer: Timer?
    private var remainingColorChangeTime: TimeInterval?
    private var remainingWarningTime: TimeInterval?
    private var warningWasActive = false
    private var colorChangeTimerStartDate: Date?
    private var colorChangeTimerInterval: TimeInterval?
    private var pendingColorChangeType: StarType?
    
    // Grace period tracking
    private var lastCorrectEatTime: TimeInterval = 0
    private var gameStartTime: TimeInterval = 0
    private let SOUND_GRACE_PERIOD: TimeInterval = 1.0  // 1 second grace period for all sounds at game start
    
    fileprivate var restartButton: MenuButton?
    private var hasTappedRestartButton = false
    fileprivate var returnToMenuButton: MenuButton?
    fileprivate var gameOverLabel: SKLabelNode?
    fileprivate var finalScoreLabel: SKLabelNode?
    private var scoreLabel: SKLabelNode!
    
    private var isGameOver = false
    private var gameOverReason: String?
    private var hasShownGameOverUI = false  // Track if game over UI has been displayed
    
    // Pause system
    private var isGamePaused = false
    private var pauseOverlay: SKSpriteNode?
    private var fingerLiftTime: TimeInterval = 0
    private let PAUSE_DELAY: TimeInterval = 0.2  // Delay before pause triggers
    
    // Passive shrink system
    private var lastShrinkTime: TimeInterval = 0
    private var shrinkIndicatorContainer: SKShapeNode?
    private var shrinkIndicatorFill: SKShapeNode?
    private var peakBlackHoleSize: CGFloat = 40.0  // Track the highest size achieved
    
    // Achievement tracking (per-game)
    private var hasReachedSize1000 = false
    private var hasShrunkThisGame = false
    
    private var mergedStarCount: Int = 0
    private var lastMergeTime: TimeInterval = 0
    private var sessionStartTime: TimeInterval = 0
    
    // Touch tracking for preventing accidental touches
    private var isBlackHoleBeingMoved = false
    private var activeTouch: UITouch?
    
    // Performance monitoring
    private var recentFrameTimes: [TimeInterval] = []
    private var lastFrameTime: TimeInterval = 0
    private var performanceMode: PerformanceMode = .high
    
    enum PerformanceMode {
        case high, medium, low
    }
    
    // Retro Aesthetic System
    private var retroManager = RetroAestheticManager.shared
    private var currentColorProfile = GameConstants.RetroAestheticSettings.defaultColorProfile
    private var colorGradingNode: SKEffectNode?
    
    // Tutorial tip tracking
    private var hasShownMovementTip = false
    private var hasShownShrinkGaugeTip = false
    private var hasShownWrongColorTip = false
    private var hasShownDangerStarTip = false
    private var hasShownPowerUpTip = false
    private var tipBannerNode: SKNode?
    
    private var gameOverBlurView: UIVisualEffectView?
    private var gameOverOverlayView: SKView?
    private weak var gameOverOverlayScene: GameOverOverlayScene?
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        // ❌ REMOVED: TextureCache.shared.preloadAllTextures()
        // Textures are already being preloaded in background from AppDelegate
        // This was causing 38-second freeze when starting game!
        // Textures will load on-demand if not ready yet (SpriteKit handles this gracefully)
        
        // Track session start time for stats
        sessionStartTime = CACurrentMediaTime()
        gameStartTime = CACurrentMediaTime()  // Track game start for sound grace period
        
        setupScene()
        setupCamera()
        setupBackgroundStars()
        setupBlackHole()
        setupPowerUpSystem()
        setupUI()
        setupPowerUpUI()
        setupShrinkIndicator()
        setupRetroAesthetics()
        startGameTimers()
        
        // Initialize background star positions relative to camera
        updateBackgroundStars()
        
        // Show movement tip on first play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAndShowMovementTip()
        }
        
        // Enable proximity sounds after 5 second grace period
        AudioManager.shared.enableProximitySounds()
        
        // Switch to game music (5 layers - all start playing, only layer 1 unmuted)
        AudioManager.shared.switchToGameMusic()
        
        // Initialize music layers for starting size (Phase 1)
        AudioManager.shared.updateMusicLayersForSize(blackHole.currentDiameter)
        
        // Removed positional audio listener (no panning for proximity)
        
        // Reset achievement tracking
        hasReachedSize1000 = false
        hasShrunkThisGame = false
        
        // Hide access point during gameplay
        GameCenterManager.shared.hideAccessPoint()
    }
    
    private func setupPowerUpSystem() {
        let currentTime = CACurrentMediaTime()
        powerUpManager = PowerUpManager(gameStartTime: currentTime)
        powerUpManager.scene = self
        
        // Initialize star field manager
        starFieldManager = StarFieldManager()
        starFieldManager.scene = self
    }
    
    private func setupScene() {
        backgroundColor = UIColor.spaceBackground
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        
        // Setup nebula gradient background
        setupNebula()
    }
    
    private func setupNebula() {
        // Create subtle nebula gradient texture
        let nebulaTexture = createNebulaTexture()
        nebulaNode = SKSpriteNode(texture: nebulaTexture)
        nebulaNode?.size = CGSize(width: 3000, height: 3000)
        nebulaNode?.position = CGPoint.zero
        nebulaNode?.zPosition = -50  // Behind all stars
        nebulaNode?.alpha = 0.35  // Very subtle
        nebulaNode?.blendMode = .alpha
        addChild(nebulaNode!)
    }
    
    private func createNebulaTexture() -> SKTexture {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Create radial gradient (dark purple center fading to transparent)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 0.1, green: 0.04, blue: 0.18, alpha: 1.0).cgColor,  // Dark purple center
                UIColor(red: 0.08, green: 0.05, blue: 0.15, alpha: 0.8).cgColor, // Mid purple
                UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.4).cgColor, // Darker mid
                UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 0.0).cgColor  // Transparent edge
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
    
    private func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        
        // Create HUD node that stays with camera
        hudNode = SKNode()
        cameraNode.addChild(hudNode)
    }
    
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
        return colors[0].0  // Fallback to white
    }
    
    private func updateBackgroundStars() {
        // Update nebula with very slow parallax
        nebulaNode?.position = CGPoint(
            x: cameraNode.position.x * 0.1,
            y: cameraNode.position.y * 0.1
        )
        
        let parallaxFactors: [CGFloat] = [0.3, 0.6, 1.0]  // How much each layer moves with camera
        let wrapDistance: CGFloat = 700  // When to wrap stars (reduced for denser starfield)
        
        for (layerIndex, layer) in backgroundLayers.enumerated() {
            let parallaxFactor = parallaxFactors[layerIndex]
            
            for star in layer {
                // Get star's base world position
                guard let baseX = star.userData?["baseX"] as? CGFloat,
                      let baseY = star.userData?["baseY"] as? CGFloat else { continue }
                
                // Calculate parallax offset from camera position
                // Far stars (0.3) move only 30% as much as camera = slower = more distant
                let offsetX = cameraNode.position.x * (1 - parallaxFactor)
                let offsetY = cameraNode.position.y * (1 - parallaxFactor)
                
                // Position star in world space with parallax offset
                star.position = CGPoint(
                    x: baseX - offsetX,
                    y: baseY - offsetY
                )
                
                // Wrap stars that go too far from camera
                var newBaseX = baseX
                var newBaseY = baseY
                
                let distFromCamera = hypot(star.position.x - cameraNode.position.x,
                                          star.position.y - cameraNode.position.y)
                
                if distFromCamera > wrapDistance {
                    // Star is too far - wrap it to opposite side
                    let angle = atan2(star.position.y - cameraNode.position.y,
                                     star.position.x - cameraNode.position.x)
                    let oppositeAngle = angle + .pi
                    let wrapRadius: CGFloat = 500  // Less than wrapDistance to prevent re-wrapping
                    
                    // Calculate new base position (reverse the parallax math)
                    newBaseX = cameraNode.position.x + cos(oppositeAngle) * wrapRadius + offsetX
                    newBaseY = cameraNode.position.y + sin(oppositeAngle) * wrapRadius + offsetY
                    
                    star.userData?["baseX"] = newBaseX
                    star.userData?["baseY"] = newBaseY
                }
            }
        }
    }
    
    private func setupBlackHole() {
        blackHole = BlackHole()
        blackHole.position = CGPoint.zero // Start at world origin
        blackHole.zPosition = 10
        addChild(blackHole)
        
        // Set initial target color from available types
        let availableTypes = getAvailableStarTypes()
        let initialType = availableTypes.randomElement() ?? .whiteDwarf
        blackHole.updateTargetType(to: initialType)
        
        // Position camera at black hole
        cameraNode.position = blackHole.position
    }
    
    private func setupUI() {
        // Score label - attached to HUD (camera)
        scoreLabel = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        scoreLabel.fontSize = GameConstants.scoreFontSize
        scoreLabel.fontColor = .white
        
        // Position relative to camera view using screen bounds (not world size)
        let screenSize = UIScreen.main.bounds.size
        let xOffset = -screenSize.width / 2 + GameConstants.scoreLabelLeftMargin
        let yOffset = screenSize.height / 2 - GameConstants.scoreLabelTopMargin - GameConstants.scoreFontSize
        scoreLabel.position = CGPoint(x: xOffset, y: yOffset)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.zPosition = 100
        
        // Add stroke effect
        let strokeLabel = SKLabelNode(fontNamed: scoreLabel.fontName)
        strokeLabel.fontSize = scoreLabel.fontSize
        strokeLabel.fontColor = .black
        strokeLabel.position = CGPoint.zero
        strokeLabel.horizontalAlignmentMode = .left
        strokeLabel.zPosition = -1
        scoreLabel.addChild(strokeLabel)
        
        updateScoreLabel()
        hudNode.addChild(scoreLabel)
    }
    
    private func setupPowerUpUI() {
        // Container for power-up indicator (top-left, below score, accounting for Dynamic Island)
        let container = SKNode()
        // Position relative to camera view using screen bounds (not world size)
        let screenSize = UIScreen.main.bounds.size
        let xOffset = -screenSize.width / 2 + 70  // Left side, with padding
        let yOffset = screenSize.height / 2 - 140  // Below score (70pt margin + 24pt font + 46pt spacing)
        container.position = CGPoint(x: xOffset, y: yOffset)
        container.name = "powerUpContainer"
        hudNode.addChild(container)
        
        // Icon background
        let iconBg = SKShapeNode(circleOfRadius: 25)
        iconBg.fillColor = UIColor.black.withAlphaComponent(0.5)
        iconBg.strokeColor = .white
        iconBg.lineWidth = 2
        iconBg.name = "powerUpIconBg"
        container.addChild(iconBg)
        
        // Timer label
        let timerLabel = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        timerLabel.fontSize = 16
        timerLabel.fontColor = .white
        timerLabel.position = CGPoint(x: 0, y: -40)
        timerLabel.name = "powerUpTimer"
        container.addChild(timerLabel)
        
        activePowerUp.indicatorNode = container
        container.isHidden = true
    }
    
    private func setupShrinkIndicator() {
        let screenSize = UIScreen.main.bounds.size
        let xPos = screenSize.width / 2 - GameConstants.shrinkIndicatorRightMargin - GameConstants.shrinkIndicatorRadius
        let yPos = screenSize.height / 2 - GameConstants.shrinkIndicatorTopMargin - GameConstants.shrinkIndicatorRadius
        
        // Outer container ring (static) - always visible
        shrinkIndicatorContainer = SKShapeNode(circleOfRadius: GameConstants.shrinkIndicatorRadius)
        shrinkIndicatorContainer!.fillColor = .clear
        shrinkIndicatorContainer!.strokeColor = UIColor.white.withAlphaComponent(0.9)
        shrinkIndicatorContainer!.lineWidth = 2
        shrinkIndicatorContainer!.position = CGPoint(x: xPos, y: yPos)
        shrinkIndicatorContainer!.zPosition = 100
        hudNode.addChild(shrinkIndicatorContainer!)
        
        // Inner fill circle (shrinks with black hole size) - SAME SIZE as outline when full
        shrinkIndicatorFill = SKShapeNode(circleOfRadius: GameConstants.shrinkIndicatorRadius)
        shrinkIndicatorFill!.fillColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.8)  // Cyan
        shrinkIndicatorFill!.strokeColor = .clear
        shrinkIndicatorFill!.position = CGPoint(x: xPos, y: yPos)
        shrinkIndicatorFill!.zPosition = 101
        hudNode.addChild(shrinkIndicatorFill!)
    }
    
    // MARK: - Retro Aesthetic Setup
    
    private func setupRetroAesthetics() {
        // Check master toggle first
        guard GameConstants.RetroAestheticSettings.enableRetroAesthetics else {
            print("🎨 Retro aesthetics DISABLED via master toggle")
            return
        }
        
        // Only setup if at least one effect is enabled
        guard GameConstants.RetroAestheticSettings.enableFilmGrain ||
              GameConstants.RetroAestheticSettings.enableVignette ||
              GameConstants.RetroAestheticSettings.enableRimLighting else {
            print("🎨 All retro effects disabled in constants")
            return
        }
        
        print("🎨 Setting up retro aesthetics...")
        
        // Setup film grain and vignette
        retroManager.setupRetroEffects(in: self)
        
        // Setup color grading (if enabled)
        if GameConstants.RetroAestheticSettings.enableColorGrading {
            setupColorGrading()
        }
        
        // Adjust existing elements (keep very subtle)
        applyRetroStyling()
        
        print("🎨 Retro aesthetics setup complete")
    }
    
    private func setupColorGrading() {
        // Create effect node for color grading
        colorGradingNode = SKEffectNode()
        colorGradingNode?.shouldEnableEffects = true
        
        // Apply color grading filter
        let colorFilter = CIFilter(name: "CIColorControls")
        let profile = currentColorProfile.adjustments
        colorFilter?.setValue(profile.saturation, forKey: kCIInputSaturationKey)
        colorFilter?.setValue(profile.contrast, forKey: kCIInputContrastKey)
        
        colorGradingNode?.filter = colorFilter
        
        // Note: For full color grading, would need to reparent scene content under this node
        // For now, we're applying the effect through the existing visual enhancements
    }
    
    private func applyRetroStyling() {
        // Keep the original pure black background - don't darken it
        // backgroundColor stays as UIColor.spaceBackground (pure black)
        
        // DON'T reduce background star brightness - they need to stay visible
        // The grain and vignette will provide the atmosphere
        
        // Enhance nebula contrast slightly
        nebulaNode?.alpha = 0.4
        nebulaNode?.colorBlendFactor = 0.2
        nebulaNode?.color = currentColorProfile.adjustments.shadows
    }
    
    private func updateRetroEffects(_ currentTime: TimeInterval) {
        // Dynamic rim light based on black hole size
        let sizeFactor = blackHole.currentDiameter / 300.0
        blackHole.retroRimLight?.alpha = RetroAestheticManager.Config.rimLightIntensity * min(sizeFactor, 1.5)
        
        // Adjust grain intensity based on action
        if stars.count > 15 {
            retroManager.grainOverlay?.alpha = RetroAestheticManager.Config.grainIntensity * 1.2
        } else {
            retroManager.grainOverlay?.alpha = RetroAestheticManager.Config.grainIntensity
        }
    }
    
    private func startGameTimers() {
        // Spawn initial stars immediately for better UX
        spawnInitialStars()
        
        // Dynamic spawn timer that adjusts with black hole size
        scheduleNextStarSpawn()
        
        // Color change timer with random intervals
        scheduleNextColorChange()
    }
    
    private func spawnInitialStars() {
        // Guarantee 3-5 stars at game start
        let initialStarCount = Int.random(in: 3...5)
        
        for _ in 0..<initialStarCount {
            let starType = selectStarType()
            let star = Star(type: starType)
            
            // Assign unique name for haptic tracking
            star.name = "star_\(UUID().uuidString)"
            
            // Spawn in a ring around player (250-400pt away)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 250...400)
            
            star.position = CGPoint(
                x: blackHole.position.x + cos(angle) * distance,
                y: blackHole.position.y + sin(angle) * distance
            )
            
            // Fade in animation
            star.alpha = 0
            star.setScale(0.3)
            let fadeIn = SKAction.fadeIn(withDuration: GameConstants.starSpawnAnimationDuration)
            let scaleUp = SKAction.scale(to: 1.0, duration: GameConstants.starSpawnAnimationDuration)
            star.run(SKAction.group([fadeIn, scaleUp]))
            
            addChild(star)
            stars.append(star)
        }
        
        print("🌟 Spawned \(initialStarCount) initial stars")
    }
    
    private func scheduleNextStarSpawn() {
        let interval = calculateSpawnInterval()
        
        starSpawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.spawnStar()
            self?.scheduleNextStarSpawn()  // Reschedule with updated interval
        }
    }
    
    private func scheduleNextColorChange() {
        // Random interval between min and max
        let interval = TimeInterval.random(in: GameConstants.colorChangeMinInterval...GameConstants.colorChangeMaxInterval)
        colorChangeTimerInterval = interval
        colorChangeTimerStartDate = Date()
        remainingColorChangeTime = nil
        remainingWarningTime = nil
        warningWasActive = false
        
        // Store current target type to check if it will actually change
        let currentTargetType = blackHole.targetType
        
        // Check what the new color will be (do this now, not in the timer closure)
        let availableTypes = getAvailableStarTypes()
        let newType: StarType
        
        if availableTypes.count > 1 {
            let differentTypes = availableTypes.filter { $0 != blackHole.targetType }
            newType = differentTypes.randomElement() ?? availableTypes.randomElement() ?? .whiteDwarf
        } else {
            newType = availableTypes.first ?? .whiteDwarf
        }
        
        pendingColorChangeType = newType
        
        // Only warn and change if the color is actually changing
        if newType != currentTargetType {
            // Schedule warning to start before the actual change
            let warningStartTime = interval - GameConstants.colorChangeWarningDuration
            
            // Start blinking warning if there's enough time for the warning
            if warningStartTime > 0 {
                // Invalidate any existing warning timer first
                colorChangeWarningTimer?.invalidate()
                
                colorChangeWarningTimer = Timer.scheduledTimer(withTimeInterval: warningStartTime, repeats: false) { [weak self] _ in
                    self?.startColorChangeWarning()
                }
            }
        }
        
        colorChangeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.remainingColorChangeTime = nil
            self.remainingWarningTime = nil
            self.warningWasActive = false
            
            // Only change color if it's actually different
            if newType != currentTargetType {
                self.stopColorChangeWarning()
                self.blackHole.updateTargetType(to: newType)
            }
            
            self.pendingColorChangeType = nil
            self.scheduleNextColorChange()  // Reschedule with new random interval
        }
    }
    
    private func calculateSpawnInterval() -> TimeInterval {
        let size = blackHole.currentDiameter
        
        // No acceleration until threshold
        guard size >= GameConstants.spawnAccelerationThreshold else {
            return GameConstants.baseStarSpawnInterval
        }
        
        // Progressive acceleration formula
        let accelerationFactor = (size - GameConstants.spawnAccelerationThreshold) / GameConstants.spawnAccelerationFactor
        let reducedInterval = GameConstants.baseStarSpawnInterval * (1.0 / (1.0 + accelerationFactor))
        
        // Enforce minimum interval
        return max(GameConstants.minStarSpawnInterval, reducedInterval)
    }
    
    // MARK: - Game Logic
    
    private func spawnStar() {
        guard !isGameOver else { return }
        guard stars.count < GameConstants.starMaxCount else { return }
        
        // Select star type based on black hole size
        let starType = selectStarType()
        let star = Star(type: starType)
        
        // Assign unique name for haptic tracking
        star.name = "star_\(UUID().uuidString)"
        
        // Try multiple positions to find valid spawn location
        var validPosition: CGPoint?
        var attempts = 0
        
        while validPosition == nil && attempts < 10 {
            // Use predictive positioning for intelligent spawning
            let spawnPosition = predictiveEdgePosition()
            
            // Check 1: Distance from black hole
            let minDistanceFromBlackHole = calculateMinSpawnDistance(for: star)
            guard distance(from: spawnPosition, to: blackHole.position) > minDistanceFromBlackHole else {
                attempts += 1
                continue
            }
            
            // Check 2: Distance from other large stars (prevents clustering)
            // Skip this check for red supergiants - they're rare enough (5-40% spawn rate)
            if starType == .redSupergiant || isValidSpawnPosition(spawnPosition, forStarSize: star.size.width) {
                validPosition = spawnPosition
            } else {
                attempts += 1
            }
        }
        
        // If valid position found, spawn the star
        guard let finalPosition = validPosition else {
            return // No valid position found, try again next interval
        }
        
        star.position = finalPosition
        star.zPosition = 5
        addChild(star)
        stars.append(star)
        
        star.playSpawnAnimation()
    }
    
    private func calculateMinSpawnDistance(for star: Star) -> CGFloat {
        let starSize = star.size.width
        
        // Progressive distance scaling based on star size
        let multiplier: CGFloat
        if starSize <= 100 {
            multiplier = 3.0      // Small stars: 3x distance
        } else if starSize <= 200 {
            multiplier = 4.0      // Medium stars: 4x distance  
        } else if starSize <= 400 {
            multiplier = 5.0      // Large stars: 5x distance
        } else {
            multiplier = 6.0      // Giant stars: 6x distance
        }
        
        let calculatedDistance = starSize * multiplier
        
        // Cap max distance at 800pt so Red Supergiants can actually spawn
        // (spawn system places stars ~526pt from black hole)
        let maxAllowedDistance: CGFloat = 800
        
        return max(GameConstants.starMinSpawnDistance, min(calculatedDistance, maxAllowedDistance))
    }
    
    private func isValidSpawnPosition(_ position: CGPoint, forStarSize size: CGFloat) -> Bool {
        // Only check against other large stars (> 80pt) to prevent death zones
        let largeStars = stars.filter { $0.size.width > 80 }
        
        for existingStar in largeStars {
            let dist = distance(from: position, to: existingStar.position)
            // Buffer zone = combined radii + 150pt safety margin
            let minSeparation = (size + existingStar.size.width) / 2 + 150
            
            if dist < minSeparation {
                return false  // Too close to another large star
            }
        }
        
        return true
    }
    
    private func selectStarType() -> StarType {
        let size = blackHole.currentDiameter
        let random = CGFloat.random(in: 0...1)
        
        // TEASE/PREVIEW SYSTEM: Spawn stars one phase ahead as challenges
        // Larger "preview" stars spawn at normal size to tease next level
        // Color indicator only shows stars you can actually eat
        
        if size < 48 {
            // Phase 1: Whites only + 7% yellow previews (large!)
            if random < 0.93 { return .whiteDwarf }      // 93% (16-24pt - edible)
            else { return .yellowDwarf }                  // 7% (28-38pt - TOO BIG, preview)
            
        } else if size < 80 {
            // Phase 2: Whites + Yellows + 7% blue previews (large!)
            if random < 0.65 { return .whiteDwarf }      // 65% (16-24pt)
            else if random < 0.93 { return .yellowDwarf } // 28% (28-38pt)
            else { return .blueGiant }                    // 7% (55-75pt - TOO BIG, preview)
            
        } else if size < 140 {
            // Phase 3: Whites + Yellows + Blues + 7% orange previews (huge!)
            if random < 0.35 { return .whiteDwarf }      // 35% (16-24pt)
            else if random < 0.65 { return .yellowDwarf } // 30% (28-38pt)
            else if random < 0.93 { return .blueGiant }   // 28% (55-75pt)
            else { return .orangeGiant }                  // 7% (120-300pt - TOO BIG, preview)
            
        } else if size < 320 {
            // Phase 4: Whites + Yellows + Blues + Oranges + 5% red previews (massive!)
            if random < 0.25 { return .whiteDwarf }      // 25% (16-24pt)
            else if random < 0.45 { return .yellowDwarf } // 20% (28-38pt)
            else if random < 0.70 { return .blueGiant }   // 25% (55-75pt)
            else if random < 0.95 { return .orangeGiant } // 25% (120-300pt)
            else { return .redSupergiant }                // 5% (280-900pt - MASSIVE, preview)
            
        } else {
            // Phase 5: All types available (320pt+)
            if random < 0.20 { return .whiteDwarf }      // 20% (16-24pt)
            else if random < 0.35 { return .yellowDwarf } // 15% (28-38pt)
            else if random < 0.55 { return .blueGiant }   // 20% (55-75pt)
            else if random < 0.80 { return .orangeGiant } // 25% (120-300pt)
            else { return .redSupergiant }                // 20% (280-900pt)
        }
    }
    
    private func randomEdgePosition() -> CGPoint {
        let edge = Int.random(in: 0...3)
        let spawnDistance: CGFloat = max(size.width, size.height) / 2 + 100
        
        // Spawn relative to black hole position (world coordinates)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        
        switch edge {
        case 0: // Top relative to view
            let x = blackHole.position.x + CGFloat.random(in: -size.width/2...size.width/2)
            let y = blackHole.position.y + spawnDistance
            return CGPoint(x: x, y: y)
        case 1: // Bottom
            let x = blackHole.position.x + CGFloat.random(in: -size.width/2...size.width/2)
            let y = blackHole.position.y - spawnDistance
            return CGPoint(x: x, y: y)
        case 2: // Left
            let x = blackHole.position.x - spawnDistance
            let y = blackHole.position.y + CGFloat.random(in: -size.height/2...size.height/2)
            return CGPoint(x: x, y: y)
        case 3: // Right
            let x = blackHole.position.x + spawnDistance
            let y = blackHole.position.y + CGFloat.random(in: -size.height/2...size.height/2)
            return CGPoint(x: x, y: y)
        default:
            return CGPoint(x: blackHole.position.x, y: blackHole.position.y + spawnDistance)
        }
    }
    
    private func predictiveEdgePosition() -> CGPoint {
        // Get movement direction and spawn weights
        let direction = movementTracker.getMovementDirection()
        let weights = direction.getSpawnWeights()
        
        // Select weighted edge based on movement direction
        let selectedEdge = selectWeightedEdge(from: weights)
        
        // Spawn relative to CURRENT position, but favor edges in direction of travel
        // This ensures validation passes while still being intelligent about placement
        return calculateEdgePosition(edge: selectedEdge, relativeTo: blackHole.position)
    }
    
    private func selectWeightedEdge(from weights: [EdgeWeight]) -> SpawnEdge {
        let random = CGFloat.random(in: 0...1)
        var cumulative: CGFloat = 0
        
        for weight in weights {
            cumulative += weight.weight
            if random <= cumulative {
                return weight.edge
            }
        }
        
        // Fallback to first edge
        return weights[0].edge
    }
    
    private func calculateEdgePosition(edge: SpawnEdge, relativeTo center: CGPoint) -> CGPoint {
        let spawnDistance: CGFloat = max(size.width, size.height) / 2 + 100
        let randomOffset = CGFloat.random(in: -200...200)
        
        switch edge {
        case .top:
            return CGPoint(x: center.x + randomOffset, y: center.y + spawnDistance)
        case .topRight:
            let offset = spawnDistance * 0.707 // cos(45°) = sin(45°)
            return CGPoint(x: center.x + offset + randomOffset * 0.5, 
                          y: center.y + offset + randomOffset * 0.5)
        case .right:
            return CGPoint(x: center.x + spawnDistance, y: center.y + randomOffset)
        case .bottomRight:
            let offset = spawnDistance * 0.707
            return CGPoint(x: center.x + offset + randomOffset * 0.5, 
                          y: center.y - offset - randomOffset * 0.5)
        case .bottom:
            return CGPoint(x: center.x + randomOffset, y: center.y - spawnDistance)
        case .bottomLeft:
            let offset = spawnDistance * 0.707
            return CGPoint(x: center.x - offset - randomOffset * 0.5, 
                          y: center.y - offset - randomOffset * 0.5)
        case .left:
            return CGPoint(x: center.x - spawnDistance, y: center.y + randomOffset)
        case .topLeft:
            let offset = spawnDistance * 0.707
            return CGPoint(x: center.x - offset - randomOffset * 0.5, 
                          y: center.y + offset + randomOffset * 0.5)
        }
    }
    
    private func startColorChangeWarning() {
        guard !isGameOver else { return }
        warningWasActive = true
        remainingWarningTime = GameConstants.colorChangeWarningDuration
        
        // Create rapid blinking animation on photon ring
        let blinkOut = SKAction.fadeAlpha(to: 0.2, duration: 0.2)
        let blinkIn = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        let blinkSequence = SKAction.sequence([blinkOut, blinkIn])
        
        // Create a repeating action and group it with a duration timer to ensure exact timing
        let repeatBlink = SKAction.repeatForever(blinkSequence)
        let durationAction = SKAction.wait(forDuration: GameConstants.colorChangeWarningDuration)
        let blinking = SKAction.group([repeatBlink, durationAction])
        
        blackHole.photonRing.run(blinking, withKey: "colorChangeWarning")
        
        // Also blink the rim light for more visibility
        if let rimLight = blackHole.retroRimLight {
            rimLight.run(blinking, withKey: "colorChangeWarningRim")
        }
    }
    
    private func stopColorChangeWarning() {
        // Invalidate the warning timer
        colorChangeWarningTimer?.invalidate()
        colorChangeWarningTimer = nil
        warningWasActive = false
        remainingWarningTime = nil
        
        // Stop blinking animation
        blackHole.photonRing.removeAction(forKey: "colorChangeWarning")
        blackHole.photonRing.alpha = 1.0  // Ensure it's fully visible
        
        if let rimLight = blackHole.retroRimLight {
            rimLight.removeAction(forKey: "colorChangeWarningRim")
            rimLight.alpha = RetroAestheticManager.Config.rimLightIntensity
        }
    }
    
    private func getAvailableStarTypes() -> [StarType] {
        // Check ALL stars currently in the game (not just visible)
        // Include a color in the indicator if ANY edible star of that color exists
        let edibleTypes = StarType.allCases.filter { type in
            stars.contains { star in
                star.starType == type && blackHole.canConsume(star)
            }
        }
        
        // Fallback: if no edible stars exist at all, at least show white dwarfs
        // (prevents indicator from going blank in edge cases)
        return edibleTypes.isEmpty ? [.whiteDwarf] : edibleTypes
    }
    
    private func applyGravity() {
        guard !isGameOver else { return }
        
        let blackHoleRadius = blackHole.currentDiameter / 2
        let blackHoleMass = blackHoleRadius * blackHoleRadius
        
        for star in stars {
            // Skip stars that are in orbital state (handled by orbital interaction)
            if star.name?.hasPrefix("orbital_") == true {
                continue
            }
            
            let dist = distance(from: star.position, to: blackHole.position)
            
            // Only apply gravity if within range
            guard dist < GameConstants.gravityMaxDistance else { continue }
            guard dist > 0 else { continue }
            
            let starRadius = star.size.width / 2
            let starMass = starRadius * starRadius
            
            // F = G * m1 * m2 / d^2
            let forceMagnitude = (GameConstants.gravitationalConstant * blackHoleMass * starMass) / (dist * dist)
            
            // Calculate force vector
            let dx = blackHole.position.x - star.position.x
            let dy = blackHole.position.y - star.position.y
            let angle = atan2(dy, dx)
            
            let forceVector = CGVector(
                dx: cos(angle) * forceMagnitude,
                dy: sin(angle) * forceMagnitude
            )
            
            star.physicsBody?.applyForce(forceVector)
        }
    }
    
    private func removeDistantStars() {
        // Scale removal distance with black hole size (larger black holes have larger gravity range)
        let removalDistance = max(GameConstants.starMaxDistanceFromScreen, blackHole.currentDiameter * 10)
        
        stars.removeAll { star in
            let dist = distance(from: star.position, to: blackHole.position)
            if dist > removalDistance {
                if let starName = star.name {
                    HapticManager.shared.stopDangerProximityHaptic(starID: starName)
                    AudioManager.shared.stopProximitySound(starID: starName)
                }
                star.removeFromParent()
                return true
            }
            return false
        }
    }
    
    // MARK: - Physics Contact Delegate
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }
        
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let nodeA = bodyA.node
        let nodeB = bodyB.node
        
        // Check if collision involves power-up
        if let powerUp = nodeA as? PowerUp {
            collectPowerUp(powerUp)
            return
        } else if let powerUp = nodeB as? PowerUp {
            collectPowerUp(powerUp)
            return
        }
        
        // Check if both nodes are stars (star-star collision)
        if GameConstants.enableStarMerging,
           let star1 = nodeA as? Star,
           let star2 = nodeB as? Star {
            print("⭐️ Star collision detected: \(star1.starType.displayName) (\(String(format: "%.0f", star1.size.width))pt) + \(star2.starType.displayName) (\(String(format: "%.0f", star2.size.width))pt)")
            handleStarMerge(star1: star1, star2: star2)
            return
        }
        
        // Determine which is black hole and which is star
        let blackHoleBody = bodyA.categoryBitMask == GameConstants.blackHoleCategory ? bodyA : bodyB
        let starBody = bodyA.categoryBitMask == GameConstants.starCategory ? bodyA : bodyB
        
        guard let starNode = starBody.node as? Star else { return }
        
        handleStarCollision(star: starNode)
    }
    
    private func handleStarCollision(star: Star) {
        // PREVENT MULTIPLE PROCESSING: Check if star has already been processed
        if star.hasBeenProcessed {
            return
        }
        star.hasBeenProcessed = true  // Mark as processed immediately
        
        // FIRST CHECK: Is star too large?
        if !blackHole.canConsume(star) {
            let rainbowActive = activePowerUp.activeType == .rainbow
            print("🚫 Star too large! Size: \(String(format: "%.0f", star.size.width))pt, Black hole: \(String(format: "%.0f", blackHole.currentDiameter))pt, Rainbow active: \(rainbowActive)")
            // Game over - black hole destabilized!
            gameOverReason = "Black hole destabilized!"
            triggerGameOver()
            return
        }
        
        // SECOND CHECK: Color/type match (or rainbow active with size restriction)
        let isCorrectType = star.starType == blackHole.targetType
        let rainbowActive = activePowerUp.activeType == .rainbow
        let canEatWithRainbow = rainbowActive && blackHole.canConsume(star)  // Rainbow allows any color but still respects size
        
        if isCorrectType || canEatWithRainbow {
            // Correct type: grow based on star size (NEW)
            if rainbowActive && !isCorrectType {
                print("🌈 Rainbow power-up: Eating \(star.starType.displayName) (size: \(String(format: "%.0f", star.size.width))pt) with rainbow - any color allowed")
            }
            
            // NEW: Calculate growth based on star size
            let beforeSize = blackHole.currentDiameter
            blackHole.growByConsumingStar(star)  // ← NEW METHOD
            let afterSize = blackHole.currentDiameter
            let growthPercent = ((afterSize - beforeSize) / beforeSize) * 100
            
            print("📈 Growth: \(String(format: "%.0f", beforeSize))pt → \(String(format: "%.0f", afterSize))pt (+\(String(format: "%.1f", growthPercent))%)")
            
            // Check size achievement
            if blackHole.currentDiameter >= 1000 && !hasReachedSize1000 {
                hasReachedSize1000 = true
                GameCenterManager.shared.reportAchievement(
                    identifier: GameCenterConstants.achievementReachSize1000
                )
            }
            
            lastCorrectEatTime = CACurrentMediaTime()  // Track for grace period
            
            let multiplier = GameManager.shared.getScoreMultiplier(blackHoleDiameter: blackHole.currentDiameter)
            let points = star.starType.basePoints * multiplier
            GameManager.shared.addScore(points)
            
            // Debug: Log size stages as black hole grows (matches star spawning phases)
            let currentSize = blackHole.currentDiameter
            let previousSize = beforeSize
            
            // Determine current phase
            let currentPhase: Int
            if currentSize < 48 {
                currentPhase = 1
            } else if currentSize < 80 {
                currentPhase = 2
            } else if currentSize < 140 {
                currentPhase = 3
            } else if currentSize < 320 {
                currentPhase = 4
            } else {
                currentPhase = 5
            }
            
            // Determine previous phase
            let previousPhase: Int
            if previousSize < 48 {
                previousPhase = 1
            } else if previousSize < 80 {
                previousPhase = 2
            } else if previousSize < 140 {
                previousPhase = 3
            } else if previousSize < 320 {
                previousPhase = 4
            } else {
                previousPhase = 5
            }
            
            // Log phase change and update music layers
            if currentPhase != previousPhase {
                if currentPhase > previousPhase {
                    print("📊 SIZE PHASE: Black hole advanced to phase \(currentPhase) (\(String(format: "%.0f", currentSize))pt)")
                } else {
                    print("📊 SIZE PHASE: Black hole regressed to phase \(currentPhase) (\(String(format: "%.0f", currentSize))pt)")
                }
                
                // Update music layers based on new phase (handles both growth and shrinkage)
                AudioManager.shared.updateMusicLayersForSize(currentSize)
            }
            // Check milestone thresholds
            if beforeSize < 600 && currentSize >= 600 {
                print("🎯 MILESTONE: Supermassive tier reached! (600pt)")
            }
            if beforeSize < 1000 && currentSize >= 1000 {
                print("🎯 MILESTONE: Cosmic tier reached! (1000pt)")
            }
            if beforeSize < 2000 && currentSize >= 2000 {
                print("🎯 MILESTONE: Legendary tier reached! (2000pt)")
            }
            
            // Check grace period before playing sounds
            let currentTime = CACurrentMediaTime()
            if currentTime - gameStartTime >= SOUND_GRACE_PERIOD {
                AudioManager.shared.playCorrectSound(on: self)
                AudioManager.shared.playGrowSound(on: self)
            }
            
            // Haptic feedback for correct consumption
            HapticManager.shared.playCorrectStarHaptic(starSize: star.size.width)
            
            blackHole.playConsumptionFeedback()
        } else {
            // Wrong type: check grace period first
            let currentTime = CACurrentMediaTime()
            let gracePeriod: TimeInterval = 0.5
            
            if currentTime - lastCorrectEatTime < gracePeriod {
                // Grace period active - just remove star without penalty
                print("🛡️ Grace period active - no shrink penalty")
                // Star still gets removed but no shrink/penalty
            } else {
                // Grace period expired - apply progressive shrink
                // Progressive forgiveness: larger black holes shrink less
                let size = blackHole.currentDiameter
                let forgivenessFactor = min(size / 200.0, 0.5) // 0 at 0pt, 0.5 at 200pt+
                let adjustedMultiplier = GameConstants.blackHoleShrinkMultiplier + (0.1 * forgivenessFactor)
                // e.g., 40pt: 0.8, 100pt: 0.85, 200pt+: 0.85
                
                print("🔻 Wrong color - shrinking by \(String(format: "%.2f", adjustedMultiplier))x (size: \(String(format: "%.0f", size))pt)")
                
                let beforeSize = blackHole.currentDiameter
                blackHole.shrinkByMultiplier(adjustedMultiplier)
                hasShrunkThisGame = true
                GameManager.shared.addScore(GameConstants.wrongColorPenalty)
                
                // Check for phase change (size regression)
                let currentSize = blackHole.currentDiameter
                let previousSize = beforeSize
                
                // Determine current phase
                let currentPhase: Int
                if currentSize < 48 {
                    currentPhase = 1
                } else if currentSize < 80 {
                    currentPhase = 2
                } else if currentSize < 140 {
                    currentPhase = 3
                } else if currentSize < 320 {
                    currentPhase = 4
                } else {
                    currentPhase = 5
                }
                
                // Determine previous phase
                let previousPhase: Int
                if previousSize < 48 {
                    previousPhase = 1
                } else if previousSize < 80 {
                    previousPhase = 2
                } else if previousSize < 140 {
                    previousPhase = 3
                } else if previousSize < 320 {
                    previousPhase = 4
                } else {
                    previousPhase = 5
                }
                
                // Log phase change and update music layers
                if currentPhase != previousPhase {
                    if currentPhase < previousPhase {
                        print("📊 SIZE PHASE: Black hole regressed to phase \(currentPhase) (\(String(format: "%.0f", currentSize))pt)")
                    } else {
                        print("📊 SIZE PHASE: Black hole advanced to phase \(currentPhase) (\(String(format: "%.0f", currentSize))pt)")
                    }
                    
                    // Update music layers based on new phase (handles both growth and shrinkage)
                    AudioManager.shared.updateMusicLayersForSize(currentSize)
                }
                
                // Check grace period before playing sounds
                if currentTime - gameStartTime >= SOUND_GRACE_PERIOD {
                    AudioManager.shared.playWrongSound(on: self)
                    AudioManager.shared.playShrinkSound(on: self)
                }
                
                // Haptic feedback for wrong consumption
                let isInDangerZone = blackHole.currentDiameter < 40
                HapticManager.shared.playWrongStarHaptic(isInDangerZone: isInDangerZone)
                
                // Show wrong color tip
                checkAndShowWrongColorTip()
                
                // Check for game over
                if blackHole.isAtMinimumSize() {
                    gameOverReason = "Black hole shrunk too small"
                    triggerGameOver()
                }
            }
        }
        
        updateScoreLabel()
        
        // Track stats - increment star count
        GameStats.shared.incrementStarCount(type: star.starType)
        
        // Create particle effect at collision point
        createCollisionParticles(at: star.position, color: star.starType.uiColor)
        
        // Remove star
        removeStar(star)
    }
    
    private func removeStar(_ star: Star) {
        if let starName = star.name {
            HapticManager.shared.stopDangerProximityHaptic(starID: starName)
            AudioManager.shared.stopProximitySound(starID: starName)
        }
        // Track if it's a merged star for cleanup
        if star.isMergedStar {
            mergedStarCount = max(0, mergedStarCount - 1)
        }
        
        stars.removeAll { $0 == star }
        star.playDeathAnimation {
            star.removeFromParent()
        }
    }
    
    private func handleStarMerge(star1: Star, star2: Star) {
        let currentTime = CACurrentMediaTime()
        
        // Safeguard 1: Check merged star limit
        guard mergedStarCount < GameConstants.maxMergedStars else {
            print("🚫 Merge blocked: max merged stars reached - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        
        // Safeguard 2: Check cooldown
        guard currentTime - lastMergeTime > GameConstants.mergeCooldown else {
            print("🚫 Merge blocked: cooldown (\(String(format: "%.1f", currentTime - lastMergeTime))s/\(GameConstants.mergeCooldown)s) - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        
        // Safeguard 3: Check minimum size
        guard star1.size.width >= GameConstants.minMergeSizeRequirement else {
            print("🚫 Merge blocked: star1 too small (\(String(format: "%.0f", star1.size.width))pt < \(GameConstants.minMergeSizeRequirement)pt) - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        guard star2.size.width >= GameConstants.minMergeSizeRequirement else {
            print("🚫 Merge blocked: star2 too small (\(String(format: "%.0f", star2.size.width))pt < \(GameConstants.minMergeSizeRequirement)pt) - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        
        // Safeguard 4: Neither star has exceeded merge limit
        guard star1.mergeCount < GameConstants.maxMergesPerStar && star2.mergeCount < GameConstants.maxMergesPerStar else {
            print("🚫 Merge blocked: star merge limit reached (star1: \(star1.mergeCount), star2: \(star2.mergeCount)) - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        
        // Safeguard 5: Not too close to black hole
        let distToBlackHole1 = distance(from: star1.position, to: blackHole.position)
        let distToBlackHole2 = distance(from: star2.position, to: blackHole.position)
        guard distToBlackHole1 > GameConstants.mergeDistanceFromBlackHole else {
            print("🚫 Merge blocked: star1 too close to black hole (\(String(format: "%.0f", distToBlackHole1))pt < \(GameConstants.mergeDistanceFromBlackHole)pt) - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        guard distToBlackHole2 > GameConstants.mergeDistanceFromBlackHole else {
            print("🚫 Merge blocked: star2 too close to black hole (\(String(format: "%.0f", distToBlackHole2))pt < \(GameConstants.mergeDistanceFromBlackHole)pt) - initiating orbital interaction")
            handleOrbitalInteraction(star1: star1, star2: star2)
            return
        }
        
        // All checks passed - perform merge
        let (largerStar, smallerStar) = star1.size.width >= star2.size.width ? (star1, star2) : (star2, star1)
        
        // Create merged star
        let mergedStar = createMergedStar(from: largerStar, and: smallerStar)
        mergedStar.position = largerStar.position
        mergedStar.zPosition = 5
        addChild(mergedStar)
        stars.append(mergedStar)
        
        // Update tracking
        mergedStarCount += 1
        lastMergeTime = currentTime
        
        print("✨ MERGE SUCCESS! \(largerStar.starType.displayName) + \(smallerStar.starType.displayName) → \(mergedStar.starType.displayName) (Count: \(mergedStarCount)/\(GameConstants.maxMergedStars))")
        
        // Show merge effect
        showMergeEffect(at: largerStar.position, color1: largerStar.starType.uiColor, color2: smallerStar.starType.uiColor)
        
        // Play sound only if merge is close to player (in camera view) and grace period has passed
        if isInCameraView(largerStar.position) && currentTime - gameStartTime >= SOUND_GRACE_PERIOD {
            AudioManager.shared.playMergeSound(on: self)
        }
        
        // Remove original stars
        stars.removeAll { $0 == star1 || $0 == star2 }
        star1.removeFromParent()
        star2.removeFromParent()
    }
    
    private func handleOrbitalInteraction(star1: Star, star2: Star) {
        // Determine which star is larger based on mass (radius squared)
        let radius1 = star1.size.width / 2
        let radius2 = star2.size.width / 2
        let (largerStar, smallerStar) = radius1 >= radius2 ? (star1, star2) : (star2, star1)
        
        // Calculate distance between stars
        let dx = largerStar.position.x - smallerStar.position.x
        let dy = largerStar.position.y - smallerStar.position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 0 else { return }
        
        // IMPORTANT: Mark smaller star as orbital to exclude from black hole gravity
        smallerStar.name = "orbital_\(UUID().uuidString)"
        
        // IMPORTANT: Disable collision between these two stars during orbital interaction
        let originalSmallerBitMask = smallerStar.physicsBody?.collisionBitMask ?? 0
        let originalLargerBitMask = largerStar.physicsBody?.collisionBitMask ?? 0
        smallerStar.physicsBody?.collisionBitMask = 0
        largerStar.physicsBody?.collisionBitMask = 0
        
        // Reduce damping for smoother orbital motion
        let originalSmallerDamping = smallerStar.physicsBody?.linearDamping ?? 0.3
        smallerStar.physicsBody?.linearDamping = 0.05
        
        // Calculate mass of larger star
        let largerMass = pow(radius1 >= radius2 ? radius1 : radius2, 2)
        
        // Calculate orbital velocity: v = sqrt(G * M / r) * multiplier
        let orbitalSpeed = sqrt((GameConstants.gravitationalConstant * largerMass) / distance) * GameConstants.orbitalSpeedMultiplier
        
        // Calculate perpendicular velocity to create circular orbit
        let angle = atan2(dy, dx)
        let perpendicularAngle = angle + CGFloat.pi / 2
        
        // Apply perpendicular velocity
        smallerStar.physicsBody?.velocity = CGVector(
            dx: cos(perpendicularAngle) * orbitalSpeed,
            dy: sin(perpendicularAngle) * orbitalSpeed
        )
        
        // Inherit some of the larger star's velocity
        if let largerVel = largerStar.physicsBody?.velocity {
            smallerStar.physicsBody?.velocity = CGVector(
                dx: smallerStar.physicsBody!.velocity.dx + largerVel.dx * GameConstants.orbitalVelocityInheritance,
                dy: smallerStar.physicsBody!.velocity.dy + largerVel.dy * GameConstants.orbitalVelocityInheritance
            )
        }
        
        // Schedule fling-away after orbital duration
        Timer.scheduledTimer(withTimeInterval: GameConstants.orbitalDuration, repeats: false) { [weak self] _ in
            self?.flingStarAway(smaller: smallerStar, larger: largerStar, originalSmallerBitMask: originalSmallerBitMask, originalLargerBitMask: originalLargerBitMask, originalSmallerDamping: originalSmallerDamping)
        }
    }
    
    private func flingStarAway(smaller: Star, larger: Star, originalSmallerBitMask: UInt32, originalLargerBitMask: UInt32, originalSmallerDamping: CGFloat) {
        // Calculate distance between stars
        let dx = larger.position.x - smaller.position.x
        let dy = larger.position.y - smaller.position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 0 else {
            // Re-enable collision bitmasks and restore name if no fling happens
            smaller.physicsBody?.collisionBitMask = originalSmallerBitMask
            larger.physicsBody?.collisionBitMask = originalLargerBitMask
            smaller.physicsBody?.linearDamping = originalSmallerDamping
            smaller.name = nil  // Remove orbital marker
            return
        }
        
        // Calculate mass of larger star
        let largerRadius = larger.size.width / 2
        let largerMass = pow(largerRadius, 2)
        
        // Calculate escape velocity: v = sqrt(2 * G * M / r) * multiplier
        let escapeSpeed = sqrt((2 * GameConstants.gravitationalConstant * largerMass) / distance) * GameConstants.escapeSpeedMultiplier
        
        // Calculate direction away from larger star
        let angle = atan2(dy, dx)
        let flingDirection = CGVector(dx: cos(angle), dy: sin(angle))
        
        // Apply strong escape velocity as an impulse (not just velocity)
        if let mass = smaller.physicsBody?.mass {
            smaller.physicsBody?.applyImpulse(CGVector(
                dx: flingDirection.dx * escapeSpeed * mass,
                dy: flingDirection.dy * escapeSpeed * mass
            ))
        }
        
        // Re-enable collision bitmasks and restore damping
        smaller.physicsBody?.collisionBitMask = originalSmallerBitMask
        larger.physicsBody?.collisionBitMask = originalLargerBitMask
        smaller.physicsBody?.linearDamping = originalSmallerDamping
        
        // IMPORTANT: Remove orbital marker so gravity applies again
        smaller.name = nil
        
        print("🚀 Star flung away at \(String(format: "%.1f", escapeSpeed)) pts/s")
    }
    
    private func createMergedStar(from star1: Star, and star2: Star) -> Star {
        // Calculate combined radius using area formula
        let radius1 = star1.size.width / 2
        let radius2 = star2.size.width / 2
        let combinedArea = (radius1 * radius1) + (radius2 * radius2)
        let newRadius = sqrt(combinedArea)
        let newDiameter = newRadius * 2
        
        // Determine new star type based on size
        let newType = determineStarType(fromDiameter: newDiameter)
        
        // Create merged star
        let mergedStar = Star(type: newType)
        
        // Override size to exact calculated value
        mergedStar.size = CGSize(width: newDiameter, height: newDiameter)
        
        // Set merge count to max of the two stars plus 1
        mergedStar.mergeCount = max(star1.mergeCount, star2.mergeCount) + 1
        mergedStar.isMergedStar = true
        
        // Calculate bonus points (50% more)
        mergedStar.basePoints = Int(Double(star1.basePoints + star2.basePoints) * GameConstants.mergedStarPointsMultiplier)
        
        // Average velocities with damping
        if let vel1 = star1.physicsBody?.velocity, let vel2 = star2.physicsBody?.velocity {
            let dampingFactor: CGFloat = 0.7
            let avgVelX = ((vel1.dx + vel2.dx) / 2) * dampingFactor
            let avgVelY = ((vel1.dy + vel2.dy) / 2) * dampingFactor
            mergedStar.physicsBody?.velocity = CGVector(dx: avgVelX, dy: avgVelY)
        }
        
        // Add enhanced glow effect
        mergedStar.addMergedStarEnhancement()
        
        return mergedStar
    }
    
    private func determineStarType(fromDiameter diameter: CGFloat) -> StarType {
        switch diameter {
        case 0..<35:
            return .whiteDwarf
        case 35..<50:
            return .yellowDwarf
        case 50..<75:
            return .blueGiant
        case 75..<150:
            return .orangeGiant
        default:
            return .redSupergiant
        }
    }
    
    private func showMergeEffect(at position: CGPoint, color1: UIColor, color2: UIColor) {
        // Flash effect
        let flash = SKShapeNode(circleOfRadius: 40)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.alpha = 0
        flash.zPosition = 50
        addChild(flash)
        
        let flashSequence = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.8, duration: 0.1),
                SKAction.scale(to: 2.0, duration: 0.1)
            ]),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.scale(to: 3.0, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(flashSequence)
        
        // Particle burst
        let particleCount = 50
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 4)
            particle.fillColor = Bool.random() ? color1 : color2
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 49
            addChild(particle)
            
            // Random velocity
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...200)
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            
            // Animate particle
            let move = SKAction.move(by: velocity, duration: 0.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let scaleDown = SKAction.scale(to: 0, duration: 0.5)
            let group = SKAction.group([move, fadeOut, scaleDown])
            
            particle.run(group) {
                particle.removeFromParent()
            }
        }
    }
    
    // MARK: - Power-Up System
    
    private func collectPowerUp(_ powerUp: PowerUp) {
        let currentTime = CACurrentMediaTime()
        
        // Remove from scene
        powerUp.removeFromParent()
        powerUpManager.activePowerUps.removeAll { $0 == powerUp }
        
        // Notify manager of collection (triggers cooldown)
        powerUpManager.onPowerUpCollected(currentTime: currentTime)
        
        // Show collection effect
        showCollectionEffect(at: powerUp.position, type: powerUp.type)
        
        // Activate power-up
        activatePowerUp(type: powerUp.type)
        
        // Play sound
        AudioManager.shared.playPowerUpCollectSound(on: self)
        
        // Haptic feedback for power-up
        HapticManager.shared.playPowerUpHaptic(type: powerUp.type)
        
        print("💎 Collected \(powerUp.type.displayName) power-up!")
    }
    
    private func activatePowerUp(type: PowerUpType) {
        let currentTime = CACurrentMediaTime()
        activePowerUp.activate(type: type, currentTime: currentTime)
        
        // Start power-up loop sound
        AudioManager.shared.startPowerUpLoopSound(on: self)
        
        // Apply immediate effects
        switch type {
        case .rainbow:
            print("🌈 Rainbow Mode activated! Eat any color for \(type.duration)s")
            startRainbowPhotonRing()
            print("🌈 Rainbow photon ring animation started")
            
        case .freeze:
            freezeAllStars()
            print("❄️ Freeze activated! Stars frozen for \(type.duration)s")
        }
    }
    
    private func handlePowerUpExpiration() {
        guard let type = activePowerUp.activeType else { 
            print("⚠️ handlePowerUpExpiration called but no active power-up type!")
            return 
        }
        
        print("⏱️ Power-up expired: \(type.displayName)")
        
        switch type {
        case .freeze:
            unfreezeAllStars()
        case .rainbow:
            // Restore normal photon ring
            print("🌈 Rainbow Mode expired - stopping rainbow animation")
            stopRainbowPhotonRing()
            print("🌈 Rainbow photon ring animation stopped and restored to target color")
        }
        
        // Stop power-up loop sound FIRST (synchronously) before playing expire sound
        AudioManager.shared.stopPowerUpLoopSound()
        
        // Deactivate the power-up AFTER handling the expiration
        activePowerUp.deactivate()
        
        // Add a small delay to ensure loop sound is fully stopped before playing expire sound
        run(SKAction.wait(forDuration: 0.1)) { [weak self] in
            guard let self = self else { return }
            AudioManager.shared.playPowerUpExpireSound(on: self)
        }
    }
    
    private func freezeAllStars() {
        for star in stars {
            star.physicsBody?.isDynamic = false
        }
    }
    
    private func unfreezeAllStars() {
        for star in stars {
            star.physicsBody?.isDynamic = true
        }
    }
    
    private func startRainbowPhotonRing() {
        print("🌈 Starting rainbow animation...")
        
        // Stop normal pulse animation
        blackHole.photonRing.removeAllActions()
        
        // Create rainbow color cycle
        let rainbowColors: [UIColor] = [
            UIColor(hex: "#F0F0F0"), // White
            UIColor(hex: "#FFD700"), // Yellow
            UIColor(hex: "#4DA6FF"), // Blue
            UIColor(hex: "#FF8C42"), // Orange
            UIColor(hex: "#DC143C")  // Red
        ]
        
        var colorActions: [SKAction] = []
        for color in rainbowColors {
            let changeColor = SKAction.run {
                self.blackHole.photonRing.strokeColor = color
            }
            let wait = SKAction.wait(forDuration: 0.3)
            colorActions.append(SKAction.sequence([changeColor, wait]))
        }
        
        let cycle = SKAction.sequence(colorActions)
        let rainbowAction = SKAction.repeatForever(cycle)
        blackHole.photonRing.run(rainbowAction, withKey: "rainbowCycle")
        
        print("🌈 Rainbow animation started with key: rainbowCycle")
    }
    
    private func stopRainbowPhotonRing() {
        print("🛑 Stopping rainbow animation...")
        
        // Stop rainbow cycle properly - remove ALL actions to ensure clean stop
        blackHole.photonRing.removeAction(forKey: "rainbowCycle")
        blackHole.photonRing.removeAllActions()
        
        // Force stop any running actions
        blackHole.photonRing.removeAllActions()
        
        print("🛑 Actions removed, restoring target color: \(blackHole.targetType.displayName)")
        
        // Restore target color immediately
        blackHole.photonRing.strokeColor = blackHole.targetType.uiColor
        
        // Resume normal pulse animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.8),
            SKAction.fadeAlpha(to: 0.7, duration: 0.8)
        ])
        blackHole.photonRing.run(SKAction.repeatForever(pulse))
        
        print("🛑 Normal pulse animation restored")
    }
    
    private func showCollectionEffect(at position: CGPoint, type: PowerUpType) {
        // Particle burst - rainbow or freeze colored
        let particleCount = 50
        
        // Get colors for rainbow effect
        let rainbowColors: [UIColor] = [
            UIColor(hex: "#F0F0F0"), // White
            UIColor(hex: "#FFD700"), // Yellow
            UIColor(hex: "#4DA6FF"), // Blue
            UIColor(hex: "#FF8C42"), // Orange
            UIColor(hex: "#DC143C")  // Red
        ]
        
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 4)
            
            // Use rainbow colors for rainbow, silver for freeze
            if type == .rainbow {
                particle.fillColor = rainbowColors.randomElement()!
            } else {
                particle.fillColor = UIColor(hex: "#87CEEB")
            }
            
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 49
            addChild(particle)
            
            // Random velocity
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 150...250)
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            
            // Animate particle
            let move = SKAction.move(by: velocity, duration: 0.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let scaleDown = SKAction.scale(to: 0, duration: 0.5)
            let group = SKAction.group([move, fadeOut, scaleDown])
            
            particle.run(group) {
                particle.removeFromParent()
            }
        }
        
        // Flash effect
        let flash = SKShapeNode(circleOfRadius: 30)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.alpha = 0
        flash.zPosition = 50
        addChild(flash)
        
        let flashSequence = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.8, duration: 0.1),
                SKAction.scale(to: 2.0, duration: 0.1)
            ]),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.scale(to: 3.0, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(flashSequence)
    }
    
    private func updatePowerUpUI(currentTime: TimeInterval) {
        guard let container = activePowerUp.indicatorNode else { return }
        
        if activePowerUp.isActive() {
            container.isHidden = false
            
            // Update icon color based on type
            if let iconBg = container.childNode(withName: "powerUpIconBg") as? SKShapeNode {
                switch activePowerUp.activeType {
                case .rainbow:
                    // Cycle rainbow colors in UI indicator
                    if iconBg.action(forKey: "rainbowCycle") == nil {
                        let colors: [UIColor] = [
                            UIColor(hex: "#F0F0F0").withAlphaComponent(0.5), // White
                            UIColor(hex: "#FFD700").withAlphaComponent(0.5), // Yellow
                            UIColor(hex: "#4DA6FF").withAlphaComponent(0.5), // Blue
                            UIColor(hex: "#FF8C42").withAlphaComponent(0.5), // Orange
                            UIColor(hex: "#DC143C").withAlphaComponent(0.5)  // Red
                        ]
                        
                        var colorActions: [SKAction] = []
                        for color in colors {
                            colorActions.append(SKAction.run {
                                iconBg.fillColor = color
                            })
                            colorActions.append(SKAction.wait(forDuration: 0.2))
                        }
                        
                        let cycle = SKAction.sequence(colorActions)
                        iconBg.run(SKAction.repeatForever(cycle), withKey: "rainbowCycle")
                    }
                    
                case .freeze:
                    iconBg.removeAction(forKey: "rainbowCycle")
                    iconBg.fillColor = UIColor(hex: "#87CEEB").withAlphaComponent(0.5)
                    
                case .none:
                    iconBg.removeAction(forKey: "rainbowCycle")
                    break
                }
            }
            
            // Update timer
            if let timerLabel = container.childNode(withName: "powerUpTimer") as? SKLabelNode {
                let remaining = activePowerUp.getRemainingTime(currentTime: currentTime)
                timerLabel.text = String(format: "%.1f", remaining)
                
                // Flash warning when < 1 second
                if remaining < 1.0 && remaining > 0 {
                    if timerLabel.action(forKey: "flash") == nil {
                        let flash = SKAction.sequence([
                            SKAction.fadeAlpha(to: 0.3, duration: 0.15),
                            SKAction.fadeAlpha(to: 1.0, duration: 0.15)
                        ])
                        timerLabel.run(SKAction.repeatForever(flash), withKey: "flash")
                    }
                } else {
                    timerLabel.removeAction(forKey: "flash")
                    timerLabel.alpha = 1.0
                }
            }
        } else {
            container.isHidden = true
        }
    }
    
    // MARK: - Particle Effects
    
    private func createCollisionParticles(at position: CGPoint, color: UIColor) {
        let particleCount = 25
        
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 15
            addChild(particle)
            
            // Random velocity
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            
            // Animate particle
            let move = SKAction.move(by: velocity, duration: 0.3)
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let scaleDown = SKAction.scale(to: 0, duration: 0.3)
            let group = SKAction.group([move, fadeOut, scaleDown])
            
            particle.run(group) {
                particle.removeFromParent()
            }
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Handle paused state - check if tapped black hole to resume
        if isGamePaused {
            // Check if "Return to Menu" button was tapped
            if let returnToMenuButton = returnToMenuButton {
                let buttonLocation = convert(location, to: returnToMenuButton.parent!)
                if returnToMenuButton.contains(point: buttonLocation) {
                    returnToMenuButton.animatePress()
                    return
                }
            }
            
            let distToBlackHole = distance(from: location, to: blackHole.position)
            let tapRadius = blackHole.currentDiameter / 2 + 50 // Generous tap area
            
            if distToBlackHole <= tapRadius {
                resumeGame(touch: touch, at: location)
            }
            return
        }
        
        // If already moving black hole with another touch, ignore new touches
        if isBlackHoleBeingMoved && activeTouch != touch {
            return
        }
        
        if isGameOver {
            // Check if restart button was tapped
            if let restartButton = restartButton {
                let buttonLocation = convert(location, to: restartButton.parent!)
                if restartButton.contains(point: buttonLocation) {
                    if !hasTappedRestartButton {
                        // First tap - just animate press but don't restart
                        restartButton.animatePress()
                        hasTappedRestartButton = true
                    } else {
                        // Second tap - restart the game
                        restartButton.animatePress()
                    }
                    return
                }
            }
            
            // Check if return to menu button was tapped
            if let returnToMenuButton = returnToMenuButton {
                let buttonLocation = convert(location, to: returnToMenuButton.parent!)
                if returnToMenuButton.contains(point: buttonLocation) {
                    returnToMenuButton.animatePress()
                }
            }
        } else {
            // Start tracking this touch for black hole movement
            isBlackHoleBeingMoved = true
            activeTouch = touch
            
            // Move black hole to touch location immediately (in world coordinates)
            blackHole.position = location
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver else { return }
        guard !isGamePaused else { return }  // Don't move when paused
        guard let touch = touches.first else { return }
        
        // Only respond to the active touch
        guard touch == activeTouch else { return }
        
        let location = touch.location(in: self)
        blackHole.position = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Handle paused state "Return to Menu" button
        if isGamePaused {
            if let returnToMenuButton = returnToMenuButton {
                let location = touch.location(in: self)
                let buttonLocation = convert(location, to: returnToMenuButton.parent!)
                if returnToMenuButton.contains(point: buttonLocation) {
                    returnToMenuButton.animateRelease()
                    returnToMenu()
                    return
                }
            }
        }
        
        // Handle game over buttons
        if isGameOver {
            if let restartButton = restartButton {
                let location = touch.location(in: self)
                let buttonLocation = convert(location, to: restartButton.parent!)
                if restartButton.contains(point: buttonLocation) {
                    restartButton.animateRelease()
                    // Only restart on second tap
                    if hasTappedRestartButton {
                        restartGame()
                        return
                    }
                }
            }
            
            if let returnToMenuButton = returnToMenuButton {
                let location = touch.location(in: self)
                let buttonLocation = convert(location, to: returnToMenuButton.parent!)
                if returnToMenuButton.contains(point: buttonLocation) {
                    returnToMenuButton.animateRelease()
                    returnToMenu()
                    return
                }
            }
        }
        
        // If the active touch ended, stop tracking movement
        if touch == activeTouch {
            isBlackHoleBeingMoved = false
            activeTouch = nil
            
            // PAUSE GAME when finger lifts (if not already game over/paused)
            if !isGameOver && !isGamePaused {
                fingerLiftTime = CACurrentMediaTime()
                // Trigger pause after delay to prevent accidental pauses
                DispatchQueue.main.asyncAfter(deadline: .now() + PAUSE_DELAY) { [weak self] in
                    guard let self = self else { return }
                    // Only pause if finger is still lifted and game hasn't resumed
                    if !self.isBlackHoleBeingMoved && !self.isGamePaused && !self.isGameOver {
                        self.pauseGame()
                    }
                }
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // If the active touch was cancelled, stop tracking movement
        if touch == activeTouch {
            isBlackHoleBeingMoved = false
            activeTouch = nil
            
            // PAUSE GAME when touch cancelled (same as finger lift)
            if !isGameOver && !isGamePaused {
                fingerLiftTime = CACurrentMediaTime()
                DispatchQueue.main.asyncAfter(deadline: .now() + PAUSE_DELAY) { [weak self] in
                    guard let self = self else { return }
                    if !self.isBlackHoleBeingMoved && !self.isGamePaused && !self.isGameOver {
                        self.pauseGame()
                    }
                }
            }
        }
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        guard !isGamePaused else { return }  // Don't update when paused
        
        // Track frame rate for performance monitoring
        trackFrameRate(currentTime)
        
        // Update camera to follow black hole smoothly
        updateCamera()
        
        // Track black hole movement for predictive spawning
        movementTracker.recordPosition(blackHole.position, at: currentTime)
        
        // Check for star field spawning
        starFieldManager.checkAndSpawnStarField(currentTime: currentTime, 
                                                blackHolePosition: blackHole.position, 
                                                scene: self)
        
        // Update background parallax
        updateBackgroundStars()
        
        // Update retro effects
        updateRetroEffects(currentTime)
        
        // Check star proximity for warnings
        checkStarProximity()
        
        // Check for danger star tip
        checkDangerStarTip()
        
        // Update power-up system
        powerUpManager.update(currentTime: currentTime)
        
        // Check for power-up tip
        checkPowerUpTip()
        
        // Check power-up expiration
        if activePowerUp.checkExpiration(currentTime: currentTime) {
            handlePowerUpExpiration()
        }
        
        // Update power-up UI
        updatePowerUpUI(currentTime: currentTime)
        
        // Apply passive shrink and update indicator
        applyPassiveShrink(currentTime: currentTime)
        updateShrinkIndicator()
        
        applyGravity()
        applyStarToStarGravity()
        removeDistantStars()
    }
    
    // MARK: - Performance Monitoring
    
    private func trackFrameRate(_ currentTime: TimeInterval) {
        if lastFrameTime > 0 {
            let frameDuration = currentTime - lastFrameTime
            recentFrameTimes.append(frameDuration)
            
            // Keep only last 60 frames
            if recentFrameTimes.count > 60 {
                recentFrameTimes.removeFirst()
            }
            
            // Check average FPS every 60 frames
            if recentFrameTimes.count == 60 {
                let averageFrameTime = recentFrameTimes.reduce(0, +) / Double(recentFrameTimes.count)
                let averageFPS = 1.0 / averageFrameTime
                
                // Log FPS for debugging
                print("📊 FPS: \(String(format: "%.1f", averageFPS)) | Stars: \(stars.count) | Mode: \(performanceMode)")
                
                // Adjust quality based on performance
                if averageFPS < 55 && performanceMode != .low {
                    reduceParticleQuality()
                } else if averageFPS > 58 && performanceMode != .high {
                    restoreParticleQuality()
                }
            }
        }
        lastFrameTime = currentTime
    }
    
    private func reduceParticleQuality() {
        print("⚠️ Reducing particle quality to maintain FPS")
        
        switch performanceMode {
        case .high:
            performanceMode = .medium
            // Reduce birth rates by 40%
            adjustStarParticleQuality(multiplier: 0.6)
            retroManager.setQuality(.medium)
        case .medium:
            performanceMode = .low
            // Further reduce and disable distant particles
            adjustStarParticleQuality(multiplier: 0.3)
            disableDistantStarParticles()
            retroManager.setQuality(.low)
        case .low:
            break
        }
    }
    
    private func restoreParticleQuality() {
        print("✅ Restoring particle quality")
        
        switch performanceMode {
        case .low:
            performanceMode = .medium
            adjustStarParticleQuality(multiplier: 0.6)
            retroManager.setQuality(.medium)
        case .medium:
            performanceMode = .high
            adjustStarParticleQuality(multiplier: 1.0)
            retroManager.setQuality(.high)
        case .high:
            break
        }
    }
    
    private func adjustStarParticleQuality(multiplier: CGFloat) {
        for star in stars {
            if let particles = star.children.first(where: { $0.name == "coronaParticles" }) as? SKEmitterNode {
                // Adjust birth rate based on multiplier
                let profile = VisualEffectProfile.profile(for: star.starType, size: star.size.width)
                particles.particleBirthRate = profile.birthRate * profile.coronaIntensity * multiplier
            }
        }
    }
    
    private func disableDistantStarParticles() {
        guard let camera = camera else { return }
        
        for star in stars {
            let distance = hypot(star.position.x - camera.position.x,
                               star.position.y - camera.position.y)
            
            // Disable particles for stars more than 500pt away
            if distance > 500 {
                if let particles = star.children.first(where: { $0.name == "coronaParticles" }) as? SKEmitterNode {
                    particles.particleBirthRate = 0
                }
            }
        }
    }
    
    private func applyStarToStarGravity() {
        guard GameConstants.enableStarMerging else { return }
        guard stars.count > 1 else { return }
        
        // Pre-calculate constants (hoist out of loops)
        let rangeSquared = GameConstants.starGravityRange * GameConstants.starGravityRange
        let G_STAR = GameConstants.gravitationalConstant * GameConstants.starGravityMultiplier
        
        for i in 0..<stars.count {
            let star1 = stars[i]
            let pos1 = star1.position  // Cache position
            
            for j in (i+1)..<stars.count {
                let star2 = stars[j]
                
                // OPTIMIZATION: Fast distance check (no sqrt)
                let dx = star2.position.x - pos1.x
                let dy = star2.position.y - pos1.y
                let distSquared = dx * dx + dy * dy
                
                // Early exit for distant stars (90% of cases) - avoids expensive sqrt
                guard distSquared < rangeSquared && distSquared > 0 else { continue }
                
                // Only calculate real distance when needed
                let dist = sqrt(distSquared)
                
                let radius1 = star1.size.width / 2
                let radius2 = star2.size.width / 2
                let mass1 = radius1 * radius1 * star1.starType.massMultiplier
                let mass2 = radius2 * radius2 * star2.starType.massMultiplier
                
                // Use distSquared for force calculation (avoid another multiplication)
                let forceMagnitude = (G_STAR * mass1 * mass2) / distSquared
                
                // Reuse dx/dy we already calculated
                let forceX = (dx / dist) * forceMagnitude
                let forceY = (dy / dist) * forceMagnitude
                
                // Larger star pulls smaller star
                if mass1 > mass2 {
                    star2.physicsBody?.applyForce(CGVector(dx: forceX, dy: forceY))
                } else {
                    star1.physicsBody?.applyForce(CGVector(dx: -forceX, dy: -forceY))
                }
            }
        }
    }
    
    private func checkStarProximity() {
        var nearestStar: Star?
        var nearestEdgeDistance: CGFloat = .greatestFiniteMagnitude
        var nearestThreshold: CGFloat = 0
        
        for star in stars {
            let dist = distance(from: star.position, to: blackHole.position)
            let starRadius = star.size.width / 2
            let blackHoleRadius = blackHole.currentDiameter / 2
            let edgeDistance = max(0, dist - starRadius - blackHoleRadius)
            let centerBasedThreshold = max(0, GameConstants.starWarningDistance - starRadius - blackHoleRadius)
            
            // Percentage-based buffer scaled by star size with BH-awareness
            let starBuffer = star.size.width * 0.15
            let blackHoleBuffer = blackHoleRadius * 0.2
            let dynamicEdgeThreshold = min(
                max(GameConstants.starWarningEdgeDistance, starBuffer + blackHoleBuffer),
                350
            )
            let threshold = max(dynamicEdgeThreshold, centerBasedThreshold)
            
            // Only warn if star is strictly larger than black hole (no wiggle room)
            let isDangerous = !blackHole.canConsume(star)
            
            if isDangerous && edgeDistance < threshold {
                // Track nearest dangerous star
                if edgeDistance < nearestEdgeDistance {
                    nearestEdgeDistance = edgeDistance
                    nearestStar = star
                    nearestThreshold = threshold
                }
            } else {
                star.hideWarningGlow()
                if let starName = star.name {
                    HapticManager.shared.stopDangerProximityHaptic(starID: starName)
                }
            }
        }
        
        // Drive effects only for nearest star
        if let star = nearestStar, let starName = star.name {
            star.showWarningGlow()
            
            if nearestEdgeDistance < GameConstants.starRimFlashDistance {
                blackHole.retroRimLight?.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 1.0, duration: 0.1),
                    SKAction.fadeAlpha(to: RetroAestheticManager.Config.rimLightIntensity, duration: 0.1)
                ]))
            }
            
            HapticManager.shared.startDangerProximityHaptic(starID: starName, distance: nearestEdgeDistance)
            
            AudioManager.shared.startProximitySound(starID: starName, distance: nearestEdgeDistance, on: self)
        } else {
            // No dangerous stars: stop global proximity
            AudioManager.shared.stopAllProximitySounds()
        }
    }
    
    private func updateCamera() {
        // Smooth camera follow
        let lerpFactor: CGFloat = 0.15
        let newX = cameraNode.position.x + (blackHole.position.x - cameraNode.position.x) * lerpFactor
        let newY = cameraNode.position.y + (blackHole.position.y - cameraNode.position.y) * lerpFactor
        cameraNode.position = CGPoint(x: newX, y: newY)
        
        // Dynamic zoom based on black hole size
        let targetZoom = calculateCameraZoom(blackHoleSize: blackHole.currentDiameter)
        let currentZoom = cameraNode.xScale
        
        // Smooth zoom transition
        let newZoom = currentZoom + (targetZoom - currentZoom) * GameConstants.cameraZoomLerpFactor
        cameraNode.setScale(newZoom)
    }
    
    private func calculateCameraZoom(blackHoleSize: CGFloat) -> CGFloat {
        // Keep black hole at constant screen percentage
        let screenHeight = size.height
        let targetPercentage = GameConstants.cameraZoomTargetPercentage
        
        // Calculate required zoom to maintain size
        // In SpriteKit: scale > 1.0 = zoomed out (see more)
        let zoomFactor = blackHoleSize / (screenHeight * targetPercentage)
        
        // Clamp between min and max zoom
        // Min 0.5 = most zoomed in, Max 4.0 = most zoomed out
        return max(GameConstants.cameraMinZoom, min(GameConstants.cameraMaxZoom, zoomFactor))
    }
    
    // MARK: - UI Updates
    
    private func updateScoreLabel() {
        let score = GameManager.shared.currentScore
        scoreLabel.text = "\(formatScore(score))"
        
        // Update stroke label
        if let strokeLabel = scoreLabel.children.first as? SKLabelNode {
            strokeLabel.text = scoreLabel.text
        }
    }
    
    fileprivate func formatScore(_ score: Int) -> String {
        return "\(score)"
    }
    
    // MARK: - Tip Banner System
    
    private func isInCameraView(_ position: CGPoint) -> Bool {
        guard let camera = cameraNode else { return false }
        guard let view = self.view else { return false }
        
        let viewportSize = view.bounds.size
        let cameraPos = camera.position
        
        // Convert world position to screen position
        let worldPos = convert(position, to: camera)
        let screenPos = CGPoint(
            x: worldPos.x + viewportSize.width / 2,
            y: worldPos.y + viewportSize.height / 2
        )
        
        // Check if position is within visible screen bounds (with some margin)
        return screenPos.x >= -50 && screenPos.x <= viewportSize.width + 50 &&
               screenPos.y >= -50 && screenPos.y <= viewportSize.height + 50
    }
    
    private func showTipBanner(text: String, duration: TimeInterval) {
        // Remove old banner if exists
        tipBannerNode?.removeFromParent()
        
        guard let camera = self.camera else { return }
        
        // Create banner background
        let bannerWidth: CGFloat = min(350, UIScreen.main.bounds.width - 40)
        let bannerHeight: CGFloat = 80
        
        let bannerBackground = SKShapeNode(rectOf: CGSize(width: bannerWidth, height: bannerHeight), cornerRadius: 8)
        bannerBackground.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.24)
        bannerBackground.strokeColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.5)
        bannerBackground.lineWidth = 1.5
        bannerBackground.zPosition = 2000
        
        // Position centered horizontally, below Dynamic Island / status bar
        let screenSize = UIScreen.main.bounds.size
        var topMargin: CGFloat = 100  // Default margin from top
        
        // Account for Dynamic Island / notch on modern iPhones
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let safeAreaTop = window.safeAreaInsets.top
            // Add extra space below the Dynamic Island / notch area and shrink gauge
            topMargin = safeAreaTop + 130  // Lower to avoid shrink gauge
        }
        
        let bannerX: CGFloat = 0  // Center horizontally
        let bannerY: CGFloat = screenSize.height / 2 - topMargin
        
        bannerBackground.position = CGPoint(x: bannerX, y: bannerY)
        
        // Create text label
        let label = SKLabelNode(fontNamed: "NDAstroneer-Regular")
        label.text = text
        label.fontSize = 16
        label.fontColor = UIColor(hex: "#9FDFFF")
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = bannerWidth - 40
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: bannerX, y: bannerY)
        label.zPosition = 2001
        
        // Group banner and label
        tipBannerNode = SKNode()
        tipBannerNode?.addChild(bannerBackground)
        tipBannerNode?.addChild(label)
        camera.addChild(tipBannerNode!)
        
        // Fade in animation
        tipBannerNode?.alpha = 0
        tipBannerNode?.setScale(0.95)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        scaleUp.timingMode = .easeOut
        tipBannerNode?.run(SKAction.group([fadeIn, scaleUp]))
        
        // Pause game (but don't show pause overlay)
        isGamePaused = true
        physicsWorld.speed = 0
        
        // Pause timers by setting fireDate to distant future
        if let starTimer = starSpawnTimer {
            starTimer.fireDate = Date.distantFuture
        }
        if let colorTimer = colorChangeTimer {
            colorTimer.fireDate = Date.distantFuture
        }
        
        // Pause power-up animations
        powerUpManager?.activePowerUps.forEach { powerUp in
            powerUp.isPaused = true
        }
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismissTipBanner()
        }
    }
    
    private func dismissTipBanner() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        tipBannerNode?.run(SKAction.sequence([fadeOut, remove])) {
            self.tipBannerNode = nil
        }
        
        // Resume game
        isGamePaused = false
        physicsWorld.speed = 1.0
        
        // Unpause timers by rescheduling them immediately with fresh intervals
        // This ensures the color change interval stays proper (5-12 seconds)
        scheduleNextStarSpawn()
        scheduleNextColorChange()
        
        // Resume power-up animations
        powerUpManager?.activePowerUps.forEach { powerUp in
            powerUp.isPaused = false
        }
        
        // Check if we should show the shrink gauge tip after movement tip
        if !self.hasShownShrinkGaugeTip && self.hasShownMovementTip {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkAndShowShrinkGaugeTip()
            }
        }
    }
    
    private func checkAndShowMovementTip() {
        hasShownMovementTip = UserDefaults.standard.bool(forKey: "hasShownMovementTip")
        if !hasShownMovementTip {
            showTipBanner(text: "Touch and drag the black hole to move. Absorb stars that match the ring color around the black hole.", duration: 5.0)
            UserDefaults.standard.set(true, forKey: "hasShownMovementTip")
        }
    }
    
    private func checkAndShowShrinkGaugeTip() {
        hasShownShrinkGaugeTip = UserDefaults.standard.bool(forKey: "hasShownShrinkGaugeTip")
        if !hasShownShrinkGaugeTip {
            showTipBanner(text: "The cyan gauge shows your size. Your black hole shrinks over time if you don't absorb stars.", duration: 4.0)
            UserDefaults.standard.set(true, forKey: "hasShownShrinkGaugeTip")
        }
    }
    
    private func checkAndShowWrongColorTip() {
        hasShownWrongColorTip = UserDefaults.standard.bool(forKey: "hasShownWrongColorTip")
        if !hasShownWrongColorTip {
            showTipBanner(text: "If you absorb a star that does not match the ring color you'll shrink.", duration: 3.0)
            UserDefaults.standard.set(true, forKey: "hasShownWrongColorTip")
        }
    }
    
    private func checkAndShowDangerStarTip() {
        hasShownDangerStarTip = UserDefaults.standard.bool(forKey: "hasShownDangerStarTip")
        if !hasShownDangerStarTip {
            showTipBanner(text: "Stay away from stars larger than you.", duration: 3.0)
            UserDefaults.standard.set(true, forKey: "hasShownDangerStarTip")
        }
    }
    
    private func checkAndShowPowerUpTip() {
        hasShownPowerUpTip = UserDefaults.standard.bool(forKey: "hasShownPowerUpTip")
        if !hasShownPowerUpTip {
            showTipBanner(text: "Absorb a comet to either freeze all stars or absorb any color for 8 seconds.", duration: 3.0)
            UserDefaults.standard.set(true, forKey: "hasShownPowerUpTip")
        }
    }
    
    private func checkDangerStarTip() {
        guard !hasShownDangerStarTip && !UserDefaults.standard.bool(forKey: "hasShownDangerStarTip") else { return }
        
        // Check if any star larger than black hole is in camera view
        for star in stars {
            if !blackHole.canConsume(star) && isInCameraView(star.position) {
                checkAndShowDangerStarTip()
                hasShownDangerStarTip = true
                break
            }
        }
    }
    
    private func checkPowerUpTip() {
        guard !hasShownPowerUpTip && !UserDefaults.standard.bool(forKey: "hasShownPowerUpTip") else { return }
        
        // Check if any power-up is in camera view
        for powerUp in powerUpManager.activePowerUps {
            if isInCameraView(powerUp.position) {
                checkAndShowPowerUpTip()
                hasShownPowerUpTip = true
                break
            }
        }
    }
    
    // MARK: - Game Over
    
    private func triggerGameOver() {
        isGameOver = true
        
        // Check no-shrink achievement
        if !hasShrunkThisGame && blackHole.currentDiameter > GameConstants.blackHoleMinDiameter {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementNoShrink
            )
        }
        
        // Show access point
        GameCenterManager.shared.showAccessPoint()
        
        // Update stats
        let sessionDuration = CACurrentMediaTime() - sessionStartTime
        GameStats.shared.updatePlayTime(seconds: sessionDuration)
        GameStats.shared.updateHighScore(score: GameManager.shared.currentScore)
        
        // Stop all danger proximity haptics
        HapticManager.shared.stopAllDangerProximityHaptics()
        
        // Stop all proximity sounds
        AudioManager.shared.stopAllProximitySounds()
        
        // Stop all music and other sounds BEFORE ad (game over sound plays last)
        AudioManager.shared.stopBackgroundMusic()
        AudioManager.shared.stopPowerUpLoopSound()
        
        // Stop color change warning if active
        stopColorChangeWarning()
        
        // Stop timers
        starSpawnTimer?.invalidate()
        colorChangeTimer?.invalidate()
        colorChangeWarningTimer?.invalidate()
        starSpawnTimer = nil
        colorChangeTimer = nil
        colorChangeWarningTimer = nil
        
        // Stop physics
        physicsWorld.speed = 0
        
        // Play game over sound (last sound before ad)
        AudioManager.shared.playGameOverSound(on: self)
        
        // Increment game over counter
        GameManager.shared.incrementGameOverCount()
        
        // Wait a brief moment for game over sound to start, then show ad
        // Check if we should show an ad
        if GameManager.shared.shouldShowAd() {
            guard let viewController = self.view?.window?.rootViewController else {
                showGameOverUI()
                return
            }
            
            AdManager.shared.showInterstitialWithLoading(
                from: viewController,
                onAdDismissed: { [weak self] in
                    // Reactivate audio session after ad
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        print("⚠️ Failed to reactivate audio session after ad: \(error)")
                    }
                    
                    GameManager.shared.resetAdCounter()
                    self?.showGameOverUI()
                },
                onNoAd: { [weak self] in
                    self?.showGameOverUI()
                }
            )
        } else {
            // Not time to show ad yet, just show game over UI
            showGameOverUI()
        }
    }
    
    private func showGameOverUI() {
        // Prevent showing game over UI twice (e.g., if ad was delayed)
        guard !hasShownGameOverUI else {
            print("⚠️ Game over UI already shown, skipping")
            return
        }
        hasShownGameOverUI = true
        
        guard let skView = view else { return }
        
        if gameOverBlurView == nil {
            let blurEffect = UIBlurEffect(style: .dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = skView.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.isUserInteractionEnabled = false
            skView.addSubview(blurView)
            gameOverBlurView = blurView
        }
        
        let overlayView = SKView(frame: skView.bounds)
        overlayView.allowsTransparency = true
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = true
        skView.addSubview(overlayView)
        gameOverOverlayView = overlayView
        
        let overlayScene = GameOverOverlayScene(size: skView.bounds.size)
        overlayScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        overlayScene.scaleMode = .aspectFill
        overlayScene.backgroundColor = .clear
        overlayScene.gameScene = self
        gameOverOverlayScene = overlayScene
        overlayView.presentScene(overlayScene)

        let hasNewHighScore = GameManager.shared.currentScore == GameManager.shared.highScore && GameManager.shared.highScore > 0
        overlayScene.configure(reason: gameOverReason, finalScore: GameManager.shared.currentScore, hasNewHighScore: hasNewHighScore)
        self.restartButton = overlayScene.restartButton
        self.returnToMenuButton = overlayScene.returnToMenuButton
    }
    
    // MARK: - Pause System
    
    private func pauseGame() {
        isGamePaused = true
        
        // Freeze physics
        physicsWorld.speed = 0
        captureColorChangeTimerState()
        let wasWarningActive = warningWasActive
        
        // Stop color change warning if active
        stopColorChangeWarning()
        warningWasActive = wasWarningActive
        AudioManager.shared.stopAllProximitySounds()
        
        // Pause timers
        starSpawnTimer?.invalidate()
        colorChangeTimer?.invalidate()
        colorChangeWarningTimer?.invalidate()
        starSpawnTimer = nil
        colorChangeTimer = nil
        colorChangeWarningTimer = nil
        
        // Show pause UI
        showPauseOverlay()
        showBlackHoleResumeIndicator()
        
        print("⏸️ Game paused - tap black hole to resume")
    }
    
    private func resumeGame(touch: UITouch, at location: CGPoint) {
        isGamePaused = false
        
        // Resume physics
        physicsWorld.speed = 1.0
        
        // Resume timers
        scheduleNextStarSpawn()
        resumeColorChangeTimerIfNeeded()
        
        // Remove pause UI
        removePauseOverlay()
        blackHole.childNode(withName: "resumeIndicator")?.removeFromParent()
        
        // Move black hole to touch location and track it
        blackHole.position = location
        isBlackHoleBeingMoved = true
        activeTouch = touch
        
        print("▶️ Game resumed")
    }
    
    private func resumeGame() {
        isGamePaused = false
        
        // Resume physics
        physicsWorld.speed = 1.0
        
        // Resume timers
        scheduleNextStarSpawn()
        resumeColorChangeTimerIfNeeded()
        
        print("▶️ Game resumed")
    }
    
    private func showPauseOverlay() {
        // Semi-transparent dark overlay
        pauseOverlay = SKSpriteNode(color: .black, size: CGSize(width: 5000, height: 5000))
        pauseOverlay!.alpha = 0
        pauseOverlay!.position = CGPoint.zero
        pauseOverlay!.zPosition = 150
        cameraNode.addChild(pauseOverlay!)
        
        pauseOverlay!.run(SKAction.fadeAlpha(to: 0.6, duration: 0.2))
        
        // Get screen size for positioning
        let screenSize = UIScreen.main.bounds.size
        
        // "PAUSED" title
        let pauseTitle = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        pauseTitle.text = "PAUSED"
        pauseTitle.fontSize = 48
        pauseTitle.fontColor = .white
        pauseTitle.position = CGPoint(x: 0, y: 150)
        pauseTitle.zPosition = 151
        pauseTitle.name = "pauseTitle"
        pauseTitle.alpha = 0
        pauseOverlay!.addChild(pauseTitle)
        
        // "Tap Black Hole to Resume" instruction
        let resumeLabel = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        resumeLabel.text = "Tap Black Hole to Resume"
        resumeLabel.fontSize = 24
        resumeLabel.fontColor = .white
        resumeLabel.position = CGPoint(x: 0, y: 100)
        resumeLabel.zPosition = 151
        resumeLabel.name = "resumeLabel"
        resumeLabel.alpha = 0
        pauseOverlay!.addChild(resumeLabel)
        
        // Fade in text
        pauseTitle.run(SKAction.fadeIn(withDuration: 0.3))
        resumeLabel.run(SKAction.fadeIn(withDuration: 0.3))
        
        // Blink animation for resume instruction
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.8),
            SKAction.fadeAlpha(to: 0.8, duration: 0.8)
        ])
        resumeLabel.run(SKAction.repeatForever(blink))
        
        // Create "Return to Menu" button
        returnToMenuButton = MenuButton(text: "RETURN TO MENU", size: .medium)
        returnToMenuButton!.position = CGPoint(x: 0, y: -screenSize.height/2 + 54)  // 54pt from bottom
        returnToMenuButton!.name = "returnToMenuButton"
        returnToMenuButton!.zPosition = 151
        returnToMenuButton!.alpha = 0
        pauseOverlay!.addChild(returnToMenuButton!)
        
        // Fade in button
        returnToMenuButton!.run(SKAction.fadeIn(withDuration: 0.3))
    }
    
    private func showBlackHoleResumeIndicator() {
        // Add pulsing ring around black hole to indicate where to tap
        let ring = SKShapeNode(circleOfRadius: blackHole.currentDiameter / 2 + 30)
        ring.strokeColor = .cyan
        ring.lineWidth = 3
        ring.glowWidth = 8
        ring.fillColor = .clear
        ring.name = "resumeIndicator"
        ring.zPosition = 200
        
        // Pulsing animation
        let scaleUp = SKAction.scale(to: 1.2, duration: 1.0)
        let scaleDown = SKAction.scale(to: 1.0, duration: 1.0)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        ring.run(SKAction.repeatForever(pulse))
        
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 1.0)
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 1.0)
        let fade = SKAction.sequence([fadeOut, fadeIn])
        ring.run(SKAction.repeatForever(fade))
        
        blackHole.addChild(ring)
    }
    
    private func removePauseOverlay() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        returnToMenuButton = nil
    }
    
    // MARK: - Background/Foreground Handling
    
    func pauseGameFromBackground() {
        // Don't double-pause
        guard !isGamePaused else { return }
        guard !isGameOver else { return }
        
        isGamePaused = true
        physicsWorld.speed = 0
        captureColorChangeTimerState()
        let wasWarningActive = warningWasActive
        
        // Stop color change warning if active
        stopColorChangeWarning()
        warningWasActive = wasWarningActive
        
        // Invalidate timers before pausing
        starSpawnTimer?.invalidate()
        colorChangeTimer?.invalidate()
        colorChangeWarningTimer?.invalidate()
        starSpawnTimer = nil
        colorChangeTimer = nil
        colorChangeWarningTimer = nil
        
        print("📱 App backgrounded - game paused")
    }
    
    func resumeGameFromForeground() {
        // Don't resume if already playing or game over
        guard isGamePaused else { return }
        guard !isGameOver else { return }
        
        isGamePaused = false
        physicsWorld.speed = 1.0
        
        // Resume timers with their original intervals
        scheduleNextStarSpawn()
        resumeColorChangeTimerIfNeeded()
        
        // Remove any existing pause overlay (from manual pause)
        removePauseOverlay()
        blackHole.childNode(withName: "resumeIndicator")?.removeFromParent()
        
        print("📱 App foregrounded - game resumed")
    }
    
    // MARK: - Passive Shrink System
    
    private func applyPassiveShrink(currentTime: TimeInterval) {
        // Don't shrink while paused
        guard !isGamePaused else { return }
        
        // Initialize timing
        if lastShrinkTime == 0 {
            lastShrinkTime = currentTime
            return
        }
        
        let deltaTime = currentTime - lastShrinkTime
        lastShrinkTime = currentTime
        
        // Skip large time gaps (backgrounding)
        guard deltaTime < 1.0 else { return }
        
        // Apply constant shrink
        let shrinkAmount = GameConstants.passiveShrinkRate * CGFloat(deltaTime)
        let newSize = max(GameConstants.blackHoleMinDiameter, blackHole.currentDiameter - shrinkAmount)
        if newSize < blackHole.currentDiameter {
            hasShrunkThisGame = true
        }
        blackHole.updateSize(to: newSize)
        
        // Check for collapse
        if blackHole.isAtMinimumSize() {
            gameOverReason = "Black hole collapsed"
            triggerGameOver()
        }
    }
    
    private func updateShrinkIndicator() {
        guard let fill = shrinkIndicatorFill else { return }
        
        // Update peak size if black hole has grown beyond current peak
        if blackHole.currentDiameter > peakBlackHoleSize {
            peakBlackHoleSize = blackHole.currentDiameter
        }
        
        // Simple approach: gauge directly mirrors black hole size relative to its current peak
        // When at peak: gauge is full (no gap with outline)
        // When shrinking from peak: gauge shrinks proportionally
        // Account for minimum size so collapse (30pt) shows as almost empty
        let minSize = GameConstants.blackHoleMinDiameter
        let effectiveCurrentSize = max(minSize, blackHole.currentDiameter)
        let effectivePeakSize = max(minSize, peakBlackHoleSize)
        let sizeRatio = max(0.0, min(1.0, (effectiveCurrentSize - minSize) / (effectivePeakSize - minSize)))
        let fillRadius = max(3, GameConstants.shrinkIndicatorRadius * sizeRatio)
        
        // Recreate fill circle
        fill.removeFromParent()
        
        let screenSize = UIScreen.main.bounds.size
        let xPos = screenSize.width / 2 - GameConstants.shrinkIndicatorRightMargin - GameConstants.shrinkIndicatorRadius
        let yPos = screenSize.height / 2 - GameConstants.shrinkIndicatorTopMargin - GameConstants.shrinkIndicatorRadius
        
        shrinkIndicatorFill = SKShapeNode(circleOfRadius: fillRadius)
        shrinkIndicatorFill!.strokeColor = .clear
        shrinkIndicatorFill!.position = CGPoint(x: xPos, y: yPos)
        shrinkIndicatorFill!.zPosition = 101
        
        // Always cyan color
        shrinkIndicatorFill!.fillColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.8)
        
        hudNode.addChild(shrinkIndicatorFill!)
    }
    
    fileprivate func returnToMenu() {
        AudioManager.shared.stopAllProximitySounds()
        HapticManager.shared.stopAllDangerProximityHaptics()
        AudioManager.shared.stopBackgroundMusic()
        
        // Reactivate audio session after ad interruption
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to reactivate audio session: \(error)")
        }
        
        AudioManager.shared.switchToMenuMusic()
        
        // Reset game state before returning to menu
        GameManager.shared.resetScore()
        removeGameOverUI()
        
        // Create menu scene
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = .aspectFill
        
        // Transition to menu
        view?.presentScene(menuScene, transition: SKTransition.fade(withDuration: 0.5))
    }
    
    fileprivate func restartGame() {
        // Clean up game over modal
        hudNode.childNode(withName: "gameOverModal")?.removeFromParent()
        restartButton = nil
        hasTappedRestartButton = false
        
        // Reset game manager
        GameManager.shared.resetScore()
        AudioManager.shared.stopAllProximitySounds()
        HapticManager.shared.stopAllDangerProximityHaptics()
        
        // Ensure music is ready for new game (switchToGameMusic will start it in didMove)
        // Don't stop music here - let it continue or restart in new scene
        
        // Create new scene programmatically
        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFill
        view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.5))
    }
    
    // MARK: - Helper Functions
    
    private func distance(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Cleanup
    
    deinit {
        starSpawnTimer?.invalidate()
        colorChangeTimer?.invalidate()
        colorChangeWarningTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        gameOverBlurView?.removeFromSuperview()
        gameOverOverlayView?.removeFromSuperview()
    }
    
    private func captureColorChangeTimerState() {
        if let startDate = colorChangeTimerStartDate, let interval = colorChangeTimerInterval {
            let elapsed = Date().timeIntervalSince(startDate)
            remainingColorChangeTime = max(0, interval - elapsed)
        } else if let timer = colorChangeTimer {
            remainingColorChangeTime = max(0, timer.fireDate.timeIntervalSinceNow)
        } else {
            remainingColorChangeTime = nil
        }
        if let remaining = remainingColorChangeTime {
            if warningWasActive {
                remainingWarningTime = 0
            } else {
                remainingWarningTime = max(0, remaining - GameConstants.colorChangeWarningDuration)
            }
        } else {
            remainingWarningTime = nil
            warningWasActive = false
        }
    }

    private func resumeColorChangeTimerIfNeeded() {
        colorChangeTimer?.invalidate()
        colorChangeTimer = nil
        colorChangeWarningTimer?.invalidate()
        colorChangeWarningTimer = nil
        guard let intervalRemaining = remainingColorChangeTime else {
            scheduleNextColorChange()
            return
        }
        let interval = max(0.01, intervalRemaining)
        colorChangeTimerInterval = interval
        colorChangeTimerStartDate = Date()
        let targetType = pendingColorChangeType ?? blackHole.targetType
        if targetType != blackHole.targetType {
            if warningWasActive {
                startColorChangeWarning()
            } else if let warningDelay = remainingWarningTime {
                if warningDelay <= 0 {
                    startColorChangeWarning()
                    warningWasActive = true
                } else {
                    warningWasActive = false
                    colorChangeWarningTimer = Timer.scheduledTimer(withTimeInterval: warningDelay, repeats: false) { [weak self] _ in
                        self?.startColorChangeWarning()
                    }
                }
            }
        } else {
            warningWasActive = false
        }
        colorChangeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let pendingType = self.pendingColorChangeType ?? targetType
            if pendingType != self.blackHole.targetType {
                self.stopColorChangeWarning()
                self.blackHole.updateTargetType(to: pendingType)
            }
            self.remainingColorChangeTime = nil
            self.remainingWarningTime = nil
            self.warningWasActive = false
            self.pendingColorChangeType = nil
            self.scheduleNextColorChange()
        }
        remainingColorChangeTime = nil
        remainingWarningTime = nil
    }
    
    func removeGameOverUI() {
        hudNode.childNode(withName: "gameOverModal")?.removeFromParent()
        gameOverBlurView?.removeFromSuperview()
        gameOverBlurView = nil
        gameOverOverlayView?.removeFromSuperview()
        gameOverOverlayView = nil
        gameOverOverlayScene = nil
        gameOverLabel = nil
        finalScoreLabel = nil
        restartButton = nil
        returnToMenuButton = nil
    }
}

private class GameOverOverlayScene: SKScene {
    weak var gameScene: GameScene?
    var restartButton: MenuButton?
    var returnToMenuButton: MenuButton?
    private var modalContainer: SKNode?

    func configure(reason: String?, finalScore: Int, hasNewHighScore: Bool) {
        removeAllChildren()
        let container = SKNode()
        container.name = "gameOverModal"
        container.zPosition = 200
        addChild(container)
        modalContainer = container

        let modalWidth: CGFloat = 300
        let buttonHeight: CGFloat = 49
        let spacingBetweenButtons: CGFloat = 20
        let topPadding: CGFloat = 20
        let bottomPadding: CGFloat = 20

        var contentHeight: CGFloat = 80
        if reason != nil { contentHeight += 50 }
        if hasNewHighScore { contentHeight += 70 }
        contentHeight += 60

        let spaceForButtons = buttonHeight + spacingBetweenButtons + buttonHeight + bottomPadding
        let modalHeight = contentHeight + topPadding + spaceForButtons

        let modalRect = CGRect(x: -modalWidth/2, y: -modalHeight/2, width: modalWidth, height: modalHeight)
        let modalBackground = SKShapeNode(rect: modalRect, cornerRadius: 8)
        modalBackground.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.24)
        modalBackground.strokeColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.5)
        modalBackground.lineWidth = 1.5
        modalBackground.zPosition = 0
        container.addChild(modalBackground)

        var currentY = modalHeight/2 - topPadding - 40

        let titleLabel = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        titleLabel.text = "GAME OVER"
        titleLabel.fontSize = GameConstants.gameOverFontSize
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: currentY)
        titleLabel.zPosition = 1
        container.addChild(titleLabel)
        gameScene?.gameOverLabel = titleLabel
        currentY -= 40

        if let reason = reason {
            let reasonLabel = SKLabelNode(fontNamed: "NDAstroneer-Regular")
            reasonLabel.text = reason
            reasonLabel.fontSize = 20
            reasonLabel.fontColor = UIColor.white.withAlphaComponent(0.6)
            reasonLabel.horizontalAlignmentMode = .center
            reasonLabel.verticalAlignmentMode = .center
            reasonLabel.position = CGPoint(x: 0, y: currentY)
            reasonLabel.zPosition = 1
            container.addChild(reasonLabel)
            currentY -= 50
        }

        if hasNewHighScore {
            let highScoreLabel = SKLabelNode(fontNamed: "NDAstroneer-Regular")
            highScoreLabel.text = "New High Score!"
            highScoreLabel.fontSize = 28
            highScoreLabel.fontColor = UIColor.white.withAlphaComponent(0.6)
            highScoreLabel.horizontalAlignmentMode = .center
            highScoreLabel.verticalAlignmentMode = .center
            highScoreLabel.position = CGPoint(x: 0, y: currentY)
            highScoreLabel.zPosition = 1
            container.addChild(highScoreLabel)

            let scaleUp = SKAction.scale(to: 1.1, duration: 0.5)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
            highScoreLabel.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
            currentY -= 70
        }

        let finalScoreLabel = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        let formattedScore = gameScene?.formatScore(finalScore) ?? String(finalScore)
        finalScoreLabel.text = "Final Score: \(formattedScore)"
        finalScoreLabel.fontSize = GameConstants.finalScoreFontSize
        finalScoreLabel.fontColor = .white
        finalScoreLabel.horizontalAlignmentMode = .center
        finalScoreLabel.verticalAlignmentMode = .center
        finalScoreLabel.position = CGPoint(x: 0, y: currentY)
        finalScoreLabel.zPosition = 1
        container.addChild(finalScoreLabel)
        gameScene?.finalScoreLabel = finalScoreLabel

        let buttonWidth = modalWidth - 40
        let returnButtonY = -modalHeight/2 + bottomPadding + buttonHeight/2
        let restartButtonY = returnButtonY + buttonHeight/2 + spacingBetweenButtons + buttonHeight/2

        let restart = MenuButton(text: "RESTART", size: .medium, fixedWidth: buttonWidth)
        restart.position = CGPoint(x: 0, y: restartButtonY)
        restart.name = "restartButton"
        restart.zPosition = 1
        container.addChild(restart)
        restartButton = restart

        let returnButton = MenuButton(text: "RETURN TO MENU", size: .medium, fixedWidth: buttonWidth)
        returnButton.position = CGPoint(x: 0, y: returnButtonY)
        returnButton.name = "returnToMenuButton"
        returnButton.zPosition = 1
        container.addChild(returnButton)
        returnToMenuButton = returnButton
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let restartButton = restartButton {
            let buttonLocation = convert(location, to: restartButton.parent!)
            if restartButton.contains(point: buttonLocation) {
                restartButton.animatePress()
            }
        }

        if let returnButton = returnToMenuButton {
            let buttonLocation = convert(location, to: returnButton.parent!)
            if returnButton.contains(point: buttonLocation) {
                returnButton.animatePress()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let restartButton = restartButton {
            let buttonLocation = convert(location, to: restartButton.parent!)
            if restartButton.contains(point: buttonLocation) {
                restartButton.animateRelease()
                gameScene?.restartGame()
                return
            } else {
                restartButton.animateRelease()
            }
        }

        if let returnButton = returnToMenuButton {
            let buttonLocation = convert(location, to: returnButton.parent!)
            if returnButton.contains(point: buttonLocation) {
                returnButton.animateRelease()
                gameScene?.returnToMenu()
                return
            } else {
                returnButton.animateRelease()
            }
        }
    }
}
