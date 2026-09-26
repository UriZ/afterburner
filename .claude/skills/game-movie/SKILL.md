---
name: game-movie
description: Deterministic 60fps gameplay capture via Godot MovieWriter, with frame-scheduled input. Exact time base — use this for motion-metrics comparison and any speed work.
user-invocable: true
argument-hint: "[--duration SECS] [--fps N] [--output FILE] [--input-script FILE] [--seed N] [--port N]"
allowed-tools: Bash, Read
---

# Game Movie Capture (60fps, deterministic)

## 1. What this is, and when to use it instead of `game-video`

| | `game-video` (TCP bridge) | `game-movie` (MovieWriter) |
|---|---|---|
| Rate | ~12 fps in gameplay, jittery | **Exactly** `--fps`, 60 by default |
| Time base | Wall clock, measured per run | **Game time — exact by construction** |
| Input | Live, wall-clock timed | Frame-scheduled timeline |
| Reproducible | No | Yes, with `--seed` |
| Headless | Yes | **No** — MovieWriter SIGABRTs headless |
| Speed | Roughly real time | Untied from real time |

Use `game-movie` for anything quantitative: motion-metrics comparison, and the
60fps footage #113's deferred speed metric requires. Use `game-video` for quick
interactive looks and for anything that must run headless.

The container fps here is not a label that happens to be right — game time *is*
the time base, so `--fps 60` means the mp4 contains exactly `60 x duration`
frames at exactly `60/1`. That is the property that makes it usable for speed
work, and the selftest refuses to tolerate any deviation from it.

## 2. Quick start

```bash
# 10 seconds of gameplay at 60fps, starting from the title screen
bash .claude/skills/game-movie/capture-movie.sh --port 9580 --output /tmp/game-capture/movie.mp4

# Reproducible: same seed, same timeline, byte-identical output
bash .claude/skills/game-movie/capture-movie.sh --duration 8 --seed 4242 --port 9581

# Feed straight into motion-metrics — no --game-true-fps needed, the sidecar has it
bash .claude/skills/motion-metrics/compare.sh \
  --ref .reference-cache/video/ab2-longplay.mp4 --ref-window 6:00-6:08 \
  --game /tmp/game-capture/movie.mp4 --game-window 2-10 --name judge-<issue>
```

**Note the `--game-window 2-10`.** The default timeline spends its first ~1.7
seconds on the title screen and music select, so a window starting at 0 compares
arcade gameplay against our menus. Skip the first two seconds, or write a
timeline that gets in faster.

## 3. Options

| Flag | Default | Meaning |
|---|---|---|
| `--duration` | `10` | Seconds of **game** time |
| `--fps` | `60` | Movie fps, and the fixed timestep |
| `--output` | `/tmp/game-capture/movie.mp4` | Final mp4; sidecar is `<output>.json` |
| `--input-script` | `timelines/start-game.json` | Timeline to play |
| `--no-input` | off | No timeline at all (title-screen capture) |
| `--seed` | unset | Deterministic RNG seed (§6) |
| `--port` | `9580` | `--mcp-port` for the bridge; distinct per concurrent agent |
| `--keep-avi` | off | Keep the intermediate MJPEG AVI |

Exit codes: `0` ok · `2` usage, bad timeline, or a `--seed` that cannot take
effect · `3` missing ffmpeg/ffprobe/Godot · `4` capture or verification failed.

## 4. Input timelines

Input is scheduled against the **frame counter**, never the wall clock. It has
to be: game time and real time have no fixed relationship under MovieWriter —
measured at 66%, 74%, 100% and 150% of real-time on this machine — so
`sleep 1; send Enter` lands on a different game frame every run, which is
exactly the non-determinism this skill exists to remove.

```json
{
  "schema": "capture-input/1",
  "events": [
    {"frame": 30,  "action": "key",      "key": "Enter"},
    {"frame": 150, "action": "key_down", "key": "Z"},
    {"frame": 450, "action": "key_up",   "key": "Z"}
  ]
}
```

- `frame` — 1-based `_process` index at which the event is **applied**. Integer >= 1.
- `action` — `key` (tap), `key_down`, `key_up`.
- `key` — resolved by `OS.find_keycode_from_string()`, the same vocabulary the
  TCP bridge uses. There is deliberately no second key-name table.

Timelines are validated **before** Godot launches, so a typo costs a second
rather than a ten-second capture. Events scheduled past the end of the run are
ignored with a warning naming them, so a timeline can be reused against a
shorter capture.

### The one-frame offset — it is load-bearing

> **An event applied at frame F is observable to game logic from frame F+1.**

`Input.parse_input_event()` is flushed at the start of the *next* frame. This is
stated rather than silently compensated for, because a hidden `-1` becomes an
off-by-one the day the engine changes. Selftest test 4 pins it.

Consequently a `key` tap presses at F and releases at F+1, giving exactly one
frame on which the key reads as held. Pressing and releasing within a single
frame makes level-triggered reads (`is_action_pressed`, `get_axis`) miss it
entirely — the #91 finding the bridge's `key_down`/`key_up` split already encodes.

### Why events set `physical_keycode`

**Every action in `project.godot` binds `physical_keycode` with `keycode: 0`.**
An `InputEventKey` carrying only `keycode` is completely inert for gameplay —
`Input.is_action_pressed()` never fires — while still reading as pressed via
`Input.is_key_pressed()`. Measured, not assumed: the selftest's negative control
sends a keycode-only event and records `is_action_pressed=0` alongside
`is_key_pressed=1`.

So if you write any input tooling for this project: set both fields, and test
through the action system. A test written the obvious way goes green on an
implementation that cannot drive the game at all.

## 5. Sidecar

`<output>.json`, in `game-video-capture/1` — the same schema `game-video`
writes, so `motion-metrics` consumes it with no changes (it reads only
`measured_fps`; verified against `motion_metrics.py`, which does not inspect
`schema` at all).

```json
{
  "schema": "game-video-capture/1",
  "source": "movie-writer",
  "frames": 480,
  "requested_fps": 60.0,
  "measured_fps": 60.0,
  "encoded_fps": 60.0,
  "wall_elapsed_s": 10.9802,
  "paced": true,
  "captured_utc": "...",
  "input_script": "...",
  "seed": 7
}
```

Two things to understand about it:

**`wall_elapsed_s` is diagnostics only. It is NOT the time base.** The real
duration is `frames / measured_fps`. If a future consumer treats wall clock as
the time base it reintroduces exactly the #116 bug this whole line of work
exists to fix.

**`interval_mean_s`, `interval_stdev_s`, `interval_max_s` and `pacing_slip` are
deliberately absent.** In `game-video-capture/1` those are wall-clock statistics
from per-frame receipt stamps. There is no such measurement here, and writing
`0.0` / `false` would be a false statement about a run whose real frame spacing
was nothing of the sort. A missing diagnostic is honest; a fabricated one is
not. Consumers already tolerate unknown keys, and omitting a key changes no
existing key's meaning, so the schema version stands.

## 6. Reproducibility

"Deterministic" means two different things here and they are worth separating:

- **Deterministic timing** — guaranteed by MovieWriter with no game change.
  This is what the speed metric needs.
- **Reproducible content** — needs `--seed`, and matters for A/B-ing the same
  scenario across builds.

Without a seed, `game_manager_2d.gd` calls `randomize()` — added deliberately in
#103, because without it every playthrough generated identical enemy formations.
That is not removed. With `--seed N` the same code path calls `seed(N)` instead,
so normal play is bit-for-bit unchanged and captures become reproducible on
demand. Two `--seed 4242` runs produce byte-identical mp4s; two unseeded runs do
not. Both directions are asserted, because a conditional like this is just as
easy to wire inverted as correct.

A `--seed` that cannot take effect is refused with exit 2 rather than silently
producing a non-reproducible capture under a flag that promises one.

**Divergence needs run length to become visible.** The default timeline spends
its first ~1.7s on menus, and two unseeded runs stay bit-identical for a while
after that — measured divergence began at frame 125 (~2.1s). A capture shorter
than about 5 seconds may contain too little gameplay for RNG to have diverged
at all, so two unseeded short runs can come out byte-identical and look as
though seeding is broken when it is not. Use `--duration 5` or more when you are
specifically checking seed behaviour; the selftest does.

## 7. Limits

- **Windowed only.** `--headless --write-movie` SIGABRTs (exit 134) and leaves a
  332-byte stub. Capture needs a display, so this cannot run on a headless CI
  box as-is. MovieWriter renders offscreen, so ordinary window overlap is
  harmless — but do not minimise the window.
- **Concurrent captures each open a window** and each need a distinct `--port`.
- **The MJPEG intermediate is large** — roughly 13 MB/s of capture, so a
  60-second run needs ~800 MB of scratch before transcode. It lives in `/tmp`
  and is deleted unless `--keep-avi`. Never write it into the repo.
- **Capture is not real-time**, in either direction. Do not time anything by
  wall clock around it.
- The reference side is still 30fps; fetching 60fps arcade footage is a separate
  piece of work (60fps exists only at 720p and above for the mandated longplay).

## 8. Validation

```bash
bash .claude/skills/game-movie/selftest.sh
```

44 assertions across the 11 areas in the spec: exact frame counts at 60 and 30
fps, sidecar contents including the four deliberately-omitted keys, the F+1
offset asserted through `Input.is_action_pressed` **plus a negative control
proving a keycode-only event would falsely pass**, seven timeline-rejection
cases (each also asserting no capture started), out-of-range warnings, seed
reproducibility and unseeded divergence, autoload inertness, AVI cleanup, and an
end-to-end run into `motion-metrics`.

Test 1 is the known-answer control and it has a pre-stated abandonment
tolerance: a 2-second capture must contain exactly 120 frames at exactly `60/1`.
**If it is off by even one frame, stop and report rather than widening the
assertion** — exactness is the whole value here, and a tool that needs a fudge
factor has lost the property the speed work depends on.

Ports are allocated from 9590 upward, skipping any already bound, so a
concurrent agent's Godot cannot turn into a bogus test failure — or, worse, a
bogus pass from answering a probe itself.
