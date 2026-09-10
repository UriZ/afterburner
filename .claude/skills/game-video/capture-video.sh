#!/bin/bash
# Game Video Capture — records gameplay as mp4 via TCP bridge frame capture + ffmpeg
# Captures as fast as TCP allows, then encodes at desired playback FPS.
# Usage: bash capture-video.sh [--duration SECS] [--playback-fps N] [--start-game] [--output FILE]

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
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT")"

# Clean and create frame directory
rm -rf "$FRAME_DIR"
mkdir -p "$FRAME_DIR"

# Start game if requested — kills and restarts Godot for a clean state
if [ "$START_GAME" = true ]; then
  echo "Restarting Godot for clean game state..."
  pkill -f Godot 2>/dev/null
  sleep 2
  PROJ_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
  /Applications/Godot.app/Contents/MacOS/Godot --path "$PROJ_DIR" &
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
else
  # Check game is running
  if ! echo '{"cmd":"screenshot"}' | nc -w 2 localhost $PORT > /dev/null 2>&1; then
    echo "ERROR: Game not running on port $PORT. Start Godot first or use --start-game."
    exit 1
  fi
fi

echo "Recording ${DURATION}s of gameplay (as fast as TCP allows)..."
echo "Playback will be at ${PLAYBACK_FPS}fps."

CAPTURED=0
START_TIME=$(python3 -c "import time; print(time.time())")

# Capture frames as fast as possible for DURATION seconds
while true; do
  ELAPSED=$(python3 -c "import time; print(time.time() - $START_TIME)")
  DONE=$(python3 -c "print('yes' if $ELAPSED >= $DURATION else 'no')")
  if [ "$DONE" = "yes" ]; then
    break
  fi

  PADDED=$(printf "%04d" $((CAPTURED + 1)))
  OUTFILE="$FRAME_DIR/frame_${PADDED}.png"

  RESULT=$(echo '{"cmd":"screenshot"}' | nc -w 3 localhost $PORT | \
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
    CAPTURED=$((CAPTURED + 1))
    if [ $((CAPTURED % 5)) -eq 0 ]; then
      echo "  Captured $CAPTURED frames (${ELAPSED}s elapsed)..."
    fi
  fi
done

ACTUAL_FPS=$(python3 -c "print(f'{$CAPTURED / $DURATION:.1f}')")
echo "Captured $CAPTURED frames in ${DURATION}s (effective ${ACTUAL_FPS} fps)."

if [ $CAPTURED -lt 3 ]; then
  echo "ERROR: Too few frames captured. Video not created."
  exit 1
fi

# Encode frames to mp4 with ffmpeg
# Frames are already sequentially numbered (only successful captures get numbered)
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
  echo "ERROR: ffmpeg encoding failed."
  # Keep frames for debugging
  echo "Frames preserved at: $FRAME_DIR"
  exit 1
fi

# Clean up frames
rm -rf "$FRAME_DIR"
