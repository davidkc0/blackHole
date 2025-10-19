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
    private var innerGlow: SKShapeNode?
    private var outerGlow: SKShapeNode?
    private var voidCore: SKShapeNode?
    
    init(diameter: CGFloat = GameConstants.blackHoleInitialDiameter) {
        self.currentDiameter = diameter
        self.targetType = StarType.random()
        
        let texture = BlackHole.createCircleTexture(diameter: diameter, color: .black)
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        
        self.name = "blackHole"
        setupPhysics()
        setupVoidCore(diameter: diameter)
        setupMultiLayerGlow(diameter: diameter)
        setupPhotonRing(diameter: diameter)
        addGravitationalLensing(diameter: diameter)
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
    
    // MARK: - Enhanced Visual Components
    
    private func setupVoidCore(diameter: CGFloat) {
        let radius = diameter / 2
        
        voidCore = SKShapeNode(circleOfRadius: radius * 0.6)
        voidCore?.fillColor = UIColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 1.0)
        voidCore?.strokeColor = .clear
        voidCore?.zPosition = -2
        voidCore?.blendMode = .multiply
        voidCore?.alpha = 0.8
        addChild(voidCore!)
        
        let voidPulse = SKAction.sequence([
            SKAction.scale(to: 1.02, duration: 3.0),
            SKAction.scale(to: 0.98, duration: 3.0)
        ])
        voidCore?.run(SKAction.repeatForever(voidPulse))
    }
    
    private func setupMultiLayerGlow(diameter: CGFloat) {
        let radius = diameter / 2
        
        // Inner glow
        innerGlow = SKShapeNode(circleOfRadius: radius * 1.05)
        innerGlow?.fillColor = .clear
        innerGlow?.strokeColor = UIColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 1.0)
        innerGlow?.lineWidth = 2
        innerGlow?.glowWidth = 15
        innerGlow?.alpha = 0.3
        innerGlow?.zPosition = -1
        innerGlow?.blendMode = .add
        innerGlow?.isAntialiased = true
        addChild(innerGlow!)
        
        // Outer glow
        outerGlow = SKShapeNode(circleOfRadius: radius * 1.15)
        outerGlow?.fillColor = .clear
        outerGlow?.strokeColor = UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1.0)
        outerGlow?.lineWidth = 1
        outerGlow?.glowWidth = 25
        outerGlow?.alpha = 0.15
        outerGlow?.zPosition = -2
        outerGlow?.blendMode = .add
        outerGlow?.isAntialiased = true
        addChild(outerGlow!)
        
        // Animations
        let glowPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 2.5),
            SKAction.fadeAlpha(to: 0.25, duration: 2.5)
        ])
        innerGlow?.run(SKAction.repeatForever(glowPulse))
        
        let outerPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 3.0),
            SKAction.fadeAlpha(to: 0.1, duration: 3.0)
        ])
        outerGlow?.run(SKAction.repeatForever(outerPulse))
    }
    
    private func addGravitationalLensing(diameter: CGFloat) {
        let radius = diameter / 2
        
        distortionRing = SKShapeNode(circleOfRadius: radius * 1.25)
        distortionRing?.fillColor = .clear
        distortionRing?.strokeColor = UIColor.white.withAlphaComponent(0.08)
        distortionRing?.lineWidth = 3
        distortionRing?.glowWidth = 20
        distortionRing?.zPosition = -3
        distortionRing?.blendMode = .add
        distortionRing?.isAntialiased = true
        
        let wave = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.12, duration: 4.0),
                SKAction.scale(to: 1.05, duration: 4.0)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.06, duration: 4.0),
                SKAction.scale(to: 0.95, duration: 4.0)
            ])
        ])
        distortionRing?.run(SKAction.repeatForever(wave))
        
        addChild(distortionRing!)
    }
    
    private func setupPhotonRing(diameter: CGFloat) {
        let radius = diameter / 2
        
        photonRing = SKShapeNode(circleOfRadius: radius * 1.03)  // 1.03x instead of 1.01x
        photonRing.fillColor = .clear
        photonRing.strokeColor = targetType.uiColor
        photonRing.lineWidth = 4  // Thicker (was 3)
        photonRing.glowWidth = 12  // Stronger (was 6)
        photonRing.zPosition = 2
        photonRing.blendMode = .add
        photonRing.isAntialiased = true
        
        // Enhanced pulse with scale
        let pulse = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.6),
                SKAction.scale(to: 1.02, duration: 0.6)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.75, duration: 0.6),
                SKAction.scale(to: 0.98, duration: 0.6)
            ])
        ])
        photonRing.run(SKAction.repeatForever(pulse))
        
        addChild(photonRing)
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
        
        // NERFED growth: 1.47% to 6.6% based on relative size (increased by 5% again)
        // Small stars (25% of black hole size) = 2.8% growth
        // Medium stars (50% of black hole size) = 4.0% growth
        // Large stars (75% of black hole size) = 5.3% growth
        let baseGrowth = 0.01467428 + (relativeSize * 0.05135996)
        
        // Diminishing returns for very large black holes
        let sizePenalty = 1.0 / (1.0 + (currentDiameter / 600.0))
        
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
    
    func updateSize(to newDiameter: CGFloat) {
        let oldDiameter = currentDiameter
        currentDiameter = newDiameter
        
        let newSize = CGSize(width: newDiameter, height: newDiameter)
        let resize = SKAction.resize(toWidth: newSize.width, height: newSize.height, 
                                     duration: GameConstants.blackHoleSizeAnimationDuration)
        resize.timingMode = .easeInEaseOut
        run(resize) { [weak self] in
            self?.updatePhysicsBody()
        }
        
        updateVisualComponents(to: newDiameter)
    }
    
    private func updateVisualComponents(to diameter: CGFloat) {
        let radius = diameter / 2
        
        // Update void core
        if let void = voidCore {
            let voidRadius = radius * 0.6
            void.path = CGPath(ellipseIn: CGRect(x: -voidRadius, y: -voidRadius, 
                                                  width: voidRadius * 2, height: voidRadius * 2), 
                              transform: nil)
        }
        
        // Update inner glow
        if let inner = innerGlow {
            let innerRadius = radius * 1.05
            inner.path = CGPath(ellipseIn: CGRect(x: -innerRadius, y: -innerRadius, 
                                                   width: innerRadius * 2, height: innerRadius * 2), 
                               transform: nil)
        }
        
        // Update outer glow
        if let outer = outerGlow {
            let outerRadius = radius * 1.15
            outer.path = CGPath(ellipseIn: CGRect(x: -outerRadius, y: -outerRadius, 
                                                   width: outerRadius * 2, height: outerRadius * 2), 
                               transform: nil)
        }
        
        // Update photon ring
        let photonRadius = radius * 1.03
        photonRing.path = CGPath(ellipseIn: CGRect(x: -photonRadius, y: -photonRadius, 
                                                    width: photonRadius * 2, height: photonRadius * 2), 
                                transform: nil)
        
        // Update distortion ring
        if let distortion = distortionRing {
            let distortionRadius = radius * 1.25
            distortion.path = CGPath(ellipseIn: CGRect(x: -distortionRadius, y: -distortionRadius, 
                                                        width: distortionRadius * 2, height: distortionRadius * 2), 
                                    transform: nil)
        }
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
            
            // Create deep void gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors: [CGColor] = [
                UIColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1.0).cgColor,  // Dark blue center
                UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor,    // Pure black
                color.withAlphaComponent(0.98).cgColor                            // Slight transparency
            ]
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            
            color.setFill()
            context.cgContext.fillEllipse(in: rect)
            
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

