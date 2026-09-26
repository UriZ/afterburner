#!/usr/bin/env python3
"""Regenerate the control fixtures for the shape-model jet detector (#140).

Why this file exists
--------------------
The fixture set is derived data: 8 jet-free gameplay backgrounds x 10 known
jet placements = 80 composites with exact ground truth. Only the inputs are
committed (`control/backgrounds/`, `assets/jet_template*.png`); the composites
are rebuilt here on demand, because 80 full-frame PNGs cost 45 MB in a repo
whose entire history is 38 MB, and because a fixture set that cannot be
regenerated goes stale the moment the jet art changes -- which it is actively
doing under the jet-silhouette rebuild. `selftest.sh` calls this automatically.

Ground truth convention
-----------------------
`jet_detect.Detector` reports the centre of the matched template's bounding
box, so ground truth here is the centre of the composited sprite's bounding
box, recorded AFTER integer rounding of the paste position. The truth is
therefore exact by construction rather than an intent the compositor may have
missed by half a pixel.

Backgrounds must contain NO jet
-------------------------------
Learned the hard way when this was first built: the first version composited
onto real gameplay frames, which already contain the game's own aircraft, so a
second jet competed with a real one and the detector was scored against the
wrong target. `control/backgrounds/` are `tests/sky_stage_preview.gd` renders
-- sky and ground for one stage's palette, no player, no enemies, no HUD.

Cases must include BANKED sprites
---------------------------------
Also learned the hard way: a level-only fixture set cannot detect a fault in
the detector's rotation sweep, and the first version missed exactly that (a
coarse 19-degree sweep locked onto a location 28 pp away and scored 0.79 doing
it). The five banked angles below are deliberately OFF the detector's own
4.75-degree sample grid, so no case can be answered by an exact self-match of
a template variant.

Regenerating the inputs
-----------------------
Jet sprite (`assets/jet_template.png` + `_mask.png`): render
`tests/jet_silhouette_preview.gd` (jet alone, level, magenta key), crop to the
silhouette's bounding box, and write the mask as key-colour != magenta.

Backgrounds: run `tests/sky_stage_preview.gd` and capture with game-capture,
then pick frames spanning the palette range -- greens, ocean blues, pale rock,
both canyon stages, a night stage. Pale bright rock is the terrain that broke
the old colour-threshold detector, so it must be represented.

Usage
-----
    make_control.py [--out DIR] [--force]

Writes `<DIR>/ctl_*.png` and `<DIR>/ground_truth.json`. Default DIR is
`control/generated/` next to this script. Skips work if the output is already
current unless `--force` is given.
"""

import argparse
import glob
import hashlib
import json
import os
import sys

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
BACKGROUNDS = os.path.join(HERE, "control", "backgrounds")
SPRITE = os.path.join(HERE, "assets", "jet_template.png")
SPRITE_MASK = os.path.join(HERE, "assets", "jet_template_mask.png")
DEFAULT_OUT = os.path.join(HERE, "control", "generated")

# Vertical placement, in pixels from the top of a 672-px frame: the jet sits
# just above the horizon, matching where it actually flies in level cruise.
CENTRE_Y = 393

# (x offset from frame centre in px, bank degrees).
#
# Case 0 is the centred, level case -- the ONLY case the pre-#140 control
# tested, kept so the suite can still demonstrate the old detector passing it.
# Everything after it is asymmetric, which is the case that catches a detector
# tracking left-right symmetric terrain instead of the aircraft.
#
# The last four are CLIPPED by the frame edge, the pose the jet is in whenever
# it reaches the sides of the screen. They exist because a fixture set whose
# jet always fits entirely inside the frame cannot detect a detector that is
# blind at the edges -- and the detector was, until these cases were added:
# cv2.matchTemplate only places a template wholly inside its search image, so
# every edge-clipped frame came back as "no detection". Measured on 28 real
# gameplay frames driven side to side, that lost 15 of them, and the 13 that
# survived spanned cx 30.9-67.8 while the true range reached 8.3-91.7. The
# detector was reporting a jet that roams half as far as it does.
#
# This is the same fault #140 was filed for, one level up: the old control
# could not see a symmetric contaminant because it never varied position, and
# this one could not see edge blindness because it never varied clipping.
CASES = [
    (0, 0.0),
    (-269, 0.0),
    (-192, 0.0),
    (192, 0.0),
    (268, 0.0),
    (-170, 7.0),
    (150, -13.0),
    (-214, 25.0),
    (210, -41.0),
    (-35, 52.0),
    (-400, 0.0),
    (400, 0.0),
    (-395, 25.0),
    (385, -41.0),
]


def rotated(img, mask, degrees):
    """Rotate with canvas expansion. Same transform jet_detect uses on the
    template, so a fixture's geometry and the detector's agree."""
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


def _inputs_fingerprint(bgs):
    h = hashlib.sha256()
    for path in [SPRITE, SPRITE_MASK] + bgs:
        with open(path, "rb") as fh:
            h.update(hashlib.sha256(fh.read()).digest())
    h.update(repr((CASES, CENTRE_Y)).encode())
    return h.hexdigest()


def build(out_dir, force=False):
    bgs = sorted(glob.glob(os.path.join(BACKGROUNDS, "*.png")))
    if not bgs:
        raise SystemExit("no backgrounds in %s" % BACKGROUNDS)
    sprite = cv2.imread(SPRITE)
    mask = cv2.imread(SPRITE_MASK, cv2.IMREAD_GRAYSCALE)
    if sprite is None or mask is None:
        raise SystemExit("missing sprite assets next to %s" % __file__)

    fingerprint = _inputs_fingerprint(bgs)
    truth_path = os.path.join(out_dir, "ground_truth.json")
    if not force and os.path.exists(truth_path):
        try:
            existing = json.load(open(truth_path))
            if existing.get("inputs_sha256") == fingerprint:
                return existing["fixtures"], False
        except (ValueError, KeyError):
            pass

    # Stale outputs are removed, not overwritten: a case list that shrinks
    # would otherwise leave last run's fixtures behind, and a stale fixture
    # read as current evidence is the #113 failure mode.
    os.makedirs(out_dir, exist_ok=True)
    for old in glob.glob(os.path.join(out_dir, "ctl_*.png")):
        os.remove(old)

    truth = {}
    for bi, bg_path in enumerate(bgs):
        bg = cv2.imread(bg_path)
        fh_, fw = bg.shape[:2]
        for ci, (dx, bank) in enumerate(CASES):
            spr, msk = rotated(sprite, mask, bank)
            th, tw = spr.shape[:2]
            x = int(round(fw / 2.0 + dx - tw / 2.0))
            y = int(round(CENTRE_Y - th / 2.0))
            # Clipped placement is intentional (see CASES), so the paste is
            # done through an intersection rather than rejected. Ground truth
            # stays the FULL sprite's bbox centre, which for a clipped case
            # legitimately falls outside 0-100 %W; the detector is expected to
            # report where the whole aircraft is, not where its visible part is.
            sx0, sy0 = max(0, -x), max(0, -y)
            dx0, dy0 = max(0, x), max(0, y)
            wv = min(tw - sx0, fw - dx0)
            hv = min(th - sy0, fh_ - dy0)
            inside = (wv * hv) / float(tw * th)
            if wv <= 0 or hv <= 0 or inside < 0.5:
                raise SystemExit(
                    "case %d (dx=%d bank=%+.0f) leaves only %.0f%% of the "
                    "sprite in a %dx%d frame" % (ci, dx, bank, inside * 100, fw, fh_))
            frame = bg.copy()
            alpha = (msk[sy0:sy0 + hv, sx0:sx0 + wv] > 127)[:, :, None]
            region = frame[dy0:dy0 + hv, dx0:dx0 + wv]
            frame[dy0:dy0 + hv, dx0:dx0 + wv] = np.where(
                alpha, spr[sy0:sy0 + hv, sx0:sx0 + wv], region)

            cx_pct = (x + tw / 2.0) / fw * 100.0
            cy_pct = (y + th / 2.0) / fh_ * 100.0
            name = "ctl_%02d_cx%02d_b%+d.png" % (
                bi * len(CASES) + ci, round(cx_pct), round(bank))
            cv2.imwrite(os.path.join(out_dir, name), frame)
            truth[name] = {
                "cx_pct": cx_pct,
                "cy_pct": cy_pct,
                "bank_deg": bank,
                "background": os.path.basename(bg_path),
                "inside_frac": inside,
            }

    with open(truth_path, "w") as fh:
        json.dump({"inputs_sha256": fingerprint,
                   "note": "regenerate with make_control.py; derived data, not committed",
                   "fixtures": truth}, fh, indent=2, sort_keys=True)
    return truth, True


def load_truth(out_dir=DEFAULT_OUT, force=False):
    """Entry point for selftest.sh: build if needed, return the truth map."""
    truth, built = build(out_dir, force=force)
    return truth, built


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args(argv)
    truth, built = build(args.out, force=args.force)
    print("%s %d fixtures in %s"
          % ("built" if built else "reused", len(truth), args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
