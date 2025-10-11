//
//  PowerUpType.swift
//  blackHole
//
//  Power-up types and comet trajectories
//

import UIKit
import CoreGraphics

enum PowerUpType {
    case rainbow, freeze
    
    var coreColor: UIColor {
        switch self {
        case .rainbow:
            return .white  // Will cycle through colors
        case .freeze:
            return UIColor(hex: "#C0C0C0")
        }
    }
    
    var displayName: String {
        switch self {
        case .rainbow:
            return "Rainbow"
        case .freeze:
            return "Freeze"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .rainbow:
            return GameConstants.rainbowDuration
        case .freeze:
            return GameConstants.freezeDuration
        }
    }
    
    var baseSpawnInterval: ClosedRange<TimeInterval> {
        switch self {
        case .rainbow:
            return 30.0...45.0  // Random between 30-45 seconds
        case .freeze:
            return 35.0...50.0  // Random between 35-50 seconds
        }
    }
    
    static var collectionCooldown: TimeInterval {
        return 30.0  // 30 seconds after any collection
    }
}

enum CometTrajectory: CaseIterable {
    case topLeftToBottomRight
    case topRightToBottomLeft
    case leftToRight
    case rightToLeft
    case bottomLeftToTopRight
    case bottomRightToTopLeft
    
    func getStartAndEnd(sceneSize: CGSize, blackHolePosition: CGPoint) -> (start: CGPoint, end: CGPoint) {
        let margin: CGFloat = 100
        
        // Adjust positions relative to black hole (world coordinates)
        let adjustedSize = sceneSize
        
        switch self {
        case .topLeftToBottomRight:
            return (
                CGPoint(x: blackHolePosition.x - adjustedSize.width / 2 - margin, 
                       y: blackHolePosition.y + adjustedSize.height / 2 + margin),
                CGPoint(x: blackHolePosition.x + adjustedSize.width / 2 + margin, 
                       y: blackHolePosition.y - adjustedSize.height / 2 - margin)
            )
        case .topRightToBottomLeft:
            return (
                CGPoint(x: blackHolePosition.x + adjustedSize.width / 2 + margin, 
                       y: blackHolePosition.y + adjustedSize.height / 2 + margin),
                CGPoint(x: blackHolePosition.x - adjustedSize.width / 2 - margin, 
                       y: blackHolePosition.y - adjustedSize.height / 2 - margin)
            )
        case .leftToRight:
            let yOffset = CGFloat.random(in: -adjustedSize.height/3...adjustedSize.height/3)
            return (
                CGPoint(x: blackHolePosition.x - adjustedSize.width / 2 - margin, 
                       y: blackHolePosition.y + yOffset),
                CGPoint(x: blackHolePosition.x + adjustedSize.width / 2 + margin, 
                       y: blackHolePosition.y + yOffset)
            )
        case .rightToLeft:
            let yOffset = CGFloat.random(in: -adjustedSize.height/3...adjustedSize.height/3)
            return (
                CGPoint(x: blackHolePosition.x + adjustedSize.width / 2 + margin, 
                       y: blackHolePosition.y + yOffset),
                CGPoint(x: blackHolePosition.x - adjustedSize.width / 2 - margin, 
                       y: blackHolePosition.y + yOffset)
            )
        case .bottomLeftToTopRight:
            return (
                CGPoint(x: blackHolePosition.x - adjustedSize.width / 2 - margin, 
                       y: blackHolePosition.y - adjustedSize.height / 2 - margin),
                CGPoint(x: blackHolePosition.x + adjustedSize.width / 2 + margin, 
                       y: blackHolePosition.y + adjustedSize.height / 2 + margin)
            )
        case .bottomRightToTopLeft:
            return (
                CGPoint(x: blackHolePosition.x + adjustedSize.width / 2 + margin, 
                       y: blackHolePosition.y - adjustedSize.height / 2 - margin),
                CGPoint(x: blackHolePosition.x - adjustedSize.width / 2 - margin, 
                       y: blackHolePosition.y + adjustedSize.height / 2 + margin)
            )
        }
    }
}

