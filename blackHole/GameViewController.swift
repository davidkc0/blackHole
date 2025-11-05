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
        
        // Set black background
        view.backgroundColor = .black
        if let skView = view as? SKView {
            skView.backgroundColor = .black
            skView.ignoresSiblingOrder = true
            skView.showsFPS = false
            skView.showsNodeCount = false
        }
        
        // Present LoadingScene IMMEDIATELY - don't wait for anything
        presentLoadingScene()
        
        // HapticManager will be initialized in GameLoadingScene when user taps Play
    }
    
    private func presentLoadingScene() {
        guard let skView = view as? SKView else { return }
        
        let scene = LoadingScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
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
