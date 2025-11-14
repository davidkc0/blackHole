//
//  AudioManager.swift
//  blackHole
//
//  Manages game audio - sounds and music
//  Supports 5-layer synchronized looping soundtrack and sound effects
//

import AVFoundation
import SpriteKit

class AudioManager {
    static let shared = AudioManager()
    
    // MARK: - Properties
    
    // Audio Engine
    private var audioEngine: AVAudioEngine?
    private var musicPlayerNodes: [AVAudioPlayerNode] = []
    private var musicMixerNode: AVAudioMixerNode?
    var isAudioEngineInitialized = false
    
    // Music Buffers
    private var menuMusicBuffers: [AVAudioPCMBuffer] = []
    private var gameMusicBuffers: [AVAudioPCMBuffer] = []
    private var currentMusicBuffers: [AVAudioPCMBuffer] = [] // Currently active buffers (menu or game)
    private var loopDuration: TimeInterval = 0.0
    
    // Layer Management
    private var activeLayers: Set<Int> = []
    private var masterPlaybackPosition: TimeInterval = 0.0
    private var playbackTimer: Timer?
    private var isPlaying = false
    private var layerVolumes: [Int: Float] = [:]
    private var currentBlackHoleSize: CGFloat = 0.0 // Track current size for phase-based volume control
    
    // Sound Effects (stored as file paths for SKAction.playSoundFileNamed)
    private var soundEffectFilePaths: [String: String] = [:]
    
    // Proximity Sound Management
    private var proximitySoundTimers: [String: Timer] = [:]
    private var lastProximitySoundTime: TimeInterval = 0
    private var proximitySoundScenes: [String: SKScene] = [:] // Store scene reference for each proximity sound
    private var proximitySoundDistances: [String: CGFloat] = [:] // Track distance per star to optimize updates
    private var proximitySoundNodes: [String: SKNode] = [:] // Store node for each proximity sound (for volume control)
    private var proximitySoundEnabledTime: TimeInterval? // Time when proximity sounds become enabled
    
    // Power-up Loop Sound Management
    private var powerUpLoopNode: SKNode?
    private var powerUpLoopScene: SKScene?
    
    // Volume and Mute State
    private var musicVolume: Float = 1.0
    private var soundVolume: Float = 1.0
    private var isMusicMuted = false
    private var isSoundMuted = false
    
    // File Names (to be configured)
    // Menu music uses single track big_pad.wav (located in Music folder)
    private let menuMusicFileNames = [
        "big_pad"
    ]
    private let gameMusicFileNames = [
        "game_music_layer1", "game_music_layer2", "game_music_layer3",
        "game_music_layer4", "game_music_layer5"
    ]
    private let soundEffectFileNames: [String: String] = [
        "correct": "correct",
        "wrong": "wrong",
        "grow": "grow",
        "shrink": "shrink",
        "gameover": "gameover",
        "powerup": "powerup",
        "merge": "merge",
        "powerup_collect": "powerup_collect",
        "powerup_expire": "powerup_expire",
        "proximity": "proximity"
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Audio session is configured in AppDelegate at app launch
    }
    
    // MARK: - Menu Music Preloading
    
    func preloadMenuMusic() {
        print("🎵 AudioManager: Preloading menu music (track: big_pad)...")
        menuMusicBuffers.removeAll()
        
        // Menu music uses only big_pad (single layer)
        let fileName = menuMusicFileNames[0] // "big_pad"
        
        // Try OGG first, then WAV
        if let buffer = loadAudioFile(fileName: fileName, extensions: ["ogg", "wav"]) {
            menuMusicBuffers.append(buffer)
            
            // Store loop duration
            let format = buffer.format
            let sampleRate = format.sampleRate
            let frameCount = Double(buffer.frameLength)
            loopDuration = frameCount / sampleRate
            print("✅ AudioManager: Menu music loaded (game_music_layer5), loop duration: \(String(format: "%.2f", loopDuration))s")
        } else {
            print("⚠️ AudioManager: Failed to load menu music: \(fileName)")
        }
        
        if menuMusicBuffers.count == 1 {
            print("✅ AudioManager: Menu music loaded (single layer)")
        } else {
            print("⚠️ AudioManager: Failed to load menu music")
        }
    }
    
    // MARK: - Game Music Preloading
    
    func preloadGameMusic() {
        print("🎵 AudioManager: Preloading game music...")
        gameMusicBuffers.removeAll()
        
        // Check if game music files exist, otherwise reuse menu music
        // Check Music folder first, then root directory
        let testFileName = gameMusicFileNames[0]
        var hasGameMusic = Bundle.main.url(forResource: testFileName, withExtension: "ogg", subdirectory: "Music") != nil ||
                          Bundle.main.url(forResource: testFileName, withExtension: "wav", subdirectory: "Music") != nil
        
        if !hasGameMusic {
            hasGameMusic = Bundle.main.url(forResource: testFileName, withExtension: "ogg") != nil ||
                          Bundle.main.url(forResource: testFileName, withExtension: "wav") != nil
        }
        
        if !hasGameMusic {
            print("ℹ️ AudioManager: Game music files not found, reusing menu music")
            gameMusicBuffers = menuMusicBuffers
            return
        }
        
        for (index, fileName) in gameMusicFileNames.enumerated() {
            if let buffer = loadAudioFile(fileName: fileName, extensions: ["ogg", "wav"]) {
                gameMusicBuffers.append(buffer)
                
                if index == 0 {
                    let format = buffer.format
                    let sampleRate = format.sampleRate
                    let frameCount = Double(buffer.frameLength)
                    loopDuration = frameCount / sampleRate
                    print("✅ AudioManager: Game music layer \(index + 1) loaded, loop duration: \(String(format: "%.2f", loopDuration))s")
                }
            } else {
                print("⚠️ AudioManager: Failed to load game music layer \(index + 1): \(fileName)")
            }
        }
        
        if gameMusicBuffers.count == 5 {
            print("✅ AudioManager: All 5 game music layers loaded")
        } else {
            print("⚠️ AudioManager: Only \(gameMusicBuffers.count)/5 game music layers loaded, reusing menu music")
            gameMusicBuffers = menuMusicBuffers
        }
    }
    
    // MARK: - Sound Effects Preloading
    
    func preloadSoundEffects() {
        print("🔊 AudioManager: Preloading sound effects...")
        soundEffectFilePaths.removeAll()
        
        for (key, fileName) in soundEffectFileNames {
            let extensions = ["wav", "mp3", "caf", "aiff", "m4a", "aac"]
            var filePath: String?
            
            for ext in extensions {
                // Try SFX folder first
                if Bundle.main.path(forResource: fileName, ofType: ext, inDirectory: "SFX") != nil {
                    filePath = "SFX/\(fileName).\(ext)"
                    break
                }
                // Try root
                if Bundle.main.path(forResource: fileName, ofType: ext) != nil {
                    filePath = "\(fileName).\(ext)"
                    break
                }
            }
            
            if let path = filePath {
                soundEffectFilePaths[key] = path
                print("✅ AudioManager: Sound effect '\(key)' found: \(path)")
            } else {
                print("⚠️ AudioManager: Failed to find sound effect '\(key)': \(fileName)")
            }
        }
        
        print("✅ AudioManager: Loaded \(soundEffectFilePaths.count)/10 sound effect paths")
    }
    
    /// Preloads sound effects by loading them into memory (silently)
    /// This helps prevent stutter on first use, but doesn't fully warm SpriteKit's cache
    /// Note: SKAction.playSoundFileNamed can't be muted, so we load files into memory instead
    func preloadSoundEffectsIntoCache(on scene: SKScene) {
        print("🔊 AudioManager: Preloading sound effects into memory...")
        
        // Load each sound file into memory using AVAudioPlayer (silent load, no playback)
        // This preloads the files into iOS audio cache without audible playback
        var preloadedCount = 0
        let totalSounds = soundEffectFilePaths.count
        
        guard totalSounds > 0 else {
            return
        }
        
        for (key, filePath) in soundEffectFilePaths {
            // File path can be "fileName.ext" or "SFX/fileName.ext"
            let pathComponents = filePath.components(separatedBy: "/")
            let fileNameWithExt = pathComponents.last ?? filePath
            let subdirectory = pathComponents.count > 1 ? pathComponents.first : nil
            
            let fileName = (fileNameWithExt as NSString).deletingPathExtension
            let fileExtension = (fileNameWithExt as NSString).pathExtension
            
            // Try to load the file as an AVAudioPlayer (silent load)
            var url: URL?
            if let subdir = subdirectory {
                url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdir)
            } else {
                url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
            }
            
            if let fileURL = url {
                do {
                    // Create AVAudioPlayer but don't play - just loads file into memory
                    let player = try AVAudioPlayer(contentsOf: fileURL)
                    _ = player  // Keep reference briefly to ensure file is loaded
                    preloadedCount += 1
                } catch {
                    print("⚠️ AudioManager: Failed to preload sound '\(key)': \(error)")
                }
            } else {
                print("⚠️ AudioManager: Could not find URL for sound '\(key)': \(filePath)")
            }
        }
        
        print("✅ AudioManager: Preloaded \(preloadedCount)/\(totalSounds) sound effects into memory")
        print("ℹ️ Note: SpriteKit cache will still warm on first actual playback, but files are in memory")
    }
    
    // MARK: - Audio Engine Initialization
    
    func initializeAudioEngine() {
        guard !isAudioEngineInitialized else {
            print("ℹ️ AudioManager: Audio engine already initialized")
            return
        }
        
        print("🎵 AudioManager: Initializing audio engine...")
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            print("❌ AudioManager: Failed to create audio engine")
            return
        }
        
        // Create 5 player nodes
        musicPlayerNodes.removeAll()
        for i in 0..<5 {
            let playerNode = AVAudioPlayerNode()
            musicPlayerNodes.append(playerNode)
            engine.attach(playerNode)
        }
        
        // Create mixer node
        musicMixerNode = AVAudioMixerNode()
        guard let mixer = musicMixerNode else {
            print("❌ AudioManager: Failed to create mixer node")
            return
        }
        engine.attach(mixer)
        
        // Connect player nodes to mixer
        for playerNode in musicPlayerNodes {
            engine.connect(playerNode, to: mixer, format: nil)
        }
        
        // Connect mixer to main output
        let mainMixer = engine.mainMixerNode
        engine.connect(mixer, to: mainMixer, format: nil)
        
        // Prepare engine
        do {
            try engine.prepare()
            isAudioEngineInitialized = true
            print("✅ AudioManager: Audio engine initialized and prepared")
        } catch {
            print("❌ AudioManager: Failed to prepare audio engine: \(error)")
        }
    }
    
    // MARK: - Background Music Playback
    
    func playBackgroundMusic() {
        // Initialize audio engine if not already initialized
        if !isAudioEngineInitialized {
            print("⚠️ AudioManager: Audio engine not initialized, initializing now...")
            initializeAudioEngine()
            if !isAudioEngineInitialized {
                print("❌ AudioManager: Cannot play music - engine initialization failed")
                return
            }
        }
        
        // Use menu music by default (can be switched to game music later)
        if currentMusicBuffers.isEmpty {
            currentMusicBuffers = menuMusicBuffers
        }
        
        // Menu music has 1 layer, game music has 5 layers
        let isMenuMusic = currentMusicBuffers.count == 1
        let expectedLayerCount = isMenuMusic ? 1 : 5
        
        guard !currentMusicBuffers.isEmpty, currentMusicBuffers.count == expectedLayerCount else {
            print("⚠️ AudioManager: Music buffers not loaded (expected \(expectedLayerCount), got \(currentMusicBuffers.count))")
            return
        }
        
        guard let engine = audioEngine else {
            print("❌ AudioManager: Audio engine is nil")
            return
        }
        
        // Start engine if not running
        if !engine.isRunning {
            do {
                try engine.start()
                print("✅ AudioManager: Audio engine started")
            } catch {
                print("❌ AudioManager: Failed to start audio engine: \(error)")
                return
            }
        }
        
        // Activate layers starting from position 0:00
        masterPlaybackPosition = 0.0
        activeLayers.removeAll()
        
        // Menu music: activate only layer 0 (single layer)
        // Game music: activate all 5 layers, but mute layers 2-5 initially (unmute based on size phases)
        if isMenuMusic {
            activateLayer(0, startFromBeginning: true)
            print("🎵 AudioManager: Menu music started (single layer)")
        } else {
            // Start all 5 layers playing, but only unmute layer 1 initially
            print("🎵 AudioManager: Game music starting - activating all 5 layers (synced playback, progressive unmuting)")
            for i in 0..<5 {
                activateLayer(i, startFromBeginning: true)
                // Mute layers 2-5 initially (layer 1 is already unmuted by activateLayer)
                if i > 0 {
                    let playerNode = musicPlayerNodes[i]
                    playerNode.volume = 0.0
                    layerVolumes[i] = 0.0
                }
            }
            print("🎵 AudioManager: Game music started (all 5 layers active, layer 1 unmuted, layers 2-5 muted)")
        }
        
        // Start playback timer
        startPlaybackTimer()
        
        isPlaying = true
        print("🎵 AudioManager: Background music started")
    }
    
    func stopBackgroundMusic() {
        guard isPlaying else { return }
        
        // Stop all player nodes
        for playerNode in musicPlayerNodes {
            playerNode.stop()
        }
        
        // Stop playback timer
        stopPlaybackTimer()
        
        // Clear active layers
        activeLayers.removeAll()
        
        // Reset position
        masterPlaybackPosition = 0.0
        
        isPlaying = false
        print("🎵 AudioManager: Background music stopped")
    }
    
    // MARK: - Layer Activation/Deactivation
    
    func activateLayer(_ layerIndex: Int, startFromBeginning: Bool = false) {
        // Menu music has 1 layer (index 0), game music has 5 layers (indices 0-4)
        let maxLayerIndex = currentMusicBuffers.count - 1
        guard layerIndex >= 0 && layerIndex <= maxLayerIndex else {
            print("⚠️ AudioManager: Invalid layer index: \(layerIndex) (max: \(maxLayerIndex))")
            return
        }
        
        guard !activeLayers.contains(layerIndex) else {
            print("ℹ️ AudioManager: Layer \(layerIndex) is already active")
            return
        }
        
        guard layerIndex < musicPlayerNodes.count && layerIndex < currentMusicBuffers.count else {
            print("⚠️ AudioManager: Layer \(layerIndex) buffer or node not available")
            return
        }
        
        let playerNode = musicPlayerNodes[layerIndex]
        let buffer = currentMusicBuffers[layerIndex]
        
        // Calculate start position
        let startPosition: TimeInterval
        if startFromBeginning || !isPlaying {
            startPosition = 0.0
        } else {
            // Start at current master position
            startPosition = masterPlaybackPosition
        }
        
        // Calculate start frame
        let format = buffer.format
        let sampleRate = format.sampleRate
        let startFrame = AVAudioFramePosition(startPosition * sampleRate)
        let totalFrames = Int64(buffer.frameLength)
        
        // Schedule from current position to end
        if startFrame > 0 && startFrame < totalFrames {
            let framesToPlay = totalFrames - startFrame
            
            // Create a sub-buffer for the remainder of the current loop
            // Copy the portion from startFrame to end into a new buffer
            guard let subBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(framesToPlay)) else {
                // If sub-buffer creation fails, fall back to full buffer
                scheduleLayerLoop(layerIndex)
                return
            }
            
            // Copy the audio data from the original buffer starting at startFrame
            let sourceChannelCount = Int(format.channelCount)
            let destChannelCount = Int(subBuffer.format.channelCount)
            
            for channel in 0..<min(sourceChannelCount, destChannelCount) {
                guard let sourceChannel = buffer.floatChannelData?[channel],
                      let destChannel = subBuffer.floatChannelData?[channel] else {
                    continue
                }
                
                let sourceOffset = Int(startFrame)
                let frameCount = Int(framesToPlay)
                let sourcePtr = sourceChannel.advanced(by: sourceOffset)
                
                // Copy frames
                destChannel.initialize(from: sourcePtr, count: frameCount)
            }
            
            subBuffer.frameLength = AVAudioFrameCount(framesToPlay)
            
            // Schedule the remainder segment
            playerNode.scheduleBuffer(subBuffer, at: nil, options: [], completionHandler: { [weak self] in
                // After current segment completes, schedule full loop
                self?.scheduleLayerLoop(layerIndex)
            })
        } else {
            // Start from beginning (startFrame <= 0) or past end, schedule full loop
            scheduleLayerLoop(layerIndex)
        }
        
        // Set initial volume
        let targetVolume = isMusicMuted ? 0.0 : musicVolume
        layerVolumes[layerIndex] = targetVolume
        playerNode.volume = targetVolume
        
        // Play the node
        if !playerNode.isPlaying {
            playerNode.play()
        }
        
        // Add to active layers
        activeLayers.insert(layerIndex)
        
        print("✅ MUSIC LAYER: Layer \(layerIndex + 1)/\(currentMusicBuffers.count) activated at position \(String(format: "%.2f", startPosition))s (Total active: \(activeLayers.count)/\(currentMusicBuffers.count))")
    }
    
    func deactivateLayer(_ layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < 5 else {
            print("⚠️ AudioManager: Invalid layer index: \(layerIndex)")
            return
        }
        
        guard activeLayers.contains(layerIndex) else {
            return
        }
        
        let playerNode = musicPlayerNodes[layerIndex]
        playerNode.stop()
        activeLayers.remove(layerIndex)
        layerVolumes.removeValue(forKey: layerIndex)
        
        print("✅ AudioManager: Layer \(layerIndex) deactivated")
    }
    
    private func scheduleLayerLoop(_ layerIndex: Int) {
        guard layerIndex < musicPlayerNodes.count && layerIndex < currentMusicBuffers.count else {
            return
        }
        
        let playerNode = musicPlayerNodes[layerIndex]
        let buffer = currentMusicBuffers[layerIndex]
        
        // Schedule full buffer with looping
        // Note: Each layer loops independently, but they should stay in sync
        // because they all started at the same relative position
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    // Switch to game music (if different from menu music)
    func switchToGameMusic() {
        guard !gameMusicBuffers.isEmpty else {
            print("⚠️ AudioManager: Game music buffers not loaded")
            return
        }
        
        let wasPlaying = isPlaying
        
        // Stop current playback
        if wasPlaying {
            stopBackgroundMusic()
        }
        
        // Switch buffers
        currentMusicBuffers = gameMusicBuffers
        
        // Update loop duration
        if let firstBuffer = gameMusicBuffers.first {
            let format = firstBuffer.format
            let sampleRate = format.sampleRate
            let frameCount = Double(firstBuffer.frameLength)
            loopDuration = frameCount / sampleRate
        }
        
        // Always start game music when switching (game should have music playing)
        playBackgroundMusic()
        
        print("✅ AudioManager: Switched to game music")
    }
    
    // Switch to menu music
    func switchToMenuMusic() {
        guard !menuMusicBuffers.isEmpty else {
            print("⚠️ AudioManager: Menu music buffers not loaded")
            return
        }
        
        let wasPlaying = isPlaying
        
        // Stop current playback
        if wasPlaying {
            stopBackgroundMusic()
        }
        
        // Switch buffers
        currentMusicBuffers = menuMusicBuffers
        
        // Update loop duration
        if let firstBuffer = menuMusicBuffers.first {
            let format = firstBuffer.format
            let sampleRate = format.sampleRate
            let frameCount = Double(firstBuffer.frameLength)
            loopDuration = frameCount / sampleRate
        }
        
        // Restart if was playing
        if wasPlaying {
            playBackgroundMusic()
        }
        
        print("✅ AudioManager: Switched to menu music")
    }
    
    // MARK: - Playback Timer
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackPosition()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackPosition() {
        guard isPlaying, let engine = audioEngine, engine.isRunning else {
            return
        }
        
        // Get position from first active layer (master)
        guard let firstActiveLayer = activeLayers.sorted().first,
              firstActiveLayer < musicPlayerNodes.count else {
            return
        }
        
        let playerNode = musicPlayerNodes[firstActiveLayer]
        
        guard let lastRenderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) else {
            return
        }
        
        let format = currentMusicBuffers[firstActiveLayer].format
        let sampleRate = format.sampleRate
        let currentPosition = Double(playerTime.sampleTime) / sampleRate
        
        // Handle looping
        if currentPosition >= loopDuration {
            // Reset to beginning of loop
            masterPlaybackPosition = currentPosition.truncatingRemainder(dividingBy: loopDuration)
        } else {
            masterPlaybackPosition = currentPosition
        }
    }
    
    // MARK: - Volume Control
    
    func setMusicVolume(_ volume: Float) {
        musicVolume = max(0.0, min(1.0, volume))
        
        // Update mute state based on volume
        isMusicMuted = (musicVolume == 0.0)
        
        // Update layers based on current phase (respect phase-based muting)
        let isGameMusic = currentMusicBuffers.count == 5
        if isGameMusic && isPlaying {
            // For game music, use phase-based volume
            updateMusicLayersForSize(currentBlackHoleSize)
        } else {
            // For menu music, update all active layers
            for layerIndex in activeLayers {
                let targetVolume = isMusicMuted ? 0.0 : musicVolume
                musicPlayerNodes[layerIndex].volume = targetVolume
                layerVolumes[layerIndex] = targetVolume
            }
        }
    }
    
    func setSoundVolume(_ volume: Float) {
        soundVolume = max(0.0, min(1.0, volume))
        
        // Update mute state based on volume
        isSoundMuted = (soundVolume == 0.0)
        
        // Note: SKAction.playSoundFileNamed() respects volume settings automatically
        // No need to update individual players since we're using SpriteKit actions
    }
    
    // MARK: - Mute Control
    
    func setMusicMuted(_ muted: Bool) {
        isMusicMuted = muted
        
        // Update layers based on current phase (respect phase-based muting)
        let isGameMusic = currentMusicBuffers.count == 5
        if isGameMusic && isPlaying {
            // For game music, use phase-based volume
            updateMusicLayersForSize(currentBlackHoleSize)
        } else {
            // For menu music, update all active layers
            for layerIndex in activeLayers {
                let targetVolume = muted ? 0.0 : (layerVolumes[layerIndex] ?? musicVolume)
                musicPlayerNodes[layerIndex].volume = targetVolume
                if !muted {
                    layerVolumes[layerIndex] = targetVolume
                }
            }
        }
    }
    
    func setSoundMuted(_ muted: Bool) {
        isSoundMuted = muted
        
        // Stop proximity sounds if muted
        if muted {
            stopAllProximitySounds()
        }
        
        // Note: SKAction.playSoundFileNamed() respects mute state via isSoundMuted flag
        // Each play method checks isSoundMuted before playing
    }
    
    // MARK: - Sound Effects
    
    func playCorrectSound(on scene: SKScene) {
        playSoundEffect("correct", on: scene)
    }
    
    func playWrongSound(on scene: SKScene) {
        playSoundEffect("wrong", on: scene)
    }
    
    func playGrowSound(on scene: SKScene) {
        playSoundEffect("grow", on: scene)
    }
    
    func playShrinkSound(on scene: SKScene) {
        playSoundEffect("shrink", on: scene)
    }
    
    func playGameOverSound(on scene: SKScene) {
        playSoundEffect("gameover", on: scene)
    }
    
    func playPowerUpSound(on scene: SKScene) {
        playSoundEffect("powerup", on: scene)
    }
    
    func playMergeSound(on scene: SKScene) {
        playSoundEffect("merge", on: scene)
    }
    
    func playPowerUpCollectSound(on scene: SKScene) {
        playSoundEffect("powerup_collect", on: scene)
    }
    
    func playPowerUpExpireSound(on scene: SKScene) {
        playSoundEffect("powerup_expire", on: scene)
    }
    
    // MARK: - Power-up Loop Sound
    
    func startPowerUpLoopSound(on scene: SKScene) {
        guard !isSoundMuted && soundVolume > 0.0 else {
            return
        }
        
        guard let filePath = soundEffectFilePaths["powerup"] else {
            print("⚠️ AudioManager: Power-up loop sound file not found")
            return
        }
        
        // Stop any existing loop
        stopPowerUpLoopSound()
        
        powerUpLoopScene = scene
        
        // Create a node for the loop sound
        let loopNode = SKNode()
        loopNode.isHidden = true
        scene.addChild(loopNode)
        powerUpLoopNode = loopNode
        
        // Play sound in a loop (using repeatForever)
        let soundAction = SKAction.playSoundFileNamed(filePath, waitForCompletion: true)
        let loop = SKAction.repeatForever(soundAction)
        loopNode.run(loop)
        
        print("🔊 AudioManager: Power-up loop sound started")
    }
    
    func stopPowerUpLoopSound() {
        // Stop all actions first (this will stop the loop)
        powerUpLoopNode?.removeAllActions()
        
        // Wait a frame to ensure actions are stopped before removing node
        // Remove node synchronously from the scene to prevent sound from continuing
        if let node = powerUpLoopNode, let scene = powerUpLoopScene {
            // Remove from scene immediately to stop playback
            node.removeFromParent()
            
            // Clear references
            powerUpLoopNode = nil
            powerUpLoopScene = nil
            
            print("🔊 AudioManager: Power-up loop sound stopped")
        } else {
            // Clear references even if node/scene are nil
            powerUpLoopNode = nil
            powerUpLoopScene = nil
        }
    }
    
    // MARK: - Proximity Sound
    
    /// Enables proximity sounds after a grace period from game start
    func enableProximitySounds() {
        proximitySoundEnabledTime = CACurrentMediaTime()
        print("🔊 AudioManager: Proximity sounds enabled (5 second grace period active)")
    }
    
    func startProximitySound(starID: String, distance: CGFloat, on scene: SKScene) {
        // Check if proximity sounds are enabled (5 second grace period after game start)
        if let enabledTime = proximitySoundEnabledTime {
            let currentTime = CACurrentMediaTime()
            let gracePeriod: TimeInterval = 5.0
            if currentTime - enabledTime < gracePeriod {
                return
            }
        } else {
            return
        }
        
        guard !isSoundMuted && soundVolume > 0.0 else {
            stopProximitySound(starID: starID)
            return
        }
        
        guard let filePath = soundEffectFilePaths["proximity"] else {
            return
        }
        
        // Store scene reference and distance
        proximitySoundScenes[starID] = scene
        proximitySoundDistances[starID] = distance
        
        // Calculate pulse interval based on distance (same as haptics)
        // Use same calculation as haptics for consistency
        let maxDistance: CGFloat = 80.0
        let clampedDistance = max(0, min(distance, maxDistance))
        let ratio = clampedDistance / maxDistance
        let pulseInterval = 0.15 + (0.85 * Double(ratio))
        
        // ALWAYS stop existing timer first - trust game logic to tell us when to start/stop
        // The game logic in checkStarProximity() already handles when to call start/stop
        stopProximitySound(starID: starID)
        
        // Create a node for this proximity sound
        let soundNode = SKNode()
        soundNode.isHidden = true
        scene.addChild(soundNode)
        proximitySoundNodes[starID] = soundNode
        
        // Create pulsing timer
        let timer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] timer in
            guard let self = self, !self.isSoundMuted && self.soundVolume > 0.0 else {
                timer.invalidate()
                self?.stopProximitySound(starID: starID)
                return
            }
            
            // Check if sound node still exists
            guard let soundNode = self.proximitySoundNodes[starID], soundNode.parent != nil else {
                timer.invalidate()
                self.stopProximitySound(starID: starID)
                return
            }
            
            // Play sound - volume is controlled globally, proximity perception via pulse frequency
            let soundAction = SKAction.playSoundFileNamed(filePath, waitForCompletion: false)
            soundNode.run(soundAction)
        }
        
        proximitySoundTimers[starID] = timer
        
        // Play immediate sound (don't wait for first interval)
        let currentTime = CACurrentMediaTime()
        if currentTime - lastProximitySoundTime > 0.2 {
            if let soundNode = proximitySoundNodes[starID] {
                let soundAction = SKAction.playSoundFileNamed(filePath, waitForCompletion: false)
                soundNode.run(soundAction)
                lastProximitySoundTime = currentTime
            }
        }
    }
    
    func stopProximitySound(starID: String) {
        // Stop timer first
        proximitySoundTimers[starID]?.invalidate()
        proximitySoundTimers.removeValue(forKey: starID)
        
        // Stop all actions on the sound node before removing
        if let soundNode = proximitySoundNodes[starID] {
            soundNode.removeAllActions()
            soundNode.removeFromParent()
        }
        
        // Clean up all references
        proximitySoundDistances.removeValue(forKey: starID)
        proximitySoundScenes.removeValue(forKey: starID)
        proximitySoundNodes.removeValue(forKey: starID)
    }
    
    func stopAllProximitySounds() {
        // Stop all timers first
        for (_, timer) in proximitySoundTimers {
            timer.invalidate()
        }
        proximitySoundTimers.removeAll()
        
        // Stop all actions and remove all nodes
        for (_, node) in proximitySoundNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        proximitySoundNodes.removeAll()
        
        // Clean up all references
        proximitySoundDistances.removeAll()
        proximitySoundScenes.removeAll()
    }
    
    private func playSoundEffect(_ key: String, on scene: SKScene) {
        guard !isSoundMuted && soundVolume > 0.0 else {
            return
        }
        
        guard let filePath = soundEffectFilePaths[key] else {
            return
        }
        
        // Use SKAction.playSoundFileNamed for non-blocking audio playback
        let soundAction = SKAction.playSoundFileNamed(filePath, waitForCompletion: false)
        scene.run(soundAction) // Run on the provided scene
    }
    
    // MARK: - Size-Based Layer Management
    
    /// Updates music layer volumes based on black hole size (matches star spawning phases)
    /// All layers play from start, but are unmuted progressively based on size
    /// Phase 1: <48pt → Layer 1 unmuted
    /// Phase 2: 48-80pt → Layers 1-2 unmuted
    /// Phase 3: 80-140pt → Layers 1-3 unmuted
    /// Phase 4: 140-320pt → Layers 1-4 unmuted
    /// Phase 5: 320pt+ → All 5 layers unmuted
    func updateMusicLayersForSize(_ blackHoleDiameter: CGFloat) {
        let isGameMusic = currentMusicBuffers.count == 5
        guard isGameMusic else {
            print("🎵 DEBUG: updateMusicLayersForSize called but not game music (buffer count: \(currentMusicBuffers.count))")
            return // Only for game music
        }
        guard isPlaying else {
            print("🎵 DEBUG: updateMusicLayersForSize called but music not playing")
            return // Only if music is playing
        }
        
        // Update tracked size
        currentBlackHoleSize = blackHoleDiameter
        
        let size = blackHoleDiameter
        
        // Determine which phase we're in (matches star spawning phases)
        let targetPhase: Int
        if size < 48 {
            targetPhase = 1  // Layer 1 only
        } else if size < 80 {
            targetPhase = 2  // Layers 1-2
        } else if size < 140 {
            targetPhase = 3  // Layers 1-3
        } else if size < 320 {
            targetPhase = 4  // Layers 1-4
        } else {
            targetPhase = 5  // All layers
        }
        
        let targetVolume = isMusicMuted ? 0.0 : musicVolume
        
        print("🎵 DEBUG: updateMusicLayersForSize - size: \(String(format: "%.1f", size))pt, phase: \(targetPhase), targetVolume: \(targetVolume), isMusicMuted: \(isMusicMuted), musicVolume: \(musicVolume)")
        
        // Update each layer's volume based on phase
        for layerIndex in 0..<5 {
            let shouldBeUnmuted = (layerIndex + 1) <= targetPhase
            let newVolume = shouldBeUnmuted ? targetVolume : 0.0
            
            // Only update if volume changed
            let currentVolume = layerVolumes[layerIndex] ?? 0.0
            let volumeDiff = abs(currentVolume - newVolume)
            
            print("🎵 DEBUG: Layer \(layerIndex + 1)/5 - shouldBeUnmuted: \(shouldBeUnmuted), currentVolume: \(String(format: "%.3f", currentVolume)), newVolume: \(String(format: "%.3f", newVolume)), diff: \(String(format: "%.3f", volumeDiff))")
            
            if volumeDiff > 0.01 {
                let playerNode = musicPlayerNodes[layerIndex]
                playerNode.volume = newVolume
                layerVolumes[layerIndex] = newVolume
                
                if shouldBeUnmuted && currentVolume == 0.0 {
                    // Layer was just unmuted
                    print("🎵 MUSIC LAYER: Phase \(targetPhase) (\(String(format: "%.0f", size))pt) - unmuting layer \(layerIndex + 1)/5")
                } else if !shouldBeUnmuted && currentVolume > 0.0 {
                    print("🎵 MUSIC LAYER: Phase \(targetPhase) (\(String(format: "%.0f", size))pt) - muting layer \(layerIndex + 1)/5")
                } else {
                    print("🎵 MUSIC LAYER: Phase \(targetPhase) (\(String(format: "%.0f", size))pt) - updating layer \(layerIndex + 1)/5 volume from \(String(format: "%.3f", currentVolume)) to \(String(format: "%.3f", newVolume))")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAudioFile(fileName: String, extensions: [String]) -> AVAudioPCMBuffer? {
        for ext in extensions {
            var url: URL?
            
            // First try in Music subdirectory
            url = Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "Music")
            
            // If not found, try root directory
            if url == nil {
                url = Bundle.main.url(forResource: fileName, withExtension: ext)
            }
            
            guard let fileURL = url else {
                continue
            }
            
            do {
                let audioFile = try AVAudioFile(forReading: fileURL)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    print("⚠️ AudioManager: Failed to create buffer for \(fileName).\(ext)")
                    continue
                }
                
                try audioFile.read(into: buffer)
                return buffer
            } catch {
                print("⚠️ AudioManager: Failed to load \(fileName).\(ext): \(error)")
                continue
            }
        }
        
        return nil
    }
    
    // Note: loadSoundEffect() method removed - we now store file paths instead of AVAudioPlayer instances
    // Sound effects are played using SKAction.playSoundFileNamed() which handles file loading automatically
    
}
