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
    
    private let userDefaults = UserDefaults.standard
    
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
    }
    
    func updatePlayTime(seconds: TimeInterval) {
        totalPlayTime += seconds
        save()
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
}

