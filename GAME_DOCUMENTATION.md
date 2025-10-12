# Black Hole Mobile Game - Technical Documentation
**Current State: MVP + Enhanced Features**  
**Last Updated: October 2025**  
**Platform:** iOS (SpriteKit/Swift)

---

## Table of Contents
1. [Game Overview](#game-overview)
2. [Architecture](#architecture)
3. [Core Systems](#core-systems)
4. [Star Classification System](#star-classification-system)
5. [Physics & Gravity](#physics--gravity)
6. [Power-Up System](#power-up-system)
7. [Star Merging System](#star-merging-system)
8. [Visual Design](#visual-design)
9. [Game Progression](#game-progression)
10. [File Structure](#file-structure)

---

## Game Overview

A 2D mobile game for iOS where players control a black hole that grows by consuming matching-colored stars in an infinite procedurally-generated space environment.

### Technical Stack
- **Language:** Swift 5.9+
- **Framework:** SpriteKit
- **Target:** iOS 15.0+
- **Orientation:** Portrait only
- **Architecture:** Scene-based with programmatic scene creation

### Core Gameplay Loop
1. Player drags finger to move black hole anywhere in infinite world
2. Stars spawn continuously around player position (every 0.6 seconds)
3. Black hole's colored particle ring shows current target color
4. Eat stars matching the target color to grow (+15% size)
5. Eat wrong color stars to shrink (-20% size)
6. Avoid eating stars larger than the black hole (instant game over)
7. Game ends when black hole shrinks to minimum size (30pt) or eats oversized star

### Win Conditions
There is no "win" - the game is endless survival with high score tracking.

**Score Targets:**
- 1,000 points: Good run
- 5,000 points: Great run
- 10,000+ points: Exceptional run

---

## Architecture

### Scene Structure
```
GameScene (Primary gameplay scene, created programmatically)
├── Camera System (SKCameraNode, follows black hole with lerp)
│   └── HUD Node (UI elements attached to camera)
│       ├── Score Label (top-left)
│       ├── Power-Up Indicator (top-right)
│       └── Game Over Screen (center, when triggered)
├── World Layer (infinite world coordinates)
│   ├── Background Stars (100 twinkling stars, repositioning parallax)
│   ├── Black Hole (player-controlled, at world origin initially)
│   ├── Game Stars (physics-enabled, up to 30 active)
│   └── Power-Up Comets (2 types, max 1 on screen at a time)
└── Physics World (zero gravity, contact-based collision detection)
```

### Key Design Decisions

**Why Infinite World?**
- No artificial boundaries
- Natural exploration feel
- Camera follows player smoothly
- Stars spawn relative to player position

**Why Programmatic Scene Creation?**
- Removed GameScene.sks template (caused "Hello World" issues)
- Full control over initialization
- Clean scene setup
- Better for dynamic systems

**Why Portrait Orientation?**
- Mobile-friendly one-handed play
- Better for drag-based controls
- Configured in `GameViewController.supportedInterfaceOrientations`

---

## Core Systems

### 1. Infinite World with Camera System

**Implementation Details:**

**Camera (SKCameraNode):**
- Follows black hole with smooth lerp interpolation
- Lerp factor: 0.15 (15% of distance per frame)
- Never instant - always smooth motion
- Position updated every frame in `update()`

**World Coordinates:**
- Black hole starts at (0, 0) in world space
- Can move anywhere - no boundaries
- Touch positions converted to world coordinates automatically
- Stars spawn relative to black hole position

**HUD Attachment:**
- Score, power-up indicator attached to camera
- Positions relative to camera center
- Always visible regardless of black hole position
- Game over screen also camera-attached

**Background Stars (Parallax):**
- 100 static stars created at game start
- Spread across 2000pt × 2000pt initial area
- When star >1500pt from camera: repositioned to opposite side
- Creates infinite starfield without memory growth
- Twinkling animation: random fade cycles (1-3s)

### 2. Touch-Based Movement

**Implementation:**
```swift
touchesBegan / touchesMoved:
    location = touch.location(in: self)  // World coordinates
    blackHole.position = location
```

**Behavior:**
- Immediate response (no acceleration)
- Works anywhere on screen
- No lag or delay
- Position set directly (not physics-based movement)

**Game Over Touch:**
- When `isGameOver = true`
- Any tap anywhere restarts game
- Creates new GameScene instance
- Fades to new scene (0.5s transition)

### 3. Collision Detection System

**Physics Categories (Bitmasks):**
```swift
blackHoleCategory: 0x1 << 0 (binary: 001)
starCategory:      0x1 << 1 (binary: 010)
powerUpCategory:   0x1 << 2 (binary: 100)
```

**Contact Detection Priority (in `didBegin`):**
```swift
1. Power-up + Black Hole → collectPowerUp()
2. Star + Star → handleStarMerge() [if merging enabled]
3. Star + Black Hole → handleStarCollision()
```

**Collision Flow:**
```swift
func didBegin(_ contact: SKPhysicsContact) {
    if power-up collision:
        collect it, activate effect, show particles
        return
    
    if star-star collision AND merging enabled:
        check 7 safeguards
        if all pass: merge stars
        return
    
    if star-blackhole collision:
        check size (too large = game over)
        check color match (or rainbow active)
        grow or shrink accordingly
        show particles, update score
        remove star
}
```

---

## Star Classification System

### Current Implementation: 5 Stellar Types

Loosely based on actual stellar classification, prioritizing gameplay over strict scientific accuracy.

| Type | Size Range (pt) | Hex Color | Base Points | Mass Mult | Glow Radius |
|------|----------------|-----------|-------------|-----------|-------------|
| **White Dwarf** | 18-28 | #F0F0F0 | 50 | 0.3x | 5pt |
| **Yellow Dwarf** | 32-42 | #FFD700 | 100 | 1.0x | 6pt |
| **Blue Giant** | 45-58 | #4DA6FF | 200 | 8.0x | 8pt |
| **Orange Giant** | 90-140 | #FF8C42 | 400 | 2.5x | 10pt |
| **Red Supergiant** | 180-400 | #DC143C | 1000 | 15.0x | 15pt |

### Size-Based Gameplay Mechanics

**Critical Rule:** Player can ONLY eat stars smaller than their black hole diameter

**Size Check (First Priority):**
```swift
if star.size.width >= blackHole.currentDiameter {
    gameOver(reason: "Black hole destabilized!")
    return
}
```

**Color Check (Second Priority):**
```swift
if star.starType == blackHole.targetType OR rainbowPowerUpActive {
    grow()
    addPoints()
} else {
    shrink()
    losePoints()
}
```

### Warning System

**Red Pulsing Glow:**
- Appears when dangerous star within 300pt of black hole
- Conditional: `!blackHole.canConsume(star) AND distance < 300`
- Visual: Red ring with glowWidth=8, pulsing alpha (0.3 ↔ 0.9)
- Updated every frame in `checkStarProximity()`

**Purpose:**
- Prevents unfair deaths
- Gives player time to react
- Visual feedback for size danger

### Scoring Formula

**Base Calculation:**
```swift
sizeMultiplier = floor(blackHoleDiameter / 60)
earnedPoints = star.basePoints × max(1, sizeMultiplier)
```

**Examples:**
- At 40pt: White Dwarf (50) × 1 = 50 points
- At 120pt: Blue Giant (200) × 2 = 400 points
- At 240pt: Red Supergiant (1000) × 4 = 4000 points

**Penalty:**
- Wrong color: -50 points (floor at 0, never negative)

### Spawn Distribution

Stars spawn based on player's current size to create natural difficulty curve.

**Size < 60pt (Early Game):**
```
White Dwarf:      50% ████████
Yellow Dwarf:     35% ███████
Blue Giant:       15% ███
Orange Giant:      0%
Red Supergiant:    0%
```

**Size 60-120pt (Mid Game):**
```
White Dwarf:      40%
Yellow Dwarf:     40%
Blue Giant:       20%
Orange Giant:      0%
Red Supergiant:    0%
```

**Size 120-180pt (Late Game):**
```
White Dwarf:      30%
Yellow Dwarf:     25%
Blue Giant:       30%
Orange Giant:     15%
Red Supergiant:    0%
```

**Size 180pt+ (End Game):**
```
White Dwarf:      25%
Yellow Dwarf:     15%
Blue Giant:       30%
Orange Giant:     20%
Red Supergiant:   10%
```

**Progression:**
- Early: Only small, safe stars
- Mid: Balanced distribution
- Late: Large stars become common
- End: Supergiants appear regularly

### Color Matching System

**Target Color Indicator:**
- Black hole has 80 particles/sec orbiting it
- Particles match current target star type color
- Changes every 8 seconds (Foundation.Timer)
- Smooth color transition (0.3s custom action)

**Ring Cycling:**
- Currently cycles through all 5 types randomly
- Future: Could weight cycling based on spawn frequency

---

## Physics & Gravity

### Physics World Setup
```swift
physicsWorld.gravity = CGVector(dx: 0, dy: 0)  // No world gravity
physicsWorld.contactDelegate = self  // GameScene handles contacts
```

### Black Hole Physics
```swift
Shape: Circle (radius = currentDiameter / 2)
isDynamic: true
affectedByGravity: false
categoryBitMask: 0x1 << 0
collisionBitMask: 0x0 (no physical collisions, passes through everything)
contactTestBitMask: 0x1 << 1 (detects contact with stars)
mass: radius² (proportional to area, grows with size)
```

**No Physical Collisions:**
- Black hole passes through stars
- Collision detected via contact events
- Allows smooth movement without bouncing

### Star Physics
```swift
Shape: Circle (radius = diameter / 2)
isDynamic: true (false when frozen by power-up)
affectedByGravity: false (custom gravity applied manually)
categoryBitMask: 0x1 << 1
collisionBitMask: 0x1 << 1 (collide with other stars for merging)
contactTestBitMask: (0x1 << 0) | (0x1 << 1) (detect black hole and stars)
mass: radius² × starType.massMultiplier
restitution: 0.1 (minimal bounce)
friction: 0.5
linearDamping: 0.1
angularDamping: 0.1
Initial velocity: random ±80 points/sec
```

**Why Collision Enabled?**
- Allows star-to-star merging
- Physical bouncing (minimal with low restitution)
- Creates dynamic star field

### Gravity Implementation

**Black Hole Gravity (Applied Every Frame):**
```swift
func applyGravity() {
    blackHoleMass = (blackHole.radius)²
    
    for star in stars:
        distance = hypot(dx, dy)
        
        if distance < 500 AND distance > 0:
            starMass = (star.radius)² × star.massMultiplier
            forceMagnitude = (800 × blackHoleMass × starMass) / distance²
            
            forceVector = (dx/distance, dy/distance) × forceMagnitude
            star.physicsBody.applyForce(forceVector)
}
```

**Star-to-Star Gravity:**
```swift
func applyStarToStarGravity() {
    G_STAR = 800 × 0.15  // 15% of black hole gravity
    
    for i in 0..<stars.count:
        for j in (i+1)..<stars.count:
            distance = hypot(dx, dy)
            
            if distance < 250:
                mass1 = (star1.radius)² × multiplier1
                mass2 = (star2.radius)² × multiplier2
                forceMagnitude = (G_STAR × mass1 × mass2) / distance²
                
                if mass1 > mass2:
                    apply force to star2 toward star1
                else:
                    apply force to star1 toward star2
}
```

**Why Weak Star Gravity?**
- Keeps focus on black hole
- Subtle drift creates dynamic field
- Sets up merging opportunities
- Doesn't overwhelm gameplay

### Mass Multipliers (Affect Gravity Pull)

**Purpose:**
- Blue giants (8.0x) and red supergiants (15.0x) pull very hard
- White dwarfs (0.3x) barely pull at all
- Creates variety in gravitational feel

**Gameplay Impact:**
- Large stars pull player stronger (harder to escape)
- Massive stars act as "gravity wells"
- Small stars easy to maneuver around

---

## Power-Up System

### Overview
Power-ups appear as colorful comets that streak across the screen with particle trails.

### Power-Up Types

#### 1. Rainbow Comet (Multicolor)

**Visual Design:**
- **Core:** 15pt circle that cycles through all 5 star colors
  - White → Yellow → Blue → Orange → Red (0.2s per color, infinite loop)
- **Glow:** Cycles with core (10pt radius, pulsing scale 1.0 ↔ 1.2)
- **Trail:** 100 particles/sec with rainbow color sequence
  - Uses SKKeyframeSequence with all 5 star colors
  - Particles fade through spectrum as they age
- **Sparkles:** 20 particles/sec, rainbow sequence
- **Inspired by:** Super Mario star power-up aesthetic

**Effect:**
- **Duration:** 8 seconds
- **Ability:** Eat ANY color star (bypasses color check)
- **Limitation:** Size restriction still applies (can't eat oversized stars)
- **UI Indicator:** Cycles through all 5 colors while active

**Spawn Timing:**
- Base interval: Random 30-45 seconds
- First spawn: 10s initial delay + random interval
- After collection: 30s cooldown + random interval

#### 2. Freeze Comet (Silver/Blue)

**Visual Design:**
- **Core:** 15pt silver circle (#C0C0C0)
- **Glow:** Silver, pulsing scale 1.0 ↔ 1.2
- **Trail:** 100 particles/sec with color sequence
  - Light cyan → Sky blue → Clear gradient
- **Sparkles:** 20 particles/sec, white with blue tint

**Effect:**
- **Duration:** 6 seconds
- **Ability:** Freezes all stars in place
  - Sets `star.physicsBody.isDynamic = false` for all stars
  - Gravity still calculated but forces not applied
  - Stars resume movement after expiration
- **Strategic Use:** Time to plan moves, navigate around large stars

**Spawn Timing:**
- Base interval: Random 35-50 seconds
- First spawn: 10s initial delay + random interval
- After collection: 30s cooldown + random interval

### Spawning Mechanics

**PowerUpManager Responsibilities:**
- Tracks next scheduled spawn time for each type (not simple intervals)
- Spawns at scheduled time if conditions met
- Reschedules with new random interval after spawn

**Spawn Restrictions:**
1. **Initial Delay:** 10 seconds after game starts (no immediate power-ups)
2. **Max on Screen:** Only 1 power-up at a time (prevents clutter)
3. **Collection Cooldown:** 30 seconds after collecting ANY power-up
4. **During Cooldown:** No spawns at all (both types affected)

**Expected Frequency:**
- Average: 1 power-up every 35-45 seconds
- Player sees ~1-2 per minute
- Feels rare and special
- Random intervals prevent predictability

### Comet Movement

**Trajectory Patterns (6 options):**
```swift
- topLeftToBottomRight (diagonal)
- topRightToBottomLeft (diagonal)
- leftToRight (horizontal)
- rightToLeft (horizontal)
- bottomLeftToTopRight (diagonal)
- bottomRightToTopLeft (diagonal)
```

**Movement Characteristics:**
- Speed: 250 points/second
- Spawn: 100pt outside visible area
- End: 100pt outside opposite edge
- Duration: Calculated from distance / speed
- Animation: SKAction.move with sequence
- Trail direction: Points opposite to movement angle

**World Integration:**
- Start/end points calculated relative to black hole position
- Works with infinite world (camera-based coordinates)
- Always appears at edge of visible screen area

### Collection System

**Physics:**
```swift
powerUp.physicsBody.isDynamic = false  // Doesn't respond to gravity
powerUp.physicsBody.categoryBitMask = 0x1 << 2
powerUp.physicsBody.contactTestBitMask = 0x1 << 0  // Black hole only
```

**Collection Flow:**
1. Contact detected in `didBegin()`
2. Power-up removed from scene
3. `PowerUpManager.onPowerUpCollected()` called → triggers 30s cooldown
4. Visual effect: 50 particle burst + white flash
   - Rainbow: Particles cycle through all star colors
   - Freeze: Light blue particles
5. `activatePowerUp()` called
6. UI indicator appears
7. Effect applied immediately

**Activation:**
```swift
Rainbow: No immediate change (affects color check in handleStarCollision)
Freeze: Sets all star.physicsBody.isDynamic = false
```

**Expiration:**
```swift
Checked every frame in update()
When currentTime >= expirationTime:
    Deactivate effect
    Unfreeze stars (if freeze was active)
    Hide UI indicator
    Play expire sound (stub)
```

### UI Indicator

**Position:** Top-right corner of HUD
**Components:**
- Circle background: 25pt radius, black with alpha 0.5
- White stroke: 2pt
- Timer label: 16pt, positioned below (-40 y offset)

**Rainbow Mode:**
- Background cycles through all 5 star colors (0.2s each)
- Visual feedback matches comet aesthetic

**Freeze Mode:**
- Background: Static light blue (#87CEEB with alpha 0.5)

**Timer:**
- Format: "X.X" seconds
- Updates every frame
- Flash animation when <1s remaining

---

## Star Merging System

### Purpose
Creates dynamic star field where stars can collide and combine, adding strategic depth and visual variety.

### Physics Configuration

**Star Collision Enabled:**
```swift
star.physicsBody.collisionBitMask = starCategory  // Allows star-star collisions
star.physicsBody.contactTestBitMask = blackHoleCategory | starCategory
restitution: 0.1  // Minimal bounce
friction: 0.5  // Slows stars on contact
```

### Merge Safeguards (Prevents Runaway Cascade)

**7 Checks (All Must Pass):**

1. **Feature Toggle:** `GameConstants.enableStarMerging == true`
2. **Merged Star Limit:** `mergedStarCount < 4`
   - Only 4 merged stars can exist simultaneously
3. **Global Cooldown:** `currentTime - lastMergeTime > 1.5 seconds`
   - Prevents rapid-fire merging
4. **Minimum Size:** Both stars must be `>= 20pt`
   - Prevents tiny star merging spam
5. **One Merge Per Star:** `!star1.hasBeenMerged AND !star2.hasBeenMerged`
   - Merged stars cannot merge again (prevents cascade)
6. **Safe Zone:** Both stars must be `>100pt` from black hole
   - Prevents clustering near player
7. **Physical Collision:** SpriteKit physics detects actual collision

**Why So Many Safeguards?**
- Without them: Runaway merging destroys gameplay
- Creates massive stars everywhere
- Overwhelming visual clutter
- These limits keep merging special

### Merge Calculation

**Combined Size:**
```swift
area1 = (star1.radius)²
area2 = (star2.radius)²
combinedArea = area1 + area2
newRadius = sqrt(combinedArea)
newDiameter = newRadius × 2
```

**Type Determination (From Size):**
```swift
if diameter < 35:   White Dwarf
if 35-50:           Yellow Dwarf
if 50-75:           Blue Giant
if 75-100:          Orange Giant
if 100+:            Red Supergiant
```

**Bonus Points:**
```swift
mergedStar.basePoints = (star1.basePoints + star2.basePoints) × 1.5
// 50% bonus for merged stars
```

**Velocity Inheritance:**
```swift
avgVelocity = (star1.velocity + star2.velocity) / 2
mergedStar.velocity = avgVelocity × 0.7  // 30% damping
```

**Flags:**
```swift
mergedStar.hasBeenMerged = true  // Cannot merge again
mergedStar.isMergedStar = true   // Has yellow ring indicator
```

### Visual Effects

**Merge Animation:**
- **Flash:** White circle at merge point
  - Starts: alpha 0, scale 1.0
  - Expands: alpha 0.8, scale 2.0 (0.1s)
  - Fades: alpha 0, scale 3.0 (0.3s)
- **Particles:** 50 particles burst outward
  - Colors: Randomly use either star's color
  - Speed: 100-200 points/sec
  - Lifetime: 0.5s

**Merged Star Indicator:**
- Yellow ring: radius + 8pt
- Line width: 3pt
- Pulsing alpha: 0.3 ↔ 0.6 (0.8s cycle)
- Added via `star.addMergedStarIndicator()`

### Cleanup

**When Merged Star Consumed:**
```swift
if star.isMergedStar:
    mergedStarCount = max(0, mergedStarCount - 1)
// Allows new merges to occur
```

**Expected Behavior:**
- See 1-2 merges per 30 seconds
- Merged stars usually consumed within 10-15 seconds
- System stays balanced (never more than 4 merged at once)

---

## Visual Design

### Black Hole (Player)

**Base Structure:**
```swift
Type: SKSpriteNode
Size: 40pt initial, scales to 30-300pt
Texture: Programmatically created black circle
zPosition: 10
```

**Visual Components:**

**1. Event Horizon (Core):**
- Pure black circular texture
- Resizes with grow/shrink

**2. Glow Effect:**
- SKShapeNode circle: radius + margin
- White stroke with glowWidth
- Alpha: 0.3
- zPosition: -1

**3. Particle Ring (Target Indicator):**
- SKEmitterNode with 80 particles/second
- Particles orbit in all directions
- Color matches target star type
- Birth rate: 80/sec
- Lifetime: 1.2s
- Speed: 25 ± 15 points/sec
- Scale: 0.4 ± 0.15
- Alpha: 0.9 → fades to 0
- Blend mode: additive
- Position range: (radius + 10) in x and y

**Animations:**
- Smooth resize on size changes (0.2s easeInEaseOut)
- Color transitions when target changes (0.3s custom action)
- Particle ring updates position range automatically

### Stars (Consumable Objects)

**Base Structure:**
```swift
Type: SKSpriteNode
Size: Type-dependent (18-400pt range)
Texture: Programmatically created colored circle
zPosition: 5
```

**Visual Components:**

**1. Core:**
- Solid circle with star type color
- Main visual element

**2. Glow Layer:**
- SKSpriteNode using same texture
- Size: core + (glowRadius × 2)
- Color blend: 50% star color
- Alpha: 0.3
- Pulsing animation: varies by type
- zPosition: -1

**3. Warning Glow (Conditional):**
- Appears when star is too large to consume
- Red SKShapeNode ring
- Line width: 3pt, glow width: 8pt
- Pulsing alpha: 0.3 ↔ 0.9 (0.3s cycles)
- Added/removed dynamically based on proximity

**4. Merged Star Indicator (Conditional):**
- Only on merged stars
- Yellow SKShapeNode ring
- Ring radius: star radius + 8pt
- Line width: 3pt
- Pulsing alpha: 0.3 ↔ 0.6
- Indicates bonus points

**Special Effects by Type:**

**White Dwarf:**
- Small, tight glow (6pt radius)
- No special animation

**Yellow Dwarf:**
- Medium glow (7pt radius)
- Moderate pulse on glow layer

**Blue Giant:**
- Bright glow (8pt radius)
- Fast twinkling: alpha 0.9 ↔ 1.0 (0.15s cycles)

**Orange Giant:**
- Large glow (12pt radius)
- Strong pulse animation

**Red Supergiant:**
- Massive glow (18pt radius)
- Dramatic pulse: scale 0.95 ↔ 1.05 (1.5s cycles)

### Particle Effects

**Star Consumption:**
- 25 particles burst at contact point
- Color matches consumed star
- Speed: 50-150 points/sec outward
- Lifetime: 0.3s
- Scale down while fading

**Star Merging:**
- 50 particles at merge point
- Mixed colors from both stars
- White flash effect
- Speed: 100-200 points/sec
- Lifetime: 0.5s

**Power-Up Collection:**
- 50 particles at collection point
- Rainbow: Random star colors
- Freeze: Light blue (#87CEEB)
- White flash effect
- Speed: 150-250 points/sec
- Lifetime: 0.5s

### Colors & Aesthetics

**Color Palette:**
```swift
White:  #F0F0F0  // Bright white (dwarfs)
Yellow: #FFD700  // Gold (sun-like stars)
Blue:   #4DA6FF  // Light dodger blue (hot stars)
Orange: #FF8C42  // Warm orange (giants)
Red:    #DC143C  // Crimson (supergiants)
Space:  #0A0E27  // Deep space background
```

**Visual Style:**
- Minimalist space theme
- Glowing effects on all objects
- Clean, modern look
- Dark background emphasizes glows
- Additive blending for particles

---

## Game Progression

### Difficulty Curve

**Early Game (0-60 seconds):**
- Small stars only (white, yellow)
- Gentle introduction
- Spawn rate: 0.6s (manageable)
- Target changes every 8s
- Learning mechanics

**Mid Game (60-120 seconds):**
- Blue giants introduced
- More variety in spawn
- Player grows to 60-120pt range
- Increased challenge

**Late Game (120+ seconds):**
- Orange giants appear
- Player large enough for big stars
- High risk/reward decisions
- Strategic navigation required

**End Game (180+ seconds):**
- Red supergiants spawn
- Massive stars dominate screen
- Survival mode
- Expert-level difficulty

### Size Milestones

**40pt (Start):**
- Can eat: White dwarfs (18-28pt)
- Challenge: Don't shrink below 30pt

**60pt:**
- Can eat: Yellow dwarfs safely
- Unlock: Blue giants in spawn pool

**120pt:**
- Can eat: Most blue giants
- Unlock: Orange giants spawn
- Size multiplier: ×2 scoring

**180pt:**
- Can eat: Orange giants safely
- Unlock: Red supergiants spawn
- Size multiplier: ×3 scoring

**250pt:**
- Can eat: Most red supergiants
- Boss difficulty: Screen full of giants
- Size multiplier: ×4 scoring

**300pt (Maximum):**
- Can eat: Anything in the game
- Ultimate size achieved
- Survival mode continues

### Death Conditions

**Two Ways to Lose:**

1. **Shrink to Minimum (30pt):**
   - Eating too many wrong colors
   - Message: "Black hole shrunk too small"

2. **Eat Oversized Star:**
   - Collision with star >= black hole size
   - Message: "Black hole destabilized!"
   - Instant game over (no shrinking first)

**Fair Death System:**
- Warning glows give advance notice
- Player always has reaction time
- Deaths feel earned, not cheap

---

## File Structure & Responsibilities

### Core Game Files

**1. Constants.swift (210 lines)**
```swift
Purpose: Centralized configuration
Contains:
  - GameConstants enum (all game values)
  - StarType enum (5 types with properties)
  - UIColor extension (hex initializer, space background)

Key Sections:
  - Black hole sizing and animation
  - Ring indicator settings
  - Star spawning and physics
  - Physics categories (bitmasks)
  - Power-up system values
  - Scoring constants
  - Star merging configuration
  - UI positioning and fonts
```

**2. BlackHole.swift (~210 lines)**
```swift
Type: SKSpriteNode subclass
Purpose: Player-controlled black hole

Properties:
  - currentDiameter: CGFloat (read-only)
  - targetType: StarType (read-only)
  - particleEmitter: SKEmitterNode (color indicator)

Key Methods:
  - init(diameter:) - Setup physics, particles, glow
  - setupPhysics() - Configure physics body
  - setupParticleEmitter() - 80 particles/sec color ring
  - setupParticleTargetNode() - Called after adding to scene
  - grow() - Increase size by 15%
  - shrink() - Decrease size by 20%
  - updateSize(to:) - Resize animation
  - updatePhysicsBody() - Recreate physics body
  - updateParticleEmitterSize() - Adjust particle range
  - updateTargetType(to:) - Smooth color transition
  - canConsume(star) -> Bool - Size check
  - isAtMinimumSize() -> Bool - Check for game over

Helpers:
  - createCircleTexture() - Generate black circle texture
  - createParticleTexture() - Generate white particle texture
  - interpolateColor() - Smooth color transitions
```

**3. Star.swift (~180 lines)**
```swift
Type: SKSpriteNode subclass
Purpose: Consumable stars with physics

Properties:
  - starType: StarType (immutable)
  - warningGlow: SKShapeNode? (red danger ring)
  - hasBeenMerged: Bool (merge safeguard)
  - isMergedStar: Bool (tracks merged stars)
  - basePoints: Int (mutable for merged stars)

Key Methods:
  - init(type:) - Random size from range, setup
  - setupPhysics(diameter:) - Circle body with mass
  - addGlowEffect() - Glow layer with pulse
  - addInitialDrift() - Random velocity ±80 pts/sec
  - startSpecialEffect() - Type-specific animations
  - playSpawnAnimation() - Scale from 0 (0.2s)
  - playDeathAnimation(completion:) - Fade + scale (0.1s)
  - showWarningGlow() - Red danger ring
  - hideWarningGlow() - Remove danger ring
  - addMergedStarIndicator() - Yellow ring for merged stars

Helpers:
  - createCircleTexture() - Generate colored circle
```

**4. GameScene.swift (~850 lines)**
```swift
Type: SKScene, SKPhysicsContactDelegate
Purpose: Main gameplay coordinator

Properties:
  - blackHole: BlackHole (player)
  - stars: [Star] (active game stars)
  - cameraNode: SKCameraNode (follows player)
  - hudNode: SKNode (UI container)
  - backgroundStars: [SKSpriteNode] (100 parallax stars)
  - powerUpManager: PowerUpManager
  - activePowerUp: ActivePowerUpState
  - Timers: star spawn, color change
  - UI labels: score, game over elements
  - Tracking: mergedStarCount, lastMergeTime, isGameOver

Scene Lifecycle:
  - didMove(to:) - Setup all systems
  - setupScene() - Background, physics world
  - setupCamera() - Create camera and HUD
  - setupBackgroundStars() - 100 twinkling stars
  - setupBlackHole() - Create player, set camera
  - setupPowerUpSystem() - Initialize manager
  - setupUI() - Score label
  - setupPowerUpUI() - Top-right indicator
  - startGameTimers() - Star spawn, color change

Game Logic:
  - spawnStar() - Create star at edge, with type selection
  - selectStarType() - Progressive spawn distribution
  - randomEdgePosition() - Relative to black hole
  - changeTargetColor() - Every 8 seconds
  - getAvailableStarTypes() - All types always available

Physics:
  - applyGravity() - Black hole to star forces
  - applyStarToStarGravity() - Star to star forces (15% strength)
  - removeDistantStars() - Cleanup >1000pt away
  - checkStarProximity() - Warning glow system

Collision Handling:
  - didBegin(contact:) - Route to appropriate handler
  - collectPowerUp() - Power-up collection flow
  - handleStarMerge() - 7 safeguards + merge logic
  - createMergedStar() - Calculate merged properties
  - determineStarType(fromDiameter:) - Size to type mapping
  - handleStarCollision() - Size check, color check, grow/shrink
  - removeStar() - Track merged stars, play death animation

Power-Up System:
  - activatePowerUp(type:) - Apply effect, UI
  - handlePowerUpExpiration() - Cleanup, unfreeze
  - freezeAllStars() - Set all isDynamic = false
  - unfreezeAllStars() - Restore isDynamic = true
  - showCollectionEffect() - Particle burst
  - updatePowerUpUI() - Indicator and timer

Visual Effects:
  - showMergeEffect() - Flash + particles
  - createCollisionParticles() - Star consumption
  - updateBackgroundStars() - Parallax repositioning

Update Loop:
  - update(currentTime:) - Main game loop
    - updateCamera() - Smooth follow (15% lerp)
    - updateBackgroundStars() - Reposition if far
    - checkStarProximity() - Warning glows
    - powerUpManager.update() - Spawn comets
    - activePowerUp.checkExpiration() - End effects
    - updatePowerUpUI() - Countdown timer
    - applyGravity() - Black hole forces
    - applyStarToStarGravity() - Star forces
    - removeDistantStars() - Cleanup

Touch Handling:
  - touchesBegan() - Move to position or restart
  - touchesMoved() - Continuous movement

Game Over:
  - triggerGameOver() - Stop physics, timers
  - showGameOverUI() - Labels on HUD
  - restartGame() - Fresh scene

UI:
  - updateScoreLabel() - Format with commas
  - formatScore() - NumberFormatter
```

**5. GameManager.swift (~40 lines)**
```swift
Type: Singleton class
Purpose: Score tracking and persistence

Properties:
  - currentScore: Int (read-only)
  - highScore: Int (read-only)

Methods:
  - addScore(points:) - Update score, check high score
  - resetScore() - Set to 0 (on restart)
  - getScoreMultiplier(blackHoleDiameter:) - floor(diameter/60)
  - saveHighScore() - UserDefaults persistence
  - loadHighScore() - Read from UserDefaults

UserDefaults Key: "blackHole_highScore"
```

**6. AudioManager.swift (~115 lines)**
```swift
Type: Singleton class
Purpose: Audio playback (stubs only, no actual files)

Methods (All print to console):
  - playCorrectSound() - Star match
  - playWrongSound() - Star mismatch
  - playGrowSound() - Black hole growth
  - playShrinkSound() - Black hole shrink
  - playGameOverSound() - Death
  - playPowerUpSound() - Generic power-up
  - playMergeSound() - Star merge
  - playPowerUpCollectSound() - Comet collection
  - playPowerUpExpireSound() - Effect ends
  - playBackgroundMusic() - Ambient loop
  - stopBackgroundMusic()
  - setMusicVolume(volume:)
  - setSoundVolume(volume:)

Future Implementation:
  - Load audio files in init()
  - Use AVAudioPlayer or SpriteKit actions
  - Files needed: correct.wav, wrong.wav, grow.wav, shrink.wav,
    gameover.wav, merge.wav, powerup_collect.wav, powerup_expire.wav,
    background_music.mp3
```

### Power-Up System Files

**7. PowerUpType.swift (~100 lines)**
```swift
Contains:
  - PowerUpType enum (rainbow, freeze)
  - CometTrajectory enum (6 patterns)

PowerUpType Properties:
  - coreColor: UIColor (white for rainbow, silver for freeze)
  - displayName: String
  - duration: TimeInterval (8s or 6s)
  - baseSpawnInterval: ClosedRange<TimeInterval>
  - collectionCooldown: TimeInterval (30s)

CometTrajectory:
  - getStartAndEnd(sceneSize:blackHolePosition:) -> (CGPoint, CGPoint)
  - Calculates spawn and end points relative to black hole
  - 100pt margin outside visible area
```

**8. PowerUp.swift (~230 lines)**
```swift
Type: SKNode subclass
Purpose: Visual comet with particle trail

Properties:
  - type: PowerUpType
  - coreNode: SKShapeNode (15pt circle)
  - trailEmitter: SKEmitterNode (100 particles/sec)
  - sparkleEmitter: SKEmitterNode (20 particles/sec)
  - trajectory: CometTrajectory

Setup Methods:
  - setupCore() - 15pt circle with glow, pulsing
  - cycleRainbowColors() - For rainbow type only
  - setupTrail() - Particle trail with color sequences
  - setupSparkles() - Sparkles around core
  - setupPhysics() - Contact detection, isDynamic=false
  - updateTrailDirection(angle:) - Point trail backward

Particle Configurations:
  - Rainbow trail: All 5 star colors in sequence
  - Rainbow sparkles: All 5 star colors in sequence
  - Freeze trail: Cyan → Sky Blue → Clear
  - Freeze sparkles: White → Sky Blue → Clear

Helper:
  - createSparkTexture() - 8x8 white circle texture
```

**9. PowerUpManager.swift (~135 lines)**
```swift
Type: Regular class
Purpose: Power-up spawning and timing

Properties:
  - activePowerUps: [PowerUp] (on-screen comets)
  - nextRainbowSpawn: TimeInterval (scheduled time)
  - nextFreezeSpawn: TimeInterval (scheduled time)
  - lastCollectionTime: TimeInterval (for cooldown)
  - gameStartTime: TimeInterval (reference)
  - MAX_POWERUPS_ON_SCREEN = 1
  - COLLECTION_COOLDOWN = 30.0
  - INITIAL_DELAY = 10.0

Methods:
  - init(gameStartTime:) - Initialize, schedule first spawns
  - scheduleNextSpawns(currentTime:) - Random intervals + initial delay
  - onPowerUpCollected(currentTime:) - Trigger 30s cooldown
  - update(currentTime:) - Check spawn conditions
  - spawnPowerUp(type:currentTime:) - Create and animate comet
  - calculateCometDuration(start:end:) - Distance / 250 pts/sec

Spawn Logic:
  - Check cooldown (no spawns if in 30s cooldown)
  - Check max (only 1 on screen)
  - Check scheduled time (randomized)
  - Spawn only if all conditions met
```

### Supporting Files

**10. GameViewController.swift**
```swift
Purpose: Scene presentation and app configuration

Key Code:
  - Creates GameScene programmatically (not from .sks file)
  - Sets scale mode: .aspectFill
  - Locks orientation: .portrait
  - Hides status bar
  - Shows FPS/node count (debug, can disable for release)
```

**11. AppDelegate.swift**
```swift
Purpose: App lifecycle (standard template)
- No custom modifications
- Standard UIApplication delegate methods
```

---

## ActivePowerUpState Class

**Location:** Defined in GameScene.swift (top of file)

**Purpose:** Tracks currently active power-up effect

**Properties:**
```swift
activeType: PowerUpType? (nil when inactive)
expirationTime: TimeInterval (CACurrentMediaTime when effect ends)
indicatorNode: SKNode? (reference to UI element)
```

**Methods:**
```swift
activate(type:currentTime:) - Start effect, set expiration
isActive() -> Bool - Check if power-up active
getRemainingTime(currentTime:) -> TimeInterval - For UI countdown
checkExpiration(currentTime:) -> Bool - Returns true if expired
deactivate() - Clear state
```

**Usage:**
```swift
// In GameScene
var activePowerUp = ActivePowerUpState()

// On collection
activePowerUp.activate(type: .rainbow, currentTime: CACurrentMediaTime())

// Every frame
if activePowerUp.checkExpiration(currentTime: currentTime) {
    handlePowerUpExpiration()
}

// In collision check
if activePowerUp.activeType == .rainbow {
    // Allow any color
}
```

---

## Data Persistence

### UserDefaults Storage

**High Score:**
```swift
Key: "blackHole_highScore"
Type: Integer
Saved: Automatically when currentScore > highScore
Loaded: On GameManager singleton initialization
Synchronized: After each save
```

**Persistence Flow:**
```swift
1. Player scores 1500 (previous high: 1000)
2. GameManager.addScore() checks: 1500 > 1000
3. highScore = 1500
4. UserDefaults.set(1500, forKey: "blackHole_highScore")
5. UserDefaults.synchronize()
```

**No Session Persistence:**
- Game state not saved on backgrounding
- Each launch is fresh start
- High score persists across sessions

**Future Enhancement:**
- Could save: current size, score, stars on screen
- Would allow resume after backgrounding
- UserDefaults or local file storage

---

## Performance Characteristics

### Target Performance
- **FPS:** 60 (constant)
- **Device:** iPhone 8+ and newer
- **Resolution:** Adaptive (uses view.bounds.size)

### Particle Budget

**Continuous Particles:**
```
Black Hole Color Ring:    80 particles
Power-Up Trail (active):  60 particles
Power-Up Sparkles:        20 particles
Total Continuous:        ~160 particles
```

**Temporary Particles (Events):**
```
Star Consumption:         25 particles (0.3s)
Star Merge:              50 particles (0.5s)
Power-Up Collection:      50 particles (0.5s)
Max Temporary:          ~125 particles
```

**Total Max:** ~285 particles simultaneously (well under SpriteKit limit of 1000+)

### Memory Management

**Star Management:**
- Max 30 stars on screen (hard limit)
- Stars >1000pt from black hole: removed
- Checked every frame
- Array cleanup: `stars.removeAll { condition }`

**Background Stars:**
- Fixed pool of 100 stars
- Never created/destroyed after init
- Repositioned when far from camera
- Zero memory growth

**Power-Ups:**
- Max 1 on screen at a time
- Auto-removes when off-screen (SKAction)
- Particles cleaned up with parent removal
- No orphaned emitters

**Particle Cleanup:**
- Temporary emitters: `numParticlesToEmit` set to specific count
- Auto-remove after wait: `SKAction.wait(forDuration:) + removeFromParent()`
- No manual particle tracking needed

### Optimization Techniques

**Distance Checks Before Calculations:**
```swift
// Don't calculate gravity if too far
if distance < 500 {
    // Calculate and apply force
}
```

**Early Returns:**
```swift
guard !isGameOver else { return }
guard stars.count > 1 else { return }
```

**Nested Loops with Early Exit:**
```swift
for i in 0..<stars.count {
    for j in (i+1)..<stars.count {
        guard distance < 250 else { continue }
        // Calculate gravity
    }
}
```

**Smart Spawn Checks:**
```swift
guard stars.count < maxCount else { return }
guard distance > minSpawnDistance else { return }
```

---

## Known Issues & Limitations

### Current Bugs/Quirks

**Star Merging:**
- Debug output shows many "blocked" merges
- Safeguards are intentionally strict
- Expected: 1-2 successful merges per 30 seconds
- Most collisions are blocked (by design)

**Console Spam:**
- Lots of debug print statements
- Useful for development
- Should be removed/disabled for release

**Visual Enhancement Plan Incomplete:**
- Black hole has simple glow (not multi-layer accretion disk)
- Stars have simple glow (not corona particles for large stars)
- No absorption animation (instant removal)
- Plan exists in `/black-hole-mvp.plan.md` but not implemented

### Not Implemented (From Original Spec)

**Missing MVP Features:**
- ❌ Main menu scene
- ❌ Pause functionality
- ❌ Actual audio files (only stubs exist)
- ❌ Background music
- ❌ Difficulty progression (spawn rate increase over time)

**Missing Polish Features:**
- ❌ Advanced particle effects
- ❌ Screen shake effects
- ❌ Tutorial/first-time instructions
- ❌ Settings menu (volume controls)

**Missing Advanced Features:**
- ❌ Additional power-ups (size override, magnet, shield)
- ❌ Achievements system
- ❌ Game Center leaderboards
- ❌ Daily challenges
- ❌ Different game modes
- ❌ Black hole skins/themes

### Technical Debt

**Code Organization:**
- GameScene.swift is very large (850+ lines)
- Could split into extensions:
  - GameScene+Spawning.swift
  - GameScene+Physics.swift
  - GameScene+Collision.swift
  - GameScene+PowerUps.swift
  - GameScene+UI.swift

**Unused Files:**
- `GameScene.sks` exists but not used (programmatic creation)
- `Actions.sks` exists but not used
- Could be deleted to clean up project

**Duplicate Todos:**
- Many completed todo items from different plans
- Should be cleaned up

---

## Development Setup

### Building the Project

**Requirements:**
- Xcode 13+ (for Swift 5.9)
- iOS Simulator or physical device
- No external dependencies (pure SpriteKit)

**Build Steps:**
1. Open `blackHole.xcodeproj`
2. Select target device/simulator
3. Build and Run (⌘R)

**Debug Features:**
- FPS display: Enabled in GameViewController
- Node count: Enabled in GameViewController
- Console logging: Extensive debug output
  - Merge events
  - Power-up spawns
  - Audio calls

### Git History

**Branch:** main  
**Commits:**
- `be047b2` - Initial Commit (Xcode template)
- `9e28ab2` - First commit (current working state)

**Working Directory:** Clean after recent revert

### Testing Workflow

**Manual Testing:**
1. Build and run
2. Test black hole movement (drag anywhere)
3. Watch stars spawn and get attracted
4. Try eating correct/wrong colors
5. Wait for power-ups (~10-45 seconds)
6. Look for star merges (console will show)
7. Test game over conditions
8. Test restart

**Console Monitoring:**
- Watch for merge events
- Check power-up spawn timings
- Monitor audio stub calls
- Verify no errors/warnings

---

## Future Development Roadmap

### Phase 2: Polish (Not Implemented)
- [ ] Implement visual enhancements (see `/black-hole-mvp.plan.md`)
- [ ] Add actual audio files and wire up AudioManager
- [ ] Improve particle effects (absorption animation)
- [ ] Add screen shake for big events
- [ ] Polish UI with better fonts and styling

### Phase 3: Features (Not Implemented)
- [ ] Main menu scene with "Start Game" button
- [ ] Pause menu (pause button, resume/restart/menu)
- [ ] Tutorial overlay for first-time players
- [ ] Settings menu (volume controls, toggle effects)
- [ ] Additional power-up types

### Phase 4: Advanced (Not Implemented)
- [ ] Game Center integration (leaderboards)
- [ ] Achievements system
- [ ] Daily challenges
- [ ] Different game modes (timed, puzzle, etc.)
- [ ] Black hole skins/cosmetics
- [ ] Difficulty progression (spawn rate increases)

---

## Common Development Tasks

### Adding a New Star Type

1. Update `StarType` enum in Constants.swift
   - Add case
   - Add to `displayName`, `uiColor`, `sizeRange`, `basePoints`, `massMultiplier`, `glowRadius`
2. Update `selectStarType()` in GameScene.swift
   - Add to spawn distribution
3. Update `determineStarType(fromDiameter:)` in GameScene.swift
   - Add size range for merged star type determination
4. Update special effects in Star.swift if needed

### Adding a New Power-Up

1. Add case to `PowerUpType` enum in PowerUpType.swift
2. Add properties (color, duration, spawn interval)
3. Update `PowerUp.setupTrail()` with new color scheme
4. Update `PowerUp.setupSparkles()` with new colors
5. Add to `PowerUpManager` spawn tracking
6. Implement effect in `GameScene.activatePowerUp()`
7. Handle expiration in `GameScene.handlePowerUpExpiration()`
8. Update UI in `GameScene.updatePowerUpUI()`

### Adjusting Difficulty

**Make Easier:**
- Increase `starSpawnInterval` (slower spawns)
- Decrease `starMaxCount` (fewer on screen)
- Increase `blackHoleGrowthMultiplier` (grow faster)
- Decrease `blackHoleShrinkMultiplier` (shrink less)

**Make Harder:**
- Decrease `starSpawnInterval` (faster spawns)
- Increase `starMaxCount` (more chaos)
- Increase `gravitationalConstant` (stronger pull)
- Adjust spawn distribution (more large stars)

### Disabling Star Merging

**Quick toggle:**
```swift
// In Constants.swift
static let enableStarMerging: Bool = false
```

**Complete removal:**
1. Set `enableStarMerging = false`
2. Set `star.physicsBody.collisionBitMask = 0` (no star-star collisions)
3. Remove star-star check in `didBegin()`

---

## Tips for Future Developers

### Understanding the Codebase

**Start Here:**
1. Read `Constants.swift` - Understand all game values
2. Read `GameScene.didMove(to:)` - See initialization order
3. Read `GameScene.update()` - See frame-by-frame logic
4. Read `GameScene.didBegin()` - See collision routing

**Key Concepts:**
- Everything is world coordinates (not screen coordinates)
- Camera follows player (not player moves in fixed view)
- Stars spawn relative to black hole position
- All game logic in `handleStarCollision()` (single source of truth)

### Common Pitfalls

**Coordinate Systems:**
- `touch.location(in: self)` returns WORLD coordinates (not screen)
- UI elements use camera-relative coordinates
- Star spawning uses black hole position (world) + offset

**Physics Bodies:**
- Must recreate physics body after size changes
- Contact events fire asynchronously
- Node might be removed before contact fires (guard against nil)

**Particle Systems:**
- Set `targetNode = self.parent` to prevent particle hierarchy issues
- Always set `numParticlesToEmit` for temporary effects
- Use `SKAction.wait + removeFromParent` for cleanup

**Timers:**
- Foundation.Timer runs on main thread
- Must invalidate in `deinit` or when scene removed
- Use `[weak self]` to prevent retain cycles

---

## Debugging Guide

### Console Output Meanings

**Star Merging:**
```
⭐️ Star collision detected: White Dwarf (25pt) + Yellow Dwarf (38pt)
  → Physical collision occurred

🚫 Merge blocked: max merged stars reached (4/4)
  → Can't merge, already have 4 merged stars

🚫 Merge blocked: cooldown (0.8s/1.5s)
  → Too soon since last merge

🚫 Merge blocked: star too close to black hole (95pt < 100pt)
  → One star within 100pt of player

✨ MERGE SUCCESS! Yellow Dwarf + Blue Giant → Blue Giant (Count: 3/4)
  → Merge occurred, now have 3 merged stars
```

**Power-Ups:**
```
⏰ Next Rainbow spawn: 42.3s
  → Rainbow comet scheduled to spawn in 42.3 seconds

🌠 Spawned Rainbow comet - duration: 4.2s
  → Comet created, will cross screen in 4.2 seconds

💎 Collected Rainbow power-up!
  → Player touched comet

🌈 Rainbow Mode activated! Eat any color for 8.0s
  → Effect active

⏰ Collection cooldown: 30.0s - Next spawns delayed
  → 30 second cooldown started

⏱️ Power-up expired: Rainbow
  → Effect ended
```

**Audio (Stubs):**
```
🔊 Playing correct sound
🔊 Playing grow sound
🔊 Playing merge sound
🔊 Playing power-up collect sound
  → All audio is currently print-only (no actual sounds)
```

### Performance Monitoring

**In-Game:**
- Top-left shows FPS (should be constant 60)
- Below FPS shows node count (should be ~100-150)

**If FPS Drops:**
- Check particle count (look for orphaned emitters)
- Check star count (should max at 30)
- Check for memory leaks (instruments)
- Reduce spawn rate or max stars

### Common Issues

**Black Hole Stuck in Corner:**
- Verify scene created programmatically (not from .sks)
- Check camera is following in `update()`
- Ensure touch positions are world coordinates

**Stars Not Spawning:**
- Check `starSpawnTimer` is running
- Verify timer not invalidated
- Check `stars.count < maxCount`
- Look for spawn position issues

**Power-Ups Not Appearing:**
- Wait 10 seconds (initial delay)
- Check for 30s cooldown after collection
- Verify only 1 on screen at a time
- Check console for scheduled spawn times

**Merges Not Happening:**
- Look for "🚫 Merge blocked" messages in console
- Common: cooldown, too close to black hole, max merged reached
- Safeguards are intentionally strict
- Expected: Most collisions are blocked

**Game Over Not Working:**
- Verify size check: `star.size.width >= blackHole.currentDiameter`
- Check `triggerGameOver()` is called
- Ensure `isGameOver` flag set
- Verify physics stopped: `physicsWorld.speed = 0`

---

## Code Conventions

### Naming
- Classes: PascalCase (`BlackHole`, `PowerUpManager`)
- Properties: camelCase (`currentDiameter`, `activePowerUp`)
- Methods: camelCase (`spawnStar()`, `handleStarCollision()`)
- Constants: camelCase (`maxMergedStars`, `cometCoreSize`)
- Enum cases: camelCase (`.whiteDwarf`, `.rainbow`)

### Organization
- MARK comments separate code sections
- Private methods when not called outside class
- Weak references for delegates/closures to prevent cycles
- Guard statements for early returns

### Physics
- All gravity applied manually (no SpriteKit gravity)
- Force-based (not impulse-based)
- Applied every frame in `update()`

---

## Testing Checklist

### Core Mechanics
- [x] Black hole moves with finger
- [x] Stars spawn at edges relative to black hole
- [x] Stars attracted by gravity
- [x] Correct color consumption grows black hole
- [x] Wrong color consumption shrinks black hole
- [x] Game over at minimum size
- [x] Game over when eating oversized star
- [x] Score displays and updates
- [x] High score persists across launches

### Advanced Features
- [x] Infinite world (can move anywhere)
- [x] Camera follows smoothly
- [x] Background stars create parallax
- [x] Warning glows appear on dangerous stars
- [x] Star merging works (with safeguards)
- [x] Rainbow power-up spawns and works
- [x] Freeze power-up spawns and works
- [x] Power-up UI shows countdown
- [x] Restart works (tap anywhere)

### Performance
- [x] Maintains 60 FPS
- [x] No memory leaks
- [x] Particles clean up properly
- [x] Stars removed when far away

---

## Summary

This is a **feature-complete MVP** of the Black Hole game with:
- ✅ Core gameplay loop working
- ✅ Infinite world exploration
- ✅ 5 star types with size-based progression
- ✅ Star merging system (with safeguards)
- ✅ 2 power-ups (rainbow, freeze) with comet visuals
- ✅ Progressive difficulty (spawn distribution)
- ✅ Score persistence
- ✅ Polish needed (visuals, audio, menus)

The game is **playable and fun** but needs visual/audio polish and menu systems for release.

---

**For questions or clarification, refer to the source code or this documentation.**

