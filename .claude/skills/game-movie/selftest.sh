#!/bin/bash
# Validation suite for the game-movie skill (#114 §9).
#
# No framework, matching the other skills. Every capture opens a real window —
# MovieWriter SIGABRTs under --headless — so expect windows to flash past.
#
# Ports are allocated from 9640 upward (PID-offset start), skipping any in use.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
CAPTURE="bash $SKILL_DIR/capture-movie.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/game-movie-selftest.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Ports are ALLOCATED, not hard-coded. Other agents run their own Godot
# instances and a collision surfaces as a bogus test failure (it did: an
# unrelated instance on 9595 made the inertness test report exit 9). Never kill
# what we did not start — step over it instead.
#
# The result is returned in $ALLOC_PORT rather than on stdout, and callers MUST
# use `next_port; X=$ALLOC_PORT` — never `X=$(next_port)`. Command substitution
# forks a subshell, so the cursor increment was discarded the instant it
# returned and every call handed back the same port (#136). The whole point of
# the allocator is state that survives across calls, and $() destroys exactly
# that state.
#
# The start offset is derived from the PID so two agents running this suite at
# the same moment do not both open on the same port. Skipping handles the rest.
PORT_BASE=9640
PORT_SPAN=100
PORT_CURSOR=$((PORT_BASE + ($$ % 40)))
ALLOC_PORT=""
next_port() {
  while [ "$PORT_CURSOR" -lt "$((PORT_BASE + PORT_SPAN))" ]; do
    local candidate="$PORT_CURSOR"
    PORT_CURSOR=$((PORT_CURSOR + 1))
    if [ -z "$(lsof -i "tcp:$candidate" -sTCP:LISTEN -t 2>/dev/null)" ]; then
      ALLOC_PORT="$candidate"
      return 0
    fi
    echo "  (port $candidate is in use by another process — skipping)" >&2
  done
  echo "ERROR: no free port in $PORT_BASE-$((PORT_BASE + PORT_SPAN))" >&2
  exit 1
}

PASSED=0
FAILED=0
pass() { PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL: $1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1 — expected '$3', got '$2'"; fi; }

frames_of() {
  ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$1" 2>/dev/null
}
rate_of() {
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$1" 2>/dev/null
}

echo "1. frame count is exact"
# KNOWN-ANSWER CONTROL with a pre-stated abandonment tolerance: a 2-second
# capture must contain EXACTLY 120 frames at EXACTLY 60/1. If this is off by one
# frame, or the rate is anything but 60/1, stop and report — do not widen the
# assertion. MovieWriter's entire value is exactness, and a tool that needs a
# fudge factor has lost the property #113's speed metric depends on.
next_port; P1=$ALLOC_PORT; $CAPTURE --duration 2 --fps 60 --port "$P1" --output "$TMP/t1.mp4" >/dev/null 2>&1
expect "2s at 60fps is exactly 120 frames" "$(frames_of "$TMP/t1.mp4")" "120"
expect "container rate is exactly 60/1" "$(rate_of "$TMP/t1.mp4")" "60/1"

echo
echo "2. fps is not hard-coded"
next_port; P2=$ALLOC_PORT; $CAPTURE --duration 2 --fps 30 --port "$P2" --output "$TMP/t2.mp4" >/dev/null 2>&1
expect "2s at 30fps is exactly 60 frames" "$(frames_of "$TMP/t2.mp4")" "60"
expect "container rate is exactly 30/1" "$(rate_of "$TMP/t2.mp4")" "30/1"

echo
echo "3. sidecar"
SIDE_OUT=$(python3 - "$TMP/t1.mp4.json" "$(frames_of "$TMP/t1.mp4")" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
probe_frames = int(sys.argv[2])
checks = [
    ("schema is game-video-capture/1", d.get("schema") == "game-video-capture/1"),
    ("source is movie-writer", d.get("source") == "movie-writer"),
    ("measured_fps equals --fps", d.get("measured_fps") == 60.0),
    ("encoded_fps equals measured_fps", d.get("encoded_fps") == d.get("measured_fps")),
    ("frames matches ffprobe", d.get("frames") == probe_frames),
    ("wall_elapsed_s present for diagnostics", isinstance(d.get("wall_elapsed_s"), float)),
]
# Judge correction 4: these four carry WALL-CLOCK semantics in
# game-video-capture/1. Emitting 0.0/false here would be a false statement about
# a run whose real frame spacing was nothing of the sort, so they are omitted.
for key in ("interval_mean_s", "interval_stdev_s", "interval_max_s", "pacing_slip"):
    checks.append(("%s omitted, not zeroed" % key, key not in d))
for name, ok in checks:
    print("  %s: %s" % ("PASS" if ok else "FAIL", name))
print("TALLY %d %d" % (sum(1 for _, o in checks if o), sum(1 for _, o in checks if not o)))
PY
)
echo "$SIDE_OUT" | grep -v '^TALLY '
PASSED=$((PASSED + $(echo "$SIDE_OUT" | grep '^TALLY ' | cut -d' ' -f2)))
FAILED=$((FAILED + $(echo "$SIDE_OUT" | grep '^TALLY ' | cut -d' ' -f3)))

echo
next_port; OFFSET_PORT=$ALLOC_PORT
echo "4. input offset is exactly one frame — THROUGH THE ACTION SYSTEM"
# project.godot binds every action to physical_keycode with keycode: 0, so a
# probe via Input.is_key_pressed() passes on an implementation that cannot drive
# the game at all. This asserts through Input.is_action_pressed() on a real
# action, and the control below proves the distinction is not hypothetical.
cat > "$TMP/offset.json" <<'EOF'
{"schema":"capture-input/1","events":[
 {"frame":10,"action":"key_down","key":"Z"},
 {"frame":20,"action":"key_up","key":"Z"},
 {"frame":30,"action":"key","key":"Z"}]}
EOF
"$GODOT" --headless --path "$PROJ_DIR" --quit-after 34 -- --mcp-port "$OFFSET_PORT" \
  --capture-input "$TMP/offset.json" --capture-probe fire_vulcan > "$TMP/probe.log" 2>&1
probe_at() { grep "^PROBE $1 " "$TMP/probe.log" | awk '{print $3}'; }
expect "key_down at F=10: action NOT yet pressed at frame 10" "$(probe_at 10)" "0"
expect "key_down at F=10: action pressed from frame 11 (F+1)" "$(probe_at 11)" "1"
expect "still held at frame 20" "$(probe_at 20)" "1"
expect "key_up at F=20: released from frame 21 (F+1)" "$(probe_at 21)" "0"
expect "tap at F=30: held on frame 31 only" "$(probe_at 31)" "1"
expect "tap at F=30: released again by frame 32" "$(probe_at 32)" "0"

# NEGATIVE CONTROL: an assertion that cannot fail is not an assertion. This
# proves a keycode-only event is inert for actions while still reading as
# pressed via the raw-key API — i.e. that probing the wrong way would go green
# on a broken implementation.
CONTROL=$("$GODOT" --headless --path "$PROJ_DIR" \
  --script res://.claude/skills/game-movie/probes/keycode_only_control.gd 2>&1 \
  | grep "^CONTROL" | head -1)
expect "control: keycode-only event does NOT drive the action" \
  "$(echo "$CONTROL" | grep -o 'keycode_only_action=[01]' | cut -d= -f2)" "0"
expect "control: keycode-only event DOES fool is_key_pressed" \
  "$(echo "$CONTROL" | grep -o 'keycode_only_rawkey=[01]' | cut -d= -f2)" "1"
expect "control: setting both fields drives the action" \
  "$(echo "$CONTROL" | grep -o 'both_action=[01]' | cut -d= -f2)" "1"

echo
echo "5. timeline validation rejects before launching Godot"
check_reject() {
  local label="$1" body="$2"
  next_port; REJECT_PORT=$ALLOC_PORT
  echo "$body" > "$TMP/bad.json"
  rm -f "$TMP/bad.mp4"
  $CAPTURE --duration 1 --port "$REJECT_PORT" --input-script "$TMP/bad.json" --output "$TMP/bad.mp4" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq 2 ] && [ ! -f "$TMP/bad.mp4" ] && [ -z "$(ls -d "${TMPDIR:-/tmp}"/game-movie-$REJECT_PORT.* 2>/dev/null)" ]; then
    pass "$label rejected with exit 2, no capture started"
  else
    fail "$label — exit $rc, mp4 present=$([ -f "$TMP/bad.mp4" ] && echo yes || echo no)"
  fi
}
check_reject "frame 0"        '{"schema":"capture-input/1","events":[{"frame":0,"action":"key","key":"Enter"}]}'
check_reject "negative frame" '{"schema":"capture-input/1","events":[{"frame":-5,"action":"key","key":"Enter"}]}'
check_reject "non-integer frame" '{"schema":"capture-input/1","events":[{"frame":1.5,"action":"key","key":"Enter"}]}'
check_reject "unknown action" '{"schema":"capture-input/1","events":[{"frame":5,"action":"wiggle","key":"Enter"}]}'
check_reject "unknown key"    '{"schema":"capture-input/1","events":[{"frame":5,"action":"key","key":"Nonsense"}]}'
check_reject "wrong schema"   '{"schema":"capture-input/2","events":[]}'
check_reject "malformed JSON" '{"schema":'

echo
echo "6. events past the end of the run are ignored with a warning"
next_port; FAR_PORT=$ALLOC_PORT
cat > "$TMP/far.json" <<'EOF'
{"schema":"capture-input/1","events":[{"frame":99999,"action":"key","key":"Enter"}]}
EOF
$CAPTURE --duration 1 --fps 60 --port "$FAR_PORT" --input-script "$TMP/far.json" \
  --output "$TMP/t6.mp4" > "$TMP/t6.log" 2>&1
expect "out-of-range event still exits 0" "$?" "0"
expect "and still produced its 60 frames" "$(frames_of "$TMP/t6.mp4")" "60"
if grep -q "never fired" "$TMP/t6.log"; then
  pass "warning names the events that never fired"
else
  fail "warning names the events that never fired"
fi

echo
echo "7. same seed reproduces byte-identical output"
next_port; SEED_PORT_A=$ALLOC_PORT; next_port; SEED_PORT_B=$ALLOC_PORT
# Divergence was measured at frame 125, so the window must run well past it.
$CAPTURE --duration 5 --fps 60 --seed 4242 --port "$SEED_PORT_A" --output "$TMP/s1.mp4" >/dev/null 2>&1
$CAPTURE --duration 5 --fps 60 --seed 4242 --port "$SEED_PORT_B" --output "$TMP/s2.mp4" >/dev/null 2>&1
M1=$(md5 -q "$TMP/s1.mp4" 2>/dev/null || md5sum "$TMP/s1.mp4" | cut -d' ' -f1)
M2=$(md5 -q "$TMP/s2.mp4" 2>/dev/null || md5sum "$TMP/s2.mp4" | cut -d' ' -f1)
if [ "$M1" = "$M2" ]; then
  pass "two --seed 4242 runs are byte-identical"
else
  fail "two --seed 4242 runs differ ($M1 vs $M2)"
fi

echo
echo "8. no seed still diverges (proves the conditional is wired, not inverted)"
next_port; NOSEED_PORT_A=$ALLOC_PORT; next_port; NOSEED_PORT_B=$ALLOC_PORT
$CAPTURE --duration 5 --fps 60 --port "$NOSEED_PORT_A" --output "$TMP/n1.mp4" >/dev/null 2>&1
$CAPTURE --duration 5 --fps 60 --port "$NOSEED_PORT_B" --output "$TMP/n2.mp4" >/dev/null 2>&1
N1=$(md5 -q "$TMP/n1.mp4" 2>/dev/null || md5sum "$TMP/n1.mp4" | cut -d' ' -f1)
N2=$(md5 -q "$TMP/n2.mp4" 2>/dev/null || md5sum "$TMP/n2.mp4" | cut -d' ' -f1)
if [ "$N1" != "$N2" ]; then
  pass "two unseeded runs differ, so randomize() still governs normal play"
else
  fail "two unseeded runs are identical — the seed conditional may be inverted"
fi
# And a --seed that cannot take effect must be refused rather than honoured silently.
if grep -q "CaptureInput.requested_seed" "$PROJ_DIR/scripts/game/game_manager_2d.gd"; then
  pass "seed conditional present in game_manager_2d.gd"
else
  fail "seed conditional present in game_manager_2d.gd"
fi

echo
echo "9. inert without --capture-input"
# Exit status of an ordinary bounded run.
next_port; INERT_PORT=$ALLOC_PORT
"$GODOT" --headless --path "$PROJ_DIR" --quit-after 120 -- --mcp-port "$INERT_PORT" > "$TMP/inert.log" 2>&1
expect "normal launch still exits 0" "$?" "0"

# Bridge reachability needs a LIVE instance, so run one without --quit-after and
# stop it ourselves. An earlier version used `--quit-after 120; sleep 3`, which
# finishes headless in well under a second — the probe then answered only
# because an unrelated agent's Godot happened to hold the port. A green that
# came from someone else's process is the worst kind.
next_port; PROBE_PORT=$ALLOC_PORT
"$GODOT" --headless --path "$PROJ_DIR" -- --mcp-port "$PROBE_PORT" > "$TMP/inert-live.log" 2>&1 &
LIVE_PID=$!
for _ in $(seq 1 30); do
  grep -q "Listening on 127.0.0.1:$PROBE_PORT" "$TMP/inert-live.log" 2>/dev/null && break
  kill -0 "$LIVE_PID" 2>/dev/null || break
  sleep 0.5
done
BRIDGE=$(echo '{"cmd":"get_runtime_tree"}' | nc -w 3 localhost "$PROBE_PORT" 2>/dev/null | head -c 20)
kill "$LIVE_PID" 2>/dev/null
wait "$LIVE_PID" 2>/dev/null
if echo "$BRIDGE" | grep -q '"ok"'; then
  pass "bridge still reachable with the autoload installed"
else
  fail "bridge still reachable with the autoload installed (got '$BRIDGE')"
fi
if grep -q "CaptureInput:" "$TMP/inert.log"; then
  fail "autoload stays silent when not capturing"
else
  pass "autoload stays silent when not capturing"
fi

echo
echo "10. intermediate AVI cleanup"
next_port; CLEAN_PORT=$ALLOC_PORT; $CAPTURE --duration 1 --port "$CLEAN_PORT" --output "$TMP/t10.mp4" >/dev/null 2>&1
if [ -z "$(ls -d "${TMPDIR:-/tmp}"/game-movie-$CLEAN_PORT.* 2>/dev/null)" ]; then
  pass "scratch AVI removed by default"
else
  fail "scratch AVI removed by default"
  rm -rf "${TMPDIR:-/tmp}"/game-movie-$CLEAN_PORT.*
fi
next_port; KEEP_PORT=$ALLOC_PORT
KEPT=$($CAPTURE --duration 1 --port "$KEEP_PORT" --keep-avi --output "$TMP/t10b.mp4" 2>&1 | grep "AVI kept" | sed 's/.*kept: //')
if [ -n "$KEPT" ] && [ -f "$KEPT" ]; then
  pass "--keep-avi keeps it and prints the path"
  rm -rf "$(dirname "$KEPT")"
else
  fail "--keep-avi keeps it and prints the path (got '$KEPT')"
fi

echo
echo "11. end-to-end into motion-metrics with no --game-true-fps"
OUT="$TMP/metrics"
bash "$PROJ_DIR/.claude/skills/motion-metrics/compare.sh" \
  --ref "$PROJ_DIR/.reference-cache/video/ab2-longplay.mp4" --ref-window 6:00-6:05 \
  --game "$TMP/s1.mp4" --game-window 0-5 --name game-movie-e2e --out "$OUT" >/dev/null 2>&1
expect "compare.sh accepts the movie via its sidecar alone" "$?" "0"
if [ -f "$OUT/strip-01.png" ] && [ -f "$OUT/report.md" ]; then
  pass "strips and report produced"
else
  fail "strips and report produced"
fi
if grep -q "60.0000" "$OUT/report.md" 2>/dev/null; then
  pass "report carries the exact 60fps true rate from the sidecar"
else
  fail "report carries the exact 60fps true rate from the sidecar"
fi

echo
echo
echo "12. the port allocator actually allocates (#136)"
# The bug: every call site used X=$(next_port), and command substitution forks a
# subshell, so PORT_CURSOR's increment was discarded and all three calls returned
# the SAME port. The suite still went 44/44 because captures run one at a time and
# each releases its port — which is exactly why this needs its own assertion
# rather than being assumed from a green suite.
next_port; A1=$ALLOC_PORT
next_port; A2=$ALLOC_PORT
next_port; A3=$ALLOC_PORT
if [ "$A1" != "$A2" ] && [ "$A2" != "$A3" ] && [ "$A1" != "$A3" ]; then
  pass "three consecutive allocations are distinct ($A1, $A2, $A3)"
else
  fail "three consecutive allocations are distinct (got $A1, $A2, $A3)"
fi
if [ "$A2" -gt "$A1" ] && [ "$A3" -gt "$A2" ]; then
  pass "the cursor advances monotonically"
else
  fail "the cursor advances monotonically (got $A1, $A2, $A3)"
fi
# NEGATIVE CONTROL: reproduce the old shape and confirm it collapses, so this
# assertion is known to be capable of failing.
SUBSHELL_CURSOR=$PORT_CURSOR
legacy_next_port() {
  while [ "$SUBSHELL_CURSOR" -lt 65000 ]; do
    if [ -z "$(lsof -i "tcp:$SUBSHELL_CURSOR" -sTCP:LISTEN -t 2>/dev/null)" ]; then
      echo "$SUBSHELL_CURSOR"; SUBSHELL_CURSOR=$((SUBSHELL_CURSOR + 1)); return 0
    fi
    SUBSHELL_CURSOR=$((SUBSHELL_CURSOR + 1))
  done
}
B1=$(legacy_next_port); B2=$(legacy_next_port)
if [ "$B1" = "$B2" ]; then
  pass "control: the old \$(next_port) form does collapse to one port ($B1)"
else
  fail "control: the old \$(next_port) form does collapse to one port (got $B1, $B2)"
fi

echo
echo "================================"
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
