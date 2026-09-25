#!/bin/bash
# Run every tests/test_*.gd and report TRUE counts.
#
# Why this exists (#118): a GDScript test file that fails to compile, or whose
# tests abort before reaching an assertion, still prints a summary line and
# exits 0. `test_enemy_jet.gd` reported "0 passed, 0 failed" for an unknown
# length of time and every suite run scanned past it as clean. Worse, a file can
# report "13 passed, 0 failed" while three assertions silently evaporated,
# because a runtime error aborts the enclosing function rather than the run.
#
# So a per-file summary line is NOT sufficient evidence that a file ran. This
# runner treats these as failures even when the engine exits 0:
#   - compile or parse errors anywhere in the output
#   - a summary of 0 passed and 0 failed (collected nothing)
#   - no summary line at all (died before printing one)
#   - any non-zero exit
#
# Usage:
#   bash tests/run_all.sh              # whole suite
#   bash tests/run_all.sh enemy        # only files matching a substring

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
FILTER="${1:-}"

# Files with known, accepted failures. Reported as KNOWN and excluded from the
# exit status, but their counts still appear — never hidden.
# test_jet_mesh_builder.gd: 13 pre-existing failures on the legacy 3D jet path.
KNOWN_FAILING="test_jet_mesh_builder.gd"

if [ ! -x "$GODOT" ]; then
  echo "ERROR: Godot not found at $GODOT. Set GODOT=/path/to/Godot." >&2
  exit 3
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/afterburner-suite.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

TOTAL_PASS=0
TOTAL_FAIL=0
BAD_FILES=()
KNOWN_FILES=()

printf '%-34s %8s %8s   %s\n' "FILE" "PASSED" "FAILED" "STATUS"
printf '%s\n' "----------------------------------------------------------------------"

for path in "$REPO_ROOT"/tests/test_*.gd; do
  file="$(basename "$path")"
  if [ -n "$FILTER" ] && [[ "$file" != *"$FILTER"* ]]; then
    continue
  fi

  log="$TMP/$file.log"
  "$GODOT" --headless --path "$REPO_ROOT" --script "res://tests/$file" > "$log" 2>&1
  rc=$?

  summary=$(grep -Eo '[0-9]+ passed, [0-9]+ failed' "$log" | tail -1)
  if [ -z "$summary" ]; then
    passed="-"; failed="-"; status="NO SUMMARY (died before reporting)"
  else
    passed=$(echo "$summary" | awk '{print $1}')
    failed=$(echo "$summary" | awk '{print $3}')
    TOTAL_PASS=$((TOTAL_PASS + passed))
    TOTAL_FAIL=$((TOTAL_FAIL + failed))
    if grep -qE 'Compile Error|Parse Error' "$log"; then
      status="COMPILE ERROR (counts above are not trustworthy)"
    elif [ "$passed" -eq 0 ] && [ "$failed" -eq 0 ]; then
      status="COLLECTED NOTHING"
    elif [ "$failed" -gt 0 ]; then
      status="FAILURES"
    elif [ "$rc" -ne 0 ]; then
      status="NONZERO EXIT ($rc)"
    else
      status="ok"
    fi
  fi

  if [ "$status" = "ok" ]; then
    :
  elif [[ " $KNOWN_FAILING " == *" $file "* ]]; then
    status="KNOWN — $status"
    KNOWN_FILES+=("$file")
  else
    BAD_FILES+=("$file: $status")
  fi

  printf '%-34s %8s %8s   %s\n' "$file" "$passed" "$failed" "$status"
done

echo
echo "TOTAL: $TOTAL_PASS passed, $TOTAL_FAIL failed"

if [ ${#KNOWN_FILES[@]} -gt 0 ]; then
  echo
  echo "Known/accepted (not counted against this run):"
  for f in "${KNOWN_FILES[@]}"; do echo "  - $f"; done
fi

if [ ${#BAD_FILES[@]} -gt 0 ]; then
  echo
  echo "PROBLEMS (${#BAD_FILES[@]}):"
  for f in "${BAD_FILES[@]}"; do echo "  - $f"; done
  echo
  echo "Full output per file is kept only for this run; re-run a single file with:"
  echo "  $GODOT --headless --path $REPO_ROOT --script res://tests/<file>"
  exit 1
fi

echo
echo "Suite clean."
