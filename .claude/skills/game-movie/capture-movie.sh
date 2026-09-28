#!/bin/bash
# 60fps deterministic gameplay capture via Godot MovieWriter (#114).
#
# Unlike the TCP-bridge path (game-video), this has an EXACT time base: game
# time is authoritative, --fixed-fps gives a true fixed timestep, and the
# container fps is a fact rather than a label. Input is scheduled against the
# frame counter, not the wall clock, because game time and real time have no
# fixed relationship (measured at 66%, 74%, 100% and 150% of real-time).
#
# Usage: bash capture-movie.sh [--duration SECS] [--fps N] [--output FILE]
#                              [--input-script FILE] [--no-input] [--seed N]
#                              [--port N] [--keep-avi]

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

DURATION=10
FPS=60
OUTPUT="/tmp/game-capture/movie.mp4"
INPUT_SCRIPT=""
NO_INPUT=false
SEED=""
PORT=9580
KEEP_AVI=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --duration) DURATION="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --input-script) INPUT_SCRIPT="$2"; shift 2 ;;
    --no-input) NO_INPUT=true; shift ;;
    --seed) SEED="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --keep-avi) KEEP_AVI=true; shift ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $1" >&2; exit "${2:-2}"; }

# ---------------------------------------------------------------- validation
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found. brew install ffmpeg" 3
command -v ffprobe >/dev/null 2>&1 || die "ffprobe not found. brew install ffmpeg" 3
[ -x "$GODOT" ] || die "Godot not found at $GODOT (set GODOT=/path/to/Godot)" 3

python3 -c "
import sys
d, f = float('$DURATION'), float('$FPS')
sys.exit(0 if d > 0 and f > 0 else 1)
" 2>/dev/null || die "--duration and --fps must both be > 0 (got $DURATION, $FPS)"

if [ "$NO_INPUT" = true ] && [ -n "$INPUT_SCRIPT" ]; then
  die "--no-input and --input-script are mutually exclusive"
fi
if [ "$NO_INPUT" != true ] && [ -z "$INPUT_SCRIPT" ]; then
  INPUT_SCRIPT="$SKILL_DIR/timelines/start-game.json"
fi

# A --seed that cannot take effect is worse than no --seed: it promises a
# reproducible capture and silently delivers a randomize()'d one.
if [ -n "$SEED" ]; then
  if ! grep -q "CaptureInput.requested_seed" "$PROJ_DIR/scripts/game/game_manager_2d.gd" 2>/dev/null; then
    die "--seed given but the seed conditional is missing from game_manager_2d.gd — rebuild required"
  fi
  case "$SEED" in (''|*[!0-9]*) die "--seed must be a non-negative integer, got '$SEED'" ;; esac
fi

FRAMES=$(python3 -c "import math; print(math.ceil(float('$DURATION') * float('$FPS')))")
[ "$FRAMES" -ge 1 ] || die "--duration x --fps must yield at least 1 frame"

# Structural timeline check first: it needs no engine and gives the better error
# message. Key NAMES are then checked by Godot itself below, so there is exactly
# one key-name vocabulary in the system rather than a shell copy that can drift.
if [ -n "$INPUT_SCRIPT" ]; then
  [ -f "$INPUT_SCRIPT" ] || die "--input-script not found: $INPUT_SCRIPT"
  python3 - "$INPUT_SCRIPT" <<'PY' || exit 2
import json, sys
path = sys.argv[1]
try:
    with open(path) as fh:
        data = json.load(fh)
except Exception as exc:
    print("ERROR: %s is not valid JSON: %s" % (path, exc), file=sys.stderr); sys.exit(2)
if not isinstance(data, dict):
    print("ERROR: %s must be a JSON object" % path, file=sys.stderr); sys.exit(2)
if data.get("schema") != "capture-input/1":
    print("ERROR: %s has schema %r, expected 'capture-input/1'"
          % (path, data.get("schema")), file=sys.stderr); sys.exit(2)
events = data.get("events")
if not isinstance(events, list):
    print("ERROR: %s has no 'events' array" % path, file=sys.stderr); sys.exit(2)
for i, ev in enumerate(events):
    where = "%s event %d" % (path, i)
    if not isinstance(ev, dict):
        print("ERROR: %s is not an object" % where, file=sys.stderr); sys.exit(2)
    frame = ev.get("frame")
    if not isinstance(frame, (int, float)) or isinstance(frame, bool) \
            or float(frame) != int(frame) or int(frame) < 1:
        print("ERROR: %s has frame %r — must be an integer >= 1" % (where, frame),
              file=sys.stderr); sys.exit(2)
    if ev.get("action") not in ("key", "key_down", "key_up"):
        print("ERROR: %s has action %r — expected key, key_down or key_up"
              % (where, ev.get("action")), file=sys.stderr); sys.exit(2)
    if not isinstance(ev.get("key"), str) or not ev["key"]:
        print("ERROR: %s has key %r — expected a non-empty string"
              % (where, ev.get("key")), file=sys.stderr); sys.exit(2)
PY

  # Dry run: loads the timeline through the real resolver and quits. Headless is
  # fine here precisely because we are NOT writing a movie. --fixed-fps "$FPS"
  # is required here too (#141): CaptureInput now refuses to schedule a
  # timeline outside a fixed time base matching its assumed 60fps, and an
  # unpaced headless frame is nowhere near that — the dry run would otherwise
  # FATAL on every default invocation before ever reaching the real capture.
  DRY_LOG=$(mktemp)
  "$GODOT" --headless --fixed-fps "$FPS" --path "$PROJ_DIR" --quit-after 1 -- \
    --mcp-port "$PORT" --capture-input "$INPUT_SCRIPT" > "$DRY_LOG" 2>&1
  DRY_RC=$?
  if [ "$DRY_RC" -eq 3 ]; then
    grep "CaptureInput: FATAL" "$DRY_LOG" >&2 || tail -5 "$DRY_LOG" >&2
    rm -f "$DRY_LOG"
    exit 2
  elif [ "$DRY_RC" -ne 0 ]; then
    echo "ERROR: timeline pre-flight failed (Godot exit $DRY_RC)" >&2
    tail -10 "$DRY_LOG" >&2
    rm -f "$DRY_LOG"
    exit 4
  fi
  rm -f "$DRY_LOG"
fi

# ------------------------------------------------------------------- capture
mkdir -p "$(dirname "$OUTPUT")"
# MJPEG intermediate runs ~13 MB/s of capture, so it lives in /tmp, never the repo.
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/game-movie-$PORT.XXXXXX")
AVI="$TMP_DIR/cap.avi"
LOG="$TMP_DIR/godot.log"
cleanup() { [ "$KEEP_AVI" = true ] || rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# --mute-audio (#143): a spawned instance, not a manual launch — the Master
# bus is audible by default since #138, and up to 6 of these can run
# concurrently during a pipeline wave.
GODOT_ARGS=(--path "$PROJ_DIR" --write-movie "$AVI" --fixed-fps "$FPS"
            --quit-after "$FRAMES" --disable-vsync -- --mcp-port "$PORT" --mute-audio)
[ -n "$INPUT_SCRIPT" ] && GODOT_ARGS+=(--capture-input "$INPUT_SCRIPT")
[ -n "$SEED" ] && GODOT_ARGS+=(--capture-seed "$SEED")

echo "Capturing $FRAMES frames at ${FPS}fps (${DURATION}s game time) on port $PORT..."
[ -n "$INPUT_SCRIPT" ] && echo "Timeline: $INPUT_SCRIPT"
# MovieWriter CANNOT run headless — it SIGABRTs (exit 134) and leaves a 332-byte
# stub. A window is required; MovieWriter renders offscreen so ordinary overlap
# is harmless, but do not minimise it.
WALL_START=$(python3 -c "import time; print(time.monotonic())")
"$GODOT" "${GODOT_ARGS[@]}" > "$LOG" 2>&1
GODOT_RC=$?
WALL_ELAPSED=$(python3 -c "import time; print(round(time.monotonic() - $WALL_START, 4))")

if [ "$GODOT_RC" -ne 0 ]; then
  echo "ERROR: Godot exited $GODOT_RC during capture." >&2
  grep -E "FATAL|ERROR|error" "$LOG" | head -10 >&2
  tail -10 "$LOG" >&2
  KEEP_AVI=true  # leave the scratch dir for diagnosis
  exit 4
fi

# Surface the autoload's own diagnostics. Godot's output goes to a scratch log so
# the summary stays readable, but a swallowed warning is a warning that does not
# exist — "N timeline events never fired" is exactly what the operator needs.
grep -E "CaptureInput:" "$LOG" | grep -vE "^CaptureInput: [0-9]+ scheduled" >&2 || true

# --------------------------------------------------------------- verification
# ALWAYS verify the artifact with ffprobe, never the engine's own stdout summary.
# Not because the console is known to lie — it agreed on this build — but
# because a producer's self-report is not evidence about what it produced.
probe_frames() {
  ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$1"
}
probe_rate() {
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$1"
}

[ -f "$AVI" ] || { echo "ERROR: no AVI produced at $AVI" >&2; exit 4; }
AVI_FRAMES=$(probe_frames "$AVI")
AVI_RATE=$(probe_rate "$AVI")
if [ "$AVI_FRAMES" != "$FRAMES" ] || [ "$AVI_RATE" != "$FPS/1" ]; then
  echo "ERROR: AVI does not match the request." >&2
  echo "  frames:   expected $FRAMES, ffprobe says $AVI_FRAMES" >&2
  echo "  fps:      expected $FPS/1, ffprobe says $AVI_RATE" >&2
  echo "MovieWriter's whole value is exactness — this is a report, not something to tolerate." >&2
  KEEP_AVI=true
  exit 4
fi

echo "Transcoding to mp4..."
ffmpeg -v error -y -i "$AVI" -c:v libx264 -crf 16 -pix_fmt yuv420p -an "$OUTPUT" || {
  echo "ERROR: ffmpeg transcode failed." >&2; KEEP_AVI=true; exit 4; }

MP4_FRAMES=$(probe_frames "$OUTPUT")
MP4_RATE=$(probe_rate "$OUTPUT")
if [ "$MP4_FRAMES" != "$FRAMES" ] || [ "$MP4_RATE" != "$FPS/1" ]; then
  echo "ERROR: mp4 drifted from the AVI during transcode." >&2
  echo "  frames:   expected $FRAMES, ffprobe says $MP4_FRAMES" >&2
  echo "  fps:      expected $FPS/1, ffprobe says $MP4_RATE" >&2
  KEEP_AVI=true
  exit 4
fi

# ------------------------------------------------------------------- sidecar
python3 - "$OUTPUT" "$FRAMES" "$FPS" "$WALL_ELAPSED" "${INPUT_SCRIPT:-}" "${SEED:-}" <<'PY'
import json, sys, time
out, frames, fps, wall, timeline, seed = sys.argv[1:7]
sidecar = {
    "schema": "game-video-capture/1",
    "source": "movie-writer",
    "output": out,
    "frames": int(frames),
    "requested_fps": float(fps),
    # Exact, not estimated: game time is authoritative under MovieWriter, so the
    # measured rate IS the requested rate and the container fps agrees.
    "measured_fps": float(fps),
    "encoded_fps": float(fps),
    # DIAGNOSTICS ONLY. This is NOT the time base — game time and wall clock have
    # no fixed relationship. frames/measured_fps is the real duration.
    "wall_elapsed_s": float(wall),
    "paced": True,
    "captured_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
# interval_mean_s / interval_stdev_s / interval_max_s / pacing_slip are
# deliberately ABSENT. In game-video-capture/1 they are wall-clock statistics
# from per-frame receipt stamps; there is no such measurement here, and writing
# 0.0 / false would be a false statement about a run whose wall-clock frame
# spacing was nothing of the sort. A missing diagnostic is honest, a fabricated
# one is not — and the schema's own rule is that unknown keys are tolerated,
# so omission needs no version bump (#114 judge gate).
if timeline:
    sidecar["input_script"] = timeline
if seed:
    sidecar["seed"] = int(seed)
with open(out + ".json", "w") as fh:
    json.dump(sidecar, fh, indent=2)
    fh.write("\n")
PY

FILESIZE=$(du -h "$OUTPUT" | cut -f1)
echo ""
echo "Movie saved: $OUTPUT ($FILESIZE)"
echo "Frames: $FRAMES | fps: $FPS (exact) | Game duration: $(python3 -c "print(f'{$FRAMES/$FPS:.3f}')")s"
echo "Wall clock: ${WALL_ELAPSED}s (diagnostics only — NOT the time base)"
echo "Timeline: ${INPUT_SCRIPT:-<none>} | Seed: ${SEED:-<unset>}"
echo "Timing sidecar: ${OUTPUT}.json"
[ "$KEEP_AVI" = true ] && echo "Intermediate AVI kept: $AVI"
exit 0
