//
//  IconButton.swift
//  blackHole
//
//  Square icon button with double-border design
//

import SpriteKit

class IconButton: SKNode {
    
    private let background: SKShapeNode
    private let outerBorder: SKShapeNode
    private let icon: SKSpriteNode
    var onTap: (() -> Void)?
    
    init(iconName: String, size: CGFloat = 40, cornerRadius: CGFloat = 5) {
        // Create icon sprite
        let iconTexture = SKTexture(imageNamed: iconName)
        iconTexture.filteringMode = .nearest  // Crisp vector edges
        self.icon = SKSpriteNode(texture: iconTexture)
        icon.size = CGSize(width: 20, height: 20)
        icon.color = .white
        icon.colorBlendFactor = 1.0
        icon.zPosition = 2
        
        // Create background square
        let bgRect = CGRect(x: -size/2, y: -size/2, width: size, height: size)
        self.background = SKShapeNode(rect: bgRect, cornerRadius: cornerRadius)
        background.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.24)
        background.strokeColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.5)
        background.lineWidth = 3
        background.zPosition = 1
        
        // Create outer border with 6pt margin
        let margin: CGFloat = 6
        let outerRect = CGRect(
            x: -size/2 - margin,
            y: -size/2 - margin,
            width: size + (margin * 2),
            height: size + (margin * 2)
        )
        
        self.outerBorder = SKShapeNode(rect: outerRect, cornerRadius: cornerRadius + margin)
        outerBorder.fillColor = .clear
        outerBorder.strokeColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.5)
        outerBorder.lineWidth = 1.5
        outerBorder.zPosition = 0
        
        super.init()
        
        self.name = "IconButton_\(iconName)"
        
        // Add in order: outer border first, then button, then icon
        addChild(outerBorder)
        addChild(background)
        addChild(icon)
        
        print("🔘 Icon button '\(iconName)' created, size: \(size)pt")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func contains(point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent!)
        return background.contains(localPoint)
    }
    
    func animatePress() {
        background.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.35)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.1)
        run(scaleDown)
    }
    
    func animateRelease() {
        background.fillColor = UIColor(hex: "#83D6FF").withAlphaComponent(0.24)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        run(scaleUp)
    }
}
