//
//  VolumeSlider.swift
//  blackHole
//
//  Custom volume slider component for settings modal
//

import SpriteKit

class VolumeSlider: SKNode {
    
    private let track: SKShapeNode
    private let fill: SKShapeNode
    private let thumb: SKShapeNode
    private let trackWidth: CGFloat
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 16
    
    var value: Float = 1.0 {
        didSet {
            updateVisuals()
        }
    }
    
    var onValueChanged: ((Float) -> Void)?
    private var isDragging = false
    
    init(frame: CGRect, initialValue: Float = 1.0) {
        self.trackWidth = frame.width
        self.value = initialValue
        
        // Track background
        let trackRect = CGRect(x: -trackWidth/2, y: -trackHeight/2, width: trackWidth, height: trackHeight)
        self.track = SKShapeNode(rect: trackRect, cornerRadius: 2)
        track.fillColor = UIColor.white.withAlphaComponent(0.2)
        track.strokeColor = .clear
        track.zPosition = 0
        
        // Fill indicator
        self.fill = SKShapeNode(rect: trackRect, cornerRadius: 2)
        fill.fillColor = UIColor(hex: "#83D6FF")
        fill.strokeColor = .clear
        fill.zPosition = 1
        
        // Thumb handle
        let thumbRect = CGRect(x: -thumbSize/2, y: -thumbSize/2, width: thumbSize, height: thumbSize)
        self.thumb = SKShapeNode(circleOfRadius: thumbSize/2)
        thumb.fillColor = .white
        thumb.strokeColor = UIColor(hex: "#83D6FF")
        thumb.lineWidth = 2
        thumb.zPosition = 2
        
        super.init()
        
        addChild(track)
        addChild(fill)
        addChild(thumb)
        
        updateVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateVisuals() {
        let clampedValue = max(0.0, min(1.0, value))
        let fillWidth = trackWidth * CGFloat(clampedValue)
        
        // Update fill width
        let fillRect = CGRect(x: -trackWidth/2, y: -trackHeight/2, width: fillWidth, height: trackHeight)
        fill.path = CGPath(roundedRect: fillRect, cornerWidth: 2, cornerHeight: 2, transform: nil)
        
        // Update thumb position (from -trackWidth/2 to +trackWidth/2)
        let thumbX = -trackWidth/2 + (fillWidth)
        thumb.position = CGPoint(x: thumbX, y: 0)
    }
    
    func updateValue(_ newValue: Float) {
        value = newValue
        updateVisuals()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Check if touch is on slider track or thumb
        let touchRect = CGRect(x: -trackWidth/2 - 10, y: -20, width: trackWidth + 20, height: 40)
        if touchRect.contains(location) {
            isDragging = true
            handleTouch(at: location)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTouch(at: location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
    }
    
    private func handleTouch(at location: CGPoint) {
        // Convert touch position to value (0.0 to 1.0)
        let relativeX = location.x + trackWidth/2
        let newValue = Float(max(0.0, min(1.0, relativeX / trackWidth)))
        
        value = newValue
        onValueChanged?(value)
    }
}

