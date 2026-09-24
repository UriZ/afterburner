#!/bin/bash
# Motion metrics — aligned reference-vs-game strips for judge/QA gates (#113).
#
# This wrapper does environment work only: tool checks and venv bootstrap. ALL
# argument parsing lives in motion_metrics.py's argparse, so there is one source
# of truth for flags, defaults and --help.
#
# Usage:
#   bash compare.sh --ref <mp4> --ref-window MM:SS-MM:SS --game <mp4> [options]
#   bash compare.sh --help

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
VENV_DIR="$REPO_ROOT/.reference-cache/venv-metrics"
MARKER="$VENV_DIR/.ready"
PACKAGE="opencv-python-headless"

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo "ERROR: ffmpeg and ffprobe are required. Install with: brew install ffmpeg" >&2
  exit 3
fi

# An operator-supplied interpreter skips the bootstrap entirely — used by
# selftest.sh and by anyone who already has cv2 somewhere.
if [ -n "${MOTION_METRICS_PYTHON:-}" ]; then
  PY="$MOTION_METRICS_PYTHON"
else
  PY="$VENV_DIR/bin/python3"
  if [ ! -f "$MARKER" ]; then
    echo "Bootstrapping $PACKAGE into $VENV_DIR (one time, ~140MB, gitignored)..." >&2
    if ! python3 -m venv "$VENV_DIR" >&2; then
      echo "ERROR: could not create the venv at $VENV_DIR." >&2
      exit 4
    fi
    if ! "$PY" -m pip install --quiet --disable-pip-version-check "$PACKAGE" >&2; then
      echo "ERROR: could not install $PACKAGE (offline?)." >&2
      echo "Install it manually with:" >&2
      echo "  $PY -m pip install $PACKAGE" >&2
      echo "or point the skill at an interpreter that already has cv2:" >&2
      echo "  MOTION_METRICS_PYTHON=/path/to/python3 bash $0 ..." >&2
      exit 4
    fi
    "$PY" -c "import cv2; print(cv2.__version__)" > "$MARKER" 2>/dev/null || {
      echo "ERROR: $PACKAGE installed but cv2 will not import." >&2
      rm -f "$MARKER"
      exit 4
    }
  fi
fi

exec "$PY" "$SKILL_DIR/motion_metrics.py" "$@"
