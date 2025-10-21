//
//  MovementTracker.swift
//  blackHole
//
//  Tracks black hole movement and predicts future position for intelligent star spawning
//

import Foundation
import CoreGraphics

enum MovementDirection {
    case north, northEast, east, southEast
    case south, southWest, west, northWest
    case stationary
    
    func getSpawnWeights() -> [EdgeWeight] {
        switch self {
        case .north:
            return [
                EdgeWeight(edge: .top, weight: 0.5),
                EdgeWeight(edge: .topRight, weight: 0.2),
                EdgeWeight(edge: .topLeft, weight: 0.2),
                EdgeWeight(edge: .right, weight: 0.05),
                EdgeWeight(edge: .left, weight: 0.05)
            ]
        case .northEast:
            return [
                EdgeWeight(edge: .top, weight: 0.35),
                EdgeWeight(edge: .right, weight: 0.35),
                EdgeWeight(edge: .topRight, weight: 0.3)
            ]
        case .east:
            return [
                EdgeWeight(edge: .right, weight: 0.5),
                EdgeWeight(edge: .topRight, weight: 0.2),
                EdgeWeight(edge: .bottomRight, weight: 0.2),
                EdgeWeight(edge: .top, weight: 0.05),
                EdgeWeight(edge: .bottom, weight: 0.05)
            ]
        case .southEast:
            return [
                EdgeWeight(edge: .right, weight: 0.35),
                EdgeWeight(edge: .bottom, weight: 0.35),
                EdgeWeight(edge: .bottomRight, weight: 0.3)
            ]
        case .south:
            return [
                EdgeWeight(edge: .bottom, weight: 0.5),
                EdgeWeight(edge: .bottomRight, weight: 0.2),
                EdgeWeight(edge: .bottomLeft, weight: 0.2),
                EdgeWeight(edge: .right, weight: 0.05),
                EdgeWeight(edge: .left, weight: 0.05)
            ]
        case .southWest:
            return [
                EdgeWeight(edge: .bottom, weight: 0.35),
                EdgeWeight(edge: .left, weight: 0.35),
                EdgeWeight(edge: .bottomLeft, weight: 0.3)
            ]
        case .west:
            return [
                EdgeWeight(edge: .left, weight: 0.5),
                EdgeWeight(edge: .topLeft, weight: 0.2),
                EdgeWeight(edge: .bottomLeft, weight: 0.2),
                EdgeWeight(edge: .top, weight: 0.05),
                EdgeWeight(edge: .bottom, weight: 0.05)
            ]
        case .northWest:
            return [
                EdgeWeight(edge: .left, weight: 0.35),
                EdgeWeight(edge: .top, weight: 0.35),
                EdgeWeight(edge: .topLeft, weight: 0.3)
            ]
        case .stationary:
            return [
                EdgeWeight(edge: .top, weight: 0.25),
                EdgeWeight(edge: .right, weight: 0.25),
                EdgeWeight(edge: .bottom, weight: 0.25),
                EdgeWeight(edge: .left, weight: 0.25)
            ]
        }
    }
}

struct EdgeWeight {
    let edge: SpawnEdge
    let weight: CGFloat
}

enum SpawnEdge {
    case top, topRight, right, bottomRight
    case bottom, bottomLeft, left, topLeft
}

class MovementTracker {
    private var positionHistory: [(position: CGPoint, time: TimeInterval)] = []
    private let historySize: Int
    private let speedThreshold: CGFloat
    
    init(historySize: Int = 5, speedThreshold: CGFloat = 50.0) {
        self.historySize = historySize
        self.speedThreshold = speedThreshold
    }
    
    func recordPosition(_ position: CGPoint, at time: TimeInterval) {
        positionHistory.append((position, time))
        if positionHistory.count > historySize {
            positionHistory.removeFirst()
        }
    }
    
    func getVelocity() -> CGVector {
        guard positionHistory.count >= 2 else { return .zero }
        
        let recent = positionHistory.last!
        let previous = positionHistory[positionHistory.count - 2]
        let dt = recent.time - previous.time
        
        guard dt > 0 else { return .zero }
        
        let dx = (recent.position.x - previous.position.x) / CGFloat(dt)
        let dy = (recent.position.y - previous.position.y) / CGFloat(dt)
        
        return CGVector(dx: dx, dy: dy)
    }
    
    func getAcceleration() -> CGVector {
        guard positionHistory.count >= 3 else { return .zero }
        
        // Calculate velocity between last two points
        let recent = positionHistory.last!
        let previous = positionHistory[positionHistory.count - 2]
        let older = positionHistory[positionHistory.count - 3]
        
        let dt1 = recent.time - previous.time
        let dt2 = previous.time - older.time
        
        guard dt1 > 0 && dt2 > 0 else { return .zero }
        
        let v1x = (recent.position.x - previous.position.x) / CGFloat(dt1)
        let v1y = (recent.position.y - previous.position.y) / CGFloat(dt1)
        
        let v2x = (previous.position.x - older.position.x) / CGFloat(dt2)
        let v2y = (previous.position.y - older.position.y) / CGFloat(dt2)
        
        let dtAvg = (dt1 + dt2) / 2
        let ax = (v1x - v2x) / CGFloat(dtAvg)
        let ay = (v1y - v2y) / CGFloat(dtAvg)
        
        return CGVector(dx: ax, dy: ay)
    }
    
    func getPredictedPosition(afterSeconds seconds: TimeInterval) -> CGPoint {
        guard let currentPos = positionHistory.last?.position else { return .zero }
        
        let velocity = getVelocity()
        let acceleration = getAcceleration()
        
        // Use kinematic equation: s = ut + 0.5at²
        let t = CGFloat(seconds)
        let predictedX = currentPos.x + velocity.dx * t + 0.5 * acceleration.dx * t * t
        let predictedY = currentPos.y + velocity.dy * t + 0.5 * acceleration.dy * t * t
        
        return CGPoint(x: predictedX, y: predictedY)
    }
    
    func getMovementDirection() -> MovementDirection {
        let velocity = getVelocity()
        let speed = hypot(velocity.dx, velocity.dy)
        
        // If moving too slowly, consider stationary
        if speed < speedThreshold {
            return .stationary
        }
        
        // Calculate angle in radians
        let angle = atan2(velocity.dy, velocity.dx)
        
        // Convert to 0-2π range
        let normalizedAngle = angle < 0 ? angle + 2 * .pi : angle
        
        // Divide into 8 segments (45 degrees each)
        let segment = Int((normalizedAngle / (.pi / 4)).rounded()) % 8
        
        switch segment {
        case 0: return .east
        case 1: return .northEast
        case 2: return .north
        case 3: return .northWest
        case 4: return .west
        case 5: return .southWest
        case 6: return .south
        case 7: return .southEast
        default: return .stationary
        }
    }
}


