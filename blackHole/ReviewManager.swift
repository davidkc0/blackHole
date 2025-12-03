//
//  ReviewManager.swift
//  blackHole
//
//  Manages App Store review prompts
//  IMPORTANT: iOS only allows ~3 prompts per year per app, so we must be conservative
//

import Foundation
import StoreKit

class ReviewManager {
    static let shared = ReviewManager()
    
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults keys
    private let totalGamesPlayedKey = "review_totalGamesPlayed"
    private let reviewRequestCountKey = "review_requestCount"  // Track how many times we've requested
    private let lastReviewRequestDateKey = "review_lastRequestDate"
    private let lastReviewRequestGameKey = "review_lastRequestGame"  // Which game number we requested on
    private let sessionGamesPlayedKey = "review_sessionGamesPlayed"
    private let sessionStartTimeKey = "review_sessionStartTime"
    private let userDeclinedReviewKey = "review_userDeclined"  // Track if user might have declined
    
    // ============================================
    // FULL CONDITIONS FOR SHOWING REVIEW PROMPT
    // ============================================
    
    // BASE REQUIREMENT (ALL must be met):
    // 1. Total games played >= 6
    // 2. Game number is ODD (not even - avoid ad conflicts)
    // 3. At least 7 days since last review request (conservative cooldown)
    // 4. We haven't requested more than 2 times in the past 365 days (conservative limit)
    
    // POSITIVE INDICATORS (at least ONE must be met):
    // A. Current game score >= 1,000 points
    //    OR
    // B. Total play time >= 10 minutes
    //    OR
    // C. Played 3+ games in current session (active engagement)
    //    OR
    // D. Reached a new high score in this game
    
    // EXCLUSIONS (will NOT show if):
    // - Game number is even (ads show after games 2, 4, 6, etc.)
    // - Already requested 2+ times in past year
    // - Less than 7 days since last request
    // - User has purchased Remove Ads (optional - might want to show to paying users too)
    
    // Configuration constants
    private let minTotalGames = 6
    private let minScoreMilestone = 1000
    private let minTotalPlayTime: TimeInterval = 10 * 60 // 10 minutes
    private let minSessionGames = 3
    
    // Conservative limits (since iOS only allows ~3 per year)
    private let maxRequestsPerYear = 2  // Be conservative - only request 2 times per year
    private let minDaysBetweenRequests = 7  // Wait at least 7 days between requests
    private let cooldownPeriodDays = 90  // Extended cooldown after decline (if we could detect it)
    
    private init() {
        // Track session start time
        if userDefaults.object(forKey: sessionStartTimeKey) == nil {
            userDefaults.set(Date(), forKey: sessionStartTimeKey)
        }
    }
    
    // MARK: - Public Methods
    
    /// Call this when a game ends
    func recordGameFinished(score: Int, playTime: TimeInterval, isNewHighScore: Bool) {
        // Increment total games
        let totalGames = userDefaults.integer(forKey: totalGamesPlayedKey) + 1
        userDefaults.set(totalGames, forKey: totalGamesPlayedKey)
        
        // Increment session games
        let sessionGames = userDefaults.integer(forKey: sessionGamesPlayedKey) + 1
        userDefaults.set(sessionGames, forKey: sessionGamesPlayedKey)
        
        // Check if we should request review
        checkAndRequestReview(
            score: score,
            totalPlayTime: GameStats.shared.totalPlayTime + playTime,
            totalGames: totalGames,
            sessionGames: sessionGames,
            isNewHighScore: isNewHighScore
        )
    }
    
    /// Call this when starting a new game session
    func startNewSession() {
        userDefaults.set(0, forKey: sessionGamesPlayedKey)
        userDefaults.set(Date(), forKey: sessionStartTimeKey)
    }
    
    // MARK: - Private Methods
    
    private func checkAndRequestReview(
        score: Int,
        totalPlayTime: TimeInterval,
        totalGames: Int,
        sessionGames: Int,
        isNewHighScore: Bool
    ) {
        print("⭐ ReviewManager: Checking review conditions...")
        print("   - Total games: \(totalGames)")
        print("   - Current score: \(score)")
        print("   - Total play time: \(Int(totalPlayTime / 60)) minutes")
        print("   - Session games: \(sessionGames)")
        print("   - New high score: \(isNewHighScore)")
        
        // ============================================
        // BASE REQUIREMENT CHECKS
        // ============================================
        
        // 1. Must have played at least minTotalGames
        guard totalGames >= minTotalGames else {
            print("   ❌ Not enough games played (\(totalGames) < \(minTotalGames))")
            return
        }
        
        // 2. CRITICAL: Don't show after even-numbered games (ads show after games 2, 4, 6, etc.)
        if totalGames % 2 == 0 {
            print("   ❌ Skipping - game \(totalGames) is even (ad shown)")
            return
        }
        
        // 3. Check if we've exceeded our conservative request limit
        let requestCount = userDefaults.integer(forKey: reviewRequestCountKey)
        if requestCount >= maxRequestsPerYear {
            // Check if oldest request was more than 365 days ago (reset counter)
            if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestDateKey) as? Date {
                let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
                if daysSinceLastRequest < 365 {
                    print("   ❌ Already requested \(requestCount) times (max: \(maxRequestsPerYear) per year)")
                    return
                } else {
                    // Reset counter after 365 days
                    print("   ✅ Resetting request counter (365+ days since last request)")
                    userDefaults.set(0, forKey: reviewRequestCountKey)
                }
            } else {
                print("   ❌ Request count limit reached")
                return
            }
        }
        
        // 4. Check cooldown period (minimum days between requests)
        if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestDateKey) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
            if daysSinceLastRequest < minDaysBetweenRequests {
                print("   ❌ Too soon since last request (\(daysSinceLastRequest) days < \(minDaysBetweenRequests) days)")
                return
            }
        }
        
        // ============================================
        // POSITIVE INDICATOR CHECKS
        // At least ONE must be true
        // ============================================
        
        let reachedScoreMilestone = score >= minScoreMilestone
        let hasEnoughPlayTime = totalPlayTime >= minTotalPlayTime
        let hasActiveSession = sessionGames >= minSessionGames
        
        print("   - Score milestone: \(reachedScoreMilestone) (score: \(score) >= \(minScoreMilestone))")
        print("   - Play time: \(hasEnoughPlayTime) (\(Int(totalPlayTime / 60)) min >= \(Int(minTotalPlayTime / 60)) min)")
        print("   - Active session: \(hasActiveSession) (\(sessionGames) games >= \(minSessionGames))")
        print("   - New high score: \(isNewHighScore)")
        
        // Check if at least one positive indicator is met
        let hasPositiveIndicator = reachedScoreMilestone || hasEnoughPlayTime || hasActiveSession || isNewHighScore
        
        guard hasPositiveIndicator else {
            print("   ❌ No positive engagement indicators met")
            return
        }
        
        // ============================================
        // ALL CONDITIONS MET - REQUEST REVIEW
        // ============================================
        
        print("   ✅ ALL CONDITIONS MET - Requesting review")
        requestReview(totalGames: totalGames)
    }
    
    private func requestReview(totalGames: Int) {
        // Only request on main thread
        DispatchQueue.main.async {
            // Request review (iOS will decide whether to show it)
            // NOTE: iOS may not show it even if we request (rate limiting, user settings, etc.)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                
                // IMPORTANT: Track that we've made a request
                // We can't know if user tapped "Not Now" vs "Rate" vs dismissed,
                // so we track every request and use conservative cooldowns
                
                let requestCount = self.userDefaults.integer(forKey: self.reviewRequestCountKey) + 1
                self.userDefaults.set(requestCount, forKey: self.reviewRequestCountKey)
                self.userDefaults.set(Date(), forKey: self.lastReviewRequestDateKey)
                self.userDefaults.set(totalGames, forKey: self.lastReviewRequestGameKey)
                
                print("⭐ ReviewManager: Requested App Store review")
                print("   - Request #\(requestCount) of \(self.maxRequestsPerYear) per year")
                print("   - After game #\(totalGames)")
                print("   - Date: \(Date())")
                
                // NOTE: We can't detect "Not Now" - iOS handles it automatically
                // iOS will rate-limit to ~3 prompts per year regardless
                // Our conservative tracking (2 requests/year, 7-day cooldown) helps avoid wasting attempts
            }
        }
    }
    
    // MARK: - Debug/Info Methods
    
    /// Get current review request status (for debugging)
    func getReviewStatus() -> (totalGames: Int, requestCount: Int, daysSinceLastRequest: Int?, lastRequestGame: Int?) {
        let totalGames = userDefaults.integer(forKey: totalGamesPlayedKey)
        let requestCount = userDefaults.integer(forKey: reviewRequestCountKey)
        let lastRequestGame = userDefaults.integer(forKey: lastReviewRequestGameKey)
        
        var daysSinceLastRequest: Int? = nil
        if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestDateKey) as? Date {
            daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day
        }
        
        return (totalGames, requestCount, daysSinceLastRequest, lastRequestGame == 0 ? nil : lastRequestGame)
    }
}

