---
name: game-video
description: Capture real gameplay video (mp4) via TCP bridge frame capture + ffmpeg encoding. Produces actual video files for side-by-side comparison with arcade footage.
user-invocable: true
argument-hint: "[--duration SECS] [--fps N] [--start-game] [--output FILE]"
allowed-tools: Bash, Read
---

# Game Video Capture Skill

Records actual mp4 video of gameplay by rapidly capturing frames via the TCP bridge and encoding them with ffmpeg. Unlike the game-capture skill (which produces individual PNGs), this produces a real video file you can play, share, and compare side-by-side with original After Burner II arcade footage.

## Requirements

- ffmpeg installed (`brew install ffmpeg`)
- Godot game running with MCP bridge on TCP port 9501

## Usage

```bash
bash .claude/skills/game-video/capture-video.sh [OPTIONS]
```

### Options
- `--duration SECS` — Recording length in seconds (default: 5)
- `--fps N` — Frames per second (default: 15, max ~20 via TCP)
- `--start-game` — Press Enter twice to get past title screen first
- `--output FILE` — Output mp4 path (default: /tmp/game-capture/gameplay.mp4)

### Examples

```bash
# Quick 5-second gameplay clip
bash .claude/skills/game-video/capture-video.sh

# 10-second recording from title screen at 20fps
bash .claude/skills/game-video/capture-video.sh --start-game --duration 10 --fps 20

# Record a specific moment
bash .claude/skills/game-video/capture-video.sh --duration 3 --fps 15 --output /tmp/boss-fight.mp4
```

## Output

- Single mp4 file encoded with H.264 (libx264), CRF 18 (high quality)
- Temporary frame PNGs are cleaned up automatically
- File size typically 1-5MB for a 5-second clip

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
