---
name: game-video
description: Capture real gameplay video (mp4) via TCP bridge frame capture + ffmpeg encoding. Produces actual video files for side-by-side comparison with arcade footage.
user-invocable: true
argument-hint: "[--duration SECS] [--playback-fps N] [--start-game] [--output FILE] [--port N]"
allowed-tools: Bash, Read
---

# Game Video Capture Skill

Records actual mp4 video of gameplay by rapidly capturing frames via the TCP bridge and encoding them with ffmpeg. Unlike the game-capture skill (which produces individual PNGs), this produces a real video file you can play, share, and compare side-by-side with original After Burner II arcade footage.

## Requirements

- ffmpeg installed (`brew install ffmpeg`)
- Godot game running with MCP bridge on TCP port 9501 (or `--port`)

## Usage

```bash
bash .claude/skills/game-video/capture-video.sh [OPTIONS]
```

### Options
- `--duration SECS` — Recording length in seconds (default: 5)
- `--playback-fps N` — Frames per second, both captured and encoded (default: 10, max ~20 via TCP)
- `--start-game` — Press Enter twice to get past title screen first
- `--output FILE` — Output mp4 path (default: /tmp/game-capture/gameplay.mp4)
- `--port N` — MCP bridge TCP port (default: 9501). Use a distinct port per concurrent agent — see Concurrency below.

### Examples

```bash
# Quick 5-second gameplay clip
bash .claude/skills/game-video/capture-video.sh

# 10-second recording from title screen at 20fps
bash .claude/skills/game-video/capture-video.sh --start-game --duration 10 --playback-fps 20

# Record a specific moment
bash .claude/skills/game-video/capture-video.sh --duration 3 --playback-fps 15 --output /tmp/boss-fight.mp4

# Isolated instance for a parallel agent
bash .claude/skills/game-video/capture-video.sh --start-game --port 9503 --duration 8
```

## Output

- Target frame count is `duration * playback-fps`. The script captures exactly that many frames (retrying a failed one up to 3 times) so the encoded video's length always matches the requested `--duration`.
- If it can't reach the target count — after retries, or after 5 consecutive frame failures (bridge unresponsive) — it **fails loudly**, states how many frames it got, and does not produce a video from a partial set.
- Single mp4 file encoded with H.264 (libx264), CRF 18 (high quality)
- Temporary frame PNGs are cleaned up automatically on success (preserved for debugging on failure)
- File size typically 1-5MB for a 5-second clip

## Concurrency

When multiple agents capture at the same time, **each must pass a distinct `--port`** (e.g. 9502, 9503, ...) whenever it uses `--start-game`.

The port is handed to Godot on its own command line (`-- --mcp-port N`), so concurrent runs share no mutable state — there is no project-wide port config to race over, and no launch lock to wait on. A Godot instance that cannot bind the port it was asked for now **exits with code 9** and says so on stderr, instead of quietly falling back to 9501 and serving somebody else's frames (#117).

With `--start-game`, this script only ever starts or stops the Godot process **it itself spawned for that port** (tracked in `/tmp/afterburner-capture/godot-<port>.pid`). It never kills a Godot instance it did not launch:
- If the script previously started an instance on that port, a new `--start-game` call restarts just that one (clean state for a re-test).
- If the port is already occupied by something this script never started (another agent's instance, or a manually launched one), the script fails immediately with a clear error naming the PID — it does not touch it. Pick a different port or stop that process yourself.

Without `--start-game`, the script just records against whatever is already listening on `--port` (default 9501).

## For Judges

Use this skill to produce video evidence for evaluation:
1. Record 5-10 seconds of gameplay
2. Open the mp4 and watch it — does it feel like After Burner II?
3. Compare with original arcade footage on YouTube
4. Video reveals timing, speed, fluidity that static frames cannot

## Limitations

- TCP bridge throughput caps practical FPS at ~20
- Frame timing may not be perfectly uniform (network jitter)
- Cannot capture audio (bridge only sends screenshots)
