#!/bin/bash
# Game Video Capture — records gameplay as mp4 via TCP bridge frame capture + ffmpeg
# Captures a fixed number of frames (duration * playback-fps) PACED against the
# wall clock, measures the rate actually achieved, and encodes at that measured
# rate so playback speed is true (#116). A timing sidecar <output>.json records
# what happened for downstream tools (#113).
# Usage: bash capture-video.sh [--duration SECS] [--playback-fps N] [--start-game] [--output FILE] [--port N]
#
# Concurrency: pass --port with a distinct value per concurrent agent. This
# script only ever starts/stops the Godot process IT spawned for that port —
# it never touches a pre-existing instance it did not launch.

DURATION=5
PLAYBACK_FPS=10
START_GAME=false
OUTPUT="/tmp/game-capture/gameplay.mp4"
PORT=9501

while [[ $# -gt 0 ]]; do
  case $1 in
    --duration) DURATION="$2"; shift 2 ;;
    --playback-fps) PLAYBACK_FPS="$2"; shift 2 ;;
    --start-game) START_GAME=true; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Port-scoped scratch dir. The old fixed path meant two concurrent agents on
# distinct ports shared one frame directory and `rm -rf`'d each other's frames
# mid-run — the same class of cross-agent aliasing #117 fixed for the port
# itself. Must be resolved after argument parsing, since it depends on $PORT.
FRAME_DIR="/tmp/game-capture/video-frames-$PORT"

mkdir -p "$(dirname "$OUTPUT")"
rm -rf "$FRAME_DIR"
mkdir -p "$FRAME_DIR"

PROJ_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_DIR="/tmp/afterburner-capture"
mkdir -p "$STATE_DIR"
PID_FILE="$STATE_DIR/godot-$PORT.pid"

# The port is passed to Godot on its own command line (`-- --mcp-port N`), so
# concurrent runs share no mutable state and need no launch lock (#117). See
# the matching comment in game-capture/capture.sh for the failure this fixes.
# Only the port/launch path changed here — frame grabbing and encoding are
# untouched and remain owned by the #113/#116 time-base work.

port_listener_pid() {
  lsof -i "tcp:$PORT" -sTCP:LISTEN -t 2>/dev/null | head -1
}

# Start game if requested — restarts only the Godot instance THIS script
# previously spawned for $PORT (tracked via PID_FILE). Never kills a process
# it did not launch.
if [ "$START_GAME" = true ]; then
  if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    rm -f "$PID_FILE"
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null && ps -p "$OLD_PID" -o comm= 2>/dev/null | grep -qi godot; then
      echo "Stopping our previous Godot instance on port $PORT (PID $OLD_PID)..."
      kill "$OLD_PID" 2>/dev/null
      for _ in $(seq 1 15); do
        kill -0 "$OLD_PID" 2>/dev/null || break
        sleep 0.3
      done
      if kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
        sleep 0.5
      fi
    fi
  fi

  EXISTING_PID=$(port_listener_pid)
  if [ -n "$EXISTING_PID" ]; then
    echo "ERROR: Port $PORT is already in use by PID $EXISTING_PID, which this script did not spawn." >&2
    echo "Choose a different --port, or stop that process manually." >&2
    exit 1
  fi

  echo "Starting Godot on port $PORT..."
  LOG_FILE=$(mktemp)
  /Applications/Godot.app/Contents/MacOS/Godot --path "$PROJ_DIR" -- --mcp-port "$PORT" > "$LOG_FILE" 2>&1 &
  GODOT_PID=$!
  echo "$GODOT_PID" > "$PID_FILE"

  READY=false
  for _ in $(seq 1 30); do
    if grep -q "MCP Bridge Game: Listening on 127.0.0.1:$PORT" "$LOG_FILE" 2>/dev/null; then
      READY=true
      break
    fi
    if ! kill -0 "$GODOT_PID" 2>/dev/null; then
      break
    fi
    sleep 0.5
  done

  if [ "$READY" != true ]; then
    echo "ERROR: Godot (PID $GODOT_PID) did not confirm listening on port $PORT within 15s." >&2
    echo "--- last log lines ---" >&2
    tail -20 "$LOG_FILE" >&2
    kill "$GODOT_PID" 2>/dev/null
    rm -f "$PID_FILE" "$LOG_FILE"
    exit 1
  fi
  rm -f "$LOG_FILE"

  echo "Godot running on port $PORT (PID $GODOT_PID). Starting game (pressing Enter twice)..."
  echo '{"cmd":"key","key":"Enter"}' | nc -w 2 localhost "$PORT" > /dev/null 2>&1
  sleep 1
  echo '{"cmd":"key","key":"Enter"}' | nc -w 2 localhost "$PORT" > /dev/null 2>&1
  sleep 1
  echo "Game started."
else
  if ! echo '{"cmd":"screenshot"}' | nc -w 2 localhost "$PORT" > /dev/null 2>&1; then
    echo "ERROR: No game responding on port $PORT. Start Godot first or use --start-game." >&2
    exit 1
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_FRAMES=$(python3 -c "import math; print(max(1, math.ceil($DURATION * $PLAYBACK_FPS)))")
echo "Capturing $TARGET_FRAMES frames on port $PORT (target: ${DURATION}s @ ${PLAYBACK_FPS}fps, paced)..."

# One driver process for the whole run instead of an nc+python3 pair per frame.
# It paces the grabs against an absolute wall-clock schedule and reports the
# rate it actually achieved on stdout as JSON; progress goes to stderr.
CAPTURE_JSON=$(python3 "$SCRIPT_DIR/capture_frames.py" \
  --port "$PORT" --frames "$TARGET_FRAMES" --fps "$PLAYBACK_FPS" --dir "$FRAME_DIR")
DRIVER_STATUS=$?

if [ "$DRIVER_STATUS" -ne 0 ] || [ -z "$CAPTURE_JSON" ]; then
  echo "ERROR: capture driver failed (exit $DRIVER_STATUS) and produced no timing data." >&2
  echo "Partial frames preserved at: $FRAME_DIR" >&2
  exit 1
fi

# Unpack the driver's JSON in one python call. Every emitted value is a number
# or a bare true/false, so eval is safe here. CAPTURED is pre-set so a malformed
# payload fails the check below instead of leaving it unset and tripping bash's
# integer comparison into a confusing error.
CAPTURED=0
eval "$(printf '%s' "$CAPTURE_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("CAPTURED=%d" % d["captured"])
print("MEASURED_FPS=%s" % d.get("measured_fps", 0))
print("WALL_ELAPSED=%s" % d.get("wall_elapsed_s", 0))
print("IV_MEAN=%s" % d.get("interval_mean_s", 0))
print("IV_STDEV=%s" % d.get("interval_stdev_s", 0))
print("IV_MAX=%s" % d.get("interval_max_s", 0))
print("PACING_SLIP=%s" % ("true" if d.get("pacing_slip") else "false"))
')"

if [ "$CAPTURED" -lt "$TARGET_FRAMES" ]; then
  echo "ERROR: Only captured $CAPTURED of $TARGET_FRAMES requested frames. Video not created." >&2
  echo "Partial frames preserved at: $FRAME_DIR" >&2
  exit 1
fi

# A rate needs at least two frames to have any meaning. Without one there is no
# honest time base to encode at, so refuse rather than fall back to the label
# that #116 exists to stop trusting.
if [ "$CAPTURED" -lt 2 ]; then
  echo "ERROR: captured only $CAPTURED frame — a capture rate needs at least 2." >&2
  echo "Increase --duration or --playback-fps. Frames preserved at: $FRAME_DIR" >&2
  exit 1
fi

echo "Captured all $CAPTURED requested frames."

if [ "$PACING_SLIP" = true ]; then
  {
    echo "WARNING: could not hold ${PLAYBACK_FPS} fps — actual rate was ${MEASURED_FPS} fps."
    echo "The video is encoded at the measured rate so playback speed is correct,"
    echo "but frames are spaced ${IV_MEAN}s apart on average (requested $(python3 -c "print(f'{1/$PLAYBACK_FPS:.4f}')")s)."
    echo "Reduce --playback-fps or close other load for evenly spaced frames."
  } >&2
fi

# Encode frames to mp4 with ffmpeg (frames are sequentially numbered, no gaps).
# -framerate is the MEASURED rate, not the requested one: the container fps is
# the video's time base, and labelling it with a rate that was never achieved is
# exactly the bug #116 fixes.
echo "Encoding video at ${MEASURED_FPS}fps (measured)..."
ffmpeg -y -framerate "$MEASURED_FPS" -i "$FRAME_DIR/frame_%04d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset fast \
  -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
  "$OUTPUT" 2>/dev/null

if [ $? -eq 0 ] && [ -f "$OUTPUT" ]; then
  # Sidecar is written only on success, alongside the mp4, with the full output
  # path as its stem so two videos of the same basename cannot collide.
  printf '%s' "$CAPTURE_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
out = sys.argv[1]
sidecar = {
    "schema": "game-video-capture/1",
    "output": out,
    "frames": d["captured"],
    "requested_fps": d["requested_fps"],
    "measured_fps": d["measured_fps"],
    "encoded_fps": d["measured_fps"],
    "wall_elapsed_s": d["wall_elapsed_s"],
    "interval_mean_s": d["interval_mean_s"],
    "interval_stdev_s": d["interval_stdev_s"],
    "interval_max_s": d["interval_max_s"],
    "paced": d["paced"],
    "pacing_slip": bool(d["pacing_slip"]),
    "captured_utc": d["captured_utc"],
}
with open(out + ".json", "w") as fh:
    json.dump(sidecar, fh, indent=2)
    fh.write("\n")
' "$OUTPUT"

  FILESIZE=$(du -h "$OUTPUT" | cut -f1)
  echo ""
  echo "Video saved: $OUTPUT ($FILESIZE)"
  echo "Frames: $CAPTURED | Requested: ${PLAYBACK_FPS} fps | MEASURED: ${MEASURED_FPS} fps | Encoded at: ${MEASURED_FPS} fps"
  echo "Real elapsed: ${WALL_ELAPSED}s | Frame interval: mean ${IV_MEAN}s, max ${IV_MAX}s, stdev ${IV_STDEV}s"
  echo "Timing sidecar: ${OUTPUT}.json"
  echo ""
  echo "Open with: open $OUTPUT"
else
  echo "ERROR: ffmpeg encoding failed." >&2
  echo "Frames preserved at: $FRAME_DIR" >&2
  exit 1
fi

rm -rf "$FRAME_DIR"
