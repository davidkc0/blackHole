//
//  PowerUpManager.swift
//  blackHole
//
//  Manages power-up spawning and lifecycle
//

import SpriteKit

class PowerUpManager {
    var activePowerUps: [PowerUp] = []
    var nextRainbowSpawn: TimeInterval = 0
    var nextFreezeSpawn: TimeInterval = 0
    var lastCollectionTime: TimeInterval = 0
    var gameStartTime: TimeInterval = 0
    
    let MAX_POWERUPS_ON_SCREEN = 1
    let COLLECTION_COOLDOWN: TimeInterval = 30.0
    let INITIAL_DELAY: TimeInterval = 10.0
    
    weak var scene: GameScene?
    
    init(gameStartTime: TimeInterval) {
        self.gameStartTime = gameStartTime
        scheduleNextSpawns(currentTime: gameStartTime)
    }
    
    func scheduleNextSpawns(currentTime: TimeInterval) {
        // Schedule next rainbow spawn with random interval
        let rainbowInterval = TimeInterval.random(in: PowerUpType.rainbow.baseSpawnInterval)
        nextRainbowSpawn = currentTime + rainbowInterval + INITIAL_DELAY
        
        // Schedule next freeze spawn with random interval
        let freezeInterval = TimeInterval.random(in: PowerUpType.freeze.baseSpawnInterval)
        nextFreezeSpawn = currentTime + freezeInterval + INITIAL_DELAY
        
        print("⏰ Next Rainbow spawn: \(String(format: "%.1f", rainbowInterval + INITIAL_DELAY))s")
        print("⏰ Next Freeze spawn: \(String(format: "%.1f", freezeInterval + INITIAL_DELAY))s")
    }
    
    func onPowerUpCollected(currentTime: TimeInterval) {
        // Record collection time for cooldown
        lastCollectionTime = currentTime
        
        // Delay next spawns
        let rainbowDelay = TimeInterval.random(in: PowerUpType.rainbow.baseSpawnInterval)
        let freezeDelay = TimeInterval.random(in: PowerUpType.freeze.baseSpawnInterval)
        
        nextRainbowSpawn = currentTime + COLLECTION_COOLDOWN + rainbowDelay
        nextFreezeSpawn = currentTime + COLLECTION_COOLDOWN + freezeDelay
        
        print("⏰ Collection cooldown: \(COLLECTION_COOLDOWN)s - Next spawns delayed")
    }
    
    func update(currentTime: TimeInterval) {
        // Don't spawn if we're in cooldown after collection
        if currentTime - lastCollectionTime < COLLECTION_COOLDOWN {
            return
        }
        
        // Don't spawn if max power-ups already on screen
        if activePowerUps.count >= MAX_POWERUPS_ON_SCREEN {
            return
        }
        
        // Check if it's time to spawn rainbow
        if currentTime >= nextRainbowSpawn {
            spawnPowerUp(type: .rainbow, currentTime: currentTime)
            // Schedule next rainbow with random interval
            let nextInterval = TimeInterval.random(in: PowerUpType.rainbow.baseSpawnInterval)
            nextRainbowSpawn = currentTime + nextInterval
        }
        
        // Check if it's time to spawn freeze
        if currentTime >= nextFreezeSpawn && activePowerUps.isEmpty {
            spawnPowerUp(type: .freeze, currentTime: currentTime)
            // Schedule next freeze with random interval
            let nextInterval = TimeInterval.random(in: PowerUpType.freeze.baseSpawnInterval)
            nextFreezeSpawn = currentTime + nextInterval
        }
    }
    
    func spawnPowerUp(type: PowerUpType, currentTime: TimeInterval) {
        guard let scene = scene else { return }
        
        // Don't spawn if max already on screen
        if activePowerUps.count >= MAX_POWERUPS_ON_SCREEN {
            return
        }
        
        // Random trajectory
        let trajectory = CometTrajectory.allCases.randomElement()!
        
        // Create power-up
        let powerUp = PowerUp(type: type, trajectory: trajectory)
        
        // Get start and end points relative to black hole
        let (start, end) = trajectory.getStartAndEnd(
            sceneSize: scene.size,
            blackHolePosition: scene.blackHole.position
        )
        powerUp.position = start
        
        // Calculate angle for trail direction
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        powerUp.updateTrailDirection(angle: angle)
        
        // Add to scene
        scene.addChild(powerUp)
        activePowerUps.append(powerUp)
        
        // Calculate duration based on distance
        let duration = calculateCometDuration(start: start, end: end)
        
        // Animate across screen
        let move = SKAction.move(to: end, duration: duration)
        let remove = SKAction.run { [weak self] in
            powerUp.removeFromParent()
            self?.activePowerUps.removeAll { $0 == powerUp }
        }
        
        powerUp.run(SKAction.sequence([move, remove]))
        
        print("🌠 Spawned \(type.displayName) comet - duration: \(String(format: "%.1f", duration))s")
    }
    
    func calculateCometDuration(start: CGPoint, end: CGPoint) -> TimeInterval {
        let distance = hypot(end.x - start.x, end.y - start.y)
        return TimeInterval(distance / GameConstants.cometSpeed)
    }
}

