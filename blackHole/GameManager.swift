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
    private(set) var timedHighScore: Int = 0
    
    /// The mode currently being played — set by GameScene on didMove
    var activeGameMode: GameMode = .normal
    
    // Ad counter properties
    private(set) var gamesPlayedSinceLastAd: Int = 0
    private let showAdEveryNGames: Int = 2  // Show ad every 2nd game
    
    private let highScoreKey = "blackHole_highScore"
    private let timedHighScoreKey = "blackHole_timedHighScore"
    
    /// Whether timed mode is unlocked (requires 500 score in normal mode)
    var isTimedModeUnlocked: Bool {
        return highScore >= TimedModeConstants.unlockScoreThreshold
    }
    
    private init() {
        loadHighScore()
    }
    
    func addScore(_ points: Int) {
        currentScore = max(0, currentScore + points)
        
        if activeGameMode == .timed {
            // Timed mode: track timed high score separately
            if currentScore > timedHighScore {
                timedHighScore = currentScore
                saveTimedHighScore()
                
                GameCenterManager.shared.submitScore(
                    timedHighScore,
                    to: GameCenterConstants.timedHighScoreLeaderboardID
                )
            }
        } else {
            // Normal mode: track normal high score
            if currentScore > highScore {
                highScore = currentScore
                saveHighScore()
                
                GameCenterManager.shared.submitScore(
                    highScore,
                    to: GameCenterConstants.highScoreLeaderboardID
                )
            }
        }
    }
    
    func resetScore() {
        currentScore = 0
    }
    
    func submitStoredHighScoresToGameCenter() {
        if highScore > 0 {
            GameCenterManager.shared.submitScore(
                highScore,
                to: GameCenterConstants.highScoreLeaderboardID
            )
        }
        
        if timedHighScore > 0 {
            GameCenterManager.shared.submitScore(
                timedHighScore,
                to: GameCenterConstants.timedHighScoreLeaderboardID
            )
        }
    }
    
    func incrementGameOverCount() {
        gamesPlayedSinceLastAd += 1
    }
    
    func shouldShowAd() -> Bool {
        // Don't show ads if user has purchased Remove Ads
        if IAPManager.shared.checkPurchaseStatus() {
            return false
        }
        
        // Show ad every 3rd game (or 2nd, change showAdEveryNGames to 2)
        return gamesPlayedSinceLastAd >= showAdEveryNGames
    }
    
    func resetAdCounter() {
        gamesPlayedSinceLastAd = 0
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
    
    private func saveTimedHighScore() {
        UserDefaults.standard.set(timedHighScore, forKey: timedHighScoreKey)
        UserDefaults.standard.synchronize()
    }
    
    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
        timedHighScore = UserDefaults.standard.integer(forKey: timedHighScoreKey)
    }
}
