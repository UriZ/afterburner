#!/usr/bin/env python3
"""Shape-model player-jet detector for composition measurements (#140).

REPLACES the colour-threshold "crop-then-centroid" method used up to #122.

Why the old method had to go
----------------------------
It took the centroid of every pixel in a fixed box with V > 0.72 and S < 0.25,
on the premise that our jet is the only large bright near-neutral object on
screen. That premise stopped being true once the ground gained bright pale
rocks. Measured on real gameplay frames, the ground outnumbered the jet by up
to 2535 pixels to 174, and a 60s capture reported cx sd 3.05 while tracking
terrain rather than the aircraft.

The known-answer control in use at the time could not catch this, because it
only asked "does a centred jet read as cx ~ 50?". Left-right symmetric terrain
also reads cx ~ 50, so the control passed for the wrong reason. A control whose
wrong answer is symmetric cannot detect a symmetric contaminant. See
`selftest.sh`, which adds the asymmetric case the old control was missing.

How this one works
------------------
Masked template matching against a real template of the jet's silhouette, on
gradient-magnitude images rather than raw colour:

  1. Sobel magnitude of frame and template. Edges survive any background
     palette, so a detector tuned on the blue stage-1 sky keeps working over
     orange desert, black night and pale snow. Absolute brightness, which is
     what the old threshold keyed on, is discarded entirely.
  2. `cv2.matchTemplate` with TM_SQDIFF_NORMED and the template's own alpha
     mask, so only jet pixels contribute to the score.
  3. The jet banks up to +-57 degrees, so the template is matched at 25
     rotations and the best-scoring one wins. The winning angle is reported as
     a by-product, recovered to within 12 degrees (mean 0.8).
  4. Below `--min-score` the frame is reported as NO DETECTION instead of
     returning a number. A detector that always answers is how the old one
     produced 120 confident measurements of a hillside.

Accuracy, measured against 112 fixtures with exact ground truth (rebuild them
with make_control.py; selftest.sh does it for you): every ACCEPTED detection
lands within 0.05 pp of true cx and 2.2 degrees of true bank, with 92/112
accepted and zero false positives on 12 jet-free frames spanning eight biomes
including both canyon stages. Refusing the other 20 is the mechanism working,
not a shortfall.

Refusals still are not uniformly distributed: the hardest cases are heavily
banked AND clipped by the frame edge at once (26 of 32 clipped fixtures are
accepted). Those are off-centre poses, so an off-centre FRACTION from this
tool remains a floor rather than a point estimate. Read the acceptance rate
before quoting a cx spread.

Cost is about 2.5 seconds per frame (25 masked matches over a 344px template,
on a search image padded to make edge-clipped jets matchable at all), so
budget five minutes for a 120-frame capture.

Usage
-----
    jet_detect.py 'frames/frame_*.png' [--min-score 0.25] [--json out.json]
    jet_detect.py --legacy 'frames/*.png'    # the OLD detector, for comparison

Exit codes: 0 ok, 2 usage error, 3 too few detections to report statistics.
"""

import argparse
import glob
import json
import math
import os
import sys

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "assets", "jet_template.png")
TEMPLATE_MASK = os.path.join(HERE, "assets", "jet_template_mask.png")

# Bank angles to try, spanning the jet's own MAX_BANK_ANGLE of 57 degrees.
#
# The step is 4.75 degrees, NOT the coarse 19 degrees this started with. A first
# version assumed matchTemplate degrades gracefully between samples; measured
# against banked ground truth it does not. At banks falling between coarse
# samples (5, 10, 25, 45 degrees) the detector locked onto a location 28 pp away
# from the true one and scored 0.79 doing it — a confident wrong answer, which
# is the exact failure this tool exists to eliminate.
#
# That was invisible until the control fixtures gained banked cases, because the
# originals only ever composited a LEVEL sprite. A control that does not vary
# the axis under test cannot detect a fault on that axis: the same mistake, in
# my own work, that #140 was filed to fix.
BANK_ANGLES = tuple(-57.0 + 4.75 * i for i in range(25))

# Below this the detection is refused rather than reported. Set from measured
# separation, not taste. Sweeping the threshold over the 112 control fixtures
# (exact ground truth, 32 of them edge-clipped) and the 12 jet-free frames:
#
#   threshold   accepted    clipped    max |cx err|   max |bank err|   false pos
#      0.20     105/112      31/32        0.16 pp         2.5 deg        3/12
#      0.25      98/112      29/32        0.05 pp         2.2 deg        1/12
#      0.30      92/112      26/32        0.05 pp         2.2 deg        0/12
#      0.35      82/112      23/32        0.05 pp         1.2 deg        0/12
#      0.40      74/112      22/32        0.05 pp         1.2 deg        0/12
#
# 0.30 is the knee: the first threshold with zero false positives, and raising
# it further only discards good detections. Accepted accuracy is flat across
# the whole range, which is the property that matters — the threshold governs
# how OFTEN the detector answers, not how well.
#
# This was 0.25 until the jet-free set gained the two CANYON stages, whose
# ground fills ~85% of the frame. Stage 17's radial rock streaks score 0.262
# against the airframe template — under the old 0.25 that was a confident
# detection of a hillside, which is the entire defect #140 was filed about,
# reappearing on terrain the first threshold sweep had not seen. The margin to
# the worst jet-free frame is only 0.04, so this is a floor that unseen terrain
# can still breach: selftest.sh's jet-free test is what will catch it, and it
# asserts "0/N detected" rather than grepping for the too-few-to-report
# message, which also appears when one or two frames DID fire.
#
# Real gameplay accepts fewer frames than the fixtures do, because the jet is
# routinely overlapped by explosions, enemies and its own afterburner. Expect
# roughly 70-80%. A rate well below that means something changed; investigate
# before reporting numbers.
DEFAULT_MIN_SCORE = 0.30

# A candidate placement must have at least this much of the template box inside
# the real frame. The edge padding that makes clipped jets detectable at all is
# a void of zero gradient, so without a floor here a box hanging almost
# entirely off the screen can match a sliver of real edges against nothing and
# score well doing it. 0.5 is below the most clipped pose the game can produce
# (the jet stops with ~73% of its box on screen) and above the runaway region.
MIN_INSIDE = 0.5

EXIT_USAGE = 2
EXIT_NO_DATA = 3


def gradient(img_bgr):
    """Sobel gradient magnitude, 8-bit. Background palette drops out here."""
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    mag = cv2.magnitude(gx, gy)
    mag = np.clip(mag / max(mag.max(), 1e-6) * 255.0, 0, 255)
    return mag.astype(np.uint8)


def rotated(img, mask, degrees):
    if degrees == 0.0:
        return img, mask
    h, w = img.shape[:2]
    m = cv2.getRotationMatrix2D((w / 2.0, h / 2.0), degrees, 1.0)
    cos, sin = abs(m[0, 0]), abs(m[0, 1])
    nw, nh = int(h * sin + w * cos), int(h * cos + w * sin)
    m[0, 2] += nw / 2.0 - w / 2.0
    m[1, 2] += nh / 2.0 - h / 2.0
    return (cv2.warpAffine(img, m, (nw, nh)),
            cv2.warpAffine(mask, m, (nw, nh)))


class Detector:
    def __init__(self, min_score=DEFAULT_MIN_SCORE):
        tpl = cv2.imread(TEMPLATE)
        msk = cv2.imread(TEMPLATE_MASK, cv2.IMREAD_GRAYSCALE)
        if tpl is None or msk is None:
            raise SystemExit("missing template assets next to %s" % __file__)
        self.min_score = min_score
        self.variants = []
        for angle in BANK_ANGLES:
            g, m = rotated(gradient(tpl), msk, angle)
            self.variants.append((angle, g, (m > 127).astype(np.uint8) * 255))

    @staticmethod
    def _inside_fraction(res_shape, tw, th, fw, fh, pad):
        """Fraction of a template box that lands inside the real frame, for
        every candidate top-left in the padded search image. Shaped to match
        matchTemplate's result exactly, and built as an outer product of two
        1-D overlap profiles — the obvious per-pixel meshgrid version is
        correct but ~20x slower, which over a 25-rotation sweep is the
        difference between one second a frame and twenty."""
        ys = np.arange(res_shape[0]) - pad         # candidate y, frame coords
        xs = np.arange(res_shape[1]) - pad
        oy = np.clip(np.minimum(ys + th, fh) - np.maximum(ys, 0), 0, None)
        ox = np.clip(np.minimum(xs + tw, fw) - np.maximum(xs, 0), 0, None)
        return np.outer(oy, ox) / float(tw * th)

    @staticmethod
    def _visible_score(fg, tg, tm, x, y):
        """TM_SQDIFF_NORMED restricted to the mask pixels that actually land on
        the frame, for one placement.

        The padded search scores a clipped jet against a void: the mask pixels
        hanging off the edge contribute their full template energy to the
        difference, so a 27%-clipped jet scored 0.22 — below the 0.26 that
        stage 17's canyon rock scores on a frame with no jet in it. There is no
        threshold that accepts the first and rejects the second, which would
        have made the edge padding useless. Re-scoring over the visible mask
        only removes the void penalty and leaves unclipped frames unchanged,
        so the calibration of the threshold sweep still holds.

        The SEARCH still ranks by the penalised map; only the reported score is
        corrected. That biases a clipped jet's located position slightly toward
        the frame interior, which is why the control fixtures carry four
        deliberately clipped cases — the bias is measured there, not assumed."""
        th, tw = tg.shape[:2]
        fh, fw = fg.shape[:2]
        sx0, sy0 = max(0, -x), max(0, -y)
        dx0, dy0 = max(0, x), max(0, y)
        wv = min(tw - sx0, fw - dx0)
        hv = min(th - sy0, fh - dy0)
        if wv <= 0 or hv <= 0:
            return 0.0
        t = tg[sy0:sy0 + hv, sx0:sx0 + wv].astype(np.float64)
        m = tm[sy0:sy0 + hv, sx0:sx0 + wv] > 0
        i = fg[dy0:dy0 + hv, dx0:dx0 + wv].astype(np.float64)
        if not m.any():
            return 0.0
        num = float(((t[m] - i[m]) ** 2).sum())
        den = math.sqrt(float((t[m] ** 2).sum()) * float((i[m] ** 2).sum()))
        if den <= 0.0:
            return 0.0
        return 1.0 - min(num / den, 1.0)

    def detect(self, path):
        frame = cv2.imread(path)
        if frame is None:
            return None
        fg = gradient(frame)
        fh, fw = fg.shape[:2]
        # Pad the GRADIENT, not the frame: zero gradient reads as "no edges
        # here", whereas padding the frame and then running Sobel would draw a
        # bright artificial border for the template to lock onto.
        #
        # Without this the detector is blind at the frame edges, because
        # matchTemplate only places a template wholly inside its search image.
        # A 344-px-wide jet half off the side of the screen was not a low
        # score, it was no candidate position at all — and those are precisely
        # the frames where the jet is furthest off centre, so the cx spread
        # this tool exists to report came back truncated toward the middle.
        # Measured on 28 gameplay frames driven side to side: 13/28 detected
        # spanning cx 30.9-67.8, against 28/28 spanning 8.3-91.7 with padding.
        #
        # Half the largest template dimension is all the pad MIN_INSIDE can
        # ever use, and the search cost is proportional to the padded area — a
        # full-template pad doubles the runtime for positions that are
        # discarded anyway.
        pad = max(max(tg.shape) for _, tg, _ in self.variants) // 2 + 2
        pg = cv2.copyMakeBorder(fg, pad, pad, pad, pad,
                                cv2.BORDER_CONSTANT, value=0)
        best = None
        for angle, tg, tm in self.variants:
            th, tw = tg.shape[:2]
            # Masked TM_SQDIFF_NORMED. OpenCV supports masking only for
            # TM_SQDIFF and TM_CCORR_NORMED; a mask passed to
            # TM_CCOEFF_NORMED is silently accepted and returns garbage in
            # low-variance regions. TM_CCORR_NORMED was tried and rejected
            # too: it scores correlation energy, so busy rocky ground scored
            # 0.61 on frames containing no jet at all. SQDIFF measures actual
            # difference, and separates cleanly (jet-free frames top out at
            # 0.26 against 0.88+ for a real jet).
            res = cv2.matchTemplate(pg, tg, cv2.TM_SQDIFF_NORMED, mask=tm)
            res = np.nan_to_num(res, nan=1e9, posinf=1e9, neginf=1e9)
            # Placements mostly outside the frame are not candidates: the pad
            # is all zeros, so a box hanging far enough off the edge matches a
            # handful of real pixels against a void and can score well doing
            # it. MIN_INSIDE is what stops that being a confident answer.
            res[self._inside_fraction(res.shape, tw, th, fw, fh, pad)
                < MIN_INSIDE] = 1e9
            diff, _, loc, _ = cv2.minMaxLoc(res)   # minimum is best for SQDIFF
            x, y = loc[0] - pad, loc[1] - pad
            score = self._visible_score(fg, tg, tm, x, y)
            if best is None or score > best[0]:
                best = (score, (x, y), tw, th, angle)
        if best is None or best[0] < self.min_score:
            return None
        score, (x, y), tw, th, angle = best
        return {
            "cx_pct": (x + tw / 2.0) / fw * 100.0,
            "cy_pct": (y + th / 2.0) / fh * 100.0,
            "score": float(score),
            "bank_deg": angle,
        }


def legacy_detect(path, box=(0.20, 0.30, 0.80, 0.85)):
    """The DEPRECATED colour-threshold detector. Kept only so the selftest can
    demonstrate it failing the asymmetric control. Do not use for measurement."""
    frame = cv2.imread(path)
    if frame is None:
        return None
    h, w = frame.shape[:2]
    x0, y0 = int(box[0] * w), int(box[1] * h)
    x1, y1 = int(box[2] * w), int(box[3] * h)
    crop = frame[y0:y1, x0:x1]
    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
    sel = (hsv[:, :, 2] > 0.72 * 255) & (hsv[:, :, 1] < 0.25 * 255)
    if sel.sum() < 50:
        return None
    ys, xs = np.where(sel)
    return {
        "cx_pct": (xs.mean() + x0) / w * 100.0,
        "cy_pct": (ys.mean() + y0) / h * 100.0,
        "score": float(sel.sum()),
        "bank_deg": 0.0,
    }


def stats(values):
    n = len(values)
    mean = sum(values) / n
    sd = math.sqrt(sum((v - mean) ** 2 for v in values) / n)
    return mean, sd


def main(argv=None):
    ap = argparse.ArgumentParser(description="Shape-model jet detector (#140)")
    ap.add_argument("pattern", help="glob for frames, quote it")
    ap.add_argument("--min-score", type=float, default=DEFAULT_MIN_SCORE)
    ap.add_argument("--legacy", action="store_true",
                    help="run the DEPRECATED colour-threshold detector instead")
    ap.add_argument("--json", help="write per-frame results here")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if args.legacy:
        # Warn at invocation, not at the end: a run that exits early on too few
        # detections would otherwise print numbers-free output with no notice
        # that the DEPRECATED detector produced it.
        print("WARNING: --legacy runs the DEPRECATED colour-threshold detector. "
              "It tracks bright terrain, not the jet (#140), and is retained only "
              "so selftest.sh can demonstrate it failing. Do not measure with it.",
              file=sys.stderr)

    files = sorted(glob.glob(args.pattern))
    if not files:
        print("no frames matched %s" % args.pattern, file=sys.stderr)
        return EXIT_USAGE

    det = None if args.legacy else Detector(args.min_score)
    rows = []
    for path in files:
        r = legacy_detect(path) if args.legacy else det.detect(path)
        rows.append({"frame": os.path.basename(path), "result": r})

    hits = [r["result"] for r in rows if r["result"]]
    if args.json:
        with open(args.json, "w") as fh:
            json.dump({"detector": "legacy" if args.legacy else "shape-model",
                       "frames": rows}, fh, indent=2)
    if len(hits) < 3:
        print("only %d/%d frames detected — too few to report statistics"
              % (len(hits), len(files)), file=sys.stderr)
        return EXIT_NO_DATA

    cx = [h["cx_pct"] for h in hits]
    cy = [h["cy_pct"] for h in hits]
    mx, sx = stats(cx)
    my, sy = stats(cy)
    off = sum(1 for v in cx if abs(v - 50) > 5) / len(cx) * 100.0
    if not args.quiet:
        label = "LEGACY colour-threshold (DEPRECATED)" if args.legacy else "shape-model"
        print("detector: %s" % label)
        print("  detected %d/%d frames" % (len(hits), len(files)))
        print("  cx mean %6.2f  sd %5.2f  range %5.1f-%5.1f" % (mx, sx, min(cx), max(cx)))
        print("  cy mean %6.2f  sd %5.2f  range %5.1f-%5.1f" % (my, sy, min(cy), max(cy)))
        print("  |cx-50|>5 in %.0f%% of frames" % off)
        if not args.legacy:
            sc = [h["score"] for h in hits]
            print("  match score min %.2f mean %.2f" % (min(sc), sum(sc) / len(sc)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
