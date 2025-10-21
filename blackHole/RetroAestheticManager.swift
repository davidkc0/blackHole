//
//  RetroAestheticManager.swift
//  blackHole
//
//  Manages retro film grain, color grading, and cinematic effects
//

import SpriteKit
import CoreImage

class RetroAestheticManager {
    static let shared = RetroAestheticManager()
    
    // Configuration
    struct Config {
        static let grainIntensity: CGFloat = 0.03  // Reduced - more subtle
        static let grainAnimationSpeed: TimeInterval = 0.05
        static let vignetteIntensity: CGFloat = 0.30  // Edge darkening
        static let rimLightColor = UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1.0)
        static let rimLightIntensity: CGFloat = 0.6  // Subtle rim light
        static let contrastBoost: CGFloat = 1.2
        static let saturationReduction: CGFloat = 0.7
        static let enableCRTScanlines: Bool = false
        static let scanlineOpacity: CGFloat = 0.05
    }
    
    private var grainTextures: [SKTexture] = []
    private var currentGrainIndex = 0
    var grainOverlay: SKSpriteNode?
    private var vignetteOverlay: SKSpriteNode?
    private var scanlineOverlay: SKSpriteNode?
    private var grainTimer: Timer?
    
    private init() {
        preloadGrainTextures()
    }
    
    // MARK: - Texture Generation
    
    private func preloadGrainTextures() {
        // Generate 10 unique grain textures for animation
        for i in 0..<10 {
            let texture = generateGrainTexture(seed: i)
            grainTextures.append(texture)
        }
    }
    
    private func generateGrainTexture(seed: Int) -> SKTexture {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Fill with TRANSPARENT (not gray!)
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add random noise - seed random for variation
            srand48(seed * 12345)
            
            // Add white noise pixels with varying alpha
            for _ in 0..<Int(size.width * size.height * 0.015) { // 1.5% pixel coverage for subtlety
                let x = CGFloat(drand48() * Double(size.width))
                let y = CGFloat(drand48() * Double(size.height))
                let alpha = CGFloat(0.2 + drand48() * 0.6)  // Varying transparency
                
                UIColor(white: 1.0, alpha: alpha).setFill()  // White pixels, not gray
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest // Preserve sharp grain
        return texture
    }
    
    // MARK: - Vignette Generation
    
    private func generateVignetteTexture() -> SKTexture {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            
            // Radial gradient from transparent center to black edges
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.clear.cgColor,
                UIColor(white: 0, alpha: 0.0).cgColor,
                UIColor(white: 0, alpha: 0.5).cgColor,
                UIColor(white: 0, alpha: 0.8).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.5, 0.8, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                return
            }
            
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
    
    // MARK: - Scanline Generation
    
    private func generateScanlineTexture() -> SKTexture {
        let size = CGSize(width: 2, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Alternating black lines
            for y in stride(from: 0, to: Int(size.height), by: 4) {
                UIColor.black.setFill()
                context.fill(CGRect(x: 0, y: y, width: 2, height: 2))
                UIColor.clear.setFill()
                context.fill(CGRect(x: 0, y: y + 2, width: 2, height: 2))
            }
        }
        
        return SKTexture(image: image)
    }
    
    // MARK: - Setup Methods
    
    func setupRetroEffects(in scene: GameScene) {
        print("📽️ RetroAestheticManager: Setting up effects...")
        
        if GameConstants.RetroAestheticSettings.enableFilmGrain {
            setupGrainOverlay(in: scene)
            startGrainAnimation()
            print("📽️ Film grain enabled")
        }
        
        if GameConstants.RetroAestheticSettings.enableVignette {
            setupVignetteOverlay(in: scene)
            print("📽️ Vignette enabled")
        }
        
        if Config.enableCRTScanlines {
            setupScanlines(in: scene)
            print("📽️ Scanlines enabled")
        }
    }
    
    private func setupGrainOverlay(in scene: GameScene) {
        guard !grainTextures.isEmpty else {
            print("⚠️ No grain textures available!")
            return
        }
        
        guard let camera = scene.camera else {
            print("⚠️ Failed to add grain overlay - camera not found")
            return
        }
        
        // Get actual screen size from the view
        let screenSize = UIScreen.main.bounds.size
        
        grainOverlay = SKSpriteNode(texture: grainTextures[0])
        grainOverlay?.size = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)  // Oversized to cover zoom
        grainOverlay?.position = CGPoint.zero  // Centered on camera
        grainOverlay?.alpha = Config.grainIntensity
        grainOverlay?.blendMode = .add  // Changed from .screen to .add for subtle effect
        grainOverlay?.zPosition = 1000 // Above everything except UI
        grainOverlay?.name = "grainOverlay"
        grainOverlay?.color = .white
        grainOverlay?.colorBlendFactor = 0.3  // Blend with white for lighter appearance
        
        camera.addChild(grainOverlay!)
        print("📽️ Grain overlay added: size=\(screenSize), blend=add, alpha=\(Config.grainIntensity)")
    }
    
    private func setupVignetteOverlay(in scene: GameScene) {
        guard let camera = scene.camera else {
            print("⚠️ Failed to add vignette overlay - camera not found")
            return
        }
        
        // Get actual screen size from the view
        let screenSize = UIScreen.main.bounds.size
        
        vignetteOverlay = SKSpriteNode(texture: generateVignetteTexture())
        vignetteOverlay?.size = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)  // Oversized to cover zoom
        vignetteOverlay?.position = CGPoint.zero  // Centered on camera
        vignetteOverlay?.alpha = Config.vignetteIntensity
        vignetteOverlay?.blendMode = .alpha  // Changed from .multiply to .alpha for subtle darkening
        vignetteOverlay?.zPosition = 999  // Just below grain
        vignetteOverlay?.name = "vignetteOverlay"
        
        camera.addChild(vignetteOverlay!)
        print("📽️ Vignette overlay added: size=\(screenSize), blend=alpha, alpha=\(Config.vignetteIntensity)")
    }
    
    private func setupScanlines(in scene: GameScene) {
        // Create horizontal scanline pattern
        let scanlineTexture = generateScanlineTexture()
        scanlineOverlay = SKSpriteNode(texture: scanlineTexture)
        scanlineOverlay?.size = scene.size
        scanlineOverlay?.alpha = Config.scanlineOpacity
        scanlineOverlay?.blendMode = .multiply
        scanlineOverlay?.zPosition = 997
        
        if let camera = scene.camera, let overlay = scanlineOverlay {
            camera.addChild(overlay)
        }
    }
    
    // MARK: - Animation
    
    private func startGrainAnimation() {
        grainTimer = Timer.scheduledTimer(withTimeInterval: Config.grainAnimationSpeed, repeats: true) { [weak self] _ in
            self?.updateGrainFrame()
        }
    }
    
    private func updateGrainFrame() {
        guard let grainOverlay = grainOverlay else { return }
        
        currentGrainIndex = (currentGrainIndex + 1) % grainTextures.count
        grainOverlay.texture = grainTextures[currentGrainIndex]
        
        // Subtle position shift for organic feel
        let offsetX = CGFloat.random(in: -1...1)
        let offsetY = CGFloat.random(in: -1...1)
        grainOverlay.position = CGPoint(x: offsetX, y: offsetY)
    }
    
    // MARK: - Performance Control
    
    func setQuality(_ quality: PerformanceMode) {
        switch quality {
        case .high:
            grainOverlay?.alpha = Config.grainIntensity
            vignetteOverlay?.alpha = Config.vignetteIntensity
        case .medium:
            grainOverlay?.alpha = Config.grainIntensity * 0.5
            vignetteOverlay?.alpha = Config.vignetteIntensity * 0.7
        case .low:
            grainOverlay?.alpha = 0
            vignetteOverlay?.alpha = Config.vignetteIntensity * 0.5
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        grainTimer?.invalidate()
        grainTimer = nil
    }
    
    deinit {
        cleanup()
    }
}

// Extension for PerformanceMode compatibility
extension RetroAestheticManager {
    enum PerformanceMode {
        case high, medium, low
    }
}

