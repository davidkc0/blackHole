//
//  StarVisualProfile.swift
//  blackHole
//
//  Visual effect parameters for different star types
//

import CoreGraphics
import Foundation

struct VisualEffectProfile {
    let birthRate: CGFloat
    let lifetime: TimeInterval
    let particleScale: CGFloat
    let particleSpeed: CGFloat
    let pulseScale: CGFloat
    let pulseDuration: TimeInterval
    let hasTwinkling: Bool
    let hasCorona: Bool
    let coronaIntensity: CGFloat
    
    static func profile(for starType: StarType, size: CGFloat) -> VisualEffectProfile {
        // Base profile for star type
        let baseProfile = baseProfile(for: starType)
        
        // Scale effects based on actual star size
        let scaleFactor = pow(size / 40.0, 0.7) // Non-linear scaling
        
        return VisualEffectProfile(
            birthRate: baseProfile.birthRate * scaleFactor,
            lifetime: baseProfile.lifetime,
            particleScale: baseProfile.particleScale * min(scaleFactor, 2.0),
            particleSpeed: baseProfile.particleSpeed,
            pulseScale: baseProfile.pulseScale,
            pulseDuration: baseProfile.pulseDuration,
            hasTwinkling: baseProfile.hasTwinkling,
            hasCorona: size > 80 && baseProfile.hasCorona, // Only large stars
            coronaIntensity: baseProfile.coronaIntensity * scaleFactor
        )
    }
    
    private static func baseProfile(for starType: StarType) -> VisualEffectProfile {
        switch starType {
        case .whiteDwarf:
            return VisualEffectProfile(
                birthRate: 10,
                lifetime: 1.5,
                particleScale: 0.3,
                particleSpeed: 10,
                pulseScale: 0.05,
                pulseDuration: 1.8,
                hasTwinkling: true,
                hasCorona: false,
                coronaIntensity: 0.5
            )
            
        case .yellowDwarf:
            return VisualEffectProfile(
                birthRate: 20,
                lifetime: 2.0,
                particleScale: 0.5,
                particleSpeed: 12,
                pulseScale: 0.08,
                pulseDuration: 2.2,
                hasTwinkling: false,
                hasCorona: false,
                coronaIntensity: 0.6
            )
            
        case .blueGiant:
            return VisualEffectProfile(
                birthRate: 35,
                lifetime: 2.5,
                particleScale: 0.7,
                particleSpeed: 15,
                pulseScale: 0.03,
                pulseDuration: 2.8,
                hasTwinkling: true,
                hasCorona: true,
                coronaIntensity: 0.8
            )
            
        case .orangeGiant:
            return VisualEffectProfile(
                birthRate: 50,
                lifetime: 3.0,
                particleScale: 1.2,
                particleSpeed: 18,
                pulseScale: 0.12,
                pulseDuration: 3.5,
                hasTwinkling: false,
                hasCorona: true,
                coronaIntensity: 1.0
            )
            
        case .redSupergiant:
            return VisualEffectProfile(
                birthRate: 40,
                lifetime: 4.0,
                particleScale: 2.0,
                particleSpeed: 20,
                pulseScale: 0.15,
                pulseDuration: 4.5,
                hasTwinkling: false,
                hasCorona: true,
                coronaIntensity: 1.2
            )
        }
    }
}

