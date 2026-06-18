//
//  GameStats.swift
//  blackHole
//
//  Statistics tracking manager
//

import Foundation

class GameStats {
    static let shared = GameStats()
    
    // MARK: - Properties
    
    var totalPlayTime: TimeInterval = 0
    var highScore: Int = 0
    var totalStarsAbsorbed: Int = 0
    var whiteDwarfsAbsorbed: Int = 0
    var yellowDwarfsAbsorbed: Int = 0
    var blueGiantsAbsorbed: Int = 0
    var orangeGiantsAbsorbed: Int = 0
    var redSupergiantsAbsorbed: Int = 0
    
    // Timed mode stats
    var timedGamesPlayed: Int = 0
    var timedHighScore: Int = 0
    var bestTimedStreak: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let timedFlawlessMinimumScore = 5000
    
    // MARK: - Initialization
    
    private init() {
        load()
    }
    
    // MARK: - Save/Load
    
    func save() {
        userDefaults.set(totalPlayTime, forKey: "totalPlayTime")
        userDefaults.set(highScore, forKey: "highScore")
        userDefaults.set(totalStarsAbsorbed, forKey: "totalStarsAbsorbed")
        userDefaults.set(whiteDwarfsAbsorbed, forKey: "whiteDwarfsAbsorbed")
        userDefaults.set(yellowDwarfsAbsorbed, forKey: "yellowDwarfsAbsorbed")
        userDefaults.set(blueGiantsAbsorbed, forKey: "blueGiantsAbsorbed")
        userDefaults.set(orangeGiantsAbsorbed, forKey: "orangeGiantsAbsorbed")
        userDefaults.set(redSupergiantsAbsorbed, forKey: "redSupergiantsAbsorbed")
        userDefaults.set(timedGamesPlayed, forKey: "timedGamesPlayed")
        userDefaults.set(timedHighScore, forKey: "timedHighScore")
        userDefaults.set(bestTimedStreak, forKey: "bestTimedStreak")
        
        submitToGameCenter()
    }
    
    func load() {
        totalPlayTime = userDefaults.double(forKey: "totalPlayTime")
        highScore = userDefaults.integer(forKey: "highScore")
        totalStarsAbsorbed = userDefaults.integer(forKey: "totalStarsAbsorbed")
        whiteDwarfsAbsorbed = userDefaults.integer(forKey: "whiteDwarfsAbsorbed")
        yellowDwarfsAbsorbed = userDefaults.integer(forKey: "yellowDwarfsAbsorbed")
        blueGiantsAbsorbed = userDefaults.integer(forKey: "blueGiantsAbsorbed")
        orangeGiantsAbsorbed = userDefaults.integer(forKey: "orangeGiantsAbsorbed")
        redSupergiantsAbsorbed = userDefaults.integer(forKey: "redSupergiantsAbsorbed")
        timedGamesPlayed = userDefaults.integer(forKey: "timedGamesPlayed")
        timedHighScore = userDefaults.integer(forKey: "timedHighScore")
        bestTimedStreak = userDefaults.integer(forKey: "bestTimedStreak")
    }
    
    // MARK: - Update Methods
    
    func incrementStarCount(type: StarType) {
        totalStarsAbsorbed += 1
        
        switch type {
        case .whiteDwarf:
            whiteDwarfsAbsorbed += 1
        case .yellowDwarf:
            yellowDwarfsAbsorbed += 1
        case .blueGiant:
            blueGiantsAbsorbed += 1
        case .orangeGiant:
            orangeGiantsAbsorbed += 1
        case .redSupergiant:
            redSupergiantsAbsorbed += 1
        }
        
        save()
        checkAchievements()
    }
    
    func updatePlayTime(seconds: TimeInterval) {
        totalPlayTime += seconds
        save()
        checkAchievements()
    }
    
    func updateHighScore(score: Int) {
        if score > highScore {
            highScore = score
            save()
        }
    }
    
    // MARK: - Formatters
    
    func formatPlayTime() -> String {
        let hours = Int(totalPlayTime) / 3600
        let minutes = (Int(totalPlayTime) % 3600) / 60
        let seconds = Int(totalPlayTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Game Center
    
    private func submitToGameCenter() {
        GameCenterManager.shared.submitScore(
            totalStarsAbsorbed,
            to: GameCenterConstants.totalStarsLeaderboardID
        )
        
        let playtimeSeconds = Int(totalPlayTime)
        GameCenterManager.shared.submitScore(
            playtimeSeconds,
            to: GameCenterConstants.longestPlaytimeLeaderboardID
        )
    }
    
    func submitStoredLeaderboardStatsToGameCenter() {
        submitToGameCenter()
        
        if timedHighScore > 0 {
            GameCenterManager.shared.submitScore(
                timedHighScore,
                to: GameCenterConstants.timedHighScoreLeaderboardID
            )
        }
    }
    
    func checkAchievements() {
        // Star collection
        if totalStarsAbsorbed >= 100 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement100Stars
            )
        }
        if totalStarsAbsorbed >= 1000 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement1000Stars
            )
        }
        if totalStarsAbsorbed >= 10000 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement10000Stars
            )
        }
        
        // Star types
        if whiteDwarfsAbsorbed >= 100 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement100WhiteDwarfs
            )
        }
        if blueGiantsAbsorbed >= 100 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement100BlueGiants
            )
        }
        if redSupergiantsAbsorbed >= 1 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementRedGiant
            )
        }
        
        // Playtime
        if totalPlayTime >= 3600 {  // 1 hour
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement1HourPlaytime
            )
        }
        if totalPlayTime >= 36000 {  // 10 hours
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievement10HoursPlaytime
            )
        }
    }
    
    // MARK: - Timed Mode
    
    func recordTimedGame(score: Int, bestStreak: Int, penalties: Int) {
        timedGamesPlayed += 1
        if score > timedHighScore {
            timedHighScore = score
            GameCenterManager.shared.submitScore(
                timedHighScore,
                to: GameCenterConstants.timedHighScoreLeaderboardID
            )
        }
        if bestStreak > bestTimedStreak {
            bestTimedStreak = bestStreak
        }
        save()
        checkTimedAchievements(score: score, bestStreak: bestStreak, penalties: penalties)
    }
    
    private func checkTimedAchievements(score: Int, bestStreak: Int, penalties: Int) {
        // First timed game
        GameCenterManager.shared.reportAchievement(
            identifier: GameCenterConstants.achievementTimedFirst
        )
        
        // Score milestones
        if score >= 5000 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedScore5000
            )
        }
        if score >= 15000 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedScore15000
            )
        }
        if score >= 25000 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedScore25000
            )
        }
        
        // Streak
        if bestStreak >= 10 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedStreak10
            )
        }
        if bestStreak >= 20 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedStreak20
            )
        }
        
        // Flawless (no penalties)
        if penalties == 0 && score >= timedFlawlessMinimumScore {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedNoPenalty
            )
        }
        
        // Timed mode repeat play
        if timedGamesPlayed >= 10 {
            GameCenterManager.shared.reportAchievement(
                identifier: GameCenterConstants.achievementTimedGames10
            )
        }
    }
}
