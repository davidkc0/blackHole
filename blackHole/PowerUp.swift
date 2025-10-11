//
//  PowerUp.swift
//  blackHole
//
//  Comet-style power-up with particle trail
//

import SpriteKit

class PowerUp: SKNode {
    let type: PowerUpType
    private let coreNode: SKShapeNode
    private let trailEmitter: SKEmitterNode
    private let sparkleEmitter: SKEmitterNode
    let trajectory: CometTrajectory
    
    init(type: PowerUpType, trajectory: CometTrajectory) {
        self.type = type
        self.trajectory = trajectory
        
        // Create core
        self.coreNode = SKShapeNode(circleOfRadius: GameConstants.cometCoreSize / 2)
        
        // Create emitters
        self.trailEmitter = SKEmitterNode()
        self.sparkleEmitter = SKEmitterNode()
        
        super.init()
        
        self.name = "powerUp"
        setupCore()
        setupTrail()
        setupSparkles()
        setupPhysics()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCore() {
        coreNode.fillColor = type.coreColor
        coreNode.strokeColor = .white
        coreNode.lineWidth = 2
        coreNode.glowWidth = 5
        coreNode.zPosition = 10
        addChild(coreNode)
        
        // Glow effect
        let glow = SKShapeNode(circleOfRadius: 10)
        glow.fillColor = type.coreColor
        glow.strokeColor = .clear
        glow.alpha = 0.4
        glow.zPosition = -1
        glow.name = "glow"
        coreNode.addChild(glow)
        
        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        glow.run(SKAction.repeatForever(pulse))
        
        // Rainbow color cycling for rainbow power-up
        if type == .rainbow {
            cycleRainbowColors()
        }
    }
    
    private func cycleRainbowColors() {
        // Use actual star colors from the game
        let colors: [UIColor] = [
            UIColor(hex: "#F0F0F0"), // White Dwarf
            UIColor(hex: "#FFD700"), // Yellow Dwarf
            UIColor(hex: "#4DA6FF"), // Blue Giant
            UIColor(hex: "#FF8C42"), // Orange Giant
            UIColor(hex: "#DC143C")  // Red Supergiant
        ]
        
        var colorActions: [SKAction] = []
        for color in colors {
            colorActions.append(SKAction.run { [weak self] in
                self?.coreNode.fillColor = color
            })
            colorActions.append(SKAction.wait(forDuration: 0.2))
        }
        
        let cycle = SKAction.sequence(colorActions)
        coreNode.run(SKAction.repeatForever(cycle), withKey: "rainbowCycle")
        
        // Also cycle the glow
        if let glow = coreNode.childNode(withName: "glow") as? SKShapeNode {
            var glowActions: [SKAction] = []
            for color in colors {
                glowActions.append(SKAction.run {
                    glow.fillColor = color
                })
                glowActions.append(SKAction.wait(forDuration: 0.2))
            }
            let glowCycle = SKAction.sequence(glowActions)
            glow.run(SKAction.repeatForever(glowCycle), withKey: "rainbowGlowCycle")
        }
    }
    
    private func setupTrail() {
        // Use programmatically created texture
        trailEmitter.particleTexture = PowerUp.createSparkTexture()
        
        trailEmitter.particleBirthRate = 100
        trailEmitter.particleLifetime = 1.5
        trailEmitter.particleLifetimeRange = 0.5
        
        // Color configuration based on type
        switch type {
        case .rainbow:
            // Rainbow spectrum trail using star colors
            trailEmitter.particleColorSequence = SKKeyframeSequence(
                keyframeValues: [
                    UIColor(hex: "#F0F0F0"), // White
                    UIColor(hex: "#FFD700"), // Yellow
                    UIColor(hex: "#4DA6FF"), // Blue
                    UIColor(hex: "#FF8C42"), // Orange
                    UIColor(hex: "#DC143C"), // Red
                    UIColor.clear
                ],
                times: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
            )
            
        case .freeze:
            trailEmitter.particleColorSequence = SKKeyframeSequence(
                keyframeValues: [
                    UIColor(hex: "#E0FFFF"),
                    UIColor(hex: "#87CEEB"),
                    UIColor.clear
                ],
                times: [0.0, 0.5, 1.0]
            )
        }
        
        // Trail shape and movement
        trailEmitter.particleSpeed = 50
        trailEmitter.particleSpeedRange = 20
        trailEmitter.emissionAngle = .pi  // Will be updated based on movement
        trailEmitter.emissionAngleRange = .pi / 6
        trailEmitter.particleScale = 0.5
        trailEmitter.particleScaleRange = 0.2
        trailEmitter.particleScaleSpeed = -0.3
        trailEmitter.particleAlpha = 0.8
        trailEmitter.particleAlphaSpeed = -0.5
        
        trailEmitter.zPosition = 5
        addChild(trailEmitter)
    }
    
    private func setupSparkles() {
        // Use programmatically created texture
        sparkleEmitter.particleTexture = PowerUp.createSparkTexture()
        
        sparkleEmitter.particleBirthRate = 20
        sparkleEmitter.particleLifetime = 0.5
        sparkleEmitter.particleLifetimeRange = 0.2
        
        // Sparkle colors based on type
        switch type {
        case .rainbow:
            // Prismatic rainbow sparkles
            sparkleEmitter.particleColorSequence = SKKeyframeSequence(
                keyframeValues: [
                    UIColor(hex: "#F0F0F0"), // White
                    UIColor(hex: "#FFD700"), // Yellow
                    UIColor(hex: "#4DA6FF"), // Blue
                    UIColor(hex: "#FF8C42"), // Orange
                    UIColor(hex: "#DC143C"), // Red
                    UIColor.clear
                ],
                times: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
            )
            
        case .freeze:
            sparkleEmitter.particleColorSequence = SKKeyframeSequence(
                keyframeValues: [
                    UIColor.white,
                    UIColor(hex: "#87CEEB"),
                    UIColor.clear
                ],
                times: [0.0, 0.5, 1.0]
            )
        }
        
        // Sparkle behavior
        sparkleEmitter.particleSpeed = 30
        sparkleEmitter.particleSpeedRange = 20
        sparkleEmitter.emissionAngle = 0
        sparkleEmitter.emissionAngleRange = .pi * 2
        sparkleEmitter.particleScale = 0.3
        sparkleEmitter.particleScaleRange = 0.2
        sparkleEmitter.particleScaleSpeed = -0.5
        sparkleEmitter.particleAlpha = 1.0
        sparkleEmitter.particleAlphaSpeed = -2.0
        sparkleEmitter.particlePosition = CGPoint(x: 0, y: 0)
        sparkleEmitter.particlePositionRange = CGVector(dx: 25, dy: 25)
        
        sparkleEmitter.zPosition = 15
        addChild(sparkleEmitter)
    }
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConstants.cometCoreSize / 2)
        body.isDynamic = false  // Comets don't respond to physics
        body.categoryBitMask = GameConstants.powerUpCategory
        body.collisionBitMask = 0x0
        body.contactTestBitMask = GameConstants.blackHoleCategory
        physicsBody = body
    }
    
    func updateTrailDirection(angle: CGFloat) {
        // Point trail opposite to movement direction
        trailEmitter.emissionAngle = angle + .pi
    }
    
    // Helper to create particle texture
    static func createSparkTexture() -> SKTexture {
        let size: CGFloat = 8
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            UIColor.white.setFill()
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            context.cgContext.fillEllipse(in: rect)
        }
        return SKTexture(image: image)
    }
}

