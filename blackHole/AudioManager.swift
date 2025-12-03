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
    private var sfxPlayerNodes: [AVAudioPlayerNode] = []
    private var sfxMixerNode: AVAudioMixerNode?
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
    
    // Sound Effects (stored as AVAudioPCMBuffer and played via AVAudioEngine)
    private var sfxBuffers: [String: AVAudioPCMBuffer] = [:]
    private(set) var areSoundEffectsPreloaded = false
    
    // SFX playback via AVAudioEngine
    private let sfxPlayerPoolSize = 12
    private var nextSFXPlayerIndex: Int = 0
    
    // Proximity Sound Management (single loop player, nearest-only)
    private var proximityPlayerNode: AVAudioPlayerNode?
    private var isProximityActive = false
    private var proximityStartTime: TimeInterval = 0
    private let proximityMinPlayDuration: TimeInterval = 1 // Minimum 1s play time
    private var proximityPendingStopWorkItem: DispatchWorkItem?
    
    // Power-up Loop Sound Management
    private var powerUpLoopPlayerNode: AVAudioPlayerNode?
    
    // UI SFX Players
    private var buttonPressPlayer: AVAudioPlayer?
    
    // Volume and Mute State
    private var musicVolume: Float = 1.0
    private var soundVolume: Float = 1.0
    private var isMusicMuted = false
    private var isSoundMuted = false
    // Curated mix multipliers (soundtrack-forward balance)
    private var musicMix: Float = 1.0
    private var sfxMix: Float = 0.6
    
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
        "proximity": "proximity",
        "button_press": "button_press"
    ]
    
    private let menuMusicLoadLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        // Audio session is configured in AppDelegate at app launch
    }
    
    // MARK: - Menu Music Preloading
    
    /// Returns true if menu music buffers are loaded and ready
    var isMenuMusicReady: Bool {
        return !menuMusicBuffers.isEmpty
    }
    
    @discardableResult
    func preloadMenuMusic() -> Bool {
        menuMusicLoadLock.lock()
        defer { menuMusicLoadLock.unlock() }
        
        // ✅ Check if already loaded before clearing buffers
        if !menuMusicBuffers.isEmpty {
            print("ℹ️ AudioManager: Menu music already loaded (\(menuMusicBuffers.count) buffer(s)), skipping preload")
            return true
        }
        
        print("🎵 AudioManager: Preloading menu music (track: big_pad)...")
        menuMusicBuffers.removeAll()
        
        // Menu music uses only big_pad (single layer)
        let fileName = menuMusicFileNames[0] // "big_pad"
        
        // Try OGG first, then WAV
        var loadSucceeded = false
        
        if let buffer = loadAudioFile(fileName: fileName, extensions: ["ogg", "wav"]) {
            menuMusicBuffers.append(buffer)
            
            // Store loop duration
            let format = buffer.format
            let sampleRate = format.sampleRate
            let frameCount = Double(buffer.frameLength)
            loopDuration = frameCount / sampleRate
            print("✅ AudioManager: Menu music loaded, loop duration: \(String(format: "%.2f", loopDuration))s")
            loadSucceeded = true
        } else {
            print("⚠️ AudioManager: Failed to load menu music: \(fileName)")
        }
        
        if loadSucceeded && menuMusicBuffers.count == 1 {
            print("✅ AudioManager: Menu music loaded (single layer)")
            return true
        } else {
            menuMusicBuffers.removeAll()
            print("⚠️ AudioManager: Failed to load menu music")
            return false
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
    
    func preloadSoundEffects(forceReload: Bool = false) {
        if areSoundEffectsPreloaded && !forceReload {
            print("ℹ️ AudioManager: Sound effects already preloaded - skipping")
            return
        }
        
        print("🔊 AudioManager: Preloading sound effects...")
        sfxBuffers.removeAll()
        areSoundEffectsPreloaded = false
        
        for (key, fileName) in soundEffectFileNames {
            let extensions = ["wav", "mp3", "caf", "aiff", "m4a", "aac"]
            
            if let buffer = loadSFXBuffer(fileName: fileName, extensions: extensions) {
                sfxBuffers[key] = buffer
                print("✅ AudioManager: Sound effect '\(key)' loaded into buffer")
            } else {
                print("⚠️ AudioManager: Failed to load sound effect '\(key)': \(fileName)")
            }
        }
        
        areSoundEffectsPreloaded = !sfxBuffers.isEmpty
        print("✅ AudioManager: Loaded \(sfxBuffers.count)/\(soundEffectFileNames.count) sound effect buffers")
    }
    
    func prepareButtonPressSound() {
        guard buttonPressPlayer == nil else { return }
        let possibleExtensions = ["wav", "mp3", "caf", "aiff", "m4a", "aac"]
        var url: URL?
        for ext in possibleExtensions {
            if let bundleURL = Bundle.main.url(forResource: "button_press", withExtension: ext, subdirectory: "SFX") {
                url = bundleURL
                break
            } else if let bundleURL = Bundle.main.url(forResource: "button_press", withExtension: ext) {
                url = bundleURL
                break
            }
        }
        guard let finalURL = url else {
            print("⚠️ AudioManager: Could not locate button_press sound file")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: finalURL)
            player.numberOfLoops = 0
            player.volume = isSoundMuted ? 0.0 : soundVolume
            player.prepareToPlay()
            buttonPressPlayer = player
            print("✅ AudioManager: Button press sound prepared")
        } catch {
            print("⚠️ AudioManager: Failed to prepare button press sound: \(error)")
        }
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
        
        // Create music mixer node
        musicMixerNode = AVAudioMixerNode()
        guard let musicMixer = musicMixerNode else {
            print("❌ AudioManager: Failed to create music mixer node")
            return
        }
        engine.attach(musicMixer)
        
        // Create SFX mixer node
        sfxMixerNode = AVAudioMixerNode()
        guard let sfxMixer = sfxMixerNode else {
            print("❌ AudioManager: Failed to create SFX mixer node")
            return
        }
        engine.attach(sfxMixer)
        
        // Connect mixers to main output
        let mainMixer = engine.mainMixerNode
        engine.connect(musicMixer, to: mainMixer, format: nil)
        engine.connect(sfxMixer, to: mainMixer, format: nil)
        
        // Create music player nodes and connect to music mixer
        musicPlayerNodes.removeAll()
        for _ in 0..<5 {
            let playerNode = AVAudioPlayerNode()
            musicPlayerNodes.append(playerNode)
            engine.attach(playerNode)
            engine.connect(playerNode, to: musicMixer, format: nil)
        }
        
        // Create SFX player pool and connect to SFX mixer
        sfxPlayerNodes.removeAll()
        nextSFXPlayerIndex = 0
        for _ in 0..<sfxPlayerPoolSize {
            let playerNode = AVAudioPlayerNode()
            sfxPlayerNodes.append(playerNode)
            engine.attach(playerNode)
            engine.connect(playerNode, to: sfxMixer, format: nil)
        }
        
        // Create dedicated loop players for proximity and power-up
        let proximityPlayer = AVAudioPlayerNode()
        proximityPlayerNode = proximityPlayer
        engine.attach(proximityPlayer)
        engine.connect(proximityPlayer, to: sfxMixer, format: nil)
        
        let powerUpPlayer = AVAudioPlayerNode()
        powerUpLoopPlayerNode = powerUpPlayer
        engine.attach(powerUpPlayer)
        engine.connect(powerUpPlayer, to: sfxMixer, format: nil)
        
        // Initialize SFX mixer volume
        updateAllSFXNodeVolumes()
        
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
    
    private func ensureAudioEngineRunning() {
        if !isAudioEngineInitialized {
            initializeAudioEngine()
        }
        
        guard let engine = audioEngine else { return }
        
        if !engine.isRunning {
            do {
                try engine.start()
                print("✅ AudioManager: Audio engine started")
            } catch {
                print("❌ AudioManager: Failed to start audio engine: \(error)")
            }
        }
    }
    
    // MARK: - Background Music Playback
    
    func playBackgroundMusic() {
        // Initialize and start audio engine if not already running
        if !isAudioEngineInitialized {
            print("⚠️ AudioManager: Audio engine not initialized, initializing now...")
            initializeAudioEngine()
            if !isAudioEngineInitialized {
                print("❌ AudioManager: Cannot play music - engine initialization failed")
                return
            }
        }
        
        ensureAudioEngineRunning()
        
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
        
        guard let _ = audioEngine else {
            print("❌ AudioManager: Audio engine is nil")
            return
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
        let targetVolume = isMusicMuted ? 0.0 : (musicVolume * musicMix)
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
        guard ensureMenuMusicBuffersLoaded() else {
            print("❌ AudioManager: Menu music buffers unavailable - cannot switch to menu music")
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
                let targetVolume = isMusicMuted ? 0.0 : (musicVolume * musicMix)
                musicPlayerNodes[layerIndex].volume = targetVolume
                layerVolumes[layerIndex] = targetVolume
            }
        }
    }
    
    func setSoundVolume(_ volume: Float) {
        soundVolume = max(0.0, min(1.0, volume))
        
        // Update mute state based on volume
        isSoundMuted = (soundVolume == 0.0)
        updateAllSFXNodeVolumes()
        if let player = buttonPressPlayer {
            player.volume = isSoundMuted ? 0.0 : (soundVolume * sfxMix)
        }
        
        // SFX played via AVAudioEngine respect mixer volume automatically
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
            buttonPressPlayer?.stop()
        }
        
        updateAllSFXNodeVolumes()
        if let player = buttonPressPlayer {
            player.volume = muted ? 0.0 : (soundVolume * sfxMix)
        }
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
    
    func playButtonPressSound() {
        if buttonPressPlayer == nil {
            prepareButtonPressSound()
        }
        guard let player = buttonPressPlayer else { return }
        guard !isSoundMuted else { return }
        player.stop()
        player.currentTime = 0
        player.volume = soundVolume * sfxMix
        player.play()
    }
    
    // MARK: - Power-up Loop Sound
    
    func startPowerUpLoopSound(on scene: SKScene) {
        guard !isSoundMuted && soundVolume > 0.0 else { return }
        
        guard let buffer = sfxBuffers["powerup"] else {
            print("⚠️ AudioManager: Power-up loop buffer not loaded")
            return
        }
        
        ensureAudioEngineRunning()
        
        guard let player = powerUpLoopPlayerNode else {
            print("⚠️ AudioManager: Power-up loop player node not available")
            return
        }
        
        if player.isPlaying {
            return
        }
        
        player.stop()
        player.volume = 1.0
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        player.play()
        
        print("🔊 AudioManager: Power-up loop sound started (AVAudioEngine)")
    }
    
    func stopPowerUpLoopSound() {
        guard let player = powerUpLoopPlayerNode else { return }
        player.stop()
        print("🔊 AudioManager: Power-up loop sound stopped")
    }
    
    // MARK: - Proximity Sound
    
    func enableProximitySounds() {
        // Grace period removed — method retained for API compatibility
    }
    
    func startProximitySound(starID: String, distance: CGFloat, on scene: SKScene) {
        guard !isSoundMuted && soundVolume > 0.0 else {
            stopAllProximitySounds()
            return
        }
        
        // Cancel any pending stop FIRST (before early return)
        proximityPendingStopWorkItem?.cancel()
        proximityPendingStopWorkItem = nil
        
        // If already playing, don't restart (avoid per-frame spam)
        if isProximityActive, let player = proximityPlayerNode, player.isPlaying {
            return
        }
        
        guard let buffer = sfxBuffers["proximity"] else {
            print("⚠️ AudioManager: Proximity sound buffer not loaded")
            return
        }
        
        ensureAudioEngineRunning()
        
        if proximityPlayerNode == nil {
            guard let engine = audioEngine, let sfxMixer = sfxMixerNode else {
                print("⚠️ AudioManager: Audio engine or SFX mixer not available for proximity sound")
                return
            }
            let player = AVAudioPlayerNode()
            proximityPlayerNode = player
            engine.attach(player)
            engine.connect(player, to: sfxMixer, format: buffer.format)
        }
        
        guard let player = proximityPlayerNode else { return }
        
        player.stop()
        player.volume = 1.0
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        player.play()
        
        isProximityActive = true
        proximityStartTime = CACurrentMediaTime() // Record when it started
    }
    
    func stopProximitySound(starID: String) {
        stopAllProximitySounds()
    }
    
    func stopAllProximitySounds() {
        guard isProximityActive, let player = proximityPlayerNode else { 
            isProximityActive = false
            proximityPendingStopWorkItem?.cancel()
            proximityPendingStopWorkItem = nil
            return 
        }
        
        let elapsed = CACurrentMediaTime() - proximityStartTime
        
        // If minimum play time hasn't elapsed, schedule stop for later
        if elapsed < proximityMinPlayDuration {
            let remainingTime = proximityMinPlayDuration - elapsed
            
            // Cancel any existing pending stop
            proximityPendingStopWorkItem?.cancel()
            
            // Schedule stop after remaining time
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isProximityActive else { return }
                self.isProximityActive = false
                
                self.proximityPlayerNode?.stop()
                self.proximityPendingStopWorkItem = nil
            }
            
            proximityPendingStopWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime, execute: workItem)
            return
        }
        
        // Minimum time has elapsed, stop immediately
        isProximityActive = false
        
        // Cancel any pending stop
        proximityPendingStopWorkItem?.cancel()
        proximityPendingStopWorkItem = nil
        
        proximityPlayerNode?.stop()
    }
    
    private func playSoundEffect(_ key: String, on scene: SKScene, volumeMultiplier: Float = 1.0) {
        guard !isSoundMuted else { return }
        
        let clampedMultiplier = max(0.0, min(1.0, volumeMultiplier))
        guard let buffer = sfxBuffers[key] else {
            print("⚠️ AudioManager: SFX buffer for key '\(key)' not loaded")
            return
        }
        
        ensureAudioEngineRunning()
        
        guard let sfxMixer = sfxMixerNode, let engine = audioEngine else {
            print("❌ AudioManager: Audio engine or SFX mixer not available")
            return
        }
        
        if sfxPlayerNodes.isEmpty {
            // Fallback: lazily create a single SFX player if pool was not created
            let player = AVAudioPlayerNode()
            sfxPlayerNodes.append(player)
            engine.attach(player)
            engine.connect(player, to: sfxMixer, format: buffer.format)
        }
        
        let index = nextSFXPlayerIndex % sfxPlayerNodes.count
        nextSFXPlayerIndex = (nextSFXPlayerIndex + 1) % sfxPlayerNodes.count
        
        let playerNode = sfxPlayerNodes[index]
        playerNode.stop()
        playerNode.volume = clampedMultiplier
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        playerNode.play()
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
        
        let targetVolume = isMusicMuted ? 0.0 : (musicVolume * musicMix)
        
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
    
    private func updateAllSFXNodeVolumes() {
        let targetVolume = isSoundMuted ? 0.0 : (soundVolume * sfxMix)
        sfxMixerNode?.outputVolume = targetVolume
    }
    
    private func ensureMenuMusicBuffersLoaded() -> Bool {
        if menuMusicBuffers.isEmpty {
            print("ℹ️ AudioManager: Menu music buffers empty, attempting reload now...")
            let success = preloadMenuMusic()
            if !success {
                return false
            }
        }
        return !menuMusicBuffers.isEmpty
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
    
    private func loadSFXBuffer(fileName: String, extensions: [String]) -> AVAudioPCMBuffer? {
        for ext in extensions {
            var url: URL?
            
            // First try in SFX subdirectory
            url = Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "SFX")
            
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
                    print("⚠️ AudioManager: Failed to create SFX buffer for \(fileName).\(ext)")
                    continue
                }
                
                try audioFile.read(into: buffer)
                return buffer
            } catch {
                print("⚠️ AudioManager: Failed to load SFX \(fileName).\(ext): \(error)")
                continue
            }
        }
        
        return nil
    }
    
}
