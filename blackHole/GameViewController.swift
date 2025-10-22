//
//  GameViewController.swift
//  blackHole
//
//  Created by David Ciaffoni on 10/9/25.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Warm up haptic generators
        _ = HapticManager.shared
        
        if let view = self.view as! SKView? {
            // Create MENU scene instead of game scene
            let scene = MenuScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            
            // Present the scene
            view.presentScene(scene)
            
            view.ignoresSiblingOrder = true
            
            // Disable FPS/node count for menu (cleaner look)
            view.showsFPS = false
            view.showsNodeCount = false
        }

        // for family in UIFont.familyNames.sorted() {
        //     let names = UIFont.fontNames(forFamilyName: family)
        //     print("Family: \(family) Font names: \(names)")
        // }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
