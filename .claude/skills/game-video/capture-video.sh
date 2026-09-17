#!/bin/bash
# Game Video Capture — records gameplay as mp4 via TCP bridge frame capture + ffmpeg
# Captures a fixed number of frames (duration * playback-fps) so the encoded
# video always matches the requested duration, then encodes at playback fps.
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
FRAME_DIR="/tmp/game-capture/video-frames"

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

mkdir -p "$(dirname "$OUTPUT")"
rm -rf "$FRAME_DIR"
mkdir -p "$FRAME_DIR"

PROJ_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_DIR="/tmp/afterburner-capture"
mkdir -p "$STATE_DIR"
LOCK_DIR="$STATE_DIR/launch.lock"
PID_FILE="$STATE_DIR/godot-$PORT.pid"
CFG_PATH="$PROJ_DIR/mcp_ports.cfg"

# --- Launch lock: serializes writes to the shared mcp_ports.cfg across
# concurrent capture scripts (game-capture and game-video both use it). ---
acquire_launch_lock() {
  local waited=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 0.2
    waited=$((waited + 1))
    if [ "$waited" -ge 300 ]; then
      echo "ERROR: Timed out waiting for another capture script to finish launching Godot." >&2
      exit 1
    fi
  done
}

release_launch_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null
}

# Always safe to call: no-ops once the lock/cfg are already gone.
cleanup_launch_state() {
  release_launch_lock
  rm -f "$CFG_PATH"
}
trap cleanup_launch_state EXIT INT TERM

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
  acquire_launch_lock
  printf '[mcp]\ngame_port=%s\n' "$PORT" > "$CFG_PATH"

  LOG_FILE=$(mktemp)
  /Applications/Godot.app/Contents/MacOS/Godot --path "$PROJ_DIR" > "$LOG_FILE" 2>&1 &
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

  rm -f "$CFG_PATH"
  release_launch_lock

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

TARGET_FRAMES=$(python3 -c "import math; print(max(1, math.ceil($DURATION * $PLAYBACK_FPS)))")
echo "Capturing $TARGET_FRAMES frames on port $PORT (target: ${DURATION}s @ ${PLAYBACK_FPS}fps playback)..."

CAPTURED=0
CONSECUTIVE_FAILS=0
MAX_CONSECUTIVE_FAILS=5

for i in $(seq 1 "$TARGET_FRAMES"); do
  PADDED=$(printf "%04d" $((CAPTURED + 1)))
  OUTFILE="$FRAME_DIR/frame_${PADDED}.png"

  OK=false
  for attempt in 1 2 3; do
    RESULT=$(echo '{"cmd":"screenshot"}' | nc -w 3 localhost "$PORT" | \
      python3 -c "
import sys, json, base64
try:
    data = json.load(sys.stdin)
    if 'image_base64' in data:
        open('$OUTFILE', 'wb').write(base64.b64decode(data['image_base64']))
        print('ok')
    else:
        print('no_image')
except Exception as e:
    print(f'error:{e}')
" 2>/dev/null)
    if [ "$RESULT" = "ok" ]; then
      OK=true
      break
    fi
    sleep 0.15
  done

  if [ "$OK" = true ]; then
    CAPTURED=$((CAPTURED + 1))
    CONSECUTIVE_FAILS=0
  else
    CONSECUTIVE_FAILS=$((CONSECUTIVE_FAILS + 1))
    echo "  WARNING: frame $i/$TARGET_FRAMES failed after 3 attempts ($RESULT)" >&2
    if [ "$CONSECUTIVE_FAILS" -ge "$MAX_CONSECUTIVE_FAILS" ]; then
      echo "ERROR: $MAX_CONSECUTIVE_FAILS consecutive frame failures — bridge on port $PORT appears unresponsive." >&2
      break
    fi
  fi

  if [ $((i % 10)) -eq 0 ] || [ "$i" -eq "$TARGET_FRAMES" ]; then
    echo "  ... $i/$TARGET_FRAMES attempted, $CAPTURED captured"
  fi
done

if [ "$CAPTURED" -lt "$TARGET_FRAMES" ]; then
  echo "ERROR: Only captured $CAPTURED of $TARGET_FRAMES requested frames. Video not created." >&2
  echo "Partial frames preserved at: $FRAME_DIR" >&2
  exit 1
fi

echo "Captured all $CAPTURED requested frames."

# Encode frames to mp4 with ffmpeg (frames are sequentially numbered, no gaps)
echo "Encoding video at ${PLAYBACK_FPS}fps..."
ffmpeg -y -framerate "$PLAYBACK_FPS" -i "$FRAME_DIR/frame_%04d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset fast \
  -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
  "$OUTPUT" 2>/dev/null

if [ $? -eq 0 ] && [ -f "$OUTPUT" ]; then
  FILESIZE=$(du -h "$OUTPUT" | cut -f1)
  VIDEO_DURATION=$(python3 -c "print(f'{$CAPTURED / $PLAYBACK_FPS:.1f}')")
  echo ""
  echo "Video saved: $OUTPUT ($FILESIZE)"
  echo "Frames: $CAPTURED | Playback: ${PLAYBACK_FPS}fps | Video length: ${VIDEO_DURATION}s"
  echo ""
  echo "Open with: open $OUTPUT"
else
  echo "ERROR: ffmpeg encoding failed." >&2
  echo "Frames preserved at: $FRAME_DIR" >&2
  exit 1
fi

rm -rf "$FRAME_DIR"
