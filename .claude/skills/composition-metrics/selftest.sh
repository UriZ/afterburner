#!/bin/bash
# Selftest for the shape-model jet detector (#140).
#
# The headline test is a TWO-WAY negative control. The detector this replaced
# passed its own control while measuring terrain, because that control only
# asked "does a centred jet read as cx ~ 50?" — which symmetric ground also
# satisfies. So this suite asserts both directions:
#
#   the OLD detector must FAIL the asymmetric case
#   the NEW detector must PASS it
#
# A control that only the new detector can pass is the only kind that proves
# anything. Exit 0 = all pass.
#
# Fixtures are built on demand by make_control.py from the committed jet-free
# backgrounds; nothing here depends on a pre-existing generated directory.
# Runtime is about seven minutes (25 masked matches per frame over 112 fixtures
# and 12 jet-free frames), plus a one-off minute the first time the fixtures
# are built.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../../.." && pwd)"
PY="${COMPOSITION_METRICS_PYTHON:-$PROJ/.reference-cache/venv-metrics/bin/python3}"

if [ ! -x "$PY" ]; then
  echo "ERROR: no interpreter with cv2 at $PY" >&2
  echo "Set COMPOSITION_METRICS_PYTHON, or bootstrap the motion-metrics venv first." >&2
  exit 4
fi

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "=== composition-metrics selftest ==="

# ---------------------------------------------------------------------------
echo
echo "tests 1-7: two-way negative control over real terrain — level, banked, clipped"
"$PY" - "$HERE" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
from jet_detect import Detector, legacy_detect
from make_control import load_truth, DEFAULT_OUT

here = sys.argv[1]
truth, built = load_truth()
print("  fixtures: %d (%s)" % (len(truth), "rebuilt" if built else "cached"))
det = Detector()

def path_of(n):
    return os.path.join(DEFAULT_OUT, n)

def errors(names, fn):
    out = []
    for n in names:
        r = fn(path_of(n))
        t = truth[n]["cx_pct"]
        out.append(abs((r["cx_pct"] if r else 1e9) - t))
    return out

sym     = sorted(n for n in truth if "_cx50_" in n)
asym    = sorted(n for n in truth if "_cx50_" not in n)
banked  = sorted(n for n in truth if abs(truth[n]["bank_deg"]) > 0.01)
clipped = sorted(n for n in truth if truth[n]["inside_frac"] < 0.999)

# Only ACCEPTED detections are scored. A refused frame is not a wrong answer;
# the detector declining to guess is the behaviour we want. Acceptance rate is
# asserted separately below so refusing everything cannot pass this suite.
_cache = {}
def accepted_errors(names):
    out = []
    for n in names:
        if n not in _cache:
            _cache[n] = det.detect(path_of(n))
        r = _cache[n]
        if r:
            out.append(abs(r["cx_pct"] - truth[n]["cx_pct"]))
    return out

legacy_sym  = max(errors(sym,  legacy_detect))
legacy_asym = max(errors(asym, legacy_detect))
shape_sym   = max(accepted_errors(sym) or [99.0])
shape_asym  = max(accepted_errors(asym) or [99.0])
shape_bank  = max(accepted_errors(banked) or [99.0])
shape_clip  = max(accepted_errors(clipped) or [99.0])
clip_rate   = len(accepted_errors(clipped)) / float(len(clipped))
accept_rate = len(accepted_errors(sorted(truth))) / float(len(truth))

results = [
    # (label, condition, detail)
    ("legacy detector PASSES the centred case (the old control's blind spot)",
     legacy_sym <= 5.0, "max err %.2f pp <= 5.0" % legacy_sym),
    ("legacy detector FAILS the asymmetric case",
     legacy_asym > 5.0, "max err %.2f pp > 5.0" % legacy_asym),
    ("shape-model PASSES both, to under 2 pp",
     max(shape_sym, shape_asym) <= 2.0,
     "max err centred %.2f pp, asymmetric %.2f pp" % (shape_sym, shape_asym)),
    ("shape-model stays accurate on BANKED cases",
     shape_bank <= 2.0, "max err %.2f pp" % shape_bank),
    # The jet is furthest off centre exactly when it is clipped by the frame
    # edge, so a detector that cannot see clipped poses reports a cx spread
    # truncated toward the middle while looking carefully conservative. These
    # two lines are what stop that regressing: matchTemplate on an unpadded
    # frame produces NO candidate position for a clipped jet, so the rate goes
    # to 0 and this fails rather than quietly narrowing the answer.
    ("shape-model SEES jets clipped by the frame edge",
     clip_rate >= 0.70, "accepted %.0f%% of clipped fixtures" % (clip_rate * 100)),
    ("shape-model locates clipped jets accurately",
     shape_clip <= 2.0, "max err %.2f pp" % shape_clip),
    ("shape-model still answers most of the time",
     accept_rate >= 0.70, "accepted %.0f%% of fixtures" % (accept_rate * 100)),
]
for label, cond, detail in results:
    print("  %s: %s (%s)" % ("PASS" if cond else "FAIL", label, detail))
sys.exit(0 if all(c for _, c, _ in results) else 1)
PY
if [ $? -eq 0 ]; then PASS=$((PASS+7)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
echo
echo "test 8: refuses frames with no jet in them"
# Defaults to the committed jet-free frames so this runs unattended. It used to
# SKIP unless an env var pointed at frames someone had rendered by hand, which
# made the suite's only false-positive guard the one test that never ran.
# `jetfree-extra/` is terrain NOT used to build the fixtures, so a pass here is
# not just the compositing backgrounds answering about themselves.
#
# Asserted as "0/N detected", never as "too few to report": that message also
# appears when the detector fires on one or two frames, so grepping for it
# alone would pass a run that produced false positives.
JETFREE_GLOBS="${COMPOSITION_SELFTEST_JETFREE:-$HERE/control/backgrounds/*.png $HERE/control/jetfree-extra/*.png}"
JETFREE_N=0
for g in $JETFREE_GLOBS; do [ -f "$g" ] && JETFREE_N=$((JETFREE_N+1)); done
if [ "$JETFREE_N" -lt 4 ]; then
  bad "only $JETFREE_N jet-free frames found — the false-positive guard needs frames to guard"
else
  # One invocation per directory: jet_detect takes a single pattern.
  ALL_CLEAN=1
  for d in "$HERE/control/backgrounds" "$HERE/control/jetfree-extra"; do
    [ -d "$d" ] || continue
    OUT=$("$PY" "$HERE/jet_detect.py" "$d/*.png" 2>&1)
    case "$OUT" in
      *"only 0/"*) ;;
      *) ALL_CLEAN=0; echo "    $(basename "$d"): $OUT" ;;
    esac
  done
  if [ "$ALL_CLEAN" -eq 1 ]; then ok "0 detections across $JETFREE_N jet-free frames"
  else bad "detected a jet in jet-free frames (see above)"; fi
fi

# ---------------------------------------------------------------------------
echo
echo "test 9: the deprecated detector is not silently usable"
# Guard the fixture path first. Without it this passes vacuously: on a missing
# file jet_detect exits at "no frames matched", and the DEPRECATED warning —
# which is printed at invocation, before the glob — is still in the output.
LEGACY_FIXTURE="$HERE/control/generated/ctl_00_cx50_b+0.png"
if [ ! -f "$LEGACY_FIXTURE" ]; then
  bad "fixture $LEGACY_FIXTURE missing — test 9 would pass vacuously"
else
  # Capture first, then grep. Piping straight into `grep -q` under `set -o
  # pipefail` reports a failure even when the match succeeds: grep exits at the
  # first hit, the python process then gets SIGPIPE, and pipefail surfaces that
  # as the pipeline's status.
  LEGACY_OUT=$("$PY" "$HERE/jet_detect.py" --legacy "$LEGACY_FIXTURE" 2>&1)
  case "$LEGACY_OUT" in
    *DEPRECATED*) ok "--legacy output is labelled DEPRECATED" ;;
    *)            bad "--legacy output does not warn: $LEGACY_OUT" ;;
  esac
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
