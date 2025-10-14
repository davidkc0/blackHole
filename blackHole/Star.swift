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
    
    private var innerGlow: SKSpriteNode?
    private var outerCorona: SKSpriteNode?
    private var coronaParticles: SKEmitterNode?
    private var visualProfile: VisualEffectProfile!
    
    init(type: StarType) {
        self.starType = type
        self.basePoints = type.basePoints
        
        // Use type-specific size range
        let diameter = CGFloat.random(in: type.sizeRange)
        
        // Get cached texture instead of generating
        let sizeBucket = TextureCache.shared.getSizeBucket(diameter)
        let texture = TextureCache.shared.getStarCoreTexture(type: type, sizeBucket: sizeBucket)
        
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        
        // Get visual profile for this star
        self.visualProfile = VisualEffectProfile.profile(for: type, size: diameter)
        
        setupPhysics(diameter: diameter)
        setupMultiLayerVisuals()
        addInitialDrift()
        startAnimations()
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
        physicsBody?.collisionBitMask = GameConstants.starCategory
        physicsBody?.contactTestBitMask = GameConstants.blackHoleCategory | GameConstants.starCategory
        
        // Improved collision behavior
        physicsBody?.linearDamping = 0.3       // Increased from 0.1 (less bouncing)
        physicsBody?.angularDamping = 0.5      // Increased from 0.1 (less spinning)
        physicsBody?.restitution = 0.05        // Decreased from 0.1 (minimal bounce)
        physicsBody?.friction = 1.0            // Increased from 0.5 (better grip)
        // Mass proportional to area with type-specific multiplier
        physicsBody?.mass = radius * radius * starType.massMultiplier
    }
    
    private func setupMultiLayerVisuals() {
        // Layer 1: Outer Corona (4x core size, very diffuse)
        createOuterCorona()
        
        // Layer 2: Inner Glow (2x core size, brighter)
        createInnerGlow()
        
        // Layer 3: Core is the base sprite (already created)
        
        // Layer 4: Corona particles (only for large stars)
        if visualProfile.hasCorona {
            createCoronaParticles()
        }
    }
    
    private func createOuterCorona() {
        let coronaSize = size.width * 4.0
        let sizeBucket = TextureCache.shared.getSizeBucket(coronaSize)
        let texture = TextureCache.shared.getStarGlowTexture(type: starType, sizeBucket: sizeBucket)
        
        outerCorona = SKSpriteNode(texture: texture, size: CGSize(width: coronaSize, height: coronaSize))
        outerCorona!.alpha = 0.15
        outerCorona!.blendMode = .add
        outerCorona!.zPosition = -2
        outerCorona!.name = "outerCorona"
        addChild(outerCorona!)
    }
    
    private func createInnerGlow() {
        let glowSize = size.width * 2.0
        let sizeBucket = TextureCache.shared.getSizeBucket(glowSize)
        let texture = TextureCache.shared.getStarGlowTexture(type: starType, sizeBucket: sizeBucket)
        
        innerGlow = SKSpriteNode(texture: texture, size: CGSize(width: glowSize, height: glowSize))
        innerGlow!.alpha = 0.5
        innerGlow!.blendMode = .add
        innerGlow!.zPosition = -1
        innerGlow!.name = "innerGlow"
        addChild(innerGlow!)
    }
    
    private func createCoronaParticles() {
        coronaParticles = SKEmitterNode()
        
        // Get particle texture
        let particleTexture = TextureCache.shared.getParticleTexture(size: 8)
        coronaParticles!.particleTexture = particleTexture
        
        // Size-based configuration
        coronaParticles!.particleBirthRate = visualProfile.birthRate * visualProfile.coronaIntensity
        coronaParticles!.particleLifetime = visualProfile.lifetime
        coronaParticles!.particleLifetimeRange = visualProfile.lifetime * 0.3
        
        // Omnidirectional slow drift
        coronaParticles!.particleSpeed = visualProfile.particleSpeed
        coronaParticles!.particleSpeedRange = visualProfile.particleSpeed * 0.5
        coronaParticles!.emissionAngle = 0
        coronaParticles!.emissionAngleRange = .pi * 2
        
        // Alpha and scale
        coronaParticles!.particleAlpha = 0.4
        coronaParticles!.particleAlphaRange = 0.1
        coronaParticles!.particleAlphaSpeed = -0.2
        coronaParticles!.particleScale = visualProfile.particleScale
        coronaParticles!.particleScaleRange = visualProfile.particleScale * 0.3
        coronaParticles!.particleScaleSpeed = 0.2  // Gentle expansion
        
        // Color and blend
        coronaParticles!.particleColor = starType.uiColor
        coronaParticles!.particleColorBlendFactor = 1.0
        coronaParticles!.particleBlendMode = .add
        
        // Positioning
        coronaParticles!.particlePosition = CGPoint.zero
        coronaParticles!.particlePositionRange = CGVector(dx: size.width / 3, dy: size.width / 3)
        coronaParticles!.zPosition = -3
        coronaParticles!.name = "coronaParticles"
        
        addChild(coronaParticles!)
    }
    
    private func startAnimations() {
        // Stagger start time to avoid synchronization
        let randomDelay = TimeInterval.random(in: 0...2.0)
        
        let startAnimations = SKAction.sequence([
            SKAction.wait(forDuration: randomDelay),
            SKAction.run { [weak self] in
                self?.applyPulseAnimation()
                
                if self?.visualProfile.hasTwinkling == true {
                    self?.createTwinkleEffect()
                }
                
                // Type-specific effects
                self?.applyTypeSpecificEffects()
            }
        ])
        
        run(startAnimations)
    }
    
    private func applyPulseAnimation() {
        guard let innerGlow = innerGlow else { return }
        
        let targetScale = 1.0 + visualProfile.pulseScale
        let halfDuration = visualProfile.pulseDuration / 2.0
        
        let pulse = SKAction.sequence([
            SKAction.scale(to: targetScale, duration: halfDuration),
            SKAction.scale(to: 1.0, duration: halfDuration)
        ])
        pulse.timingMode = .easeInEaseOut
        
        innerGlow.run(SKAction.repeatForever(pulse), withKey: "glowPulse")
    }
    
    private func createTwinkleEffect() {
        // Action-based twinkling (simpler, performant)
        let twinkle = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.8),
            SKAction.fadeAlpha(to: 0.8, duration: 1.2),
            SKAction.wait(forDuration: TimeInterval.random(in: 1.0...3.0))
        ])
        
        run(SKAction.repeatForever(twinkle), withKey: "twinkle")
    }
    
    private func applyTypeSpecificEffects() {
        // Red supergiants get dramatic scale pulsing
        if starType == .redSupergiant {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 0.95, duration: 1.5),
                SKAction.scale(to: 1.05, duration: 1.5)
            ])
            pulse.timingMode = .easeInEaseOut
            run(SKAction.repeatForever(pulse), withKey: "superPulse")
        }
        
        // Blue giants get fast twinkling on core
        if starType == .blueGiant {
            let fastTwinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.9, duration: 0.15),
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ])
            run(SKAction.repeatForever(fastTwinkle), withKey: "blueTwinkle")
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

