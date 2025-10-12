//
//  BlackHole.swift
//  blackHole
//
//  Represents the player-controlled black hole
//

import SpriteKit

class BlackHole: SKSpriteNode {
    private(set) var currentDiameter: CGFloat
    private(set) var targetType: StarType
    private var particleEmitter: SKEmitterNode!
    
    init(diameter: CGFloat = GameConstants.blackHoleInitialDiameter) {
        self.currentDiameter = diameter
        self.targetType = StarType.random()
        
        let texture = BlackHole.createCircleTexture(diameter: diameter, color: .black)
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        
        self.name = "blackHole"
        setupPhysics()
        setupParticleEmitter()
        addGlowEffect()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPhysics() {
        let radius = currentDiameter / 2
        physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = GameConstants.blackHoleCategory
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = GameConstants.starCategory
        physicsBody?.mass = radius * radius // Mass proportional to area
    }
    
    private func setupParticleEmitter() {
        particleEmitter = SKEmitterNode()
        
        // Use programmatically created circle texture
        particleEmitter.particleTexture = BlackHole.createParticleTexture()
        
        particleEmitter.particleBirthRate = 80
        particleEmitter.numParticlesToEmit = 0 // Infinite
        particleEmitter.particleLifetime = 1.2
        particleEmitter.particleLifetimeRange = 0.4
        particleEmitter.emissionAngle = 0
        particleEmitter.emissionAngleRange = CGFloat.pi * 2
        particleEmitter.particleSpeed = 25
        particleEmitter.particleSpeedRange = 15
        particleEmitter.particleAlpha = 0.9
        particleEmitter.particleAlphaRange = 0.1
        particleEmitter.particleAlphaSpeed = -0.7
        particleEmitter.particleScale = 0.4
        particleEmitter.particleScaleRange = 0.15
        particleEmitter.particleScaleSpeed = -0.15
        particleEmitter.particleColor = targetType.uiColor
        particleEmitter.particleColorBlendFactor = 1.0
        particleEmitter.particleBlendMode = .add
        particleEmitter.particlePosition = CGPoint.zero
        particleEmitter.particlePositionRange = CGVector(dx: currentDiameter / 2 + 10, dy: currentDiameter / 2 + 10)
        particleEmitter.zPosition = 1
        
        addChild(particleEmitter)
    }
    
    func setupParticleTargetNode() {
        // Call this after black hole is added to scene
        particleEmitter.targetNode = self.parent
    }
    
    private func addGlowEffect() {
        // Dark glow around the black hole
        let glowNode = SKShapeNode(circleOfRadius: currentDiameter / 2)
        glowNode.fillColor = .black
        glowNode.strokeColor = .white
        glowNode.lineWidth = 2
        glowNode.alpha = 0.3
        glowNode.glowWidth = 10
        glowNode.zPosition = -1
        glowNode.name = "glow"
        addChild(glowNode)
    }
    
    func grow() {
        // Remove the min() cap - allow infinite growth
        let newDiameter = currentDiameter * GameConstants.blackHoleGrowthMultiplier
        updateSize(to: newDiameter)
    }
    
    func shrink() {
        let newDiameter = max(currentDiameter * GameConstants.blackHoleShrinkMultiplier, GameConstants.blackHoleMinDiameter)
        updateSize(to: newDiameter)
    }
    
    private func updateSize(to newDiameter: CGFloat) {
        let oldDiameter = currentDiameter
        currentDiameter = newDiameter
        
        // Scale the sprite itself
        let newSize = CGSize(width: newDiameter, height: newDiameter)
        let resize = SKAction.resize(toWidth: newSize.width, height: newSize.height, duration: GameConstants.blackHoleSizeAnimationDuration)
        resize.timingMode = .easeInEaseOut
        run(resize) { [weak self] in
            self?.updatePhysicsBody()
        }
        
        // Update glow node size
        if let glowNode = childNode(withName: "glow") as? SKShapeNode {
            let glowPath = CGPath(ellipseIn: CGRect(
                x: -newDiameter / 2,
                y: -newDiameter / 2,
                width: newDiameter,
                height: newDiameter
            ), transform: nil)
            glowNode.path = glowPath
        }
        
        // Update particle emitter range
        updateParticleEmitterSize()
    }
    
    private func updatePhysicsBody() {
        let radius = currentDiameter / 2
        physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = GameConstants.blackHoleCategory
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = GameConstants.starCategory
        physicsBody?.mass = radius * radius
    }
    
    private func updateParticleEmitterSize() {
        let range = currentDiameter / 2 + 10
        particleEmitter.particlePositionRange = CGVector(dx: range, dy: range)
    }
    
    func updateTargetType(to newType: StarType) {
        targetType = newType
        
        // Smoothly transition particle color
        let colorAction = SKAction.customAction(withDuration: GameConstants.ringColorTransitionDuration) { [weak self] node, elapsedTime in
            guard let self = self else { return }
            let progress = elapsedTime / GameConstants.ringColorTransitionDuration
            self.particleEmitter.particleColor = self.interpolateColor(
                from: self.particleEmitter.particleColor,
                to: newType.uiColor,
                progress: progress
            )
        }
        run(colorAction)
    }
    
    func canConsume(_ star: Star) -> Bool {
        // Black hole can only consume stars smaller than itself
        return star.size.width < currentDiameter
    }
    
    private func interpolateColor(from: UIColor, to: UIColor, progress: CGFloat) -> UIColor {
        var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0
        
        from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        
        let red = fromRed + (toRed - fromRed) * progress
        let green = fromGreen + (toGreen - fromGreen) * progress
        let blue = fromBlue + (toBlue - fromBlue) * progress
        let alpha = fromAlpha + (toAlpha - fromAlpha) * progress
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // No longer need screen constraint - infinite world!
    
    func isAtMinimumSize() -> Bool {
        return currentDiameter <= GameConstants.blackHoleMinDiameter
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
    
    // Helper to create particle texture
    private static func createParticleTexture() -> SKTexture {
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

