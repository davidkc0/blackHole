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
    
    // Pause when app goes to background
    @objc func applicationWillResignActive(notification: Notification) {
        if let skView = view as? SKView, let gameScene = skView.scene as? GameScene {
            gameScene.pauseGameFromBackground()
        }
    }
    
    // Resume when app comes to foreground
    @objc func applicationDidBecomeActive(notification: Notification) {
        if let skView = view as? SKView, let gameScene = skView.scene as? GameScene {
            gameScene.resumeGameFromForeground()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Observe app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive(notification:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(notification:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }
}
