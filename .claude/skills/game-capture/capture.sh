#!/bin/bash
# Game Capture — takes a burst of gameplay screenshots via MCP bridge
# Usage: bash capture.sh [--frames N] [--interval MS] [--start-game] [--output-dir DIR] [--port N]
#
# Concurrency: pass --port with a distinct value per concurrent agent. This
# script only ever starts/stops the Godot process IT spawned for that port —
# it never touches a pre-existing instance it did not launch.

FRAMES=8
INTERVAL_MS=500
START_GAME=false
OUTPUT_DIR="/tmp/game-capture"
PORT=9501

while [[ $# -gt 0 ]]; do
  case $1 in
    --frames) FRAMES="$2"; shift 2 ;;
    --interval) INTERVAL_MS="$2"; shift 2 ;;
    --start-game) START_GAME=true; shift ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

INTERVAL_SEC=$(echo "scale=3; $INTERVAL_MS / 1000" | bc)

PROJ_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_DIR="/tmp/afterburner-capture"
mkdir -p "$STATE_DIR"
PID_FILE="$STATE_DIR/godot-$PORT.pid"

# The port is passed to Godot on its own command line (`-- --mcp-port N`), so
# concurrent runs share no mutable state and need no launch lock (#117).
#
# This used to write the port into the project-wide mcp_ports.cfg under a lock,
# and an EXIT trap removed that file. The trap was installed unconditionally —
# including on runs that never launched anything — so any finishing capture
# deleted the config a *different* agent's launch was mid-read of. That Godot
# then found no config and silently bound the default 9501, serving another
# agent's instance to whoever asked first. Both halves are now gone: nothing
# shared to delete, and the bridge treats an explicit port request as binding
# rather than falling back (see mcp_bridge_game.gd _resolve_port).

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
  # --mute-audio (#143): this is a spawned instance, not a manual launch — the
  # Master bus is audible by default since #138, and up to 6 of these can run
  # concurrently during a pipeline wave.
  /Applications/Godot.app/Contents/MacOS/Godot --path "$PROJ_DIR" -- --mcp-port "$PORT" --mute-audio > "$LOG_FILE" 2>&1 &
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

echo "Capturing $FRAMES frames at ${INTERVAL_MS}ms intervals on port $PORT..."

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

CAPTURED=0
for i in $(seq 1 "$FRAMES"); do
  PADDED=$(printf "%03d" "$i")
  OUTFILE="$OUTPUT_DIR/frame_${PADDED}.png"

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
    sleep 0.2
  done

  if [ "$OK" = true ]; then
    CAPTURED=$((CAPTURED + 1))
    echo "$OUTFILE"
  else
    echo "WARNING: frame $i failed after 3 attempts ($RESULT)" >&2
  fi

  if [ "$i" -lt "$FRAMES" ]; then
    sleep "$INTERVAL_SEC"
  fi
done

echo ""
if [ "$CAPTURED" -lt "$FRAMES" ]; then
  echo "ERROR: Only captured $CAPTURED of $FRAMES requested frames. Partial set left at $OUTPUT_DIR" >&2
  exit 1
fi

echo "Capture complete: $FRAMES frames saved to $OUTPUT_DIR"
echo "Total duration: $(echo "scale=1; ($FRAMES - 1) * $INTERVAL_MS / 1000" | bc)s"
