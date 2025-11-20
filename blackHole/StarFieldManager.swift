//
//  StarFieldManager.swift
//  blackHole
//
//  Manages dense star field spawning for discovery moments
//

import Foundation
import SpriteKit

enum StarFieldPattern {
    case cluster      // Tight circular group
    case line         // Linear formation
    case arc          // Curved arc
    case scattered    // Wide spread field
}

class StarFieldManager {
    private var lastSpawnTime: TimeInterval = 0
    private var nextSpawnInterval: TimeInterval = 0
    private var activeStarFieldStars: [Star] = []
    
    weak var scene: GameScene?
    
    init() {
        // Set initial random interval
        self.nextSpawnInterval = TimeInterval.random(in: GameConstants.starFieldMinInterval...GameConstants.starFieldMaxInterval)
    }
    
    func shouldSpawnStarField(currentTime: TimeInterval) -> Bool {
        guard currentTime - lastSpawnTime >= nextSpawnInterval else { return false }
        return true
    }
    
    func checkAndSpawnStarField(currentTime: TimeInterval, blackHolePosition: CGPoint, scene: GameScene) {
        guard shouldSpawnStarField(currentTime: currentTime) else { return }
        
        // Select random pattern
        let pattern = selectStarFieldPattern()
        
        // Calculate spawn position (600-800pt away from black hole - closer for on-screen visibility)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 600...800)
        let spawnPosition = CGPoint(
            x: blackHolePosition.x + cos(angle) * distance,
            y: blackHolePosition.y + sin(angle) * distance
        )
        
        spawnStarField(at: spawnPosition, pattern: pattern, scene: scene)
        
        // Update spawn tracking
        lastSpawnTime = currentTime
        nextSpawnInterval = TimeInterval.random(in: GameConstants.starFieldMinInterval...GameConstants.starFieldMaxInterval)
        
        print("🌌 Star field spawned: \(pattern) at \(String(format: "%.0f", distance))pt away")
    }
    
    func selectStarFieldPattern() -> StarFieldPattern {
        let random = CGFloat.random(in: 0...1)
        if random < 0.3 { return .cluster }
        else if random < 0.55 { return .scattered }
        else if random < 0.8 { return .line }
        else { return .arc }
    }
    
    func spawnStarField(at center: CGPoint, pattern: StarFieldPattern, scene: GameScene) {
        let stars = generateStarFieldStars(pattern: pattern, center: center, blackHoleSize: scene.blackHole.currentDiameter)
        
        // Spawn each star
        for star in stars {
            // Assign unique name
            // Fade in animation
            star.alpha = 0
            star.setScale(0.5)
            let fadeIn = SKAction.fadeIn(withDuration: 0.3)
            let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
            star.run(SKAction.group([fadeIn, scaleUp]))
            
            scene.addChild(star)
            scene.stars.append(star)
            activeStarFieldStars.append(star)
        }
    }
    
    func generateStarFieldStars(pattern: StarFieldPattern, center: CGPoint, blackHoleSize: CGFloat) -> [Star] {
        var stars: [Star] = []
        
        switch pattern {
        case .cluster:
            // 8-12 stars in tight circular group
            let starCount = Int.random(in: 8...12)
            let radius = CGFloat.random(in: 200...300)
            
            for i in 0..<starCount {
                let angle = (CGFloat(i) / CGFloat(starCount)) * 2 * .pi
                let randomRadius = radius * CGFloat.random(in: 0.6...1.0)
                let position = CGPoint(
                    x: center.x + cos(angle) * randomRadius,
                    y: center.y + sin(angle) * randomRadius
                )
                
                let starType = selectStarFieldStarType(blackHoleSize: blackHoleSize)
                let star = Star(type: starType)
                star.position = position
                stars.append(star)
            }
            
        case .line:
            // 6-8 stars in linear formation
            let starCount = Int.random(in: 6...8)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let spacing: CGFloat = 120
            
            for i in 0..<starCount {
                let offset = CGFloat(i - starCount / 2) * spacing
                let position = CGPoint(
                    x: center.x + cos(angle) * offset,
                    y: center.y + sin(angle) * offset
                )
                
                let starType = selectStarFieldStarType(blackHoleSize: blackHoleSize)
                let star = Star(type: starType)
                star.position = position
                stars.append(star)
            }
            
        case .arc:
            // 8-10 stars in curved arc
            let starCount = Int.random(in: 8...10)
            let radius: CGFloat = 400
            let arcAngle: CGFloat = .pi  // 180 degree arc
            let startAngle = CGFloat.random(in: 0...(2 * .pi))
            
            for i in 0..<starCount {
                let angle = startAngle + (CGFloat(i) / CGFloat(starCount - 1)) * arcAngle
                let position = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                
                let starType = selectStarFieldStarType(blackHoleSize: blackHoleSize)
                let star = Star(type: starType)
                star.position = position
                stars.append(star)
            }
            
        case .scattered:
            // 18-25 stars spread across large area
            let starCount = Int.random(in: 18...25)
            let radius: CGFloat = 500  // Increased from 400 for better visibility
            
            for _ in 0..<starCount {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let randomRadius = radius * CGFloat.random(in: 0.3...1.0)
                let position = CGPoint(
                    x: center.x + cos(angle) * randomRadius,
                    y: center.y + sin(angle) * randomRadius
                )
                
                let starType = selectStarFieldStarType(blackHoleSize: blackHoleSize)
                let star = Star(type: starType)
                star.position = position
                stars.append(star)
            }
        }
        
        return stars
    }
    
    private func selectStarFieldStarType(blackHoleSize: CGFloat) -> StarType {
        let random = CGFloat.random(in: 0...1)
        
        // Star fields use same tease system as regular spawning
        // 70% eatable stars, 30% challenge/preview stars
        
        if blackHoleSize < 48 {
            // Phase 1: Mostly whites + some yellow previews
            if random < 0.70 { return .whiteDwarf }      // 70% edible
            else { return .yellowDwarf }                  // 30% preview/challenge
            
        } else if blackHoleSize < 80 {
            // Phase 2: Whites + Yellows + some blue previews
            if random < 0.45 { return .whiteDwarf }      // 45%
            else if random < 0.70 { return .yellowDwarf } // 25%
            else { return .blueGiant }                    // 30% preview/challenge
            
        } else if blackHoleSize < 140 {
            // Phase 3: Whites + Yellows + Blues + some orange previews
            let r = CGFloat.random(in: 0...1)
            if r < 0.25 { return .whiteDwarf }           // 25%
            else if r < 0.45 { return .yellowDwarf }     // 20%
            else if r < 0.70 { return .blueGiant }       // 25%
            else { return .orangeGiant }                  // 30% preview/challenge
            
        } else if blackHoleSize < 320 {
            // Phase 4: All except reds + some red previews
            let r = CGFloat.random(in: 0...1)
            if r < 0.20 { return .whiteDwarf }           // 20%
            else if r < 0.35 { return .yellowDwarf }     // 15%
            else if r < 0.55 { return .blueGiant }       // 20%
            else if r < 0.75 { return .orangeGiant }     // 20%
            else { return .redSupergiant }                // 25% preview/challenge
            
        } else {
            // Phase 5: All types available
            let r = CGFloat.random(in: 0...1)
            if r < 0.15 { return .whiteDwarf }           // 15%
            else if r < 0.25 { return .yellowDwarf }     // 10%
            else if r < 0.45 { return .blueGiant }       // 20%
            else if r < 0.70 { return .orangeGiant }     // 25%
            else { return .redSupergiant }                // 30%
        }
    }
    
    func cleanupDistantStarFields(blackHolePosition: CGPoint) {
        let cleanupDistance: CGFloat = 2000
        activeStarFieldStars.removeAll { star in
            let distance = hypot(star.position.x - blackHolePosition.x,
                                star.position.y - blackHolePosition.y)
            return distance > cleanupDistance
        }
    }
}

