//
//  VirtualJoystick.swift
//  blackHole
//
//  Virtual joystick overlay for joystick movement mode.
//  Appears at touch point, controls black hole velocity based on thumb displacement.
//

import SpriteKit

class VirtualJoystick: SKNode {
    
    // MARK: - Configuration
    
    /// Radius of the outer joystick base ring
    private let baseRadius: CGFloat = 55
    
    /// Radius of the inner thumb knob
    private let thumbRadius: CGFloat = 22
    
    /// Dead zone as fraction of base radius (prevents drift from small touches)
    private let deadZoneFraction: CGFloat = 0.15
    
    /// Maximum black hole speed in points per second at full tilt
    static let maxSpeed: CGFloat = 400
    
    // MARK: - Nodes
    
    private let baseNode: SKShapeNode
    private let thumbNode: SKShapeNode
    
    // MARK: - State
    
    /// Normalized displacement vector (-1 to 1 on each axis)
    private(set) var displacement: CGVector = .zero
    
    /// Whether the joystick is currently being touched
    private(set) var isActive: Bool = false
    
    // MARK: - Initialization
    
    override init() {
        // Create base ring (outer circle)
        baseNode = SKShapeNode(circleOfRadius: baseRadius)
        baseNode.strokeColor = UIColor(red: 131/255, green: 214/255, blue: 255/255, alpha: 0.5)  // #83D6FF
        baseNode.lineWidth = 2
        baseNode.fillColor = UIColor(red: 131/255, green: 214/255, blue: 255/255, alpha: 0.08)
        baseNode.glowWidth = 1
        
        // Create thumb knob (inner circle)
        thumbNode = SKShapeNode(circleOfRadius: thumbRadius)
        thumbNode.strokeColor = UIColor(red: 131/255, green: 214/255, blue: 255/255, alpha: 0.7)
        thumbNode.lineWidth = 1.5
        thumbNode.fillColor = UIColor(red: 131/255, green: 214/255, blue: 255/255, alpha: 0.24)
        thumbNode.glowWidth = 2
        
        super.init()
        
        addChild(baseNode)
        addChild(thumbNode)
        
        // Start hidden
        alpha = 0
        isHidden = true
        zPosition = 1000  // Always on top
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Interface
    
    /// Show the joystick at the given position with a quick fade-in
    func show(at position: CGPoint) {
        self.position = position
        isHidden = false
        isActive = true
        displacement = .zero
        thumbNode.position = .zero
        
        removeAllActions()
        run(SKAction.fadeAlpha(to: 1.0, duration: 0.1))
    }
    
    /// Update the thumb position based on the current touch location (in scene coordinates)
    func updateThumb(touchLocation: CGPoint) {
        // Convert touch to local joystick coordinates
        let dx = touchLocation.x - position.x
        let dy = touchLocation.y - position.y
        let distance = hypot(dx, dy)
        
        // Clamp thumb to base radius
        let clampedDistance = min(distance, baseRadius)
        let angle = atan2(dy, dx)
        
        let clampedX = cos(angle) * clampedDistance
        let clampedY = sin(angle) * clampedDistance
        thumbNode.position = CGPoint(x: clampedX, y: clampedY)
        
        // Calculate normalized displacement (0 to 1)
        let normalizedDistance = clampedDistance / baseRadius
        
        // Apply dead zone
        let deadZone = deadZoneFraction
        if normalizedDistance < deadZone {
            displacement = .zero
        } else {
            // Remap from [deadZone, 1] to [0, 1] for smooth ramp-up
            let remapped = (normalizedDistance - deadZone) / (1.0 - deadZone)
            displacement = CGVector(
                dx: cos(angle) * remapped,
                dy: sin(angle) * remapped
            )
        }
    }
    
    /// Hide the joystick and reset state
    func hide() {
        isActive = false
        displacement = .zero
        thumbNode.position = .zero
        
        removeAllActions()
        run(SKAction.fadeAlpha(to: 0.0, duration: 0.15)) {
            self.isHidden = true
        }
    }
    
    /// Get the velocity vector for this frame (direction × speed)
    func getVelocity() -> CGVector {
        let speed = hypot(displacement.dx, displacement.dy) * VirtualJoystick.maxSpeed
        if speed < 1.0 { return .zero }  // Negligible
        
        let angle = atan2(displacement.dy, displacement.dx)
        return CGVector(
            dx: cos(angle) * speed,
            dy: sin(angle) * speed
        )
    }
}
