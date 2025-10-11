//
//  AudioManager.swift
//  blackHole
//
//  Manages game audio - sounds and music
//  Currently contains stub methods for future audio file integration
//

import AVFoundation
import SpriteKit

class AudioManager {
    static let shared = AudioManager()
    
    private init() {
        // TODO: Load audio files here when available
        // Example:
        // if let correctSoundURL = Bundle.main.url(forResource: "correct", withExtension: "wav") {
        //     correctSound = try? AVAudioPlayer(contentsOf: correctSoundURL)
        // }
    }
    
    // MARK: - Sound Effects
    
    func playCorrectSound() {
        // TODO: Play sound when correct colored star is eaten
        // correctSound?.play()
        print("🔊 Playing correct sound")
    }
    
    func playWrongSound() {
        // TODO: Play sound when wrong colored star is eaten
        // wrongSound?.play()
        print("🔊 Playing wrong sound")
    }
    
    func playGrowSound() {
        // TODO: Play sound when black hole grows
        // growSound?.play()
        print("🔊 Playing grow sound")
    }
    
    func playShrinkSound() {
        // TODO: Play sound when black hole shrinks
        // shrinkSound?.play()
        print("🔊 Playing shrink sound")
    }
    
    func playGameOverSound() {
        // TODO: Play sound when game ends
        // gameOverSound?.play()
        print("🔊 Playing game over sound")
    }
    
    func playPowerUpSound() {
        // TODO: Play sound when power-up is collected (for future features)
        // powerUpSound?.play()
        print("🔊 Playing power-up sound")
    }
    
    func playMergeSound() {
        // TODO: Play sound when stars merge
        // mergeSound?.play()
        print("🔊 Playing merge sound")
    }
    
    func playPowerUpCollectSound() {
        // TODO: Play sound when power-up is collected
        // powerUpCollectSound?.play()
        print("🔊 Playing power-up collect sound")
    }
    
    func playPowerUpExpireSound() {
        // TODO: Play sound when power-up expires
        // powerUpExpireSound?.play()
        print("🔊 Playing power-up expire sound")
    }
    
    // MARK: - Background Music
    
    func playBackgroundMusic() {
        // TODO: Start looping background music
        // backgroundMusic?.numberOfLoops = -1
        // backgroundMusic?.volume = 0.3
        // backgroundMusic?.play()
        print("🎵 Playing background music")
    }
    
    func stopBackgroundMusic() {
        // TODO: Stop background music
        // backgroundMusic?.stop()
        print("🎵 Stopping background music")
    }
    
    func setMusicVolume(_ volume: Float) {
        // TODO: Set music volume (0.0 to 1.0)
        // backgroundMusic?.volume = volume
    }
    
    func setSoundVolume(_ volume: Float) {
        // TODO: Set sound effects volume (0.0 to 1.0)
    }
}

