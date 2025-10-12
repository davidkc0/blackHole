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
        let baseMultiplier = Int(floor(blackHoleDiameter / 60))
        
        // Milestone bonuses for reaching massive sizes
        var bonusMultiplier = 0
        
        if blackHoleDiameter >= 600 {
            bonusMultiplier += 5      // "Supermassive" tier
        }
        if blackHoleDiameter >= 1000 {
            bonusMultiplier += 10     // "Cosmic" tier
        }
        if blackHoleDiameter >= 2000 {
            bonusMultiplier += 20     // "Legendary" tier
        }
        
        return max(1, baseMultiplier + bonusMultiplier)
    }
    
    private func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: highScoreKey)
        UserDefaults.standard.synchronize()
    }
    
    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }
}

