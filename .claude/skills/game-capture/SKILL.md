---
name: game-capture
description: Capture a sequence of gameplay screenshots over time for visual QA and judge evaluation. Provides temporal information — movement, speed, explosions, enemy flow — that a single screenshot cannot.
user-invocable: true
argument-hint: "[--frames N] [--interval MS] [--start-game] [--output-dir DIR] [--port N]"
allowed-tools: Bash, Read
---

# Game Capture Skill

Captures a burst of gameplay screenshots via the MCP bridge TCP port, giving judges and QA agents temporal context to evaluate movement, speed, and gameplay feel.

## How It Works

1. Connects to the running Godot game via TCP port 9501 (or `--port`)
2. Takes N screenshots at regular intervals, retrying a failed frame up to 3 times
3. Saves each as a numbered PNG
4. Prints all paths so agents can Read each frame
5. Fails loudly (non-zero exit) if it could not capture the full requested frame count — it never hands back a silently partial set

## Held Input Over the MCP Bridge

The bridge's legacy `{"cmd":"key","key":"Z"}` presses and releases in the same
frame's input flush, so it's invisible to level-triggered reads
(`is_action_pressed`, `Input.get_axis`) — fine for menu taps, useless for
"hold Z to fire" or "hold Left to bank". For anything that needs to be seen
as held across frames, use instead (all sent as raw JSON over the same TCP
port, e.g. via `nc`):
- `{"cmd":"key_down","key":"Z"}` / `{"cmd":"key_up","key":"Z"}` — press/release explicitly, held until you send key_up
- `{"cmd":"hold","key":"Left","ms":1500}` — press now, auto-release after `ms` (capped at 5000) via a real Timer, not a same-frame deferred call
All held keys are force-released on any scene change (title/game/game-over transitions), so a stuck hold can't leak into the next run.

## Usage

```bash
bash .claude/skills/game-capture/capture.sh [OPTIONS]
```

### Options
- `--frames N` — Number of screenshots to capture (default: 8)
- `--interval MS` — Milliseconds between frames (default: 500)
- `--start-game` — Press Enter twice to get past title screen before capturing
- `--output-dir DIR` — Where to save PNGs (default: /tmp/game-capture)
- `--port N` — MCP bridge TCP port (default: 9501). Use a distinct port per concurrent agent — see Concurrency below.

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

# Isolated instance for a parallel agent
bash .claude/skills/game-capture/capture.sh --start-game --port 9502 --frames 10
```

## Concurrency

When multiple agents capture at the same time, **each must pass a distinct `--port`** (e.g. 9502, 9503, ...) whenever it uses `--start-game`.

With `--start-game`, this script only ever starts or stops the Godot process **it itself spawned for that port** (tracked in `/tmp/afterburner-capture/godot-<port>.pid`). It never kills a Godot instance it did not launch:
- If the script previously started an instance on that port, a new `--start-game` call restarts just that one (clean state for a re-test).
- If the port is already occupied by something this script never started (another agent's instance, or a manually launched one), the script fails immediately with a clear error naming the PID — it does not touch it. Pick a different port or stop that process yourself.

Without `--start-game`, the script just captures against whatever is already listening on `--port` (default 9501) — this is the common case when a game is already running and you only need frames.

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

## Capturing a non-main-scene harness (e.g. tests/sky_stage_preview.gd)

`--start-game` only knows how to launch the real game scene. To capture a visual harness script instead (verified pattern from #115 QA):
1. Stop any capture.sh-managed instance on your port
2. Launch Godot manually with `--script <harness.gd>` (windowed — headless fails on texture readback)
3. Capture with capture.sh WITHOUT `--start-game` against the same `--port`

The harness's usage header governs its own controls (e.g. stage cycling).
