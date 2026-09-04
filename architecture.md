# Architecture

## Overview

After Burner is a third-person "into the screen" rail shooter built in Godot 4.6. The player's F-14 Tomcat moves freely on a 2D plane (screen X/Y) while the world scrolls toward the camera at high speed, creating the classic pseudo-3D "Super Scaler" effect.

The game uses Godot's 3D renderer with a fixed perspective camera. All game objects (player, enemies, missiles, ground) exist in 3D space, but the visual style uses scaled sprites or flat textured meshes to emulate the pixel-art arcade look.

## Modules

### Module 1: Player

Controls the player's F-14 jet. Handles input (move, fire vulcan, fire missile, barrel roll, throttle), applies screen-space movement constraints, manages weapon cooldowns, missile count, and invincibility frames after taking damage. The player jet visually banks when moving left/right.

### Module 2: Weapons

Vulcan cannon (unlimited ammo, rapid fire, short range) and heat-seeking missiles (limited supply, lock-on targeting, long range). Lock-on works by detecting enemies within a targeting reticle zone. Missiles track their target with homing behavior.

### Module 3: Enemies

Enemy jets that fly toward and past the player in formations. They fire bullets at the player. Types include: standard fighters, fast interceptors, and bombers. Enemy spawning is defined per-stage in wave patterns. Enemies use sprite scaling to simulate depth (small when far, large when close).

### Module 4: Stage Manager

Controls the progression through 23 stages. Each stage defines: ground texture/color, sky gradient, enemy wave patterns, spawn timing, and duration. Between every few stages, a refueling/rearm bonus stage occurs where an ally plane resupplies missiles. The ground scrolls toward the camera using a textured plane with UV scrolling.

### Module 5: Effects

Explosions (enemy destruction, player death), missile smoke trails, afterburner flame on player jet, bullet tracers, and screen shake. All use Godot's GPUParticles3D or animated sprites.

### Module 6: HUD

Minimal arcade-style overlay: score (top), missile count, speed indicator, stage number, and lives remaining. Uses a CanvasLayer with Control nodes.

### Module 7: Game State (Autoload)

Singleton managing: current score, lives, missile count, current stage, game phase (title/playing/game_over/bonus_stage). Persists across scene transitions.

### Module 8: Audio

Manages BGM tracks and SFX. The original game had an iconic soundtrack selection at the start. Music loops per stage, SFX for: vulcan fire, missile launch, lock-on beep, explosion, player death.

## Boundaries

```
Input → Player → Weapons → Projectiles (in 3D space)
                                ↓
StageManager → EnemySpawner → Enemies (in 3D space)
                                ↓
                         Collision Detection
                                ↓
                    Effects + HUD + GameState
                                ↓
                           Audio Manager
```

All gameplay happens in a single 3D scene. No networking. No scene transitions during gameplay (menus are separate scenes).

## Tech Stack

### Godot 4.6 + GDScript

Chosen because: user requirement. GDScript is fast enough for an arcade game. Godot's 3D renderer handles the pseudo-3D perspective natively. Built-in physics and collision detection work for projectile/enemy hit detection.

### Sprite3D for game objects

Sprites placed in 3D space naturally scale with distance from the camera, perfectly replicating the "Super Scaler" effect without manual sprite scaling math.

### GPUParticles3D for effects

Efficient particle systems for explosions, smoke trails, and afterburner flames.

### GUT for testing

Godot Unit Testing framework for testing game logic (scoring, stage progression, collision, weapon mechanics).

## Data Model

- **StageData** (Resource): ground_color, sky_gradient, enemy_waves[], duration, is_bonus
- **EnemyWave** (Resource): enemy_type, count, formation, spawn_delay, approach_path
- **EnemyType** (Resource): sprite, health, speed, fire_rate, score_value
- **PlayerState**: lives, score, missiles, current_stage (managed by GameState autoload)

## Design Principles

- **Arcade feel first** — every decision prioritizes making it feel like the original cabinet
- **Sprite-based visuals** — 2D sprites in 3D space, not 3D models
- **Fixed camera** — camera never moves; player and enemies move in front of it
- **Simple collision** — Area3D with simple shapes, no complex physics
- **60 FPS minimum** — arcade games are smooth; never sacrifice framerate
