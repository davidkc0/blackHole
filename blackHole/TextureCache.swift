//
//  TextureCache.swift
//  blackHole
//
//  Singleton for generating and caching procedural star textures
//

import SpriteKit
import UIKit

enum SizeBucket: String {
    case small, medium, large, huge
    
    static func bucket(for diameter: CGFloat) -> SizeBucket {
        switch diameter {
        case 0..<40:
            return .small
        case 40..<80:
            return .medium
        case 80..<150:
            return .large
        default:
            return .huge
        }
    }
    
    var textureSize: CGFloat {
        switch self {
        case .small:
            return 64
        case .medium:
            return 128
        case .large:
            return 256
        case .huge:
            return 512
        }
    }
}

class TextureCache {
    static let shared = TextureCache()
    
    private var coreTextures: [String: SKTexture] = [:]
    private var glowTextures: [String: SKTexture] = [:]
    private var particleTextures: [String: SKTexture] = [:]
    
    private init() {}
    
    func getSizeBucket(_ diameter: CGFloat) -> SizeBucket {
        return SizeBucket.bucket(for: diameter)
    }
    
    func getStarCoreTexture(type: StarType, sizeBucket: SizeBucket) -> SKTexture {
        let key = "\(type.displayName)_core_\(sizeBucket.rawValue)"
        
        if let cached = coreTextures[key] {
            return cached
        }
        
        let texture = generateStarCoreTexture(color: type.uiColor, size: sizeBucket.textureSize)
        coreTextures[key] = texture
        return texture
    }
    
    func getStarGlowTexture(type: StarType, sizeBucket: SizeBucket) -> SKTexture {
        let key = "\(type.displayName)_glow_\(sizeBucket.rawValue)"
        
        if let cached = glowTextures[key] {
            return cached
        }
        
        let texture = generateStarGlowTexture(color: type.uiColor, size: sizeBucket.textureSize)
        glowTextures[key] = texture
        return texture
    }
    
    func getParticleTexture(size: CGFloat) -> SKTexture {
        let key = "particle_\(Int(size))"
        
        if let cached = particleTextures[key] {
            return cached
        }
        
        let texture = generateParticleTexture(size: size)
        particleTextures[key] = texture
        return texture
    }
    
    func preloadAllTextures() {
        let startTime = CACurrentMediaTime()
        
        // Preload core and glow textures for all type/size combinations
        for type in StarType.allCases {
            for bucket in [SizeBucket.small, .medium, .large, .huge] {
                _ = getStarCoreTexture(type: type, sizeBucket: bucket)
                _ = getStarGlowTexture(type: type, sizeBucket: bucket)
            }
        }
        
        // Preload common particle sizes
        for size in [4.0, 8.0, 12.0, 16.0] {
            _ = getParticleTexture(size: size)
        }
        
        let elapsed = CACurrentMediaTime() - startTime
        print("✨ Preloaded \(coreTextures.count + glowTextures.count + particleTextures.count) textures in \(String(format: "%.1f", elapsed * 1000))ms")
    }
    
    // MARK: - Texture Generation
    
    private func generateStarCoreTexture(color: UIColor, size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        
        let image = renderer.image { context in
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            
            // Create radial gradient: white center → star color → transparent
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.white.cgColor,
                color.cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.3, 1.0]
            
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
    
    private func generateStarGlowTexture(color: UIColor, size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        
        let image = renderer.image { context in
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            
            // Softer gradient for glow layer
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            // Desaturate color slightly for outer glow
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let softColor = UIColor(red: r, green: g, blue: b, alpha: 0.5)
            
            let colors = [
                color.cgColor,
                softColor.cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            
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
    
    private func generateParticleTexture(size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Clear background first
            ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
            
            // Enable anti-aliasing
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)
            
            // Draw simple solid white circle
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        
        return SKTexture(image: image)
    }
}

