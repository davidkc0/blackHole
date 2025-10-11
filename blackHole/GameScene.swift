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
            deactivate()
            return true
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
    private var backgroundStars: [SKSpriteNode] = []
    
    var powerUpManager: PowerUpManager!
    var activePowerUp = ActivePowerUpState()
    
    private var starSpawnTimer: Timer?
    private var colorChangeTimer: Timer?
    
    private var scoreLabel: SKLabelNode!
    private var gameOverLabel: SKLabelNode?
    private var finalScoreLabel: SKLabelNode?
    private var restartLabel: SKLabelNode?
    
    private var isGameOver = false
    private var gameOverReason: String?
    
    private var mergedStarCount: Int = 0
    private var lastMergeTime: TimeInterval = 0
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        setupScene()
        setupCamera()
        setupBackgroundStars()
        setupBlackHole()
        setupPowerUpSystem()
        setupUI()
        setupPowerUpUI()
        startGameTimers()
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
        // Create a field of background stars for visual depth
        let starCount = 100
        let spread: CGFloat = 2000
        
        for _ in 0..<starCount {
            let starSize = CGFloat.random(in: 1...3)
            let star = SKSpriteNode(color: .white, size: CGSize(width: starSize, height: starSize))
            star.position = CGPoint(
                x: CGFloat.random(in: -spread...spread),
                y: CGFloat.random(in: -spread...spread)
            )
            star.alpha = CGFloat.random(in: 0.3...0.8)
            star.zPosition = -10
            addChild(star)
            backgroundStars.append(star)
            
            // Twinkle animation
            let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: Double.random(in: 1...3))
            let fadeIn = SKAction.fadeAlpha(to: star.alpha, duration: Double.random(in: 1...3))
            star.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
        }
    }
    
    private func updateBackgroundStars() {
        // Reposition background stars that are too far from camera
        let maxDistance: CGFloat = 1500
        
        for star in backgroundStars {
            let dx = star.position.x - cameraNode.position.x
            let dy = star.position.y - cameraNode.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > maxDistance {
                // Reposition to the opposite side
                let angle = atan2(dy, dx) + .pi
                let newDistance: CGFloat = 1000
                star.position = CGPoint(
                    x: cameraNode.position.x + cos(angle) * newDistance,
                    y: cameraNode.position.y + sin(angle) * newDistance
                )
            }
        }
    }
    
    private func setupBlackHole() {
        blackHole = BlackHole()
        blackHole.position = CGPoint.zero // Start at world origin
        blackHole.zPosition = 10
        addChild(blackHole)
        
        // Setup particle emitter target after adding to scene
        blackHole.setupParticleTargetNode()
        
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
        
        // Position relative to camera view
        let xOffset = -size.width / 2 + GameConstants.scoreLabelLeftMargin
        let yOffset = size.height / 2 - GameConstants.scoreLabelTopMargin - GameConstants.scoreFontSize
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
        let xOffset = size.width / 2 - 70
        let yOffset = size.height / 2 - 50
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
        // Star spawning timer
        starSpawnTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.starSpawnInterval, repeats: true) { [weak self] _ in
            self?.spawnStar()
        }
        
        // Color change timer
        colorChangeTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.colorChangeInterval, repeats: true) { [weak self] _ in
            self?.changeTargetColor()
        }
    }
    
    // MARK: - Game Logic
    
    private func spawnStar() {
        guard !isGameOver else { return }
        guard stars.count < GameConstants.starMaxCount else { return }
        
        // Select star type based on black hole size
        let starType = selectStarType()
        let star = Star(type: starType)
        
        // Spawn at random edge
        let spawnPosition = randomEdgePosition()
        
        // Ensure star spawns away from black hole
        guard distance(from: spawnPosition, to: blackHole.position) > GameConstants.starMinSpawnDistance else {
            return // Try again next spawn interval
        }
        
        star.position = spawnPosition
        star.zPosition = 5
        addChild(star)
        stars.append(star)
        
        star.playSpawnAnimation()
    }
    
    private func selectStarType() -> StarType {
        let size = blackHole.currentDiameter
        let random = CGFloat.random(in: 0...1)
        
        if size < 70 {
            // Early game: White and Blue only (matches ring colors)
            if random < 0.60 { return .whiteDwarf }
            else { return .blueGiant }
        } else if size < 100 {
            // Mid game: Add Yellow
            if random < 0.40 { return .whiteDwarf }
            else if random < 0.60 { return .yellowDwarf }
            else { return .blueGiant }
        } else if size < 130 {
            // Late game: Add Orange
            if random < 0.30 { return .whiteDwarf }
            else if random < 0.50 { return .yellowDwarf }
            else if random < 0.75 { return .blueGiant }
            else { return .orangeGiant }
        } else {
            // End game: All colors available
            if random < 0.25 { return .whiteDwarf }
            else if random < 0.40 { return .yellowDwarf }
            else if random < 0.65 { return .blueGiant }
            else if random < 0.88 { return .orangeGiant }
            else { return .redSupergiant }
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
        let newType = availableTypes.randomElement() ?? .whiteDwarf
        blackHole.updateTargetType(to: newType)
    }
    
    private func getAvailableStarTypes() -> [StarType] {
        let size = blackHole.currentDiameter
        
        if size < 70 {
            // Early game: White and Blue only
            return [.whiteDwarf, .blueGiant]
        } else if size < 100 {
            // Mid game: Add Yellow
            return [.whiteDwarf, .yellowDwarf, .blueGiant]
        } else if size < 130 {
            // Late game: Add Orange
            return [.whiteDwarf, .yellowDwarf, .blueGiant, .orangeGiant]
        } else {
            // End game: All colors available
            return StarType.allCases
        }
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
        // Remove stars too far from black hole (not screen center)
        stars.removeAll { star in
            let dist = distance(from: star.position, to: blackHole.position)
            if dist > GameConstants.starMaxDistanceFromScreen {
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
            // Game over - black hole destabilized!
            gameOverReason = "Black hole destabilized!"
            triggerGameOver()
            return
        }
        
        // SECOND CHECK: Color/type match (or rainbow active)
        let isCorrectType = star.starType == blackHole.targetType
        let rainbowActive = activePowerUp.activeType == .rainbow
        
        if isCorrectType || rainbowActive {
            // Correct type: grow and add score
            blackHole.grow()
            let multiplier = GameManager.shared.getScoreMultiplier(blackHoleDiameter: blackHole.currentDiameter)
            let points = star.starType.basePoints * multiplier
            GameManager.shared.addScore(points)
            AudioManager.shared.playCorrectSound()
            AudioManager.shared.playGrowSound()
        } else {
            // Wrong type: shrink and lose score
            blackHole.shrink()
            GameManager.shared.addScore(GameConstants.wrongColorPenalty)
            AudioManager.shared.playWrongSound()
            AudioManager.shared.playShrinkSound()
            
            // Check for game over
            if blackHole.isAtMinimumSize() {
                gameOverReason = "Black hole shrunk too small"
                triggerGameOver()
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
        
        print("💎 Collected \(powerUp.type.displayName) power-up!")
    }
    
    private func activatePowerUp(type: PowerUpType) {
        let currentTime = CACurrentMediaTime()
        activePowerUp.activate(type: type, currentTime: currentTime)
        
        // Apply immediate effects
        switch type {
        case .rainbow:
            print("🌈 Rainbow Mode activated! Eat any color for \(type.duration)s")
            
        case .freeze:
            freezeAllStars()
            print("❄️ Freeze activated! Stars frozen for \(type.duration)s")
        }
    }
    
    private func handlePowerUpExpiration() {
        guard let type = activePowerUp.activeType else { return }
        
        print("⏱️ Power-up expired: \(type.displayName)")
        
        switch type {
        case .freeze:
            unfreezeAllStars()
        case .rainbow:
            // Just clear state
            break
        }
        
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
        
        if isGameOver {
            // Tap anywhere to restart when game is over
            restartGame()
        } else {
            // Move black hole to touch location immediately (in world coordinates)
            blackHole.position = location
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver else { return }
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        blackHole.position = location
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
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
    
    private func applyStarToStarGravity() {
        guard GameConstants.enableStarMerging else { return }
        guard stars.count > 1 else { return }
        
        for i in 0..<stars.count {
            for j in (i+1)..<stars.count {
                let star1 = stars[i]
                let star2 = stars[j]
                
                let dist = distance(from: star1.position, to: star2.position)
                guard dist < GameConstants.starGravityRange && dist > 0 else { continue }
                
                let radius1 = star1.size.width / 2
                let radius2 = star2.size.width / 2
                let mass1 = radius1 * radius1 * star1.starType.massMultiplier
                let mass2 = radius2 * radius2 * star2.starType.massMultiplier
                
                let G_STAR = GameConstants.gravitationalConstant * GameConstants.starGravityMultiplier
                let forceMagnitude = (G_STAR * mass1 * mass2) / (dist * dist)
                
                let dx = star2.position.x - star1.position.x
                let dy = star2.position.y - star1.position.y
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
            } else {
                star.hideWarningGlow()
            }
        }
    }
    
    private func updateCamera() {
        // Smooth camera follow
        let lerpFactor: CGFloat = 0.15
        let newX = cameraNode.position.x + (blackHole.position.x - cameraNode.position.x) * lerpFactor
        let newY = cameraNode.position.y + (blackHole.position.y - cameraNode.position.y) * lerpFactor
        cameraNode.position = CGPoint(x: newX, y: newY)
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
