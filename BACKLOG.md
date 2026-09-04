# Backlog

The backlog is the starting point for all work. The user adds items here, and the TL picks them up, creates GitHub issues with acceptance criteria, and runs them through the pipeline.

## How it works

1. **User adds items** to this file — features, bugs, ideas, improvements
2. **TL reads the backlog** at the start of each session
3. **TL prioritizes** — picks the next item(s) to work on based on priority and dependencies
4. **TL creates GitHub issues** — with acceptance criteria, labels, and assigns to architect
5. **Item moves through pipeline** — architect → judge → developer → judge → QA → judge → done
6. **TL updates backlog** — marks items as done, adds new items discovered during work

---

## Priority: High

### 1. Core game scene with scrolling ground and sky

Set up the main 3D scene with a fixed perspective camera, a textured ground plane that scrolls toward the camera (UV scrolling), and a sky gradient background. This is the foundation everything else builds on — the "into the screen" Super Scaler perspective.

**Acceptance criteria:**
- [ ] 3D scene with fixed perspective camera looking down a corridor
- [ ] Ground plane with UV-scrolling texture moving toward the camera at constant speed
- [ ] Sky gradient background (blue to light blue, matching original arcade)
- [ ] Ground has horizon line visible — ground meets sky naturally
- [ ] Runs at 60 FPS
- [ ] Resolution targets 320x224 scaled up (pixel-perfect stretch)

**Notes:** This is the visual foundation. Must look like the original arcade — ground rushing toward you, horizon in the distance. Reference original After Burner screenshots for camera angle and ground perspective.

### 2. Player jet (F-14 Tomcat) with movement and banking

The player's jet rendered as a sprite, positioned at the bottom-center of the screen. Moves freely on screen X/Y axes with input. Banks (tilts) when moving left/right. Has afterburner flame effect.

**Acceptance criteria:**
- [ ] Player jet sprite visible at bottom-center of screen
- [ ] Moves with arrow keys / WASD / gamepad left stick
- [ ] Movement constrained to screen bounds (can't fly off-screen)
- [ ] Jet banks left when moving left, banks right when moving right, level when centered
- [ ] Banking uses different sprite frames (at least 5: hard-left, left, center, right, hard-right)
- [ ] Afterburner flame effect on the jet's exhaust
- [ ] Smooth, responsive movement — no input lag

**Notes:** The banking is crucial for the arcade feel. The original had ~5 sprite frames for different bank angles. The jet should feel like it has some inertia but still be very responsive.

### 3. Vulcan cannon and missile weapons

Two weapons: vulcan cannon (unlimited, rapid fire, short visual range) and heat-seeking missiles (limited supply, lock-on system). The vulcan fires bullets that fly into the screen. Missiles require locking onto an enemy in a targeting reticle, then fire and home in.

**Acceptance criteria:**
- [ ] Vulcan cannon fires with dedicated button (e.g., Z / gamepad A)
- [ ] Vulcan bullets fly "into the screen" (scale down and move toward center/horizon)
- [ ] Vulcan has rapid fire rate with short cooldown
- [ ] Missile fires with dedicated button (e.g., X / gamepad B)
- [ ] Missile lock-on: enemies in center reticle area get a lock-on indicator
- [ ] Locked-on missiles home toward target
- [ ] Missile count displayed on HUD, starts at ~50, decremented on fire
- [ ] Cannot fire missiles when count is 0
- [ ] Missile smoke trail visual effect

**Notes:** The lock-on system is key to After Burner's feel. The targeting reticle is always on screen — when an enemy passes through it, a lock-on sound plays and a marker appears on the enemy.

### 4. Enemy jets with formations and attacks

Enemy jets that fly toward the player from the horizon, in formations. They fire bullets at the player. Multiple enemy types with different behaviors. Enemies scale up as they approach (Super Scaler effect).

**Acceptance criteria:**
- [ ] Enemy jets appear from the horizon (small) and fly toward/past the player (scaling up)
- [ ] At least 3 enemy types: standard fighter, fast interceptor, bomber
- [ ] Enemies fire bullets/missiles at the player
- [ ] Enemies fly in formations (V-shape, line, scattered)
- [ ] Enemy bullets are visible and dodgeable
- [ ] Enemies that fly past the player without being destroyed disappear behind camera
- [ ] Destroyed enemies show explosion effect
- [ ] Each enemy type has a score value

**Notes:** The sprite scaling is the most important visual element. Enemies must smoothly scale from tiny dots at the horizon to large sprites flying past the player. Reference original gameplay footage.

### 5. Collision detection and damage system

Player takes damage from enemy bullets/collisions. Player has lives (default 3). On death: dramatic crash animation (jet spirals into ground, explosion). Brief invincibility after respawn.

**Acceptance criteria:**
- [ ] Player hit by enemy bullet → lose a life
- [ ] Player collides with enemy jet → both destroyed
- [ ] Death animation: jet spins/tumbles and crashes into ground with explosion
- [ ] Respawn after death with brief invincibility (flashing sprite)
- [ ] Lives counter on HUD
- [ ] Game over when lives = 0
- [ ] Game over screen with final score

**Notes:** The death animation in the original was memorable — the jet would tumble and slam into the ground. This is important for the arcade feel.

### 6. Stage system with 23 stages

Stage manager that progresses through stages. Each stage has different ground colors/textures, sky colors, and enemy wave patterns. Difficulty increases with each stage. Bonus refueling stages every few stages.

**Acceptance criteria:**
- [ ] 23 stages with progression
- [ ] Each stage has: unique ground color, sky color, enemy wave configuration
- [ ] Stage number displayed on HUD
- [ ] Difficulty increases: more enemies, faster, more aggressive
- [ ] Bonus stages every ~6 stages: ally plane flies alongside, resupplies missiles
- [ ] Stage transitions: brief "STAGE X" text overlay
- [ ] Ground environment variety: ocean, desert, forest, mountain, night city

**Notes:** The original had diverse environments — the ground color/texture changed dramatically between stages. Some stages were over water, some desert, some at night with city lights below.

### 7. HUD overlay

Arcade-style heads-up display with all gameplay info.

**Acceptance criteria:**
- [ ] Score display (top of screen)
- [ ] Missile count
- [ ] Speed indicator
- [ ] Stage number
- [ ] Lives remaining
- [ ] Lock-on reticle in center area of screen
- [ ] All text uses arcade-style pixel font
- [ ] HUD does not obstruct gameplay view

### 8. Title screen and music select

Classic After Burner title screen with music selection (the original let you pick from 3 tracks before starting).

**Acceptance criteria:**
- [ ] Title screen with "AFTER BURNER" logo
- [ ] "PRESS START" prompt
- [ ] Music selection screen (choose from 3 BGM tracks)
- [ ] Transition to gameplay on start
- [ ] High score display on title screen

**Notes:** The music select was iconic. The original had "Final Take Off", "Super Stripe", and "After Burner" as track choices.

## Priority: Medium

### 9. Barrel roll dodge mechanic

The player can perform barrel rolls to dodge incoming fire. Brief invincibility during the roll animation.

**Acceptance criteria:**
- [ ] Barrel roll triggered by double-tap left/right or dedicated button
- [ ] Roll animation: jet rotates 360 degrees on its forward axis
- [ ] Brief invincibility during roll
- [ ] Cooldown prevents roll spam
- [ ] Visual effect during roll (motion blur or trail)

### 10. Throttle control

Speed up/slow down with throttle. Affects ground scroll speed and enemy approach rate.

**Acceptance criteria:**
- [ ] Throttle up/down with dedicated keys (e.g., Shift/Ctrl or triggers)
- [ ] Ground scroll speed changes with throttle
- [ ] Enemy approach speed changes with throttle
- [ ] Speed indicator on HUD reflects throttle level
- [ ] At least 3 speed levels

### 11. Sound effects and music

Full audio implementation with SFX and BGM.

**Acceptance criteria:**
- [ ] Vulcan cannon firing SFX
- [ ] Missile launch SFX
- [ ] Lock-on beep SFX
- [ ] Explosion SFX (enemy + player)
- [ ] Engine/afterburner ambient SFX
- [ ] At least 3 BGM tracks (matching original style: upbeat synth/rock)
- [ ] BGM loops correctly
- [ ] SFX don't cut each other off inappropriately

**Notes:** Audio can use placeholder/generated sounds initially. The key is having the right audio cues in the right places. Original had very distinctive sounds for lock-on and missile launch.

### 12. Screen shake and juice effects

Visual feedback effects that make the game feel impactful.

**Acceptance criteria:**
- [ ] Screen shake on explosions
- [ ] Screen shake on player hit
- [ ] Flash effect on enemy destruction
- [ ] Speed lines or motion blur at high throttle
- [ ] Subtle camera sway during normal flight

## Priority: Low

### 13. High score system

Persistent high score table.

**Acceptance criteria:**
- [ ] Top 10 high scores saved to disk
- [ ] Name entry on new high score (3-character initials, arcade style)
- [ ] High score table displayed on title screen

### 14. Pause menu

Simple pause functionality.

**Acceptance criteria:**
- [ ] Pause with ESC / Start button
- [ ] "PAUSED" overlay
- [ ] Resume or quit options

---

## Done

<!-- TL moves completed items here with issue references -->
