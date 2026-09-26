#!/usr/bin/env python3
"""Quantitative speed measurement for motion-metrics (#127, the #113 §12 follow-up).

v1 of this skill deliberately shipped NO speed figures: AB2's dithered ground
temporally aliases below ~60fps sampling, so frame-to-frame estimates measured
the estimator's ceiling rather than the game's speed. 60fps footage on both
sides (#114 game capture, #125 reference) removes that blanket objection — but
it does not remove it everywhere, and this module is built around that fact.

Every speed figure is gated on a per-window fps-decimation control, re-derived
here rather than inherited: sample the SAME window at 60fps and at 30fps, where
per-frame displacement is exactly halved, and require the measured ratio within
10% of 0.5. The control runs on the actual windows being measured, because
whether 60fps is above the aliasing knee is a property of the CONTENT, not of
the file — measured on the cached reference, it passes on 3 of 10 windows.

Calibration is re-derived on real 60fps footage. #113 §4.2/§4.3's numbers came
from a defective fixture, are documented as wrong, and are not reused.
"""

import csv
import glob
import math
import os

# Farneback parameters. Pyramid depth above 3 is inert at these work widths
# (192 -> 96 -> 48 -> 24 hits OpenCV's floor), verified by sweeping 3-6 levels:
# identical results to 3 decimal places.
FARNEBACK = dict(pyr_scale=0.5, levels=3, winsize=15, iterations=3,
                 poly_n=5, poly_sigma=1.2, flags=0)

## Pixels are counted only where the frame has real texture. Flat sky carries no
## motion information and would dilute the mean toward zero in proportion to how
## much sky is on screen — which differs between our game and the arcade, so an
## ungated mean would compare composition rather than speed.
SOBEL_THRESHOLD = 12.0

## Work width for the flow pass. Re-derived: 192 and 384 give the same gate
## verdict on all 10 reference windows tested (median |error| 40.9% vs 43.8%),
## confirming that breakdown is a fixed FRACTION of frame width and that
## resolution buys no headroom in either direction.
DEFAULT_WORK_WIDTH = 192

## The decimation control's pass band. Pre-stated, not fitted: #113 §12 set 10%
## before any measurement was taken, and it is not widened to admit a result.
ENTRY_GATE_TOLERANCE = 0.10
ENTRY_GATE_TRUE_RATIO = 0.5

## Speed is refused outright below this true rate on either side.
SPEED_MIN_FPS = 60.0

## Measured estimator ceiling, synthetic positive control at work width 192:
## exact to +/-0.1% up to 3 px/frame; the 30fps arm breaks between 8 and 10
## px/frame, i.e. ~4% of frame width. Real reference windows read 4.4 px/frame
## on their 30fps arm — comfortably BELOW this, which is what proves their gate
## failures are content aliasing and not estimator saturation.
SATURATION_PX_FRACTION = 0.04


def flow_series(frame_paths, cv2, np, sobel_threshold=SOBEL_THRESHOLD):
    """Mean textured-region flow magnitude for each consecutive frame pair.

    Returns (px_per_frame array, mean textured fraction). Frames must already be
    grayscale and at the work width.
    """
    values = []
    textured = []
    previous = None
    for path in frame_paths:
        frame = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
        if frame is None:
            continue
        if previous is not None:
            flow = cv2.calcOpticalFlowFarneback(previous, frame, None, **FARNEBACK)
            magnitude = np.linalg.norm(flow, axis=2)
            gx = cv2.Sobel(previous, cv2.CV_32F, 1, 0, ksize=3)
            gy = cv2.Sobel(previous, cv2.CV_32F, 0, 1, ksize=3)
            mask = np.hypot(gx, gy) >= sobel_threshold
            textured.append(float(mask.mean()))
            values.append(float(magnitude[mask].mean()) if mask.any() else 0.0)
        previous = frame
    return np.asarray(values, dtype=float), (float(np.mean(textured)) if textured else 0.0)


def decimation_gate(full_rate_series, half_rate_series, np):
    """The entry gate. Halving the sample rate must double per-frame displacement.

    Returns a dict; `passed` is the only thing callers may act on.
    """
    if full_rate_series.size == 0 or half_rate_series.size == 0:
        return {"passed": False, "ratio": None, "error_pct": None,
                "reason": "no flow samples — window too short"}
    full_mean = float(full_rate_series.mean())
    half_mean = float(half_rate_series.mean())
    if half_mean <= 0.0:
        return {"passed": False, "ratio": None, "error_pct": None,
                "reason": "half-rate flow is zero — window is static"}
    ratio = full_mean / half_mean
    error = ratio / ENTRY_GATE_TRUE_RATIO - 1.0
    return {
        "passed": abs(error) <= ENTRY_GATE_TOLERANCE,
        "ratio": ratio,
        "error_pct": error * 100.0,
        "full_mean": full_mean,
        "half_mean": half_mean,
        "reason": "",
    }


def saturation_headroom(series, work_width, np):
    """How close the measured flow runs to the estimator's ceiling.

    Reported so a reader can tell a gate failure caused by content aliasing
    (readings well under the ceiling) from one caused by the estimator running
    out of range (readings at it). On the reference windows this is what
    separated the two, and they call for opposite responses.
    """
    if series.size == 0:
        return {"peak": 0.0, "ceiling": work_width * SATURATION_PX_FRACTION, "saturated": False}
    ceiling = work_width * SATURATION_PX_FRACTION
    peak = float(np.percentile(series, 95))
    return {"peak": peak, "ceiling": ceiling, "saturated": peak >= ceiling}


def write_flow_csv(path, series, interval_s):
    with open(path, "w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["pair_index", "time_s", "px_per_frame"])
        for i, value in enumerate(series):
            writer.writerow([i, round(i * interval_s, 4), round(float(value), 5)])


def render_flow_plot(path, ref_series, game_series, interval_s, cv2, np,
                     width=900, height=320):
    """Two labelled curves on one axis. cv2 only — this ffmpeg has no drawtext
    and matplotlib is not a dependency we need for two polylines."""
    img = np.full((height, width, 3), 24, dtype=np.uint8)
    pad_l, pad_b, pad_t = 52, 34, 26
    plot_w, plot_h = width - pad_l - 14, height - pad_b - pad_t
    peak = max(
        float(ref_series.max()) if ref_series.size else 0.0,
        float(game_series.max()) if game_series.size else 0.0,
        1e-6,
    ) * 1.15
    n = max(ref_series.size, game_series.size, 2)

    cv2.rectangle(img, (pad_l, pad_t), (pad_l + plot_w, pad_t + plot_h), (70, 70, 70), 1)
    for frac in (0.0, 0.25, 0.5, 0.75, 1.0):
        y = int(pad_t + plot_h - frac * plot_h)
        cv2.line(img, (pad_l, y), (pad_l + plot_w, y), (48, 48, 48), 1)
        cv2.putText(img, "%.1f" % (frac * peak), (4, y + 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.34, (170, 170, 170), 1, cv2.LINE_AA)

    for series, colour in ((ref_series, (60, 200, 255)), (game_series, (120, 255, 120))):
        points = []
        for i, value in enumerate(series):
            x = int(pad_l + (i / max(n - 1, 1)) * plot_w)
            y = int(pad_t + plot_h - (float(value) / peak) * plot_h)
            points.append((x, y))
        if len(points) > 1:
            cv2.polylines(img, [np.asarray(points, dtype=np.int32)], False, colour, 1, cv2.LINE_AA)

    cv2.putText(img, "px/frame (textured regions)", (pad_l, 18),
                cv2.FONT_HERSHEY_SIMPLEX, 0.42, (210, 210, 210), 1, cv2.LINE_AA)
    cv2.putText(img, "AB2 REFERENCE", (pad_l + 250, 18),
                cv2.FONT_HERSHEY_SIMPLEX, 0.42, (60, 200, 255), 1, cv2.LINE_AA)
    cv2.putText(img, "GAME", (pad_l + 400, 18),
                cv2.FONT_HERSHEY_SIMPLEX, 0.42, (120, 255, 120), 1, cv2.LINE_AA)
    cv2.putText(img, "0.0s", (pad_l, height - 12),
                cv2.FONT_HERSHEY_SIMPLEX, 0.36, (170, 170, 170), 1, cv2.LINE_AA)
    cv2.putText(img, "%.1fs" % ((n - 1) * interval_s), (pad_l + plot_w - 40, height - 12),
                cv2.FONT_HERSHEY_SIMPLEX, 0.36, (170, 170, 170), 1, cv2.LINE_AA)
    cv2.imwrite(path, img)
    return path


def summarize(series, work_width, np):
    if series.size == 0:
        return {"mean": 0.0, "peak": 0.0, "mean_pct_width": 0.0}
    mean = float(series.mean())
    return {
        "mean": mean,
        "peak": float(series.max()),
        "p95": float(np.percentile(series, 95)),
        "mean_pct_width": 100.0 * mean / work_width,
    }
