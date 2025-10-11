//
//  Star.swift
//  blackHole
//
//  Represents a colored star that can be consumed by the black hole
//

import SpriteKit

class Star: SKSpriteNode {
    let starType: StarType
    private var warningGlow: SKShapeNode?
    var hasBeenMerged: Bool = false
    var isMergedStar: Bool = false
    var basePoints: Int
    
    init(type: StarType) {
        self.starType = type
        self.basePoints = type.basePoints
        
        // Use type-specific size range
        let diameter = CGFloat.random(in: type.sizeRange)
        let texture = Star.createCircleTexture(diameter: diameter, color: type.uiColor)
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        
        self.name = "star"
        setupPhysics(diameter: diameter)
        addGlowEffect()
        addInitialDrift()
        startSpecialEffect()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPhysics(diameter: CGFloat) {
        let radius = diameter / 2
        physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = GameConstants.starCategory
        physicsBody?.collisionBitMask = GameConstants.starCategory // Allow star-star collisions
        physicsBody?.contactTestBitMask = GameConstants.blackHoleCategory | GameConstants.starCategory // Detect both
        physicsBody?.linearDamping = 0.1
        physicsBody?.angularDamping = 0.1
        physicsBody?.restitution = 0.1 // Minimal bounce for easier merging
        physicsBody?.friction = 0.5
        // Mass proportional to area with type-specific multiplier
        physicsBody?.mass = radius * radius * starType.massMultiplier
    }
    
    private func addGlowEffect() {
        // Add a glow with type-specific radius
        let glowRadius = starType.glowRadius
        let glowSize = size.width + (glowRadius * 2)
        let glowNode = SKSpriteNode(texture: self.texture, size: CGSize(width: glowSize, height: glowSize))
        glowNode.color = starType.uiColor
        glowNode.colorBlendFactor = 0.5
        glowNode.alpha = 0.3
        glowNode.zPosition = -1
        glowNode.name = "glow"
        addChild(glowNode)
        
        // Pulse animation for glow - intensity based on star type
        let minAlpha: CGFloat = starType == .blueGiant || starType == .whiteDwarf ? 0.3 : 0.2
        let maxAlpha: CGFloat = starType == .blueGiant || starType == .whiteDwarf ? 0.5 : 0.4
        
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: minAlpha, duration: 0.8),
            SKAction.fadeAlpha(to: maxAlpha, duration: 0.8)
        ])
        glowNode.run(SKAction.repeatForever(pulse))
    }
    
    private func startSpecialEffect() {
        switch starType {
        case .blueGiant:
            // Fast twinkling effect
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.9, duration: 0.15),
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ])
            run(SKAction.repeatForever(twinkle), withKey: "twinkle")
            
        case .redSupergiant:
            // Slow pulsing effect
            let pulse = SKAction.sequence([
                SKAction.scale(to: 0.95, duration: 1.5),
                SKAction.scale(to: 1.05, duration: 1.5)
            ])
            run(SKAction.repeatForever(pulse), withKey: "pulse")
            
        default:
            break
        }
    }
    
    private func addInitialDrift() {
        // Random velocity for drift - stronger movement
        let range = GameConstants.starInitialVelocityRange
        let dx = CGFloat.random(in: -range...range)
        let dy = CGFloat.random(in: -range...range)
        physicsBody?.velocity = CGVector(dx: dx, dy: dy)
    }
    
    func playSpawnAnimation() {
        setScale(0)
        let scaleUp = SKAction.scale(to: 1.0, duration: GameConstants.starSpawnAnimationDuration)
        scaleUp.timingMode = .easeOut
        run(scaleUp)
    }
    
    func playDeathAnimation(completion: @escaping () -> Void) {
        let fadeOut = SKAction.fadeOut(withDuration: GameConstants.starFadeOutDuration)
        let scaleDown = SKAction.scale(to: 0.5, duration: GameConstants.starFadeOutDuration)
        let group = SKAction.group([fadeOut, scaleDown])
        run(group) {
            completion()
        }
    }
    
    func showWarningGlow() {
        // Don't add if already showing
        guard warningGlow == nil else { return }
        
        let glow = SKShapeNode(circleOfRadius: size.width / 2 + 5)
        glow.strokeColor = .red
        glow.lineWidth = 3
        glow.fillColor = .clear
        glow.glowWidth = 8
        glow.alpha = 0.7
        glow.zPosition = 2
        glow.name = "warning"
        addChild(glow)
        warningGlow = glow
        
        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.3),
            SKAction.fadeAlpha(to: 0.9, duration: 0.3)
        ])
        glow.run(SKAction.repeatForever(pulse), withKey: "warningPulse")
    }
    
    func hideWarningGlow() {
        warningGlow?.removeFromParent()
        warningGlow = nil
    }
    
    func addMergedStarIndicator() {
        // Add pulsing yellow ring to show this is a merged star
        let ring = SKShapeNode(circleOfRadius: size.width / 2 + 8)
        ring.strokeColor = .yellow
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.alpha = 0.6
        ring.zPosition = 2
        ring.name = "mergedIndicator"
        addChild(ring)
        
        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 0.6, duration: 0.8)
        ])
        ring.run(SKAction.repeatForever(pulse))
    }
    
    // Helper to create a circle texture
    private static func createCircleTexture(diameter: CGFloat, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { context in
            color.setFill()
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            context.cgContext.fillEllipse(in: rect)
        }
        return SKTexture(image: image)
    }
}

