//
//  GameCenterManager.swift
//  Singularity
//
//  Game Center integration manager
//

import GameKit
import UIKit

class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    
    // MARK: - Properties
    
    private(set) var isAuthenticated = false
    private var loadedAchievements: [String: GKAchievement] = [:]
    
    // Background queue for Game Center operations
    private let gcQueue = DispatchQueue(label: "com.singularity.gamecenter", qos: .utility)
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Authentication
    
    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Game Center error: \(error.localizedDescription)")
                self.isAuthenticated = false
                return
            }
            
            if GKLocalPlayer.local.isAuthenticated {
                print("✅ Game Center authenticated: \(GKLocalPlayer.local.displayName ?? "Unknown")")
                self.isAuthenticated = true
                
                // Configure access point
                DispatchQueue.main.async {
                    GKAccessPoint.shared.location = .bottomTrailing
                    GKAccessPoint.shared.showHighlights = true
                    GKAccessPoint.shared.isActive = true
                }
                
                // Load achievements in background
                self.loadAchievements()
            } else {
                print("⚠️ Game Center not authenticated")
                self.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Access Point
    
    func showAccessPoint() {
        DispatchQueue.main.async {
            GKAccessPoint.shared.isActive = true
        }
    }
    
    func hideAccessPoint() {
        DispatchQueue.main.async {
            GKAccessPoint.shared.isActive = false
        }
    }
    
    // MARK: - Leaderboards
    
    func submitScore(_ score: Int, to leaderboardID: String) {
        guard isAuthenticated else { return }
        
        // Submit on background queue
        gcQueue.async {
            Task {
                do {
                    try await GKLeaderboard.submitScore(
                        score,
                        context: 0,
                        player: GKLocalPlayer.local,
                        leaderboardIDs: [leaderboardID]
                    )
                    print("✅ Score \(score) → \(leaderboardID)")
                } catch {
                    print("⚠️ Score submission failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Achievements
    
    private func loadAchievements() {
        gcQueue.async {
            Task {
                do {
                    let achievements = try await GKAchievement.loadAchievements()
                    for achievement in achievements {
                        self.loadedAchievements[achievement.identifier] = achievement
                    }
                    print("✅ Loaded \(achievements.count) achievements")
                } catch {
                    print("⚠️ Failed to load achievements: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func reportAchievement(identifier: String, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }
        
        // Check if already completed
        if let existing = loadedAchievements[identifier], existing.isCompleted {
            return
        }
        
        // Submit on background queue
        gcQueue.async {
            let achievement = GKAchievement(identifier: identifier)
            achievement.percentComplete = percentComplete
            achievement.showsCompletionBanner = true
            
            Task {
                do {
                    try await GKAchievement.report([achievement])
                    self.loadedAchievements[identifier] = achievement
                    print("✅ Achievement: \(identifier)")
                } catch {
                    print("⚠️ Achievement failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Debug
    
    #if DEBUG
    func resetAchievements() {
        gcQueue.async {
            Task {
                do {
                    try await GKAchievement.resetAchievements()
                    self.loadedAchievements.removeAll()
                    print("✅ Achievements reset")
                } catch {
                    print("❌ Reset failed: \(error.localizedDescription)")
                }
            }
        }
    }
    #endif
}

