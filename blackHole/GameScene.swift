//
//  GameScene.swift
//  blackHole
//
//  Main gameplay scene
//

import SpriteKit
import GameplayKit

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
    private var stars: [Star] = []
    private var cameraNode: SKCameraNode!
    private var hudNode: SKNode!
    private var backgroundLayers: [[SKSpriteNode]] = [[], [], []]  // Far, mid, near layers
    private var nebulaNode: SKSpriteNode?  // Distant nebula gradient for atmosphere
    
    var powerUpManager: PowerUpManager!
    var activePowerUp = ActivePowerUpState()
    
    private var starSpawnTimer: Timer?
    private var colorChangeTimer: Timer?
    
    // Grace period tracking
    private var lastCorrectEatTime: TimeInterval = 0
    
    private var scoreLabel: SKLabelNode!
    private var gameOverLabel: SKLabelNode?
    private var finalScoreLabel: SKLabelNode?
    private var restartLabel: SKLabelNode?
    
    private var isGameOver = false
    private var gameOverReason: String?
    
    private var mergedStarCount: Int = 0
    private var lastMergeTime: TimeInterval = 0
    
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
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        // Preload all textures BEFORE scene setup
        TextureCache.shared.preloadAllTextures()
        
        setupScene()
        setupCamera()
        setupBackgroundStars()
        setupBlackHole()
        setupPowerUpSystem()
        setupUI()
        setupPowerUpUI()
        startGameTimers()
        
        // Initialize background star positions relative to camera
        updateBackgroundStars()
    }
    
    private func setupPowerUpSystem() {
        let currentTime = CACurrentMediaTime()
        powerUpManager = PowerUpManager(gameStartTime: currentTime)
        powerUpManager.scene = self
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
            sizeRange: 0.8...1.5,  // Keep size same
            alphaRange: 0.3...0.5,  // Brighter for visibility
            useColorVariety: true,
            zPosition: -30,
            layerIndex: 0
        )
        
        // Layer 1: Mid-distance stars (moderate brightness and parallax)
        createStarLayer(
            count: 250,  // More than doubled for density
            sizeRange: 1.5...2.5,  // Keep size same
            alphaRange: 0.5...0.7,  // Brighter
            useColorVariety: true,
            zPosition: -20,
            layerIndex: 1
        )
        
        // Layer 2: Near stars (brightest, fastest parallax)
        createStarLayer(
            count: 150,  // Nearly doubled for better foreground
            sizeRange: 2.5...3.0,  // Keep size same
            alphaRange: 0.7...0.9,  // Much brighter for visibility
            useColorVariety: false,  // Near stars stay white for clarity
            zPosition: -10,
            layerIndex: 2
        )
    }
    
    private func createStarLayer(count: Int, sizeRange: ClosedRange<CGFloat>,
                                alphaRange: ClosedRange<CGFloat>, useColorVariety: Bool,
                                zPosition: CGFloat, layerIndex: Int) {
        let spread: CGFloat = 1500  // Tighter spread for denser starfield
        
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
            let star = SKSpriteNode(color: color, size: CGSize(width: starSize, height: starSize))
            
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
        let wrapDistance: CGFloat = 1500  // When to wrap stars
        
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
                    let wrapRadius: CGFloat = 1000
                    
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
        scoreLabel = SKLabelNode(fontNamed: "SFProRounded-Bold")
        if scoreLabel.fontName == nil {
            scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        }
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
        // Container for power-up indicator (top-right)
        let container = SKNode()
        // Position relative to camera view using screen bounds (not world size)
        let screenSize = UIScreen.main.bounds.size
        let xOffset = screenSize.width / 2 - 70
        let yOffset = screenSize.height / 2 - 50
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
        let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        timerLabel.fontSize = 16
        timerLabel.fontColor = .white
        timerLabel.position = CGPoint(x: 0, y: -40)
        timerLabel.name = "powerUpTimer"
        container.addChild(timerLabel)
        
        activePowerUp.indicatorNode = container
        container.isHidden = true
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
        
        colorChangeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.changeTargetColor()
            self?.scheduleNextColorChange()  // Reschedule with new random interval
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
            let spawnPosition = randomEdgePosition()
            
            // Check 1: Distance from black hole
            let minDistanceFromBlackHole = calculateMinSpawnDistance(for: star)
            guard distance(from: spawnPosition, to: blackHole.position) > minDistanceFromBlackHole else {
                attempts += 1
                continue
            }
            
            // Check 2: Distance from other large stars (prevents clustering)
            if isValidSpawnPosition(spawnPosition, forStarSize: star.size.width) {
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
        // Larger stars need more minimum distance
        // Small stars: 100pt minimum
        // Large stars: 200-300pt minimum
        return max(GameConstants.starMinSpawnDistance, star.size.width * 2.5)
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
        
        if size < 50 {
            // Phase 1: Safe learning (30-50pt) - Only tiny stars
            return .whiteDwarf  // 100% (18-28pt - always safe)
            
        } else if size < 70 {
            // Phase 2: Introduce yellow (50-70pt) - All edible
            if random < 0.70 { return .whiteDwarf }      // 70% (18-28pt)
            else { return .yellowDwarf }                  // 30% (32-42pt)
            
        } else if size < 100 {
            // Phase 3: Introduce blue (70-100pt) - Blues now safe at 70+
            if random < 0.40 { return .whiteDwarf }      // 40% (18-28pt)
            else if random < 0.70 { return .yellowDwarf } // 30% (32-42pt)
            else { return .blueGiant }                    // 30% (45-58pt)
            
        } else if size < 130 {
            // Phase 4: Introduce orange (100-130pt) - Some oranges edible, rare red giants
            if random < 0.2375 { return .whiteDwarf }      // 23.75% (18-28pt)
            else if random < 0.4275 { return .yellowDwarf } // 19% (32-42pt)
            else if random < 0.7125 { return .blueGiant }   // 28.5% (45-58pt)
            else if random < 0.95 { return .orangeGiant }   // 23.75% (90-140pt - risky!)
            else { return .redSupergiant }                  // 5% (280-600pt - VERY DANGEROUS!)
            
        } else if size < 600 {
            // Phase 5: All types (130-600pt) - Full game unlocked
            if random < 0.20 { return .whiteDwarf }      // 20% (16-24pt)
            else if random < 0.35 { return .yellowDwarf } // 15% (28-38pt)
            else if random < 0.60 { return .blueGiant }   // 25% (55-75pt)
            else if random < 0.85 { return .orangeGiant } // 25% (120-200pt)
            else { return .redSupergiant }                // 15% (280-600pt - highest reward!)
            
        } else {
            // Phase 6: Supermassive mode (600pt+)
            // Favor larger, more valuable stars
            if random < 0.10 { return .whiteDwarf }      // 10% (less tedious small stars)
            else if random < 0.15 { return .yellowDwarf } // 5%
            else if random < 0.30 { return .blueGiant }   // 15%
            else if random < 0.60 { return .orangeGiant } // 30% (common)
            else { return .redSupergiant }                // 40% (very common!)
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
    
    private func changeTargetColor() {
        guard !isGameOver else { return }
        let availableTypes = getAvailableStarTypes()
        
        // Don't repeat the same color (unless it's the only option)
        if availableTypes.count > 1 {
            let differentTypes = availableTypes.filter { $0 != blackHole.targetType }
            let newType = differentTypes.randomElement() ?? availableTypes.randomElement() ?? .whiteDwarf
            blackHole.updateTargetType(to: newType)
        } else {
            // Only one color available, no choice but to repeat
            let newType = availableTypes.first ?? .whiteDwarf
            blackHole.updateTargetType(to: newType)
        }
    }
    
    private func getAvailableStarTypes() -> [StarType] {
        let size = blackHole.currentDiameter
        
        // Determine base types for current phase
        let phaseTypes: [StarType]
        if size < 50 {
            // Phase 1: White only
            phaseTypes = [.whiteDwarf]
        } else if size < 70 {
            // Phase 2: White + Yellow
            phaseTypes = [.whiteDwarf, .yellowDwarf]
        } else if size < 100 {
            // Phase 3: White + Yellow + Blue
            phaseTypes = [.whiteDwarf, .yellowDwarf, .blueGiant]
        } else if size < 130 {
            // Phase 4: Add Orange (Red spawns at 5% but usually uneatable)
            phaseTypes = [.whiteDwarf, .yellowDwarf, .blueGiant, .orangeGiant]
        } else {
            // Phase 5+: All colors available
            phaseTypes = Array(StarType.allCases)
        }
        
        // Filter to only types that have at least one edible star currently on screen
        let edibleTypes = phaseTypes.filter { type in
            stars.contains { star in
                star.starType == type && blackHole.canConsume(star)
            }
        }
        
        // Fallback: if no edible stars of phase types, use phase types
        // (prevents indicator from going blank in edge cases)
        return edibleTypes.isEmpty ? phaseTypes : edibleTypes
    }
    
    private func applyGravity() {
        guard !isGameOver else { return }
        
        let blackHoleRadius = blackHole.currentDiameter / 2
        let blackHoleMass = blackHoleRadius * blackHoleRadius
        
        for star in stars {
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
            
            lastCorrectEatTime = CACurrentMediaTime()  // Track for grace period
            
            let multiplier = GameManager.shared.getScoreMultiplier(blackHoleDiameter: blackHole.currentDiameter)
            let points = star.starType.basePoints * multiplier
            GameManager.shared.addScore(points)
            AudioManager.shared.playCorrectSound()
            AudioManager.shared.playGrowSound()
            
            // Haptic feedback for correct consumption
            HapticManager.shared.playCorrectStarHaptic(starSize: star.size.width)
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
                
                blackHole.shrinkByMultiplier(adjustedMultiplier)
                GameManager.shared.addScore(GameConstants.wrongColorPenalty)
                AudioManager.shared.playWrongSound()
                AudioManager.shared.playShrinkSound()
                
                // Haptic feedback for wrong consumption
                let isInDangerZone = blackHole.currentDiameter < 40
                HapticManager.shared.playWrongStarHaptic(isInDangerZone: isInDangerZone)
                
                // Check for game over
                if blackHole.isAtMinimumSize() {
                    gameOverReason = "Black hole shrunk too small"
                    triggerGameOver()
                }
            }
        }
        
        updateScoreLabel()
        
        // Create particle effect at collision point
        createCollisionParticles(at: star.position, color: star.starType.uiColor)
        
        // Remove star
        removeStar(star)
    }
    
    private func removeStar(_ star: Star) {
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
            print("🚫 Merge blocked: max merged stars reached (\(mergedStarCount)/\(GameConstants.maxMergedStars))")
            return
        }
        
        // Safeguard 2: Check cooldown
        guard currentTime - lastMergeTime > GameConstants.mergeCooldown else {
            print("🚫 Merge blocked: cooldown (\(String(format: "%.1f", currentTime - lastMergeTime))s/\(GameConstants.mergeCooldown)s)")
            return
        }
        
        // Safeguard 3: Check minimum size
        guard star1.size.width >= GameConstants.minMergeSizeRequirement else {
            print("🚫 Merge blocked: star1 too small (\(String(format: "%.0f", star1.size.width))pt < \(GameConstants.minMergeSizeRequirement)pt)")
            return
        }
        guard star2.size.width >= GameConstants.minMergeSizeRequirement else {
            print("🚫 Merge blocked: star2 too small (\(String(format: "%.0f", star2.size.width))pt < \(GameConstants.minMergeSizeRequirement)pt)")
            return
        }
        
        // Safeguard 4: Neither star has already been merged
        guard !star1.hasBeenMerged && !star2.hasBeenMerged else {
            print("🚫 Merge blocked: star already merged")
            return
        }
        
        // Safeguard 5: Not too close to black hole
        let distToBlackHole1 = distance(from: star1.position, to: blackHole.position)
        let distToBlackHole2 = distance(from: star2.position, to: blackHole.position)
        guard distToBlackHole1 > GameConstants.mergeDistanceFromBlackHole else {
            print("🚫 Merge blocked: star1 too close to black hole (\(String(format: "%.0f", distToBlackHole1))pt < \(GameConstants.mergeDistanceFromBlackHole)pt)")
            return
        }
        guard distToBlackHole2 > GameConstants.mergeDistanceFromBlackHole else {
            print("🚫 Merge blocked: star2 too close to black hole (\(String(format: "%.0f", distToBlackHole2))pt < \(GameConstants.mergeDistanceFromBlackHole)pt)")
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
        
        // Play sound
        AudioManager.shared.playMergeSound()
        
        // Remove original stars
        stars.removeAll { $0 == star1 || $0 == star2 }
        star1.removeFromParent()
        star2.removeFromParent()
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
        
        // Mark as merged
        mergedStar.hasBeenMerged = true
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
        
        // Add visual indicator
        mergedStar.addMergedStarIndicator()
        
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
        AudioManager.shared.playPowerUpCollectSound()
        
        // Haptic feedback for power-up
        HapticManager.shared.playPowerUpHaptic(type: powerUp.type)
        
        print("💎 Collected \(powerUp.type.displayName) power-up!")
    }
    
    private func activatePowerUp(type: PowerUpType) {
        let currentTime = CACurrentMediaTime()
        activePowerUp.activate(type: type, currentTime: currentTime)
        
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
        
        // Deactivate the power-up AFTER handling the expiration
        activePowerUp.deactivate()
        
        AudioManager.shared.playPowerUpExpireSound()
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
        
        // If already moving black hole with another touch, ignore new touches
        if isBlackHoleBeingMoved && activeTouch != touch {
            return
        }
        
        let location = touch.location(in: self)
        
        if isGameOver {
            // Tap anywhere to restart when game is over
            restartGame()
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
        guard let touch = touches.first else { return }
        
        // Only respond to the active touch
        guard touch == activeTouch else { return }
        
        let location = touch.location(in: self)
        blackHole.position = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // If the active touch ended, stop tracking movement
        if touch == activeTouch {
            isBlackHoleBeingMoved = false
            activeTouch = nil
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // If the active touch was cancelled, stop tracking movement
        if touch == activeTouch {
            isBlackHoleBeingMoved = false
            activeTouch = nil
        }
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
        // Track frame rate for performance monitoring
        trackFrameRate(currentTime)
        
        // Update camera to follow black hole smoothly
        updateCamera()
        
        // Update background parallax
        updateBackgroundStars()
        
        // Check star proximity for warnings
        checkStarProximity()
        
        // Update power-up system
        powerUpManager.update(currentTime: currentTime)
        
        // Check power-up expiration
        if activePowerUp.checkExpiration(currentTime: currentTime) {
            handlePowerUpExpiration()
        }
        
        // Update power-up UI
        updatePowerUpUI(currentTime: currentTime)
        
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
        case .medium:
            performanceMode = .low
            // Further reduce and disable distant particles
            adjustStarParticleQuality(multiplier: 0.3)
            disableDistantStarParticles()
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
        case .medium:
            performanceMode = .high
            adjustStarParticleQuality(multiplier: 1.0)
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
        for star in stars {
            let dist = distance(from: star.position, to: blackHole.position)
            
            // If star is too large and getting close, show warning
            if !blackHole.canConsume(star) && dist < GameConstants.starWarningDistance {
                star.showWarningGlow()
                
                // Haptic warning for dangerous star
                if let starName = star.name {
                    HapticManager.shared.startDangerProximityHaptic(starID: starName, distance: dist)
                }
            } else {
                star.hideWarningGlow()
                
                // Stop haptic warning
                if let starName = star.name {
                    HapticManager.shared.stopDangerProximityHaptic(starID: starName)
                }
            }
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
        scoreLabel.text = "Score: \(formatScore(score))"
        
        // Update stroke label
        if let strokeLabel = scoreLabel.children.first as? SKLabelNode {
            strokeLabel.text = scoreLabel.text
        }
    }
    
    private func formatScore(_ score: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }
    
    // MARK: - Game Over
    
    private func triggerGameOver() {
        isGameOver = true
        
        // Stop all danger proximity haptics
        HapticManager.shared.stopAllDangerProximityHaptics()
        
        // Stop timers
        starSpawnTimer?.invalidate()
        colorChangeTimer?.invalidate()
        
        // Stop physics
        physicsWorld.speed = 0
        
        // Play sound
        AudioManager.shared.playGameOverSound()
        
        // Show game over UI
        showGameOverUI()
    }
    
    private func showGameOverUI() {
        // Game Over label - attached to HUD
        gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gameOverLabel!.text = "Game Over"
        gameOverLabel!.fontSize = GameConstants.gameOverFontSize
        gameOverLabel!.fontColor = .white
        gameOverLabel!.position = CGPoint(x: 0, y: 120)
        gameOverLabel!.zPosition = 200
        hudNode.addChild(gameOverLabel!)
        
        // Game over reason label (if applicable)
        if let reason = gameOverReason {
            let reasonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            reasonLabel.text = reason
            reasonLabel.fontSize = 20
            reasonLabel.fontColor = .red
            reasonLabel.position = CGPoint(x: 0, y: 80)
            reasonLabel.zPosition = 200
            hudNode.addChild(reasonLabel)
        }
        
        // Final score label
        finalScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        finalScoreLabel!.text = "Final Score: \(formatScore(GameManager.shared.currentScore))"
        finalScoreLabel!.fontSize = GameConstants.finalScoreFontSize
        finalScoreLabel!.fontColor = .white
        finalScoreLabel!.position = CGPoint(x: 0, y: 30)
        finalScoreLabel!.zPosition = 200
        hudNode.addChild(finalScoreLabel!)
        
        // High score label (if applicable)
        if GameManager.shared.currentScore == GameManager.shared.highScore && GameManager.shared.highScore > 0 {
            let highScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            highScoreLabel.text = "New High Score!"
            highScoreLabel.fontSize = 28
            highScoreLabel.fontColor = .yellow
            highScoreLabel.position = CGPoint(x: 0, y: -20)
            highScoreLabel.zPosition = 200
            hudNode.addChild(highScoreLabel)
            
            // Pulse animation
            let scaleUp = SKAction.scale(to: 1.1, duration: 0.5)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
            highScoreLabel.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
        }
        
        // Restart label
        restartLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        restartLabel!.text = "Tap to Restart"
        restartLabel!.fontSize = GameConstants.restartFontSize
        restartLabel!.fontColor = .lightGray
        restartLabel!.position = CGPoint(x: 0, y: -80)
        restartLabel!.zPosition = 200
        hudNode.addChild(restartLabel!)
        
        // Blink animation for restart label
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.8)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        restartLabel!.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
    }
    
    private func restartGame() {
        // Reset game manager
        GameManager.shared.resetScore()
        
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
    }
}
