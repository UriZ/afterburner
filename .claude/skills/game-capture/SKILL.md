---
name: game-capture
description: Capture a sequence of gameplay screenshots over time for visual QA and judge evaluation. Provides temporal information — movement, speed, explosions, enemy flow — that a single screenshot cannot.
user-invocable: true
argument-hint: "[--frames N] [--interval MS] [--start-game] [--output-dir DIR]"
allowed-tools: Bash, Read
---

# Game Capture Skill

Captures a burst of gameplay screenshots via the MCP bridge TCP port, giving judges and QA agents temporal context to evaluate movement, speed, and gameplay feel.

## How It Works

1. Connects to the running Godot game via TCP port 9501
2. Takes N screenshots at regular intervals
3. Saves each as a numbered PNG
4. Prints all paths so agents can Read each frame

## Usage

```bash
bash .claude/skills/game-capture/capture.sh [OPTIONS]
```

### Options
- `--frames N` — Number of screenshots to capture (default: 8)
- `--interval MS` — Milliseconds between frames (default: 500)
- `--start-game` — Press Enter twice to get past title screen before capturing
- `--output-dir DIR` — Where to save PNGs (default: /tmp/game-capture)

### Examples

```bash
# Quick 8-frame capture (4 seconds of gameplay)
bash .claude/skills/game-capture/capture.sh

# Dense 15-frame capture for speed evaluation
bash .claude/skills/game-capture/capture.sh --frames 15 --interval 300

# Start from title screen
bash .claude/skills/game-capture/capture.sh --start-game --frames 10

# Long capture for full wave evaluation
bash .claude/skills/game-capture/capture.sh --frames 20 --interval 1000
```

## After Running

1. Script prints screenshot paths to stdout
2. **Read ALL frames** with the Read tool to evaluate temporal behavior
3. Look for:
   - Ground movement between frames (speed feel)
   - Enemy approach and scaling (Super Scaler effect)
   - Explosions appearing and dissipating
   - Crosshair/lock-on behavior
   - Screen busyness over time
   - Player jet banking animation

## For Judges

When evaluating visual work, ALWAYS use this skill instead of a single screenshot. A single frame cannot show:
- Whether the ground feels fast
- Whether explosions are dramatic (they last ~1 second)
- Whether enemies scale smoothly as they approach
- Whether the screen stays busy over time
- Whether aiming/lock-on responds to input
