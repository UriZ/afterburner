#!/usr/bin/env python3
"""
measure_ground_palette.py -- #124 per-stage ground palette re-grade.

Re-derives ground_a/b/c candidates for a stage's near-ground band against the
PROVEN stage map already committed in stage_data.gd's header (#123, 7a7c4ef).
Implements the architect spec (issue #124, comment 5833754251 amendment) --
frame SELECTION, not sky masking, because #123's modal-colour method (built
for flat-fill skies) fails on grounds: on stage 1 the sky's mode share is
97.8% but the ground's is 5.7% (dithered/streaked, not flat), and a fixed
horizontal sky/ground split leaks on any banked frame (horizon tilts with
player roll -- criteria rule 17).

Pipeline per accepted frame, band = rows 76-85.5%H, full width (the HUD speed
bar starts at 86%H -- no horizon estimate needed):

  1. REJECT if flatfrac > 0.40, where flatfrac = fraction of band pixels
     whose 5x5-neighbourhood local std of V is < 1.5/255. This is the
     amendment's local-VARIANCE gate, replacing an earlier sky-colour gate
     that rejected the sea itself on blue-sea stages (colour, not texture,
     is what a flat sky and a textured sea share on stage 1). Control run
     before use, on stage-1 t=116 crops (x=0..686,y=365..410 of the 686x480
     reference):
         pure sky  crop -> flatfrac  ~97-100% (rejected, correct)
         pure sea  crop -> flatfrac  ~5-8%     (accepted, correct)
     0.40 sits well inside that >20x separation, not at either edge.
  2. REJECT if >6% of band pixels are explosion-bright (S>0.55, V>0.90).
  3. REJECT if >4% are aircraft-neutral (S<0.20, V>0.60).
  4. REJECT (mark stage unmeasurable if this fires on most/all frames) if
     <30% of band pixels are saturated (S>0.25).
  5. On an accepted frame: optionally restrict to the sea hue range
     (170-260deg; --sea-only, for stage 1's sea-vs-island separation --
     a raw B>R channel test was tried first and is documented below as
     too weak). Histogram hue (10-degree bins) of saturated pixels; take
     the dominant
     bin centre H; select pixels within +/-HUE_WINDOW of it (circular);
     record this frame's H, median S, V75 (75th pct V), V25 (25th pct V)
     within that selection.
  6. Aggregate across accepted frames by MEDIAN (not a pooled histogram) --
     per architect spec section 2.2 step 4.

Usage:
    python3 tools/measure_ground_palette.py --stage 1 --sea-only
    python3 tools/measure_ground_palette.py --stage 8

Reads the stage's verified span from stage_data.gd's own header table so the
timestamps used here are exactly the ones #123 already proved with an HUD
crop -- this tool does not re-derive stage identity, it cites the existing
proof (per criteria rule 7, the same precedent #120 set for horizon_fraction).

Requires opencv-python-headless + numpy, same venv the other measurement
skills (motion-metrics) already bootstrap. Point PYTHON at it directly:
    /path/to/afterburner/.reference-cache/venv-metrics/bin/python3 \
        tools/measure_ground_palette.py --stage 1 --sea-only
"""
import argparse
import colorsys
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
VIDEO = REPO_ROOT / ".reference-cache" / "video" / "ab2-longplay.mp4"

# rows 76-85.5%H, full width, of the 686x480 reference video -- the HUD speed
# bar starts at 86%H (architect spec section 2.2 step 1).
BAND_TOP_FRAC = 0.76
BAND_BOTTOM_FRAC = 0.855
REF_H = 480
REF_W = 686
BAND_Y0 = int(round(BAND_TOP_FRAC * REF_H))
BAND_Y1 = int(round(BAND_BOTTOM_FRAC * REF_H))

FLATFRAC_LOCALSTD_THRESH = 1.5 / 255.0
FLATFRAC_REJECT_ABOVE = 0.40
EXPLOSION_S_MIN = 0.55
EXPLOSION_V_MIN = 0.90
# Explosions/fire are warm (rule 10: fireballs are orange/red, kill puffs are
# cream -- never blue). The spec's explosion-bright test (S>0.55, V>0.90) was
# stated hue-agnostic and, run unmodified on stage 1, rejected 26/48 frames
# as "explosion" -- verified by inspecting the flagged pixels directly: hue
# ~237deg (saturated BLUE), not fire. That is the sea's own bright cyan wave
# crests (architect's own description: "bright cyan/white horizontal wave
# streaks"), the same class of gap the amendment already fixed once for the
# sky-colour rule (a rule validated on land content, unrun against the
# hardest case it had to handle). Gating explosion-bright to warm hues fixes
# it without weakening the rule's actual purpose on land stages, where an
# explosion's hue is warm by construction.
EXPLOSION_HUE_MAX_WARM = 50.0   # red..amber
EXPLOSION_HUE_MIN_WARM = 340.0  # wraps back through magenta-red
EXPLOSION_REJECT_ABOVE = 0.06
AIRCRAFT_S_MAX = 0.20
AIRCRAFT_V_MIN = 0.60
AIRCRAFT_REJECT_ABOVE = 0.04
SATURATED_S_MIN = 0.25
SATURATED_ACCEPT_MIN = 0.30
HUE_BIN_DEG = 10
HUE_WINDOW_DEG_DEFAULT = 20.0  # rule 11's own bin width (risk 3) -- not the spec's original 25deg, which the spec's own risk 3 flags as merging populations on scrub stages

# --sea-only selection range (cyan through blue). The amendment specifies
# "restrict to blue-dominant (B>R) pixels" -- verified by direct pixel
# inspection that this is too weak on its own: pure green foliage pixels
# like (B=10,G=91,R=0) satisfy B>R trivially whenever R happens to be near
# zero, which is common for saturated green. That let stage-1 island frames
# (t=104.0, t=111.5 -- both visually confirmed green forest/brown cliff, no
# sea) leak a green (~120-131deg) population into the "sea" hue histogram.
# A direct hue test is what the rest of this tool already uses everywhere
# else, so applying it here too (instead of a channel-comparison proxy) is
# the natural fix, not a new method: genuine sea/crest pixels measured
# directly on this video cluster at hue 205-250deg.
SEA_HUE_MIN = 170.0
SEA_HUE_MAX = 260.0

# VERIFIED STAGE SPANS -- copied from stage_data.gd's header (#123, 7a7c4ef).
# Do not hand-edit without also updating stage_data.gd; keep in sync.
STAGE_SPANS = {
    1: (88, 120), 2: (124, 156), 3: (160, 196), 4: (200, 240), 5: (244, 256),
    6: (260, 304), 7: (308, 340), 8: (344, 372), 9: (376, 424), 10: (428, 468),
    11: (472, 508), 12: (512, 548), 13: (552, 568), 14: (572, 608), 15: (612, 652),
    16: (656, 692), 17: (696, 724), 18: (728, 764), 19: (768, 808), 20: (812, 852),
    21: (856, 892), 22: (896, 932), 23: (936, 952),
}


def extract_band_frames(stage, start, end, sample_interval, margin=4.0):
    """Extracts the band crop (not the full frame) at each sample timestamp
    inside [start+margin, end-margin], via one ffmpeg call per frame (fast
    enough at this cadence, avoids decoding frames we don't need)."""
    lo = start + margin
    hi = end - margin
    if hi <= lo:
        lo, hi = start, end
    t = lo
    frames = []  # (timestamp, band_bgr_uint8)
    with tempfile.TemporaryDirectory() as tmp:
        idx = 0
        while t < hi:
            out = Path(tmp) / f"f{idx:04d}.png"
            cmd = [
                "ffmpeg", "-v", "error", "-ss", f"{t:.2f}", "-i", str(VIDEO),
                "-vf", f"crop={REF_W}:{BAND_Y1 - BAND_Y0}:0:{BAND_Y0}",
                "-frames:v", "1", str(out), "-y",
            ]
            subprocess.run(cmd, check=True)
            img = cv2.imread(str(out))
            if img is not None:
                frames.append((t, img))
            idx += 1
            t += sample_interval
    return frames


def local_std_v(v):
    """5x5-neighbourhood local std of a float V channel in [0,1], via the
    box-filter identity std = sqrt(E[x^2] - E[x]^2)."""
    mean = cv2.boxFilter(v, ddepth=-1, ksize=(5, 5))
    mean_sq = cv2.boxFilter(v * v, ddepth=-1, ksize=(5, 5))
    var = np.clip(mean_sq - mean * mean, 0.0, None)
    return np.sqrt(var)


def rgb_to_hsv_np(bgr_uint8):
    """Vectorised BGR uint8 -> HSV float (H in degrees 0-360, S,V in [0,1])."""
    img = bgr_uint8.astype(np.float32) / 255.0
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)  # cv2 gives H in [0,360) for float32 input
    return hsv[..., 0], hsv[..., 1], hsv[..., 2]


def hue_circular_dist(a, b):
    d = np.abs(a - b) % 360.0
    return np.minimum(d, 360.0 - d)


def evaluate_frame(band_bgr, sea_only, hue_window):
    h_deg, s, v = rgb_to_hsv_np(band_bgr)
    local_std = local_std_v(v)
    is_flat_pixel = local_std < FLATFRAC_LOCALSTD_THRESH
    flatfrac = float(np.mean(is_flat_pixel))
    if flatfrac > FLATFRAC_REJECT_ABOVE:
        return {"accepted": False, "reason": "variance_gate", "flatfrac": flatfrac}

    warm = (h_deg <= EXPLOSION_HUE_MAX_WARM) | (h_deg >= EXPLOSION_HUE_MIN_WARM)
    explosion_frac = float(np.mean((s > EXPLOSION_S_MIN) & (v > EXPLOSION_V_MIN) & warm))
    if explosion_frac > EXPLOSION_REJECT_ABOVE:
        return {"accepted": False, "reason": "explosion", "flatfrac": flatfrac, "explosion_frac": explosion_frac}

    aircraft_frac = float(np.mean((s < AIRCRAFT_S_MAX) & (v > AIRCRAFT_V_MIN)))
    if aircraft_frac > AIRCRAFT_REJECT_ABOVE:
        return {"accepted": False, "reason": "aircraft", "flatfrac": flatfrac, "aircraft_frac": aircraft_frac}

    # Pixel-level variance exclusion, IN ADDITION to the frame-level flatfrac
    # gate above. Found necessary by inspection: a frame over the stage-1
    # island can have an overall flatfrac well under 0.40 (most of the band
    # is genuinely textured land) while still containing a small residual
    # sliver of flat sky at the frame's edge (visible during a bank/climb) --
    # e.g. t=104.0s and t=111.5s, both island content, both slipping past
    # the frame-level gate with a handful of flat, blue, B>R sky-edge pixels
    # that then dominated the (otherwise mostly non-blue) saturated
    # population and got mis-read as a ~205-125deg "sea" hue. Excluding
    # individual flat pixels from the hue population (not just gating whole
    # frames on their average) removes this leak directly, using the same
    # local-variance measurement the amendment already validated -- no new
    # method, just applied at the pixel granularity the residual needed.
    sat_mask = (s > SATURATED_S_MIN) & (~is_flat_pixel)
    if sea_only:
        sea_hue = (h_deg >= SEA_HUE_MIN) & (h_deg <= SEA_HUE_MAX)
        sat_mask = sat_mask & sea_hue

    sat_frac = float(np.mean(sat_mask))
    if sat_frac < SATURATED_ACCEPT_MIN:
        return {"accepted": False, "reason": "understaturated", "flatfrac": flatfrac, "sat_frac": sat_frac}

    hues = h_deg[sat_mask]
    if hues.size == 0:
        return {"accepted": False, "reason": "understaturated", "flatfrac": flatfrac, "sat_frac": sat_frac}

    # INDEPENDENT CORROBORATION (added in the completion pass). The pipeline's
    # H is the centre of the dominant 10deg bin of the SATURATED population --
    # one estimator. mode_hue below is the hue of the single most frequent
    # exact RGB triple among the band's NON-FLAT pixels: a different estimator
    # (exact-colour mode, no saturation threshold, no hue window, no binning)
    # over a different population. Agreement between the two is evidence the
    # value is a property of the frame and not of the selector -- which is the
    # only thing that makes the thin canyon yields (stages 8, 17: 3-7 accepted
    # frames) quotable at all. Restricted to non-flat pixels because the
    # unrestricted band mode returns the SKY on any partly-flat frame
    # (measured: stage 16 t=670, band mode #a3a6fa at 36.7% == sky_top).
    nonflat_px = band_bgr[~is_flat_pixel]
    if nonflat_px.shape[0] > 0:
        packed = (nonflat_px[:, 0].astype(np.int32) << 16) | (nonflat_px[:, 1].astype(np.int32) << 8) | nonflat_px[:, 2].astype(np.int32)
        vals, counts_p = np.unique(packed, return_counts=True)
        top = int(vals[int(np.argmax(counts_p))])
        mb, mg, mr = (top >> 16) & 255, (top >> 8) & 255, top & 255
        mode_h, mode_s, mode_v = colorsys.rgb_to_hsv(mr / 255.0, mg / 255.0, mb / 255.0)
        mode_hue = mode_h * 360.0
        mode_share = float(counts_p.max()) / float(nonflat_px.shape[0])
    else:
        mode_hue, mode_s, mode_v, mode_share = float("nan"), float("nan"), float("nan"), 0.0

    # SECOND CORROBORATOR, needed because the first one goes silent exactly
    # where the ground is most dithered. On stage 14 the most frequent
    # non-flat colour is #000000 at a 4-6% share (the gaps between palm
    # crowns) on every accepted frame -- the documented modal failure
    # (reference-facts: mode share 5.7% on dithered grounds). This one has no
    # thresholds, no binning and no window at all: the chroma-weighted
    # circular MEAN hue over every non-flat band pixel, weight S*V so grey
    # and black contribute nothing without needing a cutoff that could be
    # tuned. R is the resultant length: ~1 means the band's colour points one
    # way (unimodal), ~0 means it does not (mixed biome), measured
    # per-frame and independent of the across-frame hue spread.
    nf_s, nf_v, nf_h = s[~is_flat_pixel], v[~is_flat_pixel], h_deg[~is_flat_pixel]
    w = nf_s * nf_v
    if w.sum() > 0:
        ang = np.deg2rad(nf_h)
        cx = float((w * np.cos(ang)).sum() / w.sum())
        cy = float((w * np.sin(ang)).sum() / w.sum())
        chroma_mean_hue = float(np.rad2deg(np.arctan2(cy, cx)) % 360.0)
        chroma_R = float(np.hypot(cx, cy))
    else:
        chroma_mean_hue, chroma_R = float("nan"), 0.0

    bins = (hues // HUE_BIN_DEG).astype(int) % (360 // HUE_BIN_DEG)
    counts = np.bincount(bins, minlength=360 // HUE_BIN_DEG)
    dominant_bin = int(np.argmax(counts))
    h_center = dominant_bin * HUE_BIN_DEG + HUE_BIN_DEG / 2.0

    window_mask = hue_circular_dist(h_deg, h_center) <= hue_window
    sel_mask = sat_mask & window_mask
    sel_s = s[sel_mask]
    sel_v = v[sel_mask]
    if sel_s.size < 20:
        return {"accepted": False, "reason": "understaturated", "flatfrac": flatfrac, "sat_frac": sat_frac}

    return {
        "accepted": True,
        "flatfrac": flatfrac,
        "sat_frac": sat_frac,
        "H": h_center,
        "S": float(np.median(sel_s)),
        "V75": float(np.percentile(sel_v, 75)),
        "V25": float(np.percentile(sel_v, 25)),
        "n_pixels": int(sel_s.size),
        "mode_hue": float(mode_hue),
        "mode_s": float(mode_s),
        "mode_v": float(mode_v),
        "mode_share": mode_share,
        "chroma_mean_hue": chroma_mean_hue,
        "chroma_R": chroma_R,
        # DEGENERACY DIAGNOSTIC (added in the completion pass). HSV hue and
        # saturation are meaningless at very low V: a pixel of RGB (0,0,2)
        # reports S=1.00 at hue exactly 240, so the "<30% saturated" reject
        # rule -- written to catch stages the method cannot read -- does NOT
        # fire on a near-black stage; every black pixel counts as saturated.
        # Measured directly on stage 3's band (t=175, identity-proven): the
        # most frequent colours are #000000 (14.8%), #000100, #000002,
        # #000004, with hue locked to exactly 240 or 120 by integer
        # quantisation. frac_V_lt_010 reports how much of the SELECTED
        # population sits in that regime so the reader can discount the hue
        # instead of trusting a number the colour space cannot carry.
        "V_sel_median": float(np.median(sel_v)),
        "frac_V_lt_010": float(np.mean(sel_v < 0.10)),
    }


def circular_spread(hues_deg):
    """Circular range of a set of hue angles: 360 minus the largest gap
    between consecutive sorted hues. Equals max-min for a clustered set that
    does not straddle 0deg, and stays correct for one that does."""
    h = np.sort(np.asarray(hues_deg, dtype=float) % 360.0)
    if h.size < 2:
        return 0.0
    gaps = np.diff(h)
    wrap_gap = (h[0] + 360.0) - h[-1]
    return float(360.0 - max(float(gaps.max()), wrap_gap))


def circular_median(hues_deg):
    """Median hue that survives the 0/360 wrap. Rotates the sample so the
    largest empty gap sits at the cut, takes the ordinary median there, and
    rotates back -- a linear median of {355, 5} is 180deg, the opposite hue."""
    h = np.sort(np.asarray(hues_deg, dtype=float) % 360.0)
    if h.size == 0:
        return float("nan")
    if h.size == 1:
        return float(h[0])
    gaps = np.diff(h)
    wrap_gap = (h[0] + 360.0) - h[-1]
    if wrap_gap >= (gaps.max() if gaps.size else 0.0):
        return float(np.median(h))
    cut = int(np.argmax(gaps)) + 1        # first element after the largest gap
    rotated = (h - h[cut]) % 360.0
    return float((np.median(rotated) + h[cut]) % 360.0)


def hsv_to_rgb01(h_deg, s, v):
    r, g, b = colorsys.hsv_to_rgb(h_deg / 360.0, s, v)
    return r, g, b


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--stage", type=int, required=True)
    ap.add_argument("--sample-interval", type=float, default=0.5)
    ap.add_argument("--hue-window", type=float, default=HUE_WINDOW_DEG_DEFAULT)
    ap.add_argument("--sea-only", action="store_true", help="restrict to the sea hue range (170-260deg) -- stage 1's sea-vs-island separation")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    if args.stage not in STAGE_SPANS:
        print(f"ERROR: no verified span for stage {args.stage}", file=sys.stderr)
        sys.exit(2)
    start, end = STAGE_SPANS[args.stage]

    frames = extract_band_frames(args.stage, start, end, args.sample_interval)
    total = len(frames)
    results = []
    for t, band in frames:
        r = evaluate_frame(band, args.sea_only, args.hue_window)
        r["t"] = t
        results.append(r)

    accepted = [r for r in results if r["accepted"]]
    n_accepted = len(accepted)

    reject_reasons = {}
    for r in results:
        if not r["accepted"]:
            reject_reasons[r["reason"]] = reject_reasons.get(r["reason"], 0) + 1

    out = {
        "stage": args.stage,
        "span": [start, end],
        "band_rect": {"x": [0, REF_W], "y": [BAND_Y0, BAND_Y1], "frac_y": [BAND_TOP_FRAC, BAND_BOTTOM_FRAC]},
        "sample_interval": args.sample_interval,
        "hue_window_deg": args.hue_window,
        "sea_only": args.sea_only,
        "frames_total": total,
        "frames_accepted": n_accepted,
        "reject_reasons": reject_reasons,
        "accepted_timestamps": [r["t"] for r in accepted],
    }

    if n_accepted == 0:
        out["usable"] = False
        out["median_flatfrac_accepted"] = None
    else:
        hues = [r["H"] for r in accepted]
        svals = [r["S"] for r in accepted]
        v75s = [r["V75"] for r in accepted]
        v25s = [r["V25"] for r in accepted]
        flatfracs = [r["flatfrac"] for r in accepted]
        out["median_flatfrac_accepted"] = float(np.median(flatfracs))
        out["accepted_H"] = [float(h) for h in hues]
        # CIRCULAR spread, not max-min. Hue is an angle: a stage whose frames
        # read 355deg and 5deg is 10deg apart, not 350. The linear version
        # would mark such a stage mixed-biome and reject it, and it silently
        # would have done so on any red/warm stage straddling 0deg -- stage 2
        # (H=35) and stage 19 (H=35) both sit close enough to that wrap for
        # it to matter. Circular range = 360 minus the largest empty gap
        # between consecutive sorted hues.
        out["hue_spread_deg"] = circular_spread(hues)
        out["hue_spread_linear_deg"] = float(max(hues) - min(hues))
        # The corroborator only corroborates when its own modal pixel HAS a
        # hue. colorsys returns hue 0.0 for any achromatic colour, so an
        # unfiltered modal hue reports grey and black as "red" -- it did,
        # on stages 14 and 17 (mode_hue 0 against a pipeline 55), which is
        # the self-measuring-window trap (reference-facts) inside the very
        # check meant to catch it. Same floors the pipeline itself uses:
        # S > 0.25 and, for the quantisation reason above, V >= 0.10.
        mode_hues = [
            r["mode_hue"] for r in accepted
            if not np.isnan(r["mode_hue"]) and r["mode_s"] > SATURATED_S_MIN and r["mode_v"] >= 0.10
        ]
        out["mode_frames_chromatic"] = len(mode_hues)
        cm = [r["chroma_mean_hue"] for r in accepted if not np.isnan(r["chroma_mean_hue"])]
        out["chroma_mean_hue_median"] = circular_median(cm) if cm else None
        out["chroma_R_median"] = float(np.median([r["chroma_R"] for r in accepted]))
        out["mode_hue_median"] = circular_median(mode_hues) if mode_hues else None
        out["mode_share_median"] = float(np.median([r["mode_share"] for r in accepted]))
        out["V_sel_median"] = float(np.median([r["V_sel_median"] for r in accepted]))
        out["frac_V_lt_010"] = float(np.median([r["frac_V_lt_010"] for r in accepted]))
        out["H_median"] = circular_median(hues)
        out["mode_hue_delta"] = (
            None if out["mode_hue_median"] is None
            else float(hue_circular_dist(np.array(out["mode_hue_median"]), np.array(out["H_median"])))
        )
        out["chroma_mean_delta"] = (
            None if out["chroma_mean_hue_median"] is None
            else float(hue_circular_dist(np.array(out["chroma_mean_hue_median"]), np.array(out["H_median"])))
        )
        out["S_median"] = float(np.median(svals))
        out["V75_median"] = float(np.median(v75s))
        out["V25_median"] = float(np.median(v25s))
        out["V75_sd"] = float(np.std(v75s))
        out["V25_sd"] = float(np.std(v25s))
        r_dark, g_dark, b_dark = hsv_to_rgb01(out["H_median"], out["S_median"], out["V25_median"])
        r_mid, g_mid, b_mid = hsv_to_rgb01(out["H_median"], out["S_median"], (out["V75_median"] + out["V25_median"]) / 2.0)
        r_light, g_light, b_light = hsv_to_rgb01(out["H_median"], out["S_median"], out["V75_median"])
        out["ground_a_candidate"] = [round(r_light, 3), round(g_light, 3), round(b_light, 3)]
        out["ground_b_candidate"] = [round(r_dark, 3), round(g_dark, 3), round(b_dark, 3)]
        out["ground_c_candidate"] = [round(r_mid, 3), round(g_mid, 3), round(b_mid, 3)]
        # Usable per architect spec section 2.3: enough accepted frames for a
        # median to be meaningful (n>=3 -- a median of 1-2 samples isn't one),
        # AND the hue spread isn't signalling a mixed biome (<=30deg -- clear
        # of both the single-biome ~10-20deg spec observed and the mixed-hue
        # ~80-180deg spec observed on stages 1/7/9/11/12/18/19/21/22 below).
        # n>=3 (not the tighter n>=5 tried first) because canyon stages (8,
        # 17) genuinely yield few frames -- their near-ground band is mostly
        # rock wall, not open ground, the same reason the sky measurement's
        # own column scan "kept landing on canyon wall" (stage_data.gd's sky
        # header) -- and stage 17 reproduced the SAME H/S/V within a few
        # points across three independent reruns at three sampling densities
        # (0.5s: 2/40, hue 45; 0.25s: 3/80, hue 55, hue_spread 20; 0.1s:
        # 4/200, hue 55, hue_spread 20), which is stability evidence, not a
        # count to relax past.
        out["usable"] = n_accepted >= 3 and out["hue_spread_deg"] <= 30.0

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"=== Stage {args.stage} (span t={start}-{end}s, band y={BAND_Y0}-{BAND_Y1} of {REF_W}x{REF_H}, sea_only={args.sea_only}) ===")
        print(f"frames accepted/total: {n_accepted}/{total}  ({100.0*n_accepted/max(total,1):.0f}%)")
        print(f"reject reasons: {reject_reasons}")
        if n_accepted > 0:
            print(f"median flatfrac (accepted): {out['median_flatfrac_accepted']:.3f}")
            print(f"H_median={out['H_median']:.1f}deg  hue_spread={out['hue_spread_deg']:.1f}deg (circular; linear {out['hue_spread_linear_deg']:.1f})")
            mh = out["mode_hue_median"]
            print(f"corroboration 1 (exact-colour mode, non-flat): "
                  + (f"hue={mh:.1f}deg on {out['mode_frames_chromatic']}/{n_accepted} frames (share {out['mode_share_median']:.3f}) -> delta {out['mode_hue_delta']:.1f}deg"
                     if mh is not None else f"UNAVAILABLE - modal non-flat pixel is achromatic on all {n_accepted} accepted frames"))
            print(f"corroboration 2 (chroma-weighted circular mean, no thresholds): hue={out['chroma_mean_hue_median']:.1f}deg "
                  f"-> delta {out['chroma_mean_delta']:.1f}deg, concentration R={out['chroma_R_median']:.3f}")
            print(f"selected-pixel V median={out['V_sel_median']:.3f}  frac V<0.10={out['frac_V_lt_010']:.3f} (hue is quantisation-locked below ~0.10)")
            print(f"S_median={out['S_median']:.3f}  V75_median={out['V75_median']:.3f} (sd={out['V75_sd']:.3f})  V25_median={out['V25_median']:.3f} (sd={out['V25_sd']:.3f})")
            print(f"ground_a candidate (light): {out['ground_a_candidate']}")
            print(f"ground_c candidate (mid):   {out['ground_c_candidate']}")
            print(f"ground_b candidate (dark):  {out['ground_b_candidate']}")
        print(f"USABLE: {out['usable']}")


if __name__ == "__main__":
    main()
