#!/bin/bash
# Game Capture — takes a burst of gameplay screenshots via MCP bridge
# Usage: bash capture.sh [--frames N] [--interval MS] [--start-game] [--output-dir DIR]

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
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

INTERVAL_SEC=$(echo "scale=3; $INTERVAL_MS / 1000" | bc)

# Clean and create output dir
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Start game if requested — kills and restarts Godot for a clean state
if [ "$START_GAME" = true ]; then
  echo "Restarting Godot for clean game state..."
  pkill -f Godot 2>/dev/null
  sleep 2
  /Applications/Godot.app/Contents/MacOS/Godot --path "$(cd "$(dirname "$0")/../../.." && pwd)" &
  GODOT_PID=$!
  # Wait for TCP bridge to come up
  for attempt in $(seq 1 20); do
    if echo '{"cmd":"screenshot"}' | nc -w 2 localhost $PORT > /dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  echo "Godot running. Starting game (pressing Enter twice)..."
  echo '{"cmd":"key","key":"Enter"}' | nc -w 2 localhost $PORT > /dev/null 2>&1
  sleep 1
  echo '{"cmd":"key","key":"Enter"}' | nc -w 2 localhost $PORT > /dev/null 2>&1
  sleep 1
  echo "Game started."
fi

echo "Capturing $FRAMES frames at ${INTERVAL_MS}ms intervals..."

for i in $(seq 1 $FRAMES); do
  PADDED=$(printf "%03d" $i)
  OUTFILE="$OUTPUT_DIR/frame_${PADDED}.png"

  echo '{"cmd":"screenshot"}' | nc -w 3 localhost $PORT | \
    python3 -c "
import sys, json, base64
try:
    data = json.load(sys.stdin)
    if 'image_base64' in data:
        open('$OUTFILE', 'wb').write(base64.b64decode(data['image_base64']))
        print('$OUTFILE')
    else:
        print('ERROR: No image data', file=sys.stderr)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
"

  # Sleep between frames (skip after last)
  if [ $i -lt $FRAMES ]; then
    sleep "$INTERVAL_SEC"
  fi
done

echo ""
echo "Capture complete: $FRAMES frames saved to $OUTPUT_DIR"
echo "Total duration: $(echo "scale=1; ($FRAMES - 1) * $INTERVAL_MS / 1000" | bc)s"
