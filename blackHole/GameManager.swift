//
//  GameManager.swift
//  blackHole
//
//  Manages game state, scoring, and persistence
//

import Foundation

class GameManager {
    static let shared = GameManager()
    
    private(set) var currentScore: Int = 0
    private(set) var highScore: Int = 0
    
    private let highScoreKey = "blackHole_highScore"
    
    private init() {
        loadHighScore()
    }
    
    func addScore(_ points: Int) {
        currentScore = max(0, currentScore + points)
        if currentScore > highScore {
            highScore = currentScore
            saveHighScore()
        }
    }
    
    func resetScore() {
        currentScore = 0
    }
    
    func getScoreMultiplier(blackHoleDiameter: CGFloat) -> Int {
        return max(1, Int(floor(blackHoleDiameter / 60)))
    }
    
    private func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: highScoreKey)
        UserDefaults.standard.synchronize()
    }
    
    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }
}

