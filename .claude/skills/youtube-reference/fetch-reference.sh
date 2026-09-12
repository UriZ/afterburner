#!/usr/bin/env bash
#
# fetch-reference.sh — turn a YouTube URL into local reference frame sequences.
#
# Agents cannot stream video. This converts footage into stills on disk, which
# any agent can read regardless of whether it has web tools.
#
# Frames are gitignored local development reference. Do not commit them.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CACHE_DIR="$REPO_ROOT/.reference-cache"
BIN_DIR="$CACHE_DIR/bin"
VIDEO_DIR="$CACHE_DIR/video"
OUT_ROOT="$REPO_ROOT/assets/reference/motion"

URL=""
NAME=""
BURSTS="150,420,700"
BURST_FPS=4
BURST_FRAMES=12
SPREAD_COUNT=14
SPREAD_START=90
SPREAD_EVERY=60
HEIGHT=480
FORCE=0

usage() {
  cat <<'USAGE'
Usage: fetch-reference.sh --url URL --name SLUG [options]

Required:
  --url URL            YouTube URL to pull reference footage from
  --name SLUG          Short name for this source (becomes the output subdirectory)

Options:
  --bursts "A,B,C"     Comma-separated start times in seconds for motion bursts
                       (default: 150,420,700). Each burst captures consecutive
                       frames — this is what conveys motion.
  --burst-fps N        Frames per second within a burst (default: 4, i.e. 0.25s apart)
  --burst-frames N     Frames per burst (default: 12)
  --spread-count N     Number of spread frames across the run (default: 14)
  --spread-start SECS  Where the spread begins, to skip intros (default: 90)
  --spread-every SECS  Seconds between spread frames (default: 60)
  --height PX          Max video height to download (default: 480)
  --force              Re-extract even if frames already exist
  --list               List reference sets already extracted, then exit
  -h, --help           Show this help

Examples:
  fetch-reference.sh --url "https://www.youtube.com/watch?v=VIDEOID" --name ab2-longplay
  fetch-reference.sh --url "..." --name ab2-night --bursts "300,900" --burst-fps 8
USAGE
}

list_sets() {
  if [ ! -d "$OUT_ROOT" ]; then
    echo "No reference sets extracted yet."
    return 0
  fi
  echo "Extracted reference sets in $OUT_ROOT:"
  for d in "$OUT_ROOT"/*/; do
    [ -d "$d" ] || continue
    printf "  %-24s %s frames\n" "$(basename "$d")" "$(find "$d" -name '*.jpg' | wc -l | tr -d ' ')"
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --bursts) BURSTS="$2"; shift 2 ;;
    --burst-fps) BURST_FPS="$2"; shift 2 ;;
    --burst-frames) BURST_FRAMES="$2"; shift 2 ;;
    --spread-count) SPREAD_COUNT="$2"; shift 2 ;;
    --spread-start) SPREAD_START="$2"; shift 2 ;;
    --spread-every) SPREAD_EVERY="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --list) list_sets; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$URL" ] || [ -z "$NAME" ]; then
  echo "ERROR: --url and --name are both required." >&2
  usage >&2
  exit 2
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found. Install it with: brew install ffmpeg" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$VIDEO_DIR"

# --- yt-dlp: fetch into local cache, never install system-wide ---
YTDLP="$BIN_DIR/yt-dlp"
if [ ! -x "$YTDLP" ]; then
  echo "==> Fetching yt-dlp into $BIN_DIR (local only, not a system install)"
  case "$(uname -s)" in
    Darwin) ASSET="yt-dlp_macos" ;;
    Linux)  ASSET="yt-dlp_linux" ;;
    *) echo "ERROR: unsupported platform $(uname -s)" >&2; exit 1 ;;
  esac
  if ! curl -L --fail --silent --show-error \
      -o "$YTDLP" \
      "https://github.com/yt-dlp/yt-dlp/releases/latest/download/$ASSET"; then
    echo "ERROR: could not download yt-dlp." >&2
    exit 1
  fi
  chmod +x "$YTDLP"
fi
echo "==> yt-dlp $("$YTDLP" --version 2>/dev/null || echo '(version unknown)')"

# --- Download video (cached) ---
VIDEO="$VIDEO_DIR/$NAME.mp4"
if [ -f "$VIDEO" ] && [ "$FORCE" -eq 0 ]; then
  echo "==> Using cached video: $VIDEO"
else
  echo "==> Downloading $URL"
  "$YTDLP" --no-playlist --no-warnings --quiet --progress \
    -f "bv*[height<=$HEIGHT]+ba/b[height<=$HEIGHT]/b" \
    --merge-output-format mp4 \
    -o "$VIDEO_DIR/$NAME.%(ext)s" \
    "$URL"
fi

if [ ! -f "$VIDEO" ]; then
  echo "ERROR: download did not produce $VIDEO" >&2
  exit 1
fi

DURATION=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VIDEO" 2>/dev/null | cut -d. -f1)
echo "==> Video ready: ${DURATION}s"

OUT="$OUT_ROOT/$NAME"
if [ -d "$OUT" ] && [ "$FORCE" -eq 0 ] && [ -n "$(find "$OUT" -name '*.jpg' 2>/dev/null)" ]; then
  echo "==> Frames already extracted in $OUT (use --force to redo)"
  list_sets
  exit 0
fi
mkdir -p "$OUT"

# --- Motion bursts: consecutive frames. This is the part that shows motion. ---
IFS=',' read -ra BURST_STARTS <<< "$BURSTS"
letter=a
for start in "${BURST_STARTS[@]}"; do
  start="$(echo "$start" | tr -d ' ')"
  if [ -n "$DURATION" ] && [ "$start" -ge "$DURATION" ]; then
    echo "!!  Skipping burst at ${start}s — beyond video duration ${DURATION}s"
    continue
  fi
  echo "==> Motion burst '$letter' at ${start}s (${BURST_FRAMES} frames @ ${BURST_FPS}fps)"
  ffmpeg -v error -ss "$start" -i "$VIDEO" \
    -vf "fps=$BURST_FPS" -frames:v "$BURST_FRAMES" \
    "$OUT/burst-$letter-%02d.jpg" -y
  letter=$(echo "$letter" | tr 'a-y' 'b-z')
done

# --- Stage spread: variety across the whole run ---
echo "==> Stage spread (${SPREAD_COUNT} frames, every ${SPREAD_EVERY}s from ${SPREAD_START}s)"
ffmpeg -v error -ss "$SPREAD_START" -i "$VIDEO" \
  -vf "fps=1/$SPREAD_EVERY" -frames:v "$SPREAD_COUNT" \
  "$OUT/stage-%02d.jpg" -y

COUNT=$(find "$OUT" -name '*.jpg' | wc -l | tr -d ' ')
echo ""
echo "==> Done: $COUNT frames in $OUT"
echo ""
echo "Read the burst-* frames in order to see motion — consecutive frames are"
echo "$(awk "BEGIN{printf \"%.2f\", 1/$BURST_FPS}")s apart. Compare stage-* frames for terrain and palette variety."
echo ""
echo "These frames are gitignored local reference. Do not commit them."
