//
//  BlackHole.swift
//  blackHole
//
//  Represents the player-controlled black hole
//

import SpriteKit
import UIKit

class BlackHole: SKSpriteNode {
    var currentDiameter: CGFloat
    var targetType: StarType
    var photonRing: SKShapeNode!  // Accessible for rainbow effect
    private var distortionRing: SKShapeNode?
    private var innerGlow: SKShapeNode?
    private var outerGlow: SKShapeNode?
    private var voidCore: SKShapeNode?
    var retroRimLight: SKShapeNode?  // Retro aesthetic rim lighting
    private var accretionDisk: SKEmitterNode?
    private static var cachedGlowTexture: SKTexture?
    
    init(diameter: CGFloat = GameConstants.blackHoleInitialDiameter) {
        self.currentDiameter = diameter
        self.targetType = StarType.random()
        
        let texture = BlackHole.createCircleTexture(diameter: diameter, color: UIColor.black)
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        
        self.name = "blackHole"
        setupPhysics()
        setupVoidCore(diameter: diameter)
        setupMultiLayerGlow(diameter: diameter)
        setupPhotonRing(diameter: diameter)
        setupRetroRimLight(diameter: diameter)
        addGravitationalLensing(diameter: diameter)
        setupAccretionDisk(diameter: diameter)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        accretionDisk?.removeFromParent()
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
        
        voidCore = SKShapeNode(circleOfRadius: radius * 0.75)
        voidCore?.fillColor = .black
        voidCore?.strokeColor = .clear
        voidCore?.zPosition = 5
        voidCore?.blendMode = .alpha
        voidCore?.alpha = 1.0
        addChild(voidCore!)
        
        let voidPulse = SKAction.sequence([
            SKAction.scale(to: 1.02, duration: 3.0),
            SKAction.scale(to: 0.98, duration: 3.0)
        ])
        voidCore?.run(SKAction.repeatForever(voidPulse))
    }
    
    private func setupMultiLayerGlow(diameter: CGFloat) {
        let radius = diameter / 2
        let innerGlowWidth = max(5.0, radius * 0.33)
        let outerGlowWidth = max(8.0, radius * 0.5)
        
        innerGlow = SKShapeNode(circleOfRadius: radius * 1.05)
        innerGlow?.fillColor = .clear
        innerGlow?.strokeColor = UIColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 1.0)
        innerGlow?.lineWidth = 2
        innerGlow?.glowWidth = innerGlowWidth
        innerGlow?.alpha = 0.3
        innerGlow?.zPosition = -1
        innerGlow?.blendMode = .add
        innerGlow?.isAntialiased = true
        addChild(innerGlow!)
        
        outerGlow = SKShapeNode(circleOfRadius: radius * 1.15)
        outerGlow?.fillColor = .clear
        outerGlow?.strokeColor = UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1.0)
        outerGlow?.lineWidth = 1
        outerGlow?.glowWidth = outerGlowWidth
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

    private func setupAccretionDisk(diameter: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.smallGlowTexture()
        emitter.particleBirthRate = 30
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5
        emitter.particleSpeed = 0
        emitter.particleSpeedRange = 0
        emitter.particleAlpha = 0.4
        emitter.particleAlphaSpeed = -0.2
        emitter.particleScale = 0.15
        emitter.particleScaleRange = 0.05
        emitter.particleScaleSpeed = -0.05
        emitter.particleColor = targetType.uiColor
        emitter.particleColorBlendFactor = 0.7
        emitter.particleBlendMode = .add
        emitter.particlePosition = .zero
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.zPosition = 1
        emitter.targetNode = self

        accretionDisk = emitter
        addChild(emitter)
        updateAccretionDisk(diameter: diameter)
    }

    private func updateAccretionDisk(diameter: CGFloat) {
        guard let disk = accretionDisk else { return }
        let radius = diameter / 2
        disk.particlePositionRange = CGVector(dx: radius * 0.9, dy: radius * 0.9)

        let path = UIBezierPath(arcCenter: .zero,
                                 radius: radius * 0.95,
                                 startAngle: 0,
                                 endAngle: CGFloat.pi * 2,
                                 clockwise: true)
        let follow = SKAction.follow(path.cgPath, asOffset: false, orientToPath: false, duration: 3.0)
        disk.particleAction = SKAction.repeatForever(follow)
    }
    
    private func setupPhotonRing(diameter: CGFloat) {
        let radius = diameter / 2
        let scaledLineWidth = max(1.5, min(6.0, radius * 0.06))
        let scaledGlowWidth = max(4.0, min(20.0, radius * 0.16))
        
        photonRing = SKShapeNode(circleOfRadius: radius * 1.03)  // 1.03x instead of 1.01x
        photonRing.fillColor = .clear
        photonRing.strokeColor = targetType.uiColor
        photonRing.lineWidth = scaledLineWidth
        photonRing.glowWidth = scaledGlowWidth
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
    
    private func setupRetroRimLight(diameter: CGFloat) {
        // Only add if retro aesthetics are enabled
        guard GameConstants.RetroAestheticSettings.enableRetroAesthetics &&
              GameConstants.RetroAestheticSettings.enableRimLighting else {
            return
        }
        
        let radius = diameter / 2
        
        // Create FULL CIRCLE rim light (not an arc)
        retroRimLight = SKShapeNode(circleOfRadius: radius * 1.05)
        retroRimLight?.fillColor = .clear
        // Use the target type color with warm tint (matches photon ring)
        retroRimLight?.strokeColor = blendColorWithWarmth(targetType.uiColor)
        retroRimLight?.lineWidth = 3
        retroRimLight?.glowWidth = 20
        retroRimLight?.alpha = RetroAestheticManager.Config.rimLightIntensity
        retroRimLight?.blendMode = .add
        retroRimLight?.zPosition = 3
        
        addChild(retroRimLight!)
        
        print("🌟 Black hole rim light added (full circle, color: \(targetType.displayName))")
        
        // Dramatic pulse animation
        let rimLightPulse = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.4, duration: 2.0),
                SKAction.scale(to: 1.02, duration: 2.0)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: RetroAestheticManager.Config.rimLightIntensity, duration: 2.0),
                SKAction.scale(to: 1.0, duration: 2.0)
            ])
        ])
        rimLightPulse.timingMode = .easeInEaseOut
        retroRimLight?.run(SKAction.repeatForever(rimLightPulse))
    }
    
    private func blendColorWithWarmth(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Add subtle warmth by boosting red/yellow slightly
        let warmOrange = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        var rWarm: CGFloat = 0, gWarm: CGFloat = 0, bWarm: CGFloat = 0, aWarm: CGFloat = 0
        warmOrange.getRed(&rWarm, green: &gWarm, blue: &bWarm, alpha: &aWarm)
        
        // Blend 20% warm orange into the color (less than stars for subtlety)
        let ratio: CGFloat = 0.2
        return UIColor(
            red: r * (1 - ratio) + rWarm * ratio,
            green: g * (1 - ratio) + gWarm * ratio,
            blue: b * (1 - ratio) + bWarm * ratio,
            alpha: 1.0
        )
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

    func isAtMinimumSize() -> Bool {
        return currentDiameter <= GameConstants.blackHoleMinDiameter + 0.01
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
        let innerGlowWidth = max(5.0, radius * 0.33)
        let outerGlowWidth = max(8.0, radius * 0.5)
        let scaledLineWidth = max(1.5, min(6.0, radius * 0.06))
        let scaledGlowWidth = max(4.0, min(20.0, radius * 0.16))
        
        // Update void core
        if let void = voidCore {
            let voidRadius = radius * 0.75
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
            inner.glowWidth = innerGlowWidth
        }
        
        // Update outer glow
        if let outer = outerGlow {
            let outerRadius = radius * 1.15
            outer.path = CGPath(ellipseIn: CGRect(x: -outerRadius, y: -outerRadius, 
                                                   width: outerRadius * 2, height: outerRadius * 2), 
                               transform: nil)
            outer.glowWidth = outerGlowWidth
        }
        
        // Update photon ring
        let photonRadius = radius * 1.03
        photonRing.path = CGPath(ellipseIn: CGRect(x: -photonRadius, y: -photonRadius, 
                                                    width: photonRadius * 2, height: photonRadius * 2), 
                                transform: nil)
        photonRing.lineWidth = scaledLineWidth
        photonRing.glowWidth = scaledGlowWidth

        // Update distortion ring
        if let distortion = distortionRing {
            let distortionRadius = radius * 1.25
            distortion.path = CGPath(ellipseIn: CGRect(x: -distortionRadius, y: -distortionRadius, 
                                                        width: distortionRadius * 2, height: distortionRadius * 2), 
                                    transform: nil)
        }
        
        // Update retro rim light
        if let rim = retroRimLight {
            let rimRadius = radius * 1.05
            rim.path = CGPath(ellipseIn: CGRect(x: -rimRadius, y: -rimRadius,
                                                 width: rimRadius * 2, height: rimRadius * 2),
                             transform: nil)
        }

        updateAccretionDisk(diameter: diameter)
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
            
            // Also update rim light color to match
            if let rimLight = self.retroRimLight {
                let fromColor = rimLight.strokeColor ?? self.blendColorWithWarmth(newType.uiColor)
                let toColor = self.blendColorWithWarmth(newType.uiColor)
                rimLight.strokeColor = self.interpolateColor(
                    from: fromColor,
                    to: toColor,
                    progress: progress
                )
            }
        }
        run(colorAction)

        accretionDisk?.particleColor = newType.uiColor
    }
    
    func updateIndicatorRing() {
        // Update the photon ring to match current target type
        photonRing.strokeColor = targetType.uiColor
        
        // Also update rim light color to match
        if let rimLight = retroRimLight {
            rimLight.strokeColor = blendColorWithWarmth(targetType.uiColor)
        }

        accretionDisk?.particleColor = targetType.uiColor
    }

    func playConsumptionFeedback() {
        let flashAction = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.08),
                SKAction.scale(to: 1.1, duration: 0.08)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.75, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15)
            ])
        ])
        photonRing.run(flashAction, withKey: "consumptionFlash")

        innerGlow?.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.08),
            SKAction.fadeAlpha(to: 0.3, duration: 0.15)
        ]))

        distortionRing?.run(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.2)
        ]))
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
}

private extension BlackHole {
    static func createCircleTexture(diameter: CGFloat, color: UIColor) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fillEllipse(in: rect)
        }
        return SKTexture(image: image)
    }

    static func smallGlowTexture() -> SKTexture {
        if let cached = cachedGlowTexture {
            return cached
        }
        let size: CGFloat = 12
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setShadow(offset: .zero,
                          blur: size / 2,
                          color: UIColor.white.withAlphaComponent(0.8).cgColor)
            let path = UIBezierPath(arcCenter: CGPoint(x: size / 2, y: size / 2),
                                     radius: size / 4,
                                     startAngle: 0,
                                     endAngle: CGFloat.pi * 2,
                                     clockwise: true)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
        let texture = SKTexture(image: image)
        cachedGlowTexture = texture
        return texture
    }
}

