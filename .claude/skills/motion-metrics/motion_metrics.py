#!/usr/bin/env python3
"""Aligned motion strips for judge/QA gates (#113 v1).

Takes two mp4s — the arcade reference and one of our captures — and emits
side-by-side strip images sampled at the SAME rate in *real* time, plus a
report.md. Nothing here estimates motion: v1 deliberately produces no speed
figure, no px/frame value and no ratio. AB2's dithered ground texture
temporally aliases below ~60fps sampling, so every frame-to-frame estimate on
this footage measures the estimator's ceiling rather than the game's speed
(#113 finding). Quantitative speed is gated on the 60fps capture pipeline
(#114); see SKILL.md.

The one subtlety worth knowing is the time base (§3.4 of the spec). A bridge
capture's container fps is a label, not a measurement — pre-#116 clips are
mislabelled by up to 2.2x. Sampling such a clip at "3 fps" of container time
samples it at 3 x nominal/true fps of real time, so the two strip rows would
not be at matched real intervals while appearing to be. Every window and rate
in this tool is therefore in REAL seconds, converted to container time only at
the point ffmpeg is invoked.
"""

import argparse
import contextlib
import fcntl
import glob
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

import flow_metrics
from flow_metrics import flow_series

# Exit codes — mirrored in SKILL.md's troubleshooting table.
EXIT_USAGE = 2
EXIT_NO_FFMPEG = 3
EXIT_VENV = 4
EXIT_INPUT = 5
EXIT_ASPECT = 6
EXIT_TOO_FEW_CELLS = 7
EXIT_LOCK_TIMEOUT = 8

# A run is a few seconds; this only trips if a peer is wedged. Overridable so
# selftest.sh can exercise the timeout path without waiting five minutes.
LOCK_TIMEOUT_S = float(os.environ.get("MOTION_METRICS_LOCK_TIMEOUT", "300"))
STAGING_PREFIX = ".staging-"

GUTTER = 4
LABEL_BAND_H = 26
TIME_BAND_H = 18
DIVIDER_H = 6
BG = (30, 30, 30)
DIVIDER_COLOR = (90, 90, 90)
REF_LABEL_COLOR = (60, 200, 255)
GAME_LABEL_COLOR = (120, 255, 120)
TIME_COLOR = (210, 210, 210)

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))


class UserError(Exception):
    def __init__(self, message, code=EXIT_USAGE):
        super().__init__(message)
        self.code = code


# --------------------------------------------------------------------------
# Pure helpers. Kept free of I/O so selftest.sh can exercise them directly.
# --------------------------------------------------------------------------

_TIMECODE = re.compile(r"^(?:(?:(\d+):)?(\d+):)?(\d+(?:\.\d+)?)$")


def parse_timecode(token):
    """`[[HH:]MM:]SS[.frac]` or bare seconds -> float seconds."""
    m = _TIMECODE.match(token.strip())
    if not m:
        raise UserError(
            "bad timecode %r — expected [[HH:]MM:]SS[.frac] or bare seconds, e.g. 6:00, 1:02:03.5, 370" % token
        )
    hours, minutes, seconds = m.groups()
    return int(hours or 0) * 3600 + int(minutes or 0) * 60 + float(seconds)


def parse_window(spec):
    """`START-END` -> (start_s, end_s), both in real seconds."""
    parts = spec.split("-")
    if len(parts) != 2:
        raise UserError(
            "bad window %r — expected exactly one '-' separating START and END, e.g. 6:00-6:10" % spec
        )
    start, end = parse_timecode(parts[0]), parse_timecode(parts[1])
    if start >= end:
        raise UserError("bad window %r — START (%.3fs) must be before END (%.3fs)" % (spec, start, end))
    if start < 0:
        raise UserError("bad window %r — START must not be negative" % spec)
    return start, end


def resolve_true_fps(clip_path, flag, container_fps, fallback_to_container):
    """Real capture rate of a clip, and a human-readable source for the report.

    An explicit flag always wins over a sidecar: the operator may know the
    sidecar is stale or belongs to a re-encode. Absent a flag, a #116 sidecar
    is the only *measured* answer. The reference falls back to its container
    fps (a real video recording's container fps is its time base); a game
    capture does not — stating it is the discipline this tool exists to add.
    """
    if flag is not None:
        if str(flag).strip() == "container":
            return container_fps, "declared --true-fps container (%.4f, NOT measured)" % container_fps
        try:
            value = float(flag)
        except ValueError:
            raise UserError("--true-fps must be a number or the literal 'container', got %r" % flag)
        if value <= 0:
            raise UserError("--true-fps must be positive, got %r" % flag)
        return value, "declared on the command line (%.4f, NOT measured)" % value

    sidecar = clip_path + ".json"
    if os.path.exists(sidecar):
        try:
            with open(sidecar) as fh:
                data = json.load(fh)
            measured = float(data["measured_fps"])
        except (ValueError, KeyError, OSError) as exc:
            raise UserError("sidecar %s exists but has no usable measured_fps (%s)" % (sidecar, exc))
        return measured, "measured, sidecar %s" % sidecar

    if fallback_to_container:
        return container_fps, "container fps (%.4f), no sidecar" % container_fps

    raise UserError(
        "no time base for %s.\n"
        "  A bridge capture's container fps is a LABEL, not a measurement — pre-#116\n"
        "  captures are mislabelled by up to 2.2x, which would misalign the strip rows.\n"
        "  Either re-capture with capture-video.sh (writes %s automatically),\n"
        "  or pass --game-true-fps <rate>, or --game-true-fps container to accept the label."
        % (clip_path, sidecar)
    )


def _even(value):
    """Round to the nearest even integer at or below the rounded value.

    Even dimensions keep libx264/ffmpeg filters and the yuv420p chroma plane
    happy, and keep the two rows' cell grids identical.
    """
    rounded = int(round(value))
    return rounded - (rounded % 2)


def compute_crop_rect(width, height, crop):
    """(top, bottom, left, right) fractions -> (cw, ch, cx, cy) for ffmpeg."""
    top, bottom, left, right = crop
    if min(crop) < 0 or top + bottom >= 1.0 or left + right >= 1.0:
        raise UserError("--crop fractions must be >= 0 and leave a non-empty frame, got %s" % (crop,))
    cw = _even(width * (1.0 - left - right))
    ch = _even(height * (1.0 - top - bottom))
    cx = int(round(width * left))
    cy = int(round(height * top))
    if cw < 2 or ch < 2:
        raise UserError("--crop leaves nothing to compare (%dx%d)" % (cw, ch))
    return cw, ch, cx, cy


def resolve_aspect(ref_rect, game_rect, policy):
    """Reconcile post-crop aspects. Returns (ref_rect, game_rect, note)."""
    ref_aspect = ref_rect[0] / ref_rect[1]
    game_aspect = game_rect[0] / game_rect[1]
    smaller = min(ref_aspect, game_aspect)
    delta = abs(ref_aspect - game_aspect) / smaller
    if delta <= 0.02:
        return ref_rect, game_rect, "aspects within %.2f%% (%.4f vs %.4f), no adjustment" % (
            delta * 100, ref_aspect, game_aspect)
    if policy != "center-crop":
        raise UserError(
            "post-crop aspects differ by %.1f%%: reference %.4f (%dx%d) vs game %.4f (%dx%d).\n"
            "  Comparing them would distort one row. Re-run with --aspect-policy center-crop\n"
            "  to centre-crop the wider clip to the narrower aspect."
            % (delta * 100, ref_aspect, ref_rect[0], ref_rect[1], game_aspect, game_rect[0], game_rect[1]),
            code=EXIT_ASPECT,
        )

    target = smaller
    rects = []
    for cw, ch, cx, cy in (ref_rect, game_rect):
        if cw / ch > target:
            new_w = _even(ch * target)
            rects.append((new_w, ch, cx + (cw - new_w) // 2, cy))
        else:
            rects.append((cw, ch, cx, cy))
    return rects[0], rects[1], "centre-cropped to aspect %.4f (was %.4f vs %.4f, %.1f%% apart)" % (
        target, ref_aspect, game_aspect, delta * 100)


def plan_sampling(duration, strip_fps, cols, max_strips):
    """-> (n_cells, interval_s). Both in REAL time.

    When the window holds more cells than the strip cap, the cells are spread
    uniformly across the whole window rather than truncating its tail — a strip
    covering the first third of a 30s window would silently answer a different
    question than the one asked. The widened interval is folded back into the
    ffmpeg `fps` filter rate (see real_to_container_fps) so extraction stays a
    single pass; nothing is extracted and then thrown away.
    """
    cap = cols * max_strips
    available = int(math.floor(duration * strip_fps + 1e-9))
    if available <= cap:
        return available, 1.0 / strip_fps
    return cap, duration / cap


def container_window(real_start, real_duration, time_scale):
    """Real-time window -> container-time window."""
    return real_start * time_scale, real_duration * time_scale


def real_to_container_fps(effective_real_fps, time_scale):
    """The rate to ask ffmpeg's fps filter for, to land cells at a real rate."""
    return effective_real_fps / time_scale


# --------------------------------------------------------------------------
# I/O
# --------------------------------------------------------------------------

def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def probe(path):
    if not os.path.exists(path):
        raise UserError("input not found: %s" % path, code=EXIT_INPUT)
    result = _run([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height,avg_frame_rate",
        "-show_entries", "format=duration",
        "-of", "json", path,
    ])
    if result.returncode != 0:
        raise UserError("could not probe %s: %s" % (path, result.stderr.strip()), code=EXIT_INPUT)
    try:
        data = json.loads(result.stdout)
        stream = data["streams"][0]
        num, den = stream["avg_frame_rate"].split("/")
        fps = float(num) / float(den)
        return {
            "path": path,
            "width": int(stream["width"]),
            "height": int(stream["height"]),
            "container_fps": fps,
            "container_duration": float(data["format"]["duration"]),
        }
    except (KeyError, IndexError, ValueError, ZeroDivisionError) as exc:
        raise UserError("unusable probe output for %s (%s)" % (path, exc), code=EXIT_INPUT)


@contextlib.contextmanager
def out_dir_lock(out_dir, timeout_s=LOCK_TIMEOUT_S):
    """Exclusive lock over an `--out` directory, held for the whole run.

    Two agents working the same issue land on the same `--out`, because both
    agent inserts use a stable `--name judge-<issue>` / `--name qa-<issue>`.
    Without this, both processes write `strip-01.png` at the same instant and
    every strip ends up a torn PNG: valid signature and IHDR, interleaved IDAT,
    `libpng error: IDAT: CRC error`. `file` and `sips` call those files fine, so
    nothing signals the agent to distrust them (#119).

    `fcntl.flock` rather than a PID lockfile: the kernel drops it when the fd
    closes, including on SIGKILL, so there is no stale-lock recovery path to get
    wrong. Serializing also preserves the documented "`--out` already populated:
    overwrite, do not error" semantics — the second run simply waits, then
    replaces the first run's output completely.
    """
    os.makedirs(out_dir, exist_ok=True)
    lock_path = os.path.join(out_dir, ".lock")
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o644)
    deadline = time.monotonic() + timeout_s
    announced = False
    try:
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.monotonic() >= deadline:
                    raise UserError(
                        "another compare.sh run has held %s for over %ds.\n"
                        "  Concurrent runs sharing one --out are serialized so they cannot\n"
                        "  corrupt each other's strips. If nothing else is running, remove the\n"
                        "  lock file, or give this run its own --out / --name."
                        % (lock_path, int(timeout_s)), code=EXIT_LOCK_TIMEOUT)
                if not announced:
                    print("Waiting for another compare.sh run to finish with %s ..." % out_dir,
                          file=sys.stderr)
                    announced = True
                time.sleep(0.25)
        yield
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)


def clear_previous_run(out_dir):
    """Remove this run's own artifacts from a re-used --out directory.

    `--out` defaults to a directory derived from `--name`, and both the judge
    and QA inserts tell agents to use a stable `--name judge-<issue>`. Re-running
    after a fix therefore lands in a populated directory. A shorter window
    produces fewer strips, so without this the leftover strip-02/03 from the
    previous run stay on disk showing a different window entirely, and the agent
    reads them as current evidence ("Read every strip-NN.png").

    Deliberately narrow: only the files this tool writes. An operator may have
    put notes or a copied report in the directory, and `--out` can be pointed at
    an existing path, so this must never behave like `rm -rf <out_dir>`. The
    `.lock` file is excluded for the obvious reason.

    Only ever called while holding out_dir_lock(), which is what makes sweeping
    abandoned `.staging-*` trees safe — no peer can be mid-write in one.
    """
    for entry in os.listdir(out_dir):
        path = os.path.join(out_dir, entry)
        if re.fullmatch(r"strip-\d+\.png", entry) or entry == "report.md":
            try:
                os.remove(path)
            except OSError:
                pass
        elif entry == ".frames" or entry.startswith(STAGING_PREFIX):
            shutil.rmtree(path, ignore_errors=True)


def publish(staging_dir, out_dir, artifacts):
    """Move finished artifacts into place with os.replace (atomic per file).

    The lock already prevents two runs from interleaving, so this is the second
    line of defence and the one that covers a crash: a run that dies mid-compose
    leaves a half-written PNG in the staging tree, never at the path an agent is
    told to read.
    """
    published = []
    for name in artifacts:
        src = os.path.join(staging_dir, name)
        dst = os.path.join(out_dir, name)
        os.replace(src, dst)
        published.append(dst)
    return published


def extract(clip, rect, cell_size, cstart, cdur, cfps, n_cells, out_dir):
    # Fresh per-clip directory: composing must never be able to pick up a
    # previous run's cells. clear_previous_run() already removed the tree, but a
    # second guard here keeps extract() correct in isolation.
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir, exist_ok=True)
    cw, ch, cx, cy = rect
    scale_flags = "area" if cell_size[0] < cw else "bicubic"
    vf = "fps=%.6f,crop=%d:%d:%d:%d,scale=%d:%d:flags=%s,format=rgb24" % (
        cfps, cw, ch, cx, cy, cell_size[0], cell_size[1], scale_flags)
    cmd = [
        "ffmpeg", "-v", "error",
        "-ss", "%.6f" % cstart, "-t", "%.6f" % cdur, "-i", clip["path"],
        "-vf", vf, "-frames:v", str(n_cells),
        os.path.join(out_dir, "c-%03d.png"), "-y",
    ]
    result = _run(cmd)
    # Walk the expected sequence rather than globbing the directory. ffmpeg
    # numbers from 1 and stops where it stops, so the contiguous run starting at
    # c-001 IS this invocation's output; anything else in the directory is not
    # ours and must not reach the compositor.
    frames = []
    for i in range(1, n_cells + 1):
        path = os.path.join(out_dir, "c-%03d.png" % i)
        if not os.path.exists(path):
            break
        frames.append(path)
    if len(frames) < 2:
        raise UserError(
            "extracted %d frames from %s — need at least 2 cells.\n  ffmpeg said: %s"
            % (len(frames), clip["path"], result.stderr.strip() or "(nothing)"),
            code=EXIT_TOO_FEW_CELLS,
        )
    return frames


def _mmss(seconds):
    return "%d:%02d" % (int(seconds) // 60, int(seconds) % 60)


def compose_strips(cv2, np, ref_frames, game_frames, cell_size, args, meta, out_dir):
    cell_w, cell_h = cell_size
    cols = args.strip_cols
    n = min(len(ref_frames), len(game_frames))
    strip_w = cols * cell_w + (cols - 1) * GUTTER
    row_h = LABEL_BAND_H + cell_h + TIME_BAND_H
    strip_h = row_h * 2 + DIVIDER_H

    ref_label = "AB2 REFERENCE   t0=%s  (%s)" % (_mmss(meta["ref_start"]), os.path.basename(args.ref))
    game_label = "GAME CAPTURE    t0=%s  %s" % (_mmss(meta["game_start"]), os.path.basename(args.game))

    written = []
    for strip_index in range(min(args.max_strips, math.ceil(n / cols))):
        img = np.full((strip_h, strip_w, 3), BG, dtype=np.uint8)
        img[row_h:row_h + DIVIDER_H, :] = DIVIDER_COLOR

        for row, (frames, label, color) in enumerate((
            (ref_frames, ref_label, REF_LABEL_COLOR),
            (game_frames, game_label, GAME_LABEL_COLOR),
        )):
            row_top = row * (row_h + DIVIDER_H)
            cv2.putText(img, label, (6, row_top + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                        color, 1, cv2.LINE_AA)
            frame_top = row_top + LABEL_BAND_H
            time_top = frame_top + cell_h
            for col in range(cols):
                cell_index = strip_index * cols + col
                if cell_index >= n:
                    break
                x = col * (cell_w + GUTTER)
                cell = cv2.imread(frames[cell_index], cv2.IMREAD_COLOR)
                if cell is None:
                    continue
                if cell.shape[0] != cell_h or cell.shape[1] != cell_w:
                    cell = cv2.resize(cell, (cell_w, cell_h), interpolation=cv2.INTER_AREA)
                img[frame_top:frame_top + cell_h, x:x + cell_w] = cell
                cv2.putText(img, "+%.2fs" % (cell_index * meta["interval"]),
                            (x + 4, time_top + 13), cv2.FONT_HERSHEY_SIMPLEX, 0.38,
                            TIME_COLOR, 1, cv2.LINE_AA)

        path = os.path.join(out_dir, "strip-%02d.png" % (strip_index + 1))
        cv2.imwrite(path, img)
        written.append(path)
    return written, n


def write_report(args, meta, strips, out_dir, warnings):
    lines = []
    add = lines.append
    add("# Motion comparison — %s" % args.name)
    add("Generated %s" % datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    add("")
    if warnings:
        add("## Warnings")
        for w in warnings:
            add("- %s" % w)
        add("")
    add("## Inputs")
    add("| clip | path | resolution | container fps | true fps | true fps source | window (real) | analysed (real) |")
    add("|---|---|---|---|---|---|---|---|")
    for key, label in (("ref", "reference"), ("game", "game")):
        c = meta[key]
        add("| %s | `%s` | %dx%d | %.4f | %.4f | %s | %s | %.3fs |" % (
            label, c["path"], c["width"], c["height"], c["container_fps"],
            c["true_fps"], c["true_fps_source"], c["window_label"], meta["effective_duration"]))
    add("")
    add("## Normalization")
    add("- crop fractions (top,bottom,left,right): `%s`, applied identically to both clips" %
        ",".join("%g" % v for v in args.crop))
    add("- aspect policy `%s` — %s" % (args.aspect_policy, meta["aspect_note"]))
    add("- cell size: %dx%d px" % (meta["cell_size"][0], meta["cell_size"][1]))
    add("- sampling interval (real time): %.4fs (%.3f cells/s)" % (meta["interval"], 1.0 / meta["interval"]))
    add("- strips produced: %d, up to %d cells each, %d cells total" % (
        len(strips), args.strip_cols, meta["cells"]))
    if meta["widened"]:
        add("- window held more cells than `--max-strips x --strip-cols` allows, so %d cells were spread "
            "uniformly across it; the interval above is the widened one, folded into the extraction rate."
            % meta["cells"])
    if meta["truncation_note"]:
        add("- %s" % meta["truncation_note"])
    add("")
    add("## Time base")
    add("All windows and intervals above are in **real** seconds. Container time differs whenever a clip's")
    add("true rate differs from its container fps.")
    add("")
    for key, label in (("ref", "reference"), ("game", "game")):
        c = meta[key]
        add("- **%s**: container %.4f fps, true %.4f fps (time scale %.4f) — %s" % (
            label, c["container_fps"], c["true_fps"], c["time_scale"], c["true_fps_source"]))
    add("")
    if meta["declared"]:
        add("> **A true rate here was DECLARED, not measured.** A pre-#116 capture's container fps is a")
        add("> label applied after an unpaced grab loop; the real rate can be off by up to 2.2x, which")
        add("> shifts one row against the other in real time. Re-capture with `capture-video.sh` (which")
        add("> writes a measured sidecar) before drawing conclusions from cell-to-cell correspondence.")
        add("")
    add("## Strips")
    add("| file | covers (real time) | cell interval |")
    add("|---|---|---|")
    for i, path in enumerate(strips):
        first = i * args.strip_cols
        last = min(first + args.strip_cols, meta["cells"]) - 1
        add("| `%s` | +%.2fs to +%.2fs | %.4fs |" % (
            os.path.basename(path), first * meta["interval"], last * meta["interval"], meta["interval"]))
    add("")
    add("What to look for: pick the same cell index in both rows and compare horizon height,")
    add("ground detail, object count, jet pose and explosion size.")
    add("")
    _add_speed_section(add, meta.get("speed") or {})
    add("## Reproduce")
    add("```bash")
    add(meta["command"])
    add("```")
    path = os.path.join(out_dir, "report.md")
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


# --------------------------------------------------------------------------

def _add_speed_section(add, speed):
    """Speed, or an explicit account of why there is none.

    The scope guard inverts with the sampling rate: below 60fps a numeric speed
    figure in this file is a defect, and at 60fps with the gate passed its
    ABSENCE is. Both directions are asserted by selftest.
    """
    if speed.get("reported"):
        gates = speed["gates"]
        add("## Speed (quantitative)")
        add("Measured at %.0f fps on both clips, over textured regions only, at a work width"
            % flow_metrics.SPEED_MIN_FPS)
        add("of %d px. Flat sky carries no motion information; including it would compare how"
            % speed["work_width"])
        add("much sky each clip shows rather than how fast each one moves.")
        add("")
        add("| clip | mean px/frame | peak | p95 | mean as % of frame width | textured pixels |")
        add("|---|---|---|---|---|---|")
        for key, label in (("ref", "AB2 reference"), ("game", "game")):
            s = gates[key]["summary"]
            add("| %s | **%.4f** | %.4f | %.4f | %.3f%% | %.1f%% |" % (
                label, s["mean"], s["peak"], s["p95"], s["mean_pct_width"],
                100.0 * gates[key]["textured_fraction"]))
        add("")
        add("**Speed ratio (game / reference): %.4f** — our game moves at %.1f%% of the"
            % (speed["ratio"], 100.0 * speed["ratio"]))
        add("arcade's speed over these windows.")
        add("")
        add("Curves: `flow-plot.png`. Per-frame values: `flow-ref.csv`, `flow-game.csv`.")
        add("")
        add("### Entry gate (passed — this is why the figures above are reported)")
        add("Each window was independently resampled at %.0f fps, where per-frame displacement"
            % (flow_metrics.SPEED_MIN_FPS / 2))
        add("is exactly doubled. A measured ratio near 0.5 means the sampling is above the")
        add("aliasing knee for that content; tolerance %.0f%%, set before measuring."
            % (flow_metrics.ENTRY_GATE_TOLERANCE * 100))
        add("")
        add("| clip | measured ratio | true | error | verdict |")
        add("|---|---|---|---|---|")
        for key, label in (("ref", "AB2 reference"), ("game", "game")):
            g = gates[key]
            add("| %s | %.4f | 0.5 | %+.1f%% | PASS |" % (label, g["ratio"], g["error_pct"]))
        add("")
        return

    add("## Speed — NOT REPORTED")
    add("")
    reason = speed.get("reason") or "speed was not requested"
    for line in str(reason).splitlines():
        add(line.strip())
    add("")
    gates = speed.get("gates")
    if gates:
        # Gate diagnostics only. The per-clip flow magnitudes are deliberately
        # NOT printed here: they are exactly the numbers a reader would quote,
        # and the whole point of this section is that they did not qualify.
        add("| clip | decimation ratio | true | error | verdict |")
        add("|---|---|---|---|---|")
        for key, label in (("ref", "AB2 reference"), ("game", "game")):
            g = gates.get(key)
            if not g:
                continue
            add("| %s | %.4f | 0.5 | %+.1f%% | %s |" % (
                label, g["ratio"], g["error_pct"], "pass" if g["passed"] else "**FAIL**"))
        add("")
        for key, label in (("ref", "AB2 reference"), ("game", "game")):
            g = gates.get(key)
            if not g or g["passed"]:
                continue
            h = g["headroom"]
            # QUALITATIVE ONLY. This sentence used to quote the 30fps-arm p95 and
            # the ceiling as bare "px" figures — which slipped past a guard
            # looking for "px/frame" and printed a displacement magnitude two
            # lines above the claim that no such figure appears (#127 QA). The
            # distinction between the two causes is what a reader needs; the
            # numbers behind it are exactly what they must not quote from a
            # window that failed certification.
            add("%s: %s" % (label, (
                "the 30fps arm is running at the estimator's ceiling, so this is **estimator "
                "saturation** — lower the window's motion or raise `--flow-work-width`."
                if h["saturated"] else
                "the 30fps arm sits well below the estimator's ceiling, so this is **content "
                "aliasing, not estimator saturation** — the texture itself decorrelates between "
                "samples, and no work-width or parameter change will recover it.")))
            add("")
    add("No px/frame figure and no speed ratio appear above, deliberately. A number with a")
    add("known systematic error of this size is worse than no number: #113 exists because a")
    add("confident flow figure with no signal in it passed three review gates.")
    add("")


def parse_crop(spec):
    parts = spec.split(",")
    if len(parts) != 4:
        raise UserError("--crop needs four comma-separated fractions T,B,L,R, got %r" % spec)
    try:
        return tuple(float(p) for p in parts)
    except ValueError:
        raise UserError("--crop values must be numbers, got %r" % spec)


def build_parser():
    p = argparse.ArgumentParser(
        prog="compare.sh",
        description="Aligned motion strips: reference vs game capture, sampled at the same REAL rate. "
                    "Produces no speed figures by design — see SKILL.md.",
    )
    p.add_argument("--ref", required=True, help="reference (arcade) mp4")
    p.add_argument("--ref-window", required=True, metavar="START-END", help="window in REAL time, e.g. 6:00-6:10")
    p.add_argument("--game", required=True, help="game capture mp4")
    p.add_argument("--game-window", metavar="START-END", help="window in REAL time (default: whole clip)")
    p.add_argument("--out", help="output dir (default .reference-cache/metrics/<name>)")
    p.add_argument("--name", help="run name (default run-YYYYMMDD-HHMMSS)")
    p.add_argument("--game-true-fps", help="real capture rate, or 'container'. Required unless a sidecar exists")
    p.add_argument("--ref-true-fps", help="same for the reference (default: its container fps)")
    p.add_argument("--strip-fps", type=float, default=3.0, help="common sampling rate in REAL time (default 3.0)")
    p.add_argument("--strip-cols", type=int, default=8, help="cells per strip image (default 8)")
    p.add_argument("--strip-cell-width", type=int, default=180, help="cell width in px (default 180)")
    p.add_argument("--max-strips", type=int, default=3, help="cap on strip images (default 3)")
    p.add_argument("--crop", default="0.12,0.12,0,0", help="T,B,L,R fractions cropped off both clips")
    p.add_argument("--aspect-policy", choices=("strict", "center-crop"), default="strict")
    p.add_argument("--keep-frames", action="store_true", help="keep extracted frames for debugging")
    p.add_argument("--speed", choices=("auto", "on", "off"), default="auto",
                   help="quantitative speed: auto (report iff both clips >=60fps and the "
                        "entry gate passes), on (require it, exit 2 otherwise), off")
    p.add_argument("--flow-work-width", type=int, default=flow_metrics.DEFAULT_WORK_WIDTH,
                   help="width the flow pass analyses at (default %d)" % flow_metrics.DEFAULT_WORK_WIDTH)
    p.add_argument("--flow-sobel", type=float, default=flow_metrics.SOBEL_THRESHOLD,
                   help="gradient threshold selecting textured pixels (default %.0f)"
                        % flow_metrics.SOBEL_THRESHOLD)
    return p


def run(args, argv):
    import numpy as np  # noqa: PLC0415 — deferred so --help works without the venv
    try:
        import cv2  # noqa: PLC0415
    except ImportError as exc:
        raise UserError("opencv is not importable (%s); re-run via compare.sh" % exc, code=EXIT_VENV)

    args.crop = parse_crop(args.crop)
    if args.strip_fps <= 0 or args.strip_cols < 1 or args.max_strips < 1 or args.strip_cell_width < 2:
        raise UserError("--strip-fps, --strip-cols, --max-strips and --strip-cell-width must be positive")

    clips = {"ref": probe(args.ref), "game": probe(args.game)}

    for key, flag, fallback in (("ref", args.ref_true_fps, True), ("game", args.game_true_fps, False)):
        c = clips[key]
        c["true_fps"], c["true_fps_source"] = resolve_true_fps(
            c["path"], flag, c["container_fps"], fallback)
        c["time_scale"] = c["true_fps"] / c["container_fps"]
        c["real_duration"] = c["container_duration"] / c["time_scale"]
        if args.strip_fps > c["true_fps"]:
            raise UserError(
                "--strip-fps %.3f exceeds the %s clip's true rate of %.3f fps — it cannot supply "
                "distinct frames that fast. Use --strip-fps %.1f or lower."
                % (args.strip_fps, key, c["true_fps"], math.floor(c["true_fps"] * 10) / 10))

    windows = {}
    for key, spec in (("ref", args.ref_window), ("game", args.game_window)):
        c = clips[key]
        if spec is None:
            windows[key] = (0.0, c["real_duration"])
        else:
            start, end = parse_window(spec)
            if end > c["real_duration"] + 1e-6:
                raise UserError(
                    "%s window %s ends at %.3fs but the clip is only %.3f REAL seconds long "
                    "(container %.3fs at a true rate of %.3f fps). Windows are never clamped silently."
                    % (key, spec, end, c["real_duration"], c["container_duration"], c["true_fps"]))
            windows[key] = (start, end)
        c["window_label"] = "%.3f-%.3fs" % windows[key]

    ref_dur = windows["ref"][1] - windows["ref"][0]
    game_dur = windows["game"][1] - windows["game"][0]
    effective = min(ref_dur, game_dur)
    truncation_note = ""
    if abs(ref_dur - game_dur) > 1e-6:
        truncation_note = (
            "windows differ in length (reference %.3fs, game %.3fs); both truncated from their start "
            "to %.3fs so cells stay time-aligned rather than proportionally aligned"
            % (ref_dur, game_dur, effective))
        print("WARNING: %s" % truncation_note, file=sys.stderr)

    rects = {k: compute_crop_rect(clips[k]["width"], clips[k]["height"], args.crop) for k in clips}
    rects["ref"], rects["game"], aspect_note = resolve_aspect(rects["ref"], rects["game"], args.aspect_policy)

    # Both rows must share a cell height or the grids stop lining up. Under
    # `strict` the aspects are within 2%, which bounds the game row's vertical
    # distortion to under 2%; under `center-crop` they are exactly equal.
    cell_w = args.strip_cell_width
    cell_h = _even(round(cell_w / (rects["ref"][0] / rects["ref"][1])))
    cell_size = (cell_w, cell_h)

    cells, interval = plan_sampling(effective, args.strip_fps, args.strip_cols, args.max_strips)
    if cells < 2:
        raise UserError(
            "window yields %d cell(s) at --strip-fps %.3f over %.3fs — need at least 2."
            % (cells, args.strip_fps, effective), code=EXIT_TOO_FEW_CELLS)
    widened = abs(interval - 1.0 / args.strip_fps) > 1e-9
    effective_real_fps = 1.0 / interval

    name = args.name or datetime.now().strftime("run-%Y%m%d-%H%M%S")
    args.name = name
    out_dir = args.out or os.path.join(REPO_ROOT, ".reference-cache", "metrics", name)
    out_dir = os.path.abspath(out_dir)

    # Everything from here to publish() runs under an exclusive lock on out_dir,
    # and writes into a staging tree rather than the paths agents are told to
    # read. Two concurrent runs therefore serialize instead of interleaving, and
    # a failure leaves the directory empty rather than half-written (#119).
    with out_dir_lock(out_dir):
        clear_previous_run(out_dir)
        staging = tempfile.mkdtemp(dir=out_dir, prefix=STAGING_PREFIX)
        try:
            return _build_and_publish(
                cv2, np, args, argv, clips, windows, rects, cell_size, cells,
                interval, widened, effective, effective_real_fps, truncation_note,
                aspect_note, out_dir, staging)
        finally:
            shutil.rmtree(staging, ignore_errors=True)


def _build_and_publish(cv2, np, args, argv, clips, windows, rects, cell_size, cells,
                       interval, widened, effective, effective_real_fps, truncation_note,
                       aspect_note, out_dir, staging):
    frames_root = os.path.join(staging, "frames")

    extracted = {}
    for key in ("ref", "game"):
        c = clips[key]
        cstart, cdur = container_window(windows[key][0], effective, c["time_scale"])
        cfps = real_to_container_fps(effective_real_fps, c["time_scale"])
        extracted[key] = extract(c, rects[key], cell_size, cstart, cdur, cfps, cells,
                                 os.path.join(frames_root, key))

    meta = {
        "ref": clips["ref"], "game": clips["game"],
        "ref_start": windows["ref"][0], "game_start": windows["game"][0],
        "interval": interval, "cells": cells, "widened": widened,
        "cell_size": cell_size, "aspect_note": aspect_note,
        "truncation_note": truncation_note,
        "effective_duration": effective,
        "declared": any("NOT measured" in clips[k]["true_fps_source"] for k in clips),
        "command": "bash .claude/skills/motion-metrics/compare.sh " + " ".join(_quote(a) for a in argv),
    }

    strips, used = compose_strips(cv2, np, extracted["ref"], extracted["game"], cell_size, args, meta, staging)
    meta["cells"] = min(cells, used)

    speed = run_speed_pass(cv2, np, args, clips, windows, rects, effective, staging)
    meta["speed"] = speed

    write_report(args, meta, strips, staging, _collect_warnings(clips, truncation_note))

    # Publish only once every artifact is fully written.
    extras = [os.path.basename(p) for p in speed.get("artifacts", [])]
    published = publish(staging, out_dir,
                        [os.path.basename(p) for p in strips] + extras + ["report.md"])
    if args.keep_frames:
        kept = os.path.join(out_dir, ".frames")
        # Must not exist, or shutil.move nests inside it instead of replacing.
        shutil.rmtree(kept, ignore_errors=True)
        shutil.move(frames_root, kept)
    # Otherwise the frames die with the staging tree — default because they are
    # frames of copyrighted arcade footage.

    print("Strips: %s" % ", ".join(p for p in published if "strip-" in p))
    for path in published:
        if "flow" in os.path.basename(path):
            print("Speed artifact: %s" % path)
    print("Report: %s" % published[-1])
    return 0


def extract_flow_frames(clip, rect, work_width, real_start, real_duration, real_fps, out_dir):
    """Grayscale frames at a given REAL rate, for the flow pass.

    Shares the crop and the real-time conversion with the strip path, so the two
    halves of the report describe the same pixels over the same seconds.
    """
    os.makedirs(out_dir, exist_ok=True)
    cw, ch, cx, cy = rect
    cstart, cdur = container_window(real_start, real_duration, clip["time_scale"])
    cfps = real_to_container_fps(real_fps, clip["time_scale"])
    vf = ("fps=%.6f,crop=%d:%d:%d:%d,scale=%d:-2:flags=area,format=gray"
          % (cfps, cw, ch, cx, cy, work_width))
    result = _run([
        "ffmpeg", "-v", "error",
        "-ss", "%.6f" % cstart, "-t", "%.6f" % cdur, "-i", clip["path"],
        "-vf", vf, "-frames:v", str(int(math.ceil(real_duration * real_fps))),
        os.path.join(out_dir, "f-%05d.png"), "-y",
    ])
    frames = sorted(glob.glob(os.path.join(out_dir, "f-*.png")))
    if len(frames) < 2:
        raise UserError("flow extraction produced %d frames from %s: %s"
                        % (len(frames), clip["path"], result.stderr.strip() or "(nothing)"),
                        code=EXIT_TOO_FEW_CELLS)
    return frames


def run_speed_pass(cv2, np, args, clips, windows, rects, effective, staging):
    """Quantitative speed, or a documented refusal to report it.

    The refusal path is not a failure mode — it is the deliverable when the
    entry gate says a measurement would be fiction. #113 exists because a
    confident number with no signal in it passed three gates.
    """
    mode = args.speed
    below = [k for k in ("ref", "game") if clips[k]["true_fps"] < flow_metrics.SPEED_MIN_FPS]

    if mode == "off":
        return {"reported": False, "reason": "--speed off", "artifacts": []}

    if below:
        detail = "; ".join("%s clip is %.3f fps" % (k, clips[k]["true_fps"]) for k in below)
        message = (
            "speed needs a true rate of at least %.0f fps on BOTH clips (%s).\n"
            "  Below that, AB2's dithered ground temporally aliases and a flow figure\n"
            "  measures the estimator's ceiling rather than the game's speed (#113).\n"
            "  Re-capture the game with the game-movie skill (60fps, exact) and use\n"
            "  the 60fps reference at .reference-cache/video/ab2-longplay-60fps.mp4."
            % (flow_metrics.SPEED_MIN_FPS, detail))
        if mode == "on":
            raise UserError(message)
        # Same wording in the report as in the exit-2 message: a reader should
        # not have to re-run with --speed on to find out why there is no number.
        return {"reported": False, "reason": message, "artifacts": []}

    work_width = args.flow_work_width
    flow_root = os.path.join(staging, "flow")
    series = {}
    gates = {}
    for key in ("ref", "game"):
        full = extract_flow_frames(clips[key], rects[key], work_width, windows[key][0],
                                   effective, flow_metrics.SPEED_MIN_FPS,
                                   os.path.join(flow_root, key, "full"))
        half = extract_flow_frames(clips[key], rects[key], work_width, windows[key][0],
                                   effective, flow_metrics.SPEED_MIN_FPS / 2.0,
                                   os.path.join(flow_root, key, "half"))
        full_series, textured = flow_series(full, cv2, np, args.flow_sobel)
        half_series, _ = flow_series(half, cv2, np, args.flow_sobel)
        series[key] = full_series
        gates[key] = flow_metrics.decimation_gate(full_series, half_series, np)
        gates[key]["textured_fraction"] = textured
        gates[key]["headroom"] = flow_metrics.saturation_headroom(half_series, work_width, np)
        gates[key]["summary"] = flow_metrics.summarize(full_series, work_width, np)

    failed = [k for k in ("ref", "game") if not gates[k]["passed"]]
    result = {"gates": gates, "work_width": work_width, "artifacts": [],
              "interval_s": 1.0 / flow_metrics.SPEED_MIN_FPS}

    if failed:
        detail = "; ".join(
            "%s window measures %.4f where 0.5 is true (%+.1f%%)"
            % (k, gates[k]["ratio"] or float("nan"), gates[k]["error_pct"] or float("nan"))
            for k in failed)
        message = (
            "fps-decimation entry gate FAILED on: %s.\n"
            "  Sampling this window at 30fps does not halve per-frame displacement, so\n"
            "  60fps is not above the aliasing knee for this content and a speed figure\n"
            "  here would carry a systematic error of that size. No speed is reported."
            % detail)
        print("WARNING: %s" % message, file=sys.stderr)
        if mode == "on":
            raise UserError(message)
        result.update({"reported": False, "reason": message})
        return result

    ratio = gates["game"]["summary"]["mean"] / gates["ref"]["summary"]["mean"]
    flow_metrics.write_flow_csv(os.path.join(staging, "flow-ref.csv"),
                                series["ref"], result["interval_s"])
    flow_metrics.write_flow_csv(os.path.join(staging, "flow-game.csv"),
                                series["game"], result["interval_s"])
    flow_metrics.render_flow_plot(os.path.join(staging, "flow-plot.png"),
                                  series["ref"], series["game"], result["interval_s"], cv2, np)
    result.update({
        "reported": True,
        "ratio": ratio,
        "artifacts": [os.path.join(staging, n) for n in
                      ("flow-ref.csv", "flow-game.csv", "flow-plot.png")],
    })
    return result


def _collect_warnings(clips, truncation_note):
    warnings = []
    for key, label in (("ref", "reference"), ("game", "game")):
        if "NOT measured" in clips[key]["true_fps_source"]:
            warnings.append(
                "The %s clip's true rate was **declared, not measured** (%s). Row-to-row real-time "
                "correspondence is only as good as that declaration." % (label, clips[key]["true_fps_source"]))
    if truncation_note:
        warnings.append(truncation_note[0].upper() + truncation_note[1:] + ".")
    return warnings


def _quote(token):
    return token if re.match(r"^[\w./:=-]+$", token) else "'%s'" % token


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        print("ERROR: ffmpeg and ffprobe are required. Install with: brew install ffmpeg", file=sys.stderr)
        return EXIT_NO_FFMPEG
    args = build_parser().parse_args(argv)
    try:
        return run(args, argv)
    except UserError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return exc.code


if __name__ == "__main__":
    sys.exit(main())
