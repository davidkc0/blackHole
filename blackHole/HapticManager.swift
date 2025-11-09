//
//  HapticManager.swift
//  blackHole
//
//  Manages haptic feedback for gameplay events
//

import UIKit
import CoreHaptics

class HapticManager {
    static let shared = HapticManager()
    
    // Generators (pre-warmed for low latency)
    private var impactLight: UIImpactFeedbackGenerator?
    private var impactMedium: UIImpactFeedbackGenerator?
    private var impactHeavy: UIImpactFeedbackGenerator?
    private var notification: UINotificationFeedbackGenerator?
    
    // State tracking
    private let hapticsEnabledKey = "HapticManager.hapticsEnabled"
    private var isHapticsEnabled: Bool
    private var dangerousStarTimers: [String: Timer] = [:]
    private var lastDangerHapticTime: TimeInterval = 0
    private var generatorsPrepared = false
    
    private init() {
        if UserDefaults.standard.object(forKey: hapticsEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: hapticsEnabledKey)
        }
        isHapticsEnabled = UserDefaults.standard.bool(forKey: hapticsEnabledKey)
    }
    
    private func prepareGeneratorsIfNeeded() {
        guard !generatorsPrepared else { return }
        generatorsPrepared = true
        impactLight = UIImpactFeedbackGenerator(style: .light)
        impactMedium = UIImpactFeedbackGenerator(style: .medium)
        impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        notification = UINotificationFeedbackGenerator()
        
        // Pre-warm generators for low latency
        impactLight?.prepare()
        impactMedium?.prepare()
        impactHeavy?.prepare()
        notification?.prepare()
    }
    
    // MARK: - Event 1: Correct Star Absorption
    
    func playCorrectStarHaptic(starSize: CGFloat) {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        
        // Base success notification
        notification?.notificationOccurred(.success)
        notification?.prepare()
        
        // Add impact for large stars (extra satisfaction)
        if starSize >= 50 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.impactLight?.impactOccurred()
                self?.impactLight?.prepare()
            }
        }
    }
    
    // MARK: - Event 2: Wrong Star Absorption
    
    func playWrongStarHaptic(isInDangerZone: Bool) {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        
        // Base error notification
        notification?.notificationOccurred(.error)
        notification?.prepare()
        
        // Add warning if player is in danger zone
        if isInDangerZone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.notification?.notificationOccurred(.warning)
                self?.notification?.prepare()
            }
        }
    }
    
    // MARK: - Event 3: Dangerous Star Proximity
    
    func startDangerProximityHaptic(starID: String, distance: CGFloat) {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        
        // Cooldown check (prevent overlapping pulses)
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastDangerHapticTime > 0.2 else { return }
        
        // Calculate pulse interval based on edge distance (0 = touching surface)
        let clampedDistance = max(0, min(distance, GameConstants.starWarningEdgeDistance))
        let ratio = clampedDistance / GameConstants.starWarningEdgeDistance
        let pulseInterval = 0.15 + (0.85 * ratio) // Ranges from 0.15 (urgent) to ~1.0 (distant)
        
        // Cancel existing timer for this star
        dangerousStarTimers[starID]?.invalidate()
        
        // Create pulsing timer
        let timer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.impactMedium?.impactOccurred()
            self.impactMedium?.prepare()
            self.lastDangerHapticTime = CACurrentMediaTime()
        }
        
        dangerousStarTimers[starID] = timer
        
        // Trigger immediate haptic (don't wait for first interval)
        impactMedium?.impactOccurred()
        impactMedium?.prepare()
        lastDangerHapticTime = currentTime
    }
    
    func stopDangerProximityHaptic(starID: String) {
        dangerousStarTimers[starID]?.invalidate()
        dangerousStarTimers.removeValue(forKey: starID)
    }
    
    func stopAllDangerProximityHaptics() {
        for (_, timer) in dangerousStarTimers {
            timer.invalidate()
        }
        dangerousStarTimers.removeAll()
    }
    
    // MARK: - Event 4: Power-Up Collection
    
    func playPowerUpHaptic(type: PowerUpType) {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        
        // Success notification
        notification?.notificationOccurred(.success)
        notification?.prepare()
        
        // Delayed impact (creates double-tap feel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            
            switch type {
            case .rainbow:
                self.impactHeavy?.impactOccurred()  // Full power
                self.impactHeavy?.prepare()
            case .freeze:
                self.impactMedium?.impactOccurred() // Softer
                self.impactMedium?.prepare()
            }
        }
    }
    
    // MARK: - Settings
    
    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: hapticsEnabledKey)
        
        if !enabled {
            stopAllDangerProximityHaptics()
        }
    }
    
    func areHapticsEnabled() -> Bool {
        return isHapticsEnabled
    }
    
    func warmUpIfNeeded() {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
    }
    
    // MARK: - Tutorial Haptic Methods
    
    func playSelection() {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        impactLight?.impactOccurred()
    }
    
    func playSuccess() {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        notification?.notificationOccurred(.success)
    }
    
    func playError() {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        notification?.notificationOccurred(.error)
    }
    
    func playWarning() {
        guard isHapticsEnabled else { return }
        prepareGeneratorsIfNeeded()
        notification?.notificationOccurred(.warning)
    }
}

