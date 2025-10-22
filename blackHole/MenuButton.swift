//
//  MenuButton.swift
//  blackHole
//
//  Simple button that actually fucking works
//

import SpriteKit

class MenuButton: SKNode {
    
    enum ButtonSize {
        case large, medium, small
        
        var fontSize: CGFloat {
            switch self {
            case .large: return 32
            case .medium: return 24
            case .small: return 18
            }
        }
        
        var padding: CGSize {
            switch self {
            case .large: return CGSize(width: 120, height: 30)
            case .medium: return CGSize(width: 100, height: 25)
            case .small: return CGSize(width: 80, height: 20)
            }
        }
    }
    
    private let label: SKLabelNode
    private let background: SKShapeNode
    private let size: ButtonSize
    var onTap: (() -> Void)?
    
    var buttonSize: CGSize {
        return CGSize(
            width: label.frame.width + size.padding.width,
            height: label.frame.height + size.padding.height
        )
    }
    
    init(text: String, size: ButtonSize = .medium) {
        self.size = size
        
        // Create label
        self.label = SKLabelNode(fontNamed: "NDAstroneer-Bold")
        label.text = text
        label.fontSize = size.fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        
        // Create background
        let bgSize = CGSize(
            width: label.frame.width + size.padding.width,
            height: label.frame.height + size.padding.height
        )
        let bgRect = CGRect(x: -bgSize.width/2, y: -bgSize.height/2, 
                           width: bgSize.width, height: bgSize.height)
        
        self.background = SKShapeNode(rect: bgRect, cornerRadius: 8)
        background.fillColor = UIColor(white: 0.1, alpha: 0.8)
        background.strokeColor = UIColor(white: 0.5, alpha: 0.5)
        background.lineWidth = 2
        background.zPosition = 0
        
        super.init()
        
        self.name = "MenuButton_\(text)"
        
        addChild(background)
        addChild(label)
        
        print("🔘 Simple button '\(text)' created, size: \(bgSize)")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func contains(point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent!)
        return background.contains(localPoint)
    }
    
    func animatePress() {
        background.fillColor = UIColor(white: 0.2, alpha: 0.9)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.1)
        run(scaleDown)
    }
    
    func animateRelease() {
        background.fillColor = UIColor(white: 0.1, alpha: 0.8)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        run(scaleUp)
    }
}
