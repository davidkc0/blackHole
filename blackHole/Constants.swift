//
//  Constants.swift
//  blackHole
//
//  Game configuration constants
//

import UIKit
import CoreGraphics

enum GameConstants {
    // Black Hole
    static let blackHoleInitialDiameter: CGFloat = 40
    static let blackHoleMinDiameter: CGFloat = 30
    static let blackHoleMaxDiameter: CGFloat = 10000  // Effectively unlimited
    static let blackHoleShrinkMultiplier: CGFloat = 0.80  // Moderate penalty: lose 20% of size
    static let blackHoleSizeAnimationDuration: TimeInterval = 0.2
    static let blackHoleScreenPadding: CGFloat = 30
    
    // Growth System
    static let minGrowthPercent: CGFloat = 0.05        // 5% minimum growth
    static let maxGrowthPercent: CGFloat = 0.30        // 30% maximum growth
    static let sizePenaltyThreshold: CGFloat = 800     // Size where max penalty applies
    static let minSizePenalty: CGFloat = 0.3           // Minimum 30% of base growth
    
    // Legacy (for backward compatibility)
    static let blackHoleGrowthMultiplier: CGFloat = 1.15  // Deprecated
    
    // Camera Zoom
    static let cameraZoomTargetPercentage: CGFloat = 0.20  // Black hole takes 20% of screen
    static let cameraMinZoom: CGFloat = 0.5                // Maximum zoom in
    static let cameraMaxZoom: CGFloat = 4.0                // Maximum zoom out
    static let cameraZoomLerpFactor: CGFloat = 0.15        // Smooth zoom speed
    
    // Ring Indicator
    static let ringGap: CGFloat = 10
    static let ringWidth: CGFloat = 8
    static let ringColorTransitionDuration: TimeInterval = 0.3
    static let ringPulseDuration: TimeInterval = 1.5
    static let ringPulseScaleMin: CGFloat = 0.95
    static let ringPulseScaleMax: CGFloat = 1.05
    
    // Stars - Dynamic spawning with acceleration
    static let baseStarSpawnInterval: TimeInterval = 0.6       // Early game baseline
    static let minStarSpawnInterval: TimeInterval = 0.15       // Late game minimum
    static let spawnAccelerationThreshold: CGFloat = 200       // When acceleration begins
    static let spawnAccelerationFactor: CGFloat = 400          // Rate of acceleration
    static let starSpawnInterval: TimeInterval = 0.6           // Legacy constant (kept for compatibility)
    static let starMaxCount: Int = 72
    static let starMinSpawnDistance: CGFloat = 100
    static let starSpawnAnimationDuration: TimeInterval = 0.2
    static let starFadeOutDuration: TimeInterval = 0.1
    static let starMaxDistanceFromScreen: CGFloat = 1000
    static let starInitialVelocityRange: CGFloat = 80
    static let starWarningDistance: CGFloat = 300
    static let starWarningEdgeDistance: CGFloat = 80
    static let starRimFlashDistance: CGFloat = 40
    
    // Physics
    static let gravitationalConstant: CGFloat = 800
    static let gravityMaxDistance: CGFloat = 500
    
    // Physics Categories
    static let blackHoleCategory: UInt32 = 0x1 << 0
    static let starCategory: UInt32 = 0x1 << 1
    static let powerUpCategory: UInt32 = 0x1 << 2
    
    // Power-Up System
    static let cometCoreSize: CGFloat = 15
    static let cometSpeed: CGFloat = 250
    static let rainbowDuration: TimeInterval = 5.0
    static let freezeDuration: TimeInterval = 6.0
    static let rainbowSpawnInterval: TimeInterval = 20.0
    static let freezeSpawnInterval: TimeInterval = 25.0
    
    // Scoring
    static let correctColorScore: Int = 100
    static let wrongColorPenalty: Int = -50
    
    // Color Change
    static let colorChangeMinInterval: TimeInterval = 5.0
    static let colorChangeMaxInterval: TimeInterval = 12.0
    static let colorChangeWarningDuration: TimeInterval = 2.0  // Blink for 2 seconds before change
    
    // Star-to-Star Interactions
    static let starGravityMultiplier: CGFloat = 0.15
    static let starGravityRange: CGFloat = 250
    static let maxMergedStars: Int = 10
    static let mergeCooldown: TimeInterval = 1.5
    static let minMergeSizeRequirement: CGFloat = 20
    static let mergeDistanceFromBlackHole: CGFloat = 100
    static let mergedStarPointsMultiplier: Double = 1.5
    static let enableStarMerging: Bool = true
    static let maxMergesPerStar: Int = 3  // Allow stars to merge up to 3 times
    
    // Orbital Interaction (when max merge limit reached)
    static let orbitalSpeedMultiplier: CGFloat = 1.2      // Faster orbit
    static let orbitalDuration: TimeInterval = 0.4        // How long the orbit lasts
    static let escapeSpeedMultiplier: CGFloat = 1.5       // Stronger fling
    static let orbitalVelocityInheritance: CGFloat = 0.3  // How much of larger star's velocity is inherited
    
    // UI (adjusted for Dynamic Island clearance)
    static let scoreLabelTopMargin: CGFloat = 70
    static let scoreLabelLeftMargin: CGFloat = 20
    static let scoreFontSize: CGFloat = 24
    static let scoreStrokeWidth: CGFloat = -3
    
    // Passive Shrink System
    static let passiveShrinkRate: CGFloat = 0.1        
    static let passiveShrinkScaling: CGFloat = 0.0     // No scaling with size (constant rate)
    
    // Predictive Spawning
    static let movementHistorySize: Int = 5
    static let predictionTimeAhead: TimeInterval = 1.5
    static let movementSpeedThreshold: CGFloat = 50.0 // Below this = stationary
    
    // Star Field System
    static let starFieldMinInterval: TimeInterval = 45.0
    static let starFieldMaxInterval: TimeInterval = 60.0
    static let starFieldDensityMultiplier: CGFloat = 2.5 // 2.5x normal density
    static let starFieldRadius: CGFloat = 400.0
    static let starFieldChallengePct: CGFloat = 0.30 // 30% larger stars
    
    // Shrink Indicator UI (circular gauge in top-right, accounting for Dynamic Island)
    static let shrinkIndicatorRadius: CGFloat = 20
    static let shrinkIndicatorRightMargin: CGFloat = 20
    static let shrinkIndicatorTopMargin: CGFloat = 70
    
    // Game Over
    static let gameOverFontSize: CGFloat = 48
    static let finalScoreFontSize: CGFloat = 32
    static let restartFontSize: CGFloat = 24
    
    // Retro Aesthetic Settings
    enum RetroAestheticSettings {
        // MASTER TOGGLE - Set to false to disable ALL retro effects
        static let enableRetroAesthetics: Bool = true  // ✅ ENABLED
        
        // Individual effect toggles (only apply if master toggle is true)
        static let enableFilmGrain: Bool = true        // ✅ WORKING - subtle white noise
        static let enableVignette: Bool = true         // ✅ WORKING - edge darkening
        static let enableRimLighting: Bool = true      // ✅ WORKING - color-matched circles
        static let enableColorGrading: Bool = true    // ❌ OFF
        static let defaultColorProfile: ColorGradingProfile = .bladeRunner
        static let enableScanlines: Bool = false
        static let grainIntensity: CGFloat = 0.03      // Reduced - more subtle
        static let vignetteIntensity: CGFloat = 0.30   // Edge darkening
    }
}

enum StarType: CaseIterable {
    case whiteDwarf, yellowDwarf, blueGiant, orangeGiant, redSupergiant
    
    var displayName: String {
        switch self {
        case .whiteDwarf:
            return "White Dwarf"
        case .yellowDwarf:
            return "Yellow Dwarf"
        case .blueGiant:
            return "Blue Giant"
        case .orangeGiant:
            return "Orange Giant"
        case .redSupergiant:
            return "Red Supergiant"
        }
    }
    
    var uiColor: UIColor {
        switch self {
        case .whiteDwarf:
            return UIColor(red: 0.941, green: 0.941, blue: 0.941, alpha: 1.0) // #F0F0F0
        case .yellowDwarf:
            return UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1.0) // #FFD700
        case .blueGiant:
            return UIColor(red: 0.302, green: 0.651, blue: 1.0, alpha: 1.0) // #4DA6FF
        case .orangeGiant:
            return UIColor(red: 1.0, green: 0.549, blue: 0.259, alpha: 1.0) // #FF8C42
        case .redSupergiant:
            return UIColor(red: 0.863, green: 0.078, blue: 0.235, alpha: 1.0) // #DC143C
        }
    }
    
    var sizeRange: ClosedRange<CGFloat> {
        switch self {
        case .whiteDwarf:
            return 16...24        // Slightly smaller
        case .yellowDwarf:
            return 28...38        // Keep similar
        case .blueGiant:
            return 55...75        // Larger (+17pt max)
        case .orangeGiant:
            return 120...300      // Much larger (+80pt max increase)
        case .redSupergiant:
            return 280...900      // MASSIVE (+300pt max increase!)
        }
    }
    
    var basePoints: Int {
        switch self {
        case .whiteDwarf:
            return 50
        case .yellowDwarf:
            return 100
        case .blueGiant:
            return 200
        case .orangeGiant:
            return 400
        case .redSupergiant:
            return 1000
        }
    }
    
    var massMultiplier: CGFloat {
        switch self {
        case .whiteDwarf:
            return 0.3
        case .yellowDwarf:
            return 1.0
        case .blueGiant:
            return 8.0
        case .orangeGiant:
            return 2.5
        case .redSupergiant:
            return 15.0
        }
    }
    
    var glowRadius: CGFloat {
        switch self {
        case .whiteDwarf:
            return 5
        case .yellowDwarf:
            return 6
        case .blueGiant:
            return 8
        case .orangeGiant:
            return 10
        case .redSupergiant:
            return 15
        }
    }
    
    static func random() -> StarType {
        return StarType.allCases.randomElement()!
    }
}

extension UIColor {
    static let spaceBackground = UIColor(hex: "#000000")  // Pure black 
    
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

