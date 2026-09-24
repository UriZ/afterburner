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
- `--playback-fps N` — Rate the capture loop is **paced** at. The video is encoded at the rate actually achieved, not this one — see Timing (default: 10)
- `--start-game` — Press Enter twice to get past title screen first
- `--output FILE` — Output mp4 path (default: /tmp/game-capture/gameplay.mp4)
- `--port N` — MCP bridge TCP port (default: 9501). Use a distinct port per concurrent agent — see Concurrency below.

### Examples

```bash
# Quick 5-second gameplay clip
bash .claude/skills/game-video/capture-video.sh

# Record a specific moment
bash .claude/skills/game-video/capture-video.sh --duration 3 --playback-fps 15 --output /tmp/boss-fight.mp4

# Isolated instance for a parallel agent
bash .claude/skills/game-video/capture-video.sh --start-game --port 9503 --duration 8
```

### Canonical evaluation command (source of truth)

`judge.md`, `qa.md`, `criteria.md`, `developer.md` and `ui-designer.md` each carry this command
inline so it can be run without a lookup. **This block is the version they are copies of** — if
the tooling changes, change it here first and then update all five.

```bash
bash .claude/skills/game-video/capture-video.sh --start-game --duration 15 --playback-fps 15 --output /tmp/game-capture/<role>-video.mp4
```

## Timing

The capture loop is **paced**: frame `i` targets wall-clock `t0 + i/playback-fps` on an
absolute schedule, so a slow or retried frame is absorbed instead of accumulating drift.
After the run, the rate actually achieved is computed over the `n-1` inter-frame intervals
and **that** is what ffmpeg encodes at.

This matters because before #116 the loop was unpaced and the encode used
`-framerate <requested>` — a label, not a measurement. Every capture taken that way is
slow motion by an unknown, load-dependent factor (measured between 1.15x and 2.2x).
**The container fps of a bridge capture is only trustworthy for videos produced after
#116.** Legacy clips have no recoverable true rate: re-capture rather than trust them.

### Sidecar

On success only, the script writes `<output>.json` — the full output path with `.json`
appended, so `gameplay.mp4` gives `gameplay.mp4.json` and two videos with the same
basename in different directories cannot collide.

```json
{
  "schema": "game-video-capture/1",
  "output": "/abs/path/gameplay.mp4",
  "frames": 100,
  "requested_fps": 10.0,
  "measured_fps": 10.019,
  "encoded_fps": 10.019,
  "wall_elapsed_s": 9.8813,
  "interval_mean_s": 0.0998,
  "interval_stdev_s": 0.0942,
  "interval_max_s": 1.011,
  "paced": true,
  "pacing_slip": false,
  "captured_utc": "2026-09-24T21:59:30Z"
}
```

All values are JSON numbers or booleans, never strings. Consumers must tolerate unknown
additional keys; `schema` is the compatibility contract and is bumped if any existing key
changes meaning. `motion-metrics/compare.sh` reads `measured_fps` from this file.

### Achievable rates (measured, 2026-09-24)

The ceiling is **content-dependent**, because the bridge PNG-encodes and base64s the whole
viewport per frame:

| Scene | Round trip | Ceiling |
|---|---|---|
| Title screen (flat, compresses small) | ~33 ms | ~30 fps |
| Live gameplay (~675 KB PNG) | ~80 ms | ~12 fps |

So a gameplay capture requested at 15 fps will usually report `pacing_slip: true` on a
busy machine. That is the honest degraded mode, not an error: every sleep is zero, frames
come as fast as the bridge can serve them, and the encode uses the measured rate so
playback speed is still correct. Request 10 fps if you want pacing held exactly — a
steady-state gameplay run at 10 measured **9.995 fps with stdev 0.0062 s** (0.05% rate
error, 6% jitter).

`interval_max_s` is worth reading. Across a dozen runs on 2026-09-24, about half showed a
single **~1.0 s** outlier in a 10 s window while the rest stayed under 0.16 s — consistent
with contention from other agents rather than a fixed engine hitch, but worth reporting if
you see it. Absolute-schedule pacing absorbs it (the mean rate stays correct) and CFR
encoding renders it as one normal-length frame interval rather than a visible pause, so
`interval_max_s` is the only place it shows up.

## Output

- Target frame count is `duration * playback-fps`. The script captures exactly that many frames (retrying a failed one up to 3 times), and because the loop is paced it now really does take about `--duration` seconds of wall clock.
- If it can't reach the target count — after retries, or after 5 consecutive frame failures (bridge unresponsive) — it **fails loudly**, states how many frames it got, preserves the partial frames, and produces neither a video nor a sidecar.
- Fewer than 2 frames is also an error: a rate needs at least one interval to be measured, and there is no honest time base without one.
- Single mp4 file encoded with H.264 (libx264), CRF 18 (high quality), at the **measured** fps
- A `<output>.json` timing sidecar (see Timing)
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

- TCP bridge throughput caps the practical rate at ~12 fps during gameplay, ~30 fps on flat scenes (see Timing)
- Frame spacing is paced and measured, so **mean playback speed is true**. The residual is per-frame jitter: on a steady-state run stdev is ~6% of the interval, but an engine hitch (currently ~1 s, once per ~10 s) lands in `interval_max_s` and is flattened by CFR encoding.
- Heavy concurrent capture by several agents is the most likely cause of `pacing_slip`
- Videos captured before #116 have an unrecoverable true rate — re-capture, don't trust their container fps
- Cannot capture audio (bridge only sends screenshots)

## Concurrency scratch space

Frame PNGs go to `/tmp/game-capture/video-frames-<port>`, scoped per port so concurrent
agents cannot delete each other's frames mid-run. `--output` is **not** port-scoped: pass a
distinct `--output` per agent, or two concurrent runs will overwrite one video and sidecar.
