#!/bin/bash
# Validation suite for the motion-metrics skill (#113 §10).
#
# No test framework — matches the convention of the other skills in this repo.
# Fixtures are generated with ffmpeg into a temp dir and removed on exit.
#
# Fixture note: `-loop 1 -i <png>` defaults to 25fps input regardless of what
# you label the output with, which silently produces duplicated frames. Every
# fixture here uses an lavfi source with an explicit `rate=`, so the container
# fps and the real frame cadence agree unless a test deliberately breaks them.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
PY="${MOTION_METRICS_PYTHON:-$REPO_ROOT/.reference-cache/venv-metrics/bin/python3}"
COMPARE="bash $SKILL_DIR/compare.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/motion-metrics-selftest.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL: $1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1 — expected '$3', got '$2'"; fi; }

# mkclip <path> <W> <H> <container_fps> <n_frames>
mkclip() {
  ffmpeg -v error -y -f lavfi -i "testsrc2=size=${2}x${3}:rate=${4}" \
    -frames:v "$5" -c:v libx264 -pix_fmt yuv420p "$1"
}

# mksidecar <clip> <measured_fps>
mksidecar() {
  cat > "$1.json" <<EOF
{"schema":"game-video-capture/1","output":"$1","frames":0,"requested_fps":$2,
 "measured_fps":$2,"encoded_fps":$2,"wall_elapsed_s":0,"interval_mean_s":0,
 "interval_stdev_s":0,"interval_max_s":0,"paced":true,"pacing_slip":false,
 "captured_utc":"2026-09-25T00:00:00Z"}
EOF
}

dims() { ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$1"; }

echo "Building fixtures in $TMP ..."
REF="$TMP/ref.mp4"      # 686x480 @ 30fps, 10s — the reference's real geometry
GAME="$TMP/game.mp4"    # 960x672 @ 10fps, 10s — our capture geometry
WIDE="$TMP/wide.mp4"    # 960x540 @ 10fps — 16:9, for the aspect test
SLOW="$TMP/slow.mp4"    # 960x672 @ 10fps container, 30 frames, sidecar says 20
mkclip "$REF" 686 480 30 300
mkclip "$GAME" 960 672 10 100
mkclip "$WIDE" 960 540 10 100
mkclip "$SLOW" 960 672 10 30
mksidecar "$GAME" 10.0
mksidecar "$SLOW" 20.0
mksidecar "$WIDE" 10.0

echo
echo "unit: pure functions"
export SKILL_DIR
UNIT_OUT=$("$PY" - <<'PYEOF'
import sys, os
sys.path.insert(0, os.environ["SKILL_DIR"])
from motion_metrics import (parse_window, resolve_true_fps, compute_crop_rect,
                            resolve_aspect, plan_sampling, container_window,
                            real_to_container_fps, UserError)

ok, bad = [], []
def check(name, cond):
    (ok if cond else bad).append(name)

check("parse_window 6:00-6:10", parse_window("6:00-6:10") == (360.0, 370.0))
check("parse_window bare seconds", parse_window("0-8") == (0.0, 8.0))
check("parse_window HH:MM:SS.frac", parse_window("1:02:03.5-1:02:04") == (3723.5, 3724.0))
try:
    parse_window("banana"); check("parse_window rejects junk", False)
except UserError:
    check("parse_window rejects junk", True)
try:
    parse_window("10-5"); check("parse_window rejects reversed", False)
except UserError:
    check("parse_window rejects reversed", True)

check("compute_crop_rect ref 686x480", compute_crop_rect(686, 480, (0.12, 0.12, 0, 0)) == (686, 364, 0, 58))
check("compute_crop_rect game 960x672", compute_crop_rect(960, 672, (0.12, 0.12, 0, 0)) == (960, 510, 0, 81))

r, g, note = resolve_aspect((686, 364, 0, 58), (960, 510, 0, 81), "strict")
check("resolve_aspect passes 0.12% mismatch", r == (686, 364, 0, 58) and g == (960, 510, 0, 81))
try:
    resolve_aspect((686, 364, 0, 58), (960, 410, 0, 64), "strict")
    check("resolve_aspect strict rejects 16:9", False)
except UserError as e:
    check("resolve_aspect strict rejects 16:9", e.code == 6)
r2, g2, _ = resolve_aspect((686, 364, 0, 58), (960, 410, 0, 64), "center-crop")
check("resolve_aspect center-crop equalizes",
      abs((r2[0]/r2[1]) - (g2[0]/g2[1])) < 0.02)

check("plan_sampling under cap", plan_sampling(4.0, 3.0, 8, 3) == (12, 1/3.0))
n, iv = plan_sampling(30.0, 3.0, 8, 3)
check("plan_sampling widens over cap", n == 24 and abs(iv - 30.0/24) < 1e-9)

# §3.4 worked-example oracle (judge correction 2): a legacy clip with nominal
# 15 fps and a true rate of 17.3 fps holds 150 frames = 8.67 real seconds, so
# the window must be 0-8s, not the 0-10s the first draft of the spec used.
ts = 17.3 / 15.0
cstart, cdur = container_window(0.0, 8.0, ts)
cfps = real_to_container_fps(3.0, ts)
check("oracle container window 0-9.22s", abs(cstart) < 1e-9 and abs(cdur - 9.2267) < 0.001)
check("oracle container_fps 2.602", abs(cfps - 2.6012) < 0.001)
check("oracle 24 cells", plan_sampling(8.0, 3.0, 8, 3)[0] == 24)
check("oracle frame count consistency", abs(cdur * cfps - 24.0) < 0.05)
check("oracle rejects the stale 0-10s window", 10.0 > 150 / 17.3)

check("resolve_true_fps declared container",
      resolve_true_fps("/nope.mp4", "container", 15.0, False)[0] == 15.0)
check("resolve_true_fps declared float",
      resolve_true_fps("/nope.mp4", "17.3", 15.0, False)[0] == 17.3)
try:
    resolve_true_fps("/nope.mp4", None, 15.0, False)
    check("resolve_true_fps demands a game time base", False)
except UserError as e:
    check("resolve_true_fps demands a game time base", e.code == 2)
check("resolve_true_fps ref falls back to container",
      resolve_true_fps("/nope.mp4", None, 30.0, True)[0] == 30.0)

for name in ok:
    print("  PASS: %s" % name)
for name in bad:
    print("  FAIL: %s" % name)
print("TALLY %d %d" % (len(ok), len(bad)))
PYEOF
)
echo "$UNIT_OUT" | grep -v '^TALLY '
UNIT_OK=$(echo "$UNIT_OUT" | grep '^TALLY ' | cut -d' ' -f2)
UNIT_BAD=$(echo "$UNIT_OUT" | grep '^TALLY ' | cut -d' ' -f3)
PASSED=$((PASSED + ${UNIT_OK:-0}))
FAILED=$((FAILED + ${UNIT_BAD:-1}))

echo
echo "1. strip geometry"
OUT="$TMP/t1"
$COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --name t1 --out "$OUT" >/dev/null 2>&1
expect "strip-01.png is 1468x286" "$(dims "$OUT/strip-01.png" 2>/dev/null)" "1468,286"
expect "three strips produced" "$(ls "$OUT" | grep -c '^strip-')" "3"

echo
echo "2. row alignment"
OUT="$TMP/t2"
$COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --name t2 --out "$OUT" --keep-frames >/dev/null 2>&1
NREF=$(ls "$OUT/.frames/ref" 2>/dev/null | wc -l | tr -d ' ')
NGAME=$(ls "$OUT/.frames/game" 2>/dev/null | wc -l | tr -d ' ')
expect "both rows extracted the same cell count" "$NREF" "$NGAME"
# Timestamp bands are the mechanical check that the two rows carry identical
# labels: same pixels means same text at the same x for every cell.
BANDS=$("$PY" - "$OUT/strip-01.png" <<'PYEOF'
import sys, cv2, numpy as np
img = cv2.imread(sys.argv[1])
row_h = 26 + 96 + 18
top = img[26 + 96:row_h]
bot = img[row_h + 6 + 26 + 96:]
print("same" if np.array_equal(top, bot) else "differ")
PYEOF
)
expect "timestamp bands identical across rows" "$BANDS" "same"

echo
echo "3. real-time equalization against a mislabeled clip"
OUT="$TMP/t3"
$COMPARE --ref "$REF" --ref-window 0-1.5 --game "$SLOW" --name t3 --out "$OUT" --keep-frames >/dev/null 2>&1
# SLOW: 30 frames, container 10fps (3.0s), sidecar measured_fps 20 -> time_scale
# 2.0 -> 1.5 REAL seconds. At --strip-fps 3 that is 4 cells. Sampling in
# container time would have given floor(3.0*3)=9.
expect "cells follow real duration, not container duration" \
  "$(ls "$OUT/.frames/game" 2>/dev/null | wc -l | tr -d ' ')" "4"
if grep -q "20.0000" "$OUT/report.md" 2>/dev/null; then
  pass "report carries the sidecar's true rate"
else
  fail "report carries the sidecar's true rate"
fi

echo
echo "4. sidecar precedence"
OUT="$TMP/t4a"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" --game-window 0-5 --game-true-fps 12.5 \
  --name t4a --out "$OUT" >/dev/null 2>&1
if grep -q "declared on the command line" "$OUT/report.md" 2>/dev/null; then
  pass "explicit --game-true-fps beats the sidecar"
else
  fail "explicit --game-true-fps beats the sidecar"
fi
OUT="$TMP/t4b"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" --game-window 0-5 --name t4b --out "$OUT" >/dev/null 2>&1
if grep -q "measured, sidecar" "$OUT/report.md" 2>/dev/null; then
  pass "sidecar used when no flag is given"
else
  fail "sidecar used when no flag is given"
fi
NOSIDE="$TMP/nosidecar.mp4"
cp "$GAME" "$NOSIDE"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$NOSIDE" --name t4c --out "$TMP/t4c" >/dev/null 2>&1
expect "no sidecar and no flag exits 2" "$?" "2"

echo
echo "5. strip-fps above the clip's true rate"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" --strip-fps 30 --name t5 --out "$TMP/t5" >/dev/null 2>&1
expect "--strip-fps 30 on a 10fps capture exits 2" "$?" "2"

echo
echo "6. bad windows"
ERR=$($COMPARE --ref "$REF" --ref-window 99:00-99:10 --game "$GAME" --name t6a --out "$TMP/t6a" 2>&1)
CODE=$?
expect "out-of-range window exits 2" "$CODE" "2"
if echo "$ERR" | grep -q "REAL seconds long"; then
  pass "out-of-range window names the clip's true real duration"
else
  fail "out-of-range window names the clip's true real duration"
fi
$COMPARE --ref "$REF" --ref-window banana --game "$GAME" --name t6b --out "$TMP/t6b" >/dev/null 2>&1
expect "malformed window exits 2" "$?" "2"

echo
echo "7. aspect mismatch"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$WIDE" --game-window 0-5 --name t7a --out "$TMP/t7a" >/dev/null 2>&1
expect "16:9 vs 10:7 exits 6 under strict" "$?" "6"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$WIDE" --game-window 0-5 --aspect-policy center-crop \
  --name t7b --out "$TMP/t7b" >/dev/null 2>&1
expect "center-crop policy exits 0" "$?" "0"

echo
echo "8. truncation"
OUT="$TMP/t8"
$COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --game-window 0-6 --name t8 --out "$OUT" >/dev/null 2>&1
if grep -q "truncated from their start" "$OUT/report.md" 2>/dev/null; then
  pass "unequal windows truncate to the shorter, noted in the report"
else
  fail "unequal windows truncate to the shorter, noted in the report"
fi

echo
echo "9. scope boundary — no speed figures in report.md"
# Asserts against NUMERIC patterns, not the bare words: the report template
# deliberately contains the sentence "No speed, px/frame or ratio figures ..."
# explaining why v1 has none, and a literal-string guard would fail a correct
# implementation (judge correction 1).
#
# The ratio arm requires a DECIMAL, not any digit — "ratio figures: AB2's" puts
# a 2 within a few characters of the word, so a bare-digit guard false-positives
# on the explanatory sentence itself. `[^.]` keeps each arm inside one sentence.
SCOPE_PAT='[0-9]+(\.[0-9]+)?[[:space:]]*px/frame|px/frame[^.]{0,12}[0-9]|ratio[^.]{0,24}[0-9]+\.[0-9]|ratio[[:space:]]*[:|][[:space:]]*[0-9]'
OUT="$TMP/t1"
NUMERIC=$(grep -Eic "$SCOPE_PAT" "$OUT/report.md")
expect "report.md carries no numeric speed figure" "$NUMERIC" "0"
if grep -q "px/frame or ratio figures" "$OUT/report.md"; then
  pass "the explanatory sentence survives the guard"
else
  fail "the explanatory sentence survives the guard"
fi
# Negative control on the guard itself — a guard that cannot fail is not a guard.
cat > "$TMP/scope-control.md" <<'EOF'
No speed, px/frame or ratio figures: AB2's ground texture temporally aliases below
| mean flow | 5.001 px/frame |
Flow ratio (game/ref): 0.92
EOF
expect "the guard does catch real speed figures" \
  "$(grep -Eic "$SCOPE_PAT" "$TMP/scope-control.md")" "2"

echo
echo "10. frame cleanup"
OUT="$TMP/t10"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" --game-window 0-5 --name t10 --out "$OUT" >/dev/null 2>&1
if [ -d "$OUT/.frames" ]; then fail ".frames removed by default"; else pass ".frames removed by default"; fi
OUT="$TMP/t10b"
$COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" --game-window 0-5 --keep-frames \
  --name t10b --out "$OUT" >/dev/null 2>&1
if [ -d "$OUT/.frames" ]; then pass ".frames kept with --keep-frames"; else fail ".frames kept with --keep-frames"; fi

echo
echo "11. max strips"
OUT="$TMP/t11"
$COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --name t11 --out "$OUT" >/dev/null 2>&1
expect "10s at 3fps yields exactly max-strips files" "$(ls "$OUT" | grep -c '^strip-')" "3"
if grep -q "spread uniformly across it" "$OUT/report.md" 2>/dev/null; then
  pass "report states the widened effective interval"
else
  fail "report states the widened effective interval"
fi
INTERVAL=$(grep -o 'sampling interval (real time): [0-9.]*' "$OUT/report.md" | grep -o '[0-9.]*$')
if [ "$(echo "$INTERVAL > 0.33" | bc)" = "1" ]; then
  pass "widened interval ($INTERVAL s) exceeds 1/strip-fps"
else
  fail "widened interval ($INTERVAL s) exceeds 1/strip-fps"
fi

echo
echo "12. idempotent re-run into a populated --out"
# The documented workflow re-uses --name (and therefore --out) across runs of the
# same issue. A second, shorter run must leave the directory matching ITSELF —
# orphaned strips from run 1 show a different window and get read as current
# evidence. Checked with --keep-frames too, because stale cells in .frames/ were
# the worse half of the same defect.
OUT="$TMP/t12"
$COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --name t12 --out "$OUT" --keep-frames >/dev/null 2>&1
FIRST_STRIPS=$(ls "$OUT" | grep -c '^strip-')
FIRST_CELLS=$(ls "$OUT/.frames/ref" 2>/dev/null | wc -l | tr -d ' ')
expect "run 1 (10s window) produces 3 strips" "$FIRST_STRIPS" "3"
$COMPARE --ref "$REF" --ref-window 0-2 --game "$GAME" --game-window 0-2 --name t12 --out "$OUT" --keep-frames >/dev/null 2>&1
expect "run 2 (2s window) leaves exactly its own strips" "$(ls "$OUT" | grep -c '^strip-')" "1"
expect "run 2 leaves no stale extracted cells" "$(ls "$OUT/.frames/ref" 2>/dev/null | wc -l | tr -d ' ')" "6"
REPORTED=$(grep -o 'strips produced: [0-9]*' "$OUT/report.md" | grep -o '[0-9]*$')
expect "report's strip count matches what is on disk" "$REPORTED" "$(ls "$OUT" | grep -c '^strip-')"
# Narrow by design: only this tool's own artifacts are cleared.
touch "$OUT/operator-notes.md"
$COMPARE --ref "$REF" --ref-window 0-2 --game "$GAME" --game-window 0-2 --name t12 --out "$OUT" >/dev/null 2>&1
if [ -f "$OUT/operator-notes.md" ]; then
  pass "unrelated files in --out are left alone"
else
  fail "unrelated files in --out are left alone"
fi

echo
echo "13. concurrent runs sharing one --out (#119)"
# Two agents working the same issue land on the same --out, because both agent
# inserts use a stable --name judge-<issue> / --name qa-<issue>. Pre-fix, both
# processes wrote strip-01.png at the same instant and every strip became a torn
# PNG that `file` and `sips` still called fine — only cv2/libpng caught it.
#
# Starts from a DIRTY directory on purpose: the sequential clearing path and the
# concurrency path have to hold at the same time.
OUT="$TMP/t13"
$COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --name t13-seed --out "$OUT" >/dev/null 2>&1
SEEDED=$(ls "$OUT" | grep -c '^strip-')
expect "seeded a populated --out before racing into it" "$SEEDED" "3"

# The two runs do IDENTICAL work (same windows, so the same ffmpeg cost) and
# differ only in --strip-cell-width, which makes their strips 1468px and 1948px
# wide. Equal cost is what makes their compose phases actually collide; the
# width difference is what makes a survivor's provenance visible.
#
# Measured on the pre-fix code over 6 trials: torn PNGs appeared in 1 trial, but
# strips from BOTH runs survived side by side in 4. Mixed provenance is the
# likelier symptom of this race, and it decodes perfectly — so a fix that only
# stops the tearing would still leave an artifact describing two different
# windows. Three trials, because a single one is a coin flip.
for trial in 1 2 3; do
  $COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --game-window 0-10 \
    --strip-cell-width 180 --name t13a --out "$OUT" >/dev/null 2>&1 &
  PID_A=$!
  $COMPARE --ref "$REF" --ref-window 0-10 --game "$GAME" --game-window 0-10 \
    --strip-cell-width 240 --name t13b --out "$OUT" >/dev/null 2>&1 &
  PID_B=$!
  wait $PID_A; RC_A=$?
  wait $PID_B; RC_B=$?
  expect "trial $trial: both concurrent runs exit 0" "$RC_A$RC_B" "00"

  VERDICT=$("$PY" - "$OUT" <<'PYEOF'
import cv2, glob, os, re, sys
out = sys.argv[1]
strips = sorted(glob.glob(os.path.join(out, "strip-*.png")))
imgs = [(os.path.basename(f), cv2.imread(f)) for f in strips]
print("decodable" if strips and all(im is not None for _, im in imgs) else "corrupt")
widths = sorted({im.shape[1] for _, im in imgs if im is not None})
report = open(os.path.join(out, "report.md")).read()
cell_w = int(re.search(r"cell size: (\d+)x\d+", report).group(1))
cols = int(re.search(r"up to (\d+) cells each", report).group(1))
expected = cols * cell_w + (cols - 1) * 4
if len(widths) != 1:
    print("mixed-provenance:%s" % widths)
elif widths[0] != expected:
    print("strips-disagree-with-report:%d-vs-%d" % (widths[0], expected))
else:
    print("one-run")
PYEOF
)
  expect "trial $trial: every surviving strip decodes via cv2.imread" \
    "$(echo "$VERDICT" | sed -n 1p)" "decodable"
  expect "trial $trial: surviving strips all come from the run that wrote the report" \
    "$(echo "$VERDICT" | sed -n 2p)" "one-run"
done

if [ -z "$(ls -d "$OUT"/.staging-* 2>/dev/null)" ]; then
  pass "no staging directories left behind"
else
  fail "no staging directories left behind"
fi

# Negative control: the validator above must be capable of returning "corrupt",
# or "decodable" proves nothing. Torn exactly the way the race tore them — a
# valid PNG header over a damaged IDAT stream, which `file` still calls a PNG.
CONTROL="$TMP/t13-control.png"
cp "$OUT/strip-01.png" "$CONTROL"
"$PY" - "$CONTROL" <<'PYEOF'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
for i in range(len(data) // 2, len(data) // 2 + 2000):
    data[i] ^= 0xFF
open(sys.argv[1], "wb").write(data)
PYEOF
CONTROL_RESULT=$("$PY" -c "
import cv2, sys
print('corrupt' if cv2.imread(sys.argv[1]) is None else 'decodable')" "$CONTROL" 2>/dev/null)
expect "the decode check does detect a torn PNG" "$CONTROL_RESULT" "corrupt"

echo
echo "14. lock timeout is reported, not silently ignored"
OUT="$TMP/t14"
mkdir -p "$OUT"
# Hold the lock from outside, then race a run against it with a 1s patience.
"$PY" - "$OUT/.lock" <<'PYEOF' &
import fcntl, os, sys, time
fd = os.open(sys.argv[1], os.O_CREAT | os.O_RDWR, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
time.sleep(6)
PYEOF
HOLDER=$!
sleep 1
MOTION_METRICS_LOCK_TIMEOUT=1 $COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" \
  --game-window 0-5 --name t14 --out "$OUT" >/dev/null 2>&1
expect "a held lock times out with exit 8" "$?" "8"
wait $HOLDER 2>/dev/null
# And the lock is genuinely released when the holder exits, so the next run works.
$COMPARE --ref "$REF" --ref-window 0-5 --game "$GAME" --game-window 0-5 --name t14 --out "$OUT" >/dev/null 2>&1
expect "the same --out works once the lock is free" "$?" "0"

echo
echo "================================"
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
