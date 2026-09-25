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
HEIGHT_SET=0
MIN_FPS=0
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
  --height PX          Max video height to download (default: 480, or 720 when
                       --min-fps is given and --height is not)
  --min-fps N          Require at least N fps (adds an [fps>=N] format term).
                       Many sources carry their higher frame rate only at 720p+,
                       so this bumps the default --height to 720 unless you set
                       one explicitly. The download is cached under a name
                       distinct from the plain (no --min-fps) copy, so a later
                       plain fetch of the same --name never clobbers it, and
                       vice versa.
  --force              Re-extract even if frames already exist
  --list               List reference sets already extracted, then exit
  -h, --help           Show this help

Examples:
  fetch-reference.sh --url "https://www.youtube.com/watch?v=VIDEOID" --name ab2-longplay
  fetch-reference.sh --url "..." --name ab2-night --bursts "300,900" --burst-fps 8
  fetch-reference.sh --url "..." --name ab2-longplay --min-fps 60
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
    --height) HEIGHT="$2"; HEIGHT_SET=1; shift 2 ;;
    --min-fps) MIN_FPS="$2"; shift 2 ;;
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

# A higher frame rate is typically only muxed at 720p+ on YouTube (verified for
# the AB2 60fps longplay: every <=480p format is 30fps). Bump the default
# height so `--min-fps N` alone finds something, unless the caller already
# chose a height explicitly.
if [ "$MIN_FPS" -gt 0 ] && [ "$HEIGHT_SET" -eq 0 ]; then
  HEIGHT=720
fi

# A --min-fps download is a different, much larger asset (~300-380 MiB vs
# ~100 MiB) than the plain fetch of the same --name. Cache it under a
# distinct name so neither direction clobbers the other.
if [ "$MIN_FPS" -gt 0 ]; then
  CACHE_NAME="${NAME}-${MIN_FPS}fps"
  FPS_TERM="[fps>=$MIN_FPS]"
else
  CACHE_NAME="$NAME"
  FPS_TERM=""
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
VIDEO="$VIDEO_DIR/$CACHE_NAME.mp4"
FORMAT_SELECTOR="bv*[height<=$HEIGHT]${FPS_TERM}+ba/b[height<=$HEIGHT]${FPS_TERM}/b"
if [ -f "$VIDEO" ] && [ "$FORCE" -eq 0 ]; then
  echo "==> Using cached video: $VIDEO"
else
  echo "==> Downloading $URL (format: $FORMAT_SELECTOR)"
  if ! "$YTDLP" --no-playlist --no-warnings --quiet --progress \
      -f "$FORMAT_SELECTOR" \
      --merge-output-format mp4 \
      -o "$VIDEO_DIR/$CACHE_NAME.%(ext)s" \
      "$URL"; then
    echo "ERROR: yt-dlp could not satisfy format selector '$FORMAT_SELECTOR'." >&2
    echo "       Available formats:" >&2
    "$YTDLP" --no-warnings -F "$URL" >&2 || true
    exit 1
  fi
fi

if [ ! -f "$VIDEO" ]; then
  echo "ERROR: download did not produce $VIDEO" >&2
  exit 1
fi

DURATION=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VIDEO" 2>/dev/null | cut -d. -f1)
ACTUAL_FPS_RAW=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$VIDEO" 2>/dev/null)
ACTUAL_FPS=$(awk -F'/' '{ if ($2 > 0) printf "%.2f", $1/$2; else print $1 }' <<< "$ACTUAL_FPS_RAW")
echo "==> Video ready: ${DURATION}s, ${ACTUAL_FPS}fps ($ACTUAL_FPS_RAW)"

if [ "$MIN_FPS" -gt 0 ]; then
  MEETS_MIN=$(awk -v have="$ACTUAL_FPS" -v want="$MIN_FPS" 'BEGIN { print (have + 0.01 >= want) ? 1 : 0 }')
  if [ "$MEETS_MIN" -ne 1 ]; then
    echo "ERROR: downloaded video is ${ACTUAL_FPS}fps, below --min-fps $MIN_FPS." >&2
    echo "       Format selector used: $FORMAT_SELECTOR" >&2
    echo "       Re-run with --force after checking 'yt-dlp -F' output, or raise --height." >&2
    exit 1
  fi
  echo "==> Verified >= ${MIN_FPS}fps"
fi

OUT="$OUT_ROOT/$CACHE_NAME"
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
echo "$(awk -v fps="$BURST_FPS" 'BEGIN{printf "%.2f", 1/fps}')s apart. Compare stage-* frames for terrain and palette variety."
echo ""
echo "These frames are gitignored local reference. Do not commit them."
