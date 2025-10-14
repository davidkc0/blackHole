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
    var photonRing: SKShapeNode!  // Accessible for rainbow effect
    private var distortionRing: SKShapeNode?
    
    init(diameter: CGFloat = GameConstants.blackHoleInitialDiameter) {
        self.currentDiameter = diameter
        self.targetType = StarType.random()
        
        let texture = BlackHole.createCircleTexture(diameter: diameter, color: .black)
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        
        self.name = "blackHole"
        setupPhysics()
        setupPhotonRing(diameter: diameter)
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
    
    private func setupPhotonRing(diameter: CGFloat) {
        let radius = diameter / 2
        
        // Thin colored ring right at the event horizon edge
        photonRing = SKShapeNode(circleOfRadius: radius * 1.01)
        photonRing.fillColor = .clear
        photonRing.strokeColor = targetType.uiColor  // Target color indicator
        photonRing.lineWidth = 3  // Thin, visible line
        photonRing.glowWidth = 6  // Soft glow
        photonRing.zPosition = 1  // Above black hole
        photonRing.blendMode = .add
        photonRing.isAntialiased = true
        
        // Add subtle pulse to make it noticeable
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.8),
            SKAction.fadeAlpha(to: 0.7, duration: 0.8)
        ])
        photonRing.run(SKAction.repeatForever(pulse))
        
        addChild(photonRing)
    }
    
    private func addGlowEffect() {
        // Subtle glow around the black hole
        let glowNode = SKShapeNode(circleOfRadius: currentDiameter / 2)
        glowNode.fillColor = .black
        glowNode.strokeColor = .white
        glowNode.lineWidth = 1  // Thinner line
        glowNode.alpha = 0.2    // More subtle
        glowNode.glowWidth = 8  // Slightly less glow
        glowNode.zPosition = -1
        glowNode.name = "glow"
        glowNode.isAntialiased = true  // Smooth edges
        addChild(glowNode)
    }
    
    @available(*, deprecated, message: "Use growByConsumingStar(_ star:) for relative size-based growth")
    func grow() {
        // Fallback to fixed multiplier if needed
        let newDiameter = currentDiameter * GameConstants.blackHoleGrowthMultiplier
        updateSize(to: newDiameter)
    }
    
    func growByConsumingStar(_ star: Star) {
        let growthMultiplier = calculateGrowthMultiplier(starSize: star.size.width)
        let newDiameter = currentDiameter * growthMultiplier
        updateSize(to: newDiameter)
    }
    
    private func calculateGrowthMultiplier(starSize: CGFloat) -> CGFloat {
        // Calculate relative size (0.0 to 1.0, where 1.0 = star is same size as black hole)
        let relativeSize = starSize / currentDiameter
        
        // Base growth: 5% to 30% based on relative size
        // Small stars (25% of black hole size) = 12.5% growth
        // Medium stars (50% of black hole size) = 20% growth
        // Large stars (75% of black hole size) = 27.5% growth
        let baseGrowth = 0.05 + (relativeSize * 0.25)
        
        // Diminishing returns for very large black holes
        // At 0pt: multiplier = 1.0 (no penalty)
        // At 400pt: multiplier = 0.5 (50% penalty)
        // At 800pt+: multiplier = 0.3 (70% penalty, minimum)
        let sizePenalty = max(0.3, 1.0 - (currentDiameter / 800.0))
        
        // Combine base growth with size penalty
        let adjustedGrowth = baseGrowth * sizePenalty
        
        // Debug logging
        print("📊 Growth calc: BH=\(String(format: "%.0f", currentDiameter))pt, Star=\(String(format: "%.0f", starSize))pt, Rel=\(String(format: "%.1f", relativeSize * 100))%, Base=\(String(format: "%.1f", baseGrowth * 100))%, Penalty=\(String(format: "%.1f", sizePenalty * 100))%, Final=\(String(format: "%.1f", adjustedGrowth * 100))%")
        
        return 1.0 + adjustedGrowth
    }
    
    func shrink() {
        shrinkByMultiplier(GameConstants.blackHoleShrinkMultiplier)
    }
    
    func shrinkByMultiplier(_ multiplier: CGFloat) {
        let newDiameter = max(currentDiameter * multiplier, GameConstants.blackHoleMinDiameter)
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
            let newRadius = newDiameter / 2
            let glowPath = CGPath(
                ellipseIn: CGRect(
                    x: -newRadius, y: -newRadius,
                    width: newRadius * 2, height: newRadius * 2
                ),
                transform: nil
            )
            glowNode.path = glowPath
        }
        
        // Update photon ring
        let newRadius = newDiameter / 2 * 1.01
        let photonPath = CGPath(
            ellipseIn: CGRect(
                x: -newRadius, y: -newRadius,
                width: newRadius * 2, height: newRadius * 2
            ),
            transform: nil
        )
        photonRing.path = photonPath
        
        // Update distortion effect (Phase 3)
        updateDistortionEffect()
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
    
    func updateTargetType(to newType: StarType) {
        targetType = newType
        
        // Smoothly transition photon ring color
        let colorAction = SKAction.customAction(withDuration: GameConstants.ringColorTransitionDuration) { [weak self] node, elapsedTime in
            guard let self = self else { return }
            let progress = elapsedTime / GameConstants.ringColorTransitionDuration
            self.photonRing.strokeColor = self.interpolateColor(
                from: self.photonRing.strokeColor ?? newType.uiColor,
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
    
    // MARK: - Distortion Ring Effect (Phase 3)
    
    private func updateDistortionEffect() {
        if currentDiameter > 150 && distortionRing == nil {
            // Only create for large black holes (>150pt)
            let radius = currentDiameter / 2 * 1.2  // Just 20% larger
            
            distortionRing = SKShapeNode(circleOfRadius: radius)
            distortionRing?.fillColor = .clear
            distortionRing?.strokeColor = UIColor.white.withAlphaComponent(0.1)
            distortionRing?.lineWidth = 2
            distortionRing?.glowWidth = 10
            distortionRing?.zPosition = -1  // Behind black hole
            distortionRing?.blendMode = .add
            distortionRing?.isAntialiased = true
            
            // Subtle wave effect
            let wave = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.15, duration: 2.0),
                SKAction.fadeAlpha(to: 0.05, duration: 2.0)
            ])
            distortionRing?.run(SKAction.repeatForever(wave))
            
            addChild(distortionRing!)
            
        } else if currentDiameter <= 150 && distortionRing != nil {
            // Remove if black hole shrinks below threshold
            distortionRing?.removeFromParent()
            distortionRing = nil
            
        } else if let ring = distortionRing {
            // Update size for existing ring
            let newRadius = currentDiameter / 2 * 1.2
            let newPath = CGPath(
                ellipseIn: CGRect(
                    x: -newRadius, y: -newRadius,
                    width: newRadius * 2, height: newRadius * 2
                ),
                transform: nil
            )
            ring.path = newPath
        }
    }
    
    // MARK: - Helper Methods
    
    // Helper to create a circle texture
    private static func createCircleTexture(diameter: CGFloat, color: UIColor) -> SKTexture {
        // Generate at FIXED high resolution regardless of diameter
        // This allows smooth scaling both up and down
        let textureSize: CGFloat = 200  // Fixed size for all black holes
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: textureSize, height: textureSize))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: textureSize, height: textureSize)
            let center = CGPoint(x: textureSize / 2, y: textureSize / 2)
            let radius = textureSize / 2
            
            // Draw solid black circle
            color.setFill()
            context.cgContext.fillEllipse(in: rect)
            
            // Add subtle gradient for depth
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors: [CGColor] = [
                color.cgColor,
                color.withAlphaComponent(0.95).cgColor
            ]
            let locations: [CGFloat] = [0.0, 1.0]
            
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: []
                )
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear  // CRITICAL: enables smooth scaling
        return texture
    }
    
}

