//
//  Star.swift
//  blackHole
//
//  Represents a colored star that can be consumed by the black hole
//

import SpriteKit
import CoreGraphics

class Star: SKSpriteNode {
    let starType: StarType
    private var warningGlow: SKShapeNode?
    var mergeCount: Int = 0  // Track how many times this star has been merged
    var isMergedStar: Bool = false
    var hasBeenProcessed: Bool = false  // Prevent multiple collision processing
    var basePoints: Int
    
    private var innerGlow: SKSpriteNode?
    private var outerCorona: SKSpriteNode?
    private var coronaParticles: SKEmitterNode?
    private var visualProfile: VisualEffectProfile!
    private var retroBloom: SKEffectNode?
    private var retroRimLight: SKShapeNode?
    
    init(type: StarType) {
        self.starType = type
        self.basePoints = type.basePoints
        
        // Use type-specific size range
        let diameter = CGFloat.random(in: type.sizeRange)
        
        // Get cached texture instead of generating
        let sizeBucket = TextureCache.shared.getSizeBucket(diameter)
        let texture = TextureCache.shared.getStarCoreTexture(type: type, sizeBucket: sizeBucket)
        
        super.init(texture: texture, color: .clear, size: CGSize(width: diameter, height: diameter))
        self.name = "star_\(UUID().uuidString)"
        
        // Get visual profile for this star
        self.visualProfile = VisualEffectProfile.profile(for: type, size: diameter)
        
        setupPhysics(diameter: diameter)
        setupMultiLayerVisuals()
        // addRetroBloom()  // DISABLED - causes FPS drop
        // Retro rim light removed - replaced with core glow for brighter, fuller appearance
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
        
        // Layer 3: Core Glow Fill (1.4x core size, filled circle for fullness)
        createCoreGlow()
        
        // Layer 4: Core is the base sprite (already created)
        
        // Layer 5: Corona particles (only for large stars)
        if visualProfile.hasCorona {
            createCoronaParticles()
        }
    }
    
    private func createOuterCorona() {
        let coronaSize = size.width * 4.0
        let sizeBucket = TextureCache.shared.getSizeBucket(coronaSize)
        let texture = TextureCache.shared.getStarGlowTexture(type: starType, sizeBucket: sizeBucket)
        
        outerCorona = SKSpriteNode(texture: texture, size: CGSize(width: coronaSize, height: coronaSize))
        outerCorona!.alpha = 0.2  // Increased from 0.15 for brighter appearance
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
        innerGlow!.alpha = 0.65  // Increased from 0.5 for brighter appearance
        innerGlow!.blendMode = .add
        innerGlow!.zPosition = -1
        innerGlow!.name = "innerGlow"
        addChild(innerGlow!)
    }
    
    private func createCoreGlow() {
        // Core glow with inverse gradient: bright center fading to transparent edges
        let glowSize = size.width * 1.4
        let texture = generateCoreGlowTexture(color: starType.uiColor, size: glowSize)
        let glow = SKSpriteNode(texture: texture, size: CGSize(width: glowSize, height: glowSize))
        glow.alpha = 0.3
        glow.blendMode = .add
        glow.zPosition = 0  // Between inner glow (z: -1) and core (z: 0, default)
        glow.name = "coreGlow"
        addChild(glow)
    }
    
    private func generateCoreGlowTexture(color: UIColor, size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        
        let image = renderer.image { context in
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            
            // Create radial gradient: bright center → star color → transparent edges
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            // Bright center color (more intense version of star color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let brightCenter = UIColor(
                red: min(1.0, r * 1.3),
                green: min(1.0, g * 1.3),
                blue: min(1.0, b * 1.3),
                alpha: 0.8
            )
            
            // Mid color (star color at medium opacity)
            let midColor = color.withAlphaComponent(0.4)
            
            let colors = [
                brightCenter.cgColor,
                midColor.cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.4, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                return
            }
            
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
        
        return SKTexture(image: image)
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
    
    private func addRetroBloom() {
        // Only add bloom to large, bright stars
        guard size.width > 80 else { return }
        
        retroBloom = SKEffectNode()
        retroBloom?.shouldEnableEffects = true
        
        // Create bloom glow
        let bloomGlow = SKShapeNode(circleOfRadius: size.width / 2)
        bloomGlow.fillColor = starType.uiColor
        bloomGlow.strokeColor = .clear
        bloomGlow.alpha = 0.6
        bloomGlow.blendMode = .add
        
        // Apply gaussian blur for bloom
        let bloomFilter = CIFilter(name: "CIGaussianBlur")
        bloomFilter?.setValue(10.0, forKey: kCIInputRadiusKey)
        retroBloom?.filter = bloomFilter
        
        retroBloom?.addChild(bloomGlow)
        retroBloom?.zPosition = -4
        addChild(retroBloom!)
    }
    
    private func addRetroRimLight() {
        // Only add if retro aesthetics are enabled
        guard GameConstants.RetroAestheticSettings.enableRetroAesthetics &&
              GameConstants.RetroAestheticSettings.enableRimLighting else {
            return
        }
        
        // PERFORMANCE: Only add rim light to medium/large stars (> 35pt)
        guard size.width > 35 else { return }
        
        let radius = size.width / 2
        
        // Create FULL CIRCLE rim light (not an arc)
        retroRimLight = SKShapeNode(circleOfRadius: radius * 1.08)
        retroRimLight?.fillColor = .clear
        
        // Use star's color for rim light with warm tint
        let starColor = starType.uiColor
        
        // Add warmth by mixing with orange
        let warmOrange = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        retroRimLight?.strokeColor = blendColors(starColor, warmOrange, ratio: 0.3)
        
        // Scale line width and glow with star size
        let baseLineWidth: CGFloat = size.width > 80 ? 2.5 : 1.5
        let baseGlowWidth: CGFloat = size.width > 80 ? 15 : 10
        
        retroRimLight?.lineWidth = baseLineWidth
        retroRimLight?.glowWidth = baseGlowWidth
        retroRimLight?.alpha = 0.5  // More subtle than black hole
        retroRimLight?.blendMode = .add
        retroRimLight?.zPosition = 3
        
        addChild(retroRimLight!)
        
        // Subtle pulse animation (slower than black hole)
        let rimLightPulse = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.3, duration: 2.5),
                SKAction.scale(to: 1.01, duration: 2.5)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.5, duration: 2.5),
                SKAction.scale(to: 1.0, duration: 2.5)
            ])
        ])
        rimLightPulse.timingMode = .easeInEaseOut
        retroRimLight?.run(SKAction.repeatForever(rimLightPulse))
    }
    
    private func blendColors(_ color1: UIColor, _ color2: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(
            red: r1 * (1 - ratio) + r2 * ratio,
            green: g1 * (1 - ratio) + g2 * ratio,
            blue: b1 * (1 - ratio) + b2 * ratio,
            alpha: 1.0
        )
    }
    
    private func brightenStarColor(_ color: UIColor, intensity: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Scale each RGB component toward 1.0 to increase brightness
        // Preserves color identity while making it more intense
        let brightnessBoost = 1.0 + (intensity * 0.4)
        return UIColor(
            red: min(1.0, r * brightnessBoost),
            green: min(1.0, g * brightnessBoost),
            blue: min(1.0, b * brightnessBoost),
            alpha: 1.0
        )
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
        
        // Match the star's actual visual footprint (outer corona size + buffer)
        // Outer corona is 4x the core size, so radius is 2x core radius + buffer
        let glow = SKShapeNode(circleOfRadius: size.width + 10)
        
        // Use brighter shade of the star's own color instead of red
        let starColor = starType.uiColor
        let brighterColor = brightenStarColor(starColor, intensity: 0.4)
        
        glow.strokeColor = brighterColor
        glow.lineWidth = size.width > 200 ? 4 : 3
        glow.fillColor = .clear
        glow.glowWidth = size.width > 200 ? 12 : 8
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
        guard let glow = warningGlow else { return }
        glow.removeAllActions()
        glow.removeFromParent()
        warningGlow = nil
    }
    
    deinit {
        // Cleanup warning glow when star is deallocated
        hideWarningGlow()
    }
    
    func addMergedStarEnhancement() {
        guard let innerGlow = innerGlow, let outerCorona = outerCorona else { return }
        
        // Store original properties for restoration
        let originalInnerAlpha = innerGlow.alpha
        let originalCoronaAlpha = outerCorona.alpha
        
        // Boost glow intensity
        let boostedInnerAlpha = min(originalInnerAlpha + 0.4, 1.0)
        let boostedCoronaAlpha = min(originalCoronaAlpha + 0.3, 1.0)
        
        // Immediately apply boosted alpha
        innerGlow.alpha = boostedInnerAlpha
        outerCorona.alpha = boostedCoronaAlpha
        
        // Create intense pulsing animation (faster and more dramatic than normal)
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.25)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.25)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        
        let alphaUp = SKAction.fadeAlpha(to: min(boostedInnerAlpha + 0.15, 1.0), duration: 0.25)
        let alphaDown = SKAction.fadeAlpha(to: boostedInnerAlpha, duration: 0.25)
        alphaUp.timingMode = .easeInEaseOut
        alphaDown.timingMode = .easeInEaseOut
        
        // Combined scale and alpha pulse
        let scalePulse = SKAction.sequence([scaleUp, scaleDown])
        let alphaPulse = SKAction.sequence([alphaUp, alphaDown])
        
        // Remove any existing normal pulse animations
        innerGlow.removeAction(forKey: "glowPulse")
        outerCorona.removeAction(forKey: "glowPulse")
        
        // Apply enhanced pulse to both layers
        innerGlow.run(SKAction.repeatForever(scalePulse), withKey: "mergedScalePulse")
        innerGlow.run(SKAction.repeatForever(alphaPulse), withKey: "mergedAlphaPulse")
        outerCorona.run(SKAction.repeatForever(scalePulse), withKey: "mergedScalePulse")
        
        // After 8 seconds, restore to normal state
        let wait = SKAction.wait(forDuration: 8.0)
        let restore = SKAction.run { [weak self, weak innerGlow, weak outerCorona] in
            guard let self = self, let innerGlow = innerGlow, let outerCorona = outerCorona else { return }
            
            // Remove enhanced pulse animations
            innerGlow.removeAction(forKey: "mergedScalePulse")
            innerGlow.removeAction(forKey: "mergedAlphaPulse")
            outerCorona.removeAction(forKey: "mergedScalePulse")
            
            // Smoothly fade back to original alpha values
            let fadeInner = SKAction.fadeAlpha(to: originalInnerAlpha, duration: 1.0)
            let fadeCorona = SKAction.fadeAlpha(to: originalCoronaAlpha, duration: 1.0)
            fadeInner.timingMode = .easeInEaseOut
            fadeCorona.timingMode = .easeInEaseOut
            
            // Smoothly scale back to normal
            let scaleBack = SKAction.scale(to: 1.0, duration: 1.0)
            scaleBack.timingMode = .easeInEaseOut
            
            innerGlow.run(fadeInner)
            innerGlow.run(scaleBack)
            outerCorona.run(fadeCorona)
            outerCorona.run(scaleBack)
            
            // Restore original pulse animation if it existed
            self.applyPulseAnimation()
        }
        
        run(SKAction.sequence([wait, restore]))
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

