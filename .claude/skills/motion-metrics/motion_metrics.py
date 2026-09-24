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
import json
import math
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

# Exit codes — mirrored in SKILL.md's troubleshooting table.
EXIT_USAGE = 2
EXIT_NO_FFMPEG = 3
EXIT_VENV = 4
EXIT_INPUT = 5
EXIT_ASPECT = 6
EXIT_TOO_FEW_CELLS = 7

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


def clear_previous_run(out_dir, frames_root):
    """Remove this run's own artifacts from a re-used --out directory.

    `--out` defaults to a directory derived from `--name`, and both the judge
    and QA inserts tell agents to use a stable `--name judge-<issue>`. Re-running
    after a fix therefore lands in a populated directory. A shorter window
    produces fewer strips, so without this the leftover strip-02/03 from the
    previous run stay on disk showing a different window entirely, and the agent
    reads them as current evidence ("Read every strip-NN.png").

    Deliberately narrow: only the files this tool writes. An operator may have
    put notes or a copied report in the directory, and `--out` can be pointed at
    an existing path, so this must never behave like `rm -rf <out_dir>`.
    """
    for entry in os.listdir(out_dir):
        if re.fullmatch(r"strip-\d+\.png", entry) or entry == "report.md":
            try:
                os.remove(os.path.join(out_dir, entry))
            except OSError:
                pass
    shutil.rmtree(frames_root, ignore_errors=True)


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
    add("## What this report does not contain")
    add("No speed, px/frame or ratio figures: AB2's ground texture temporally aliases below")
    add("~60fps sampling, so frame-to-frame motion estimates measure the estimator's ceiling")
    add("rather than actual speed (#113 finding). Quantitative speed is gated on 60fps capture (#114).")
    add("")
    add("## Reproduce")
    add("```bash")
    add(meta["command"])
    add("```")
    path = os.path.join(out_dir, "report.md")
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


# --------------------------------------------------------------------------

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
    os.makedirs(out_dir, exist_ok=True)
    frames_root = os.path.join(out_dir, ".frames")
    clear_previous_run(out_dir, frames_root)

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

    strips, used = compose_strips(cv2, np, extracted["ref"], extracted["game"], cell_size, args, meta, out_dir)
    meta["cells"] = min(cells, used)
    report = write_report(args, meta, strips, out_dir, _collect_warnings(clips, truncation_note))

    if not args.keep_frames:
        # Default because these are frames of copyrighted arcade footage.
        shutil.rmtree(frames_root, ignore_errors=True)

    print("Strips: %s" % ", ".join(strips))
    print("Report: %s" % report)
    return 0


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
