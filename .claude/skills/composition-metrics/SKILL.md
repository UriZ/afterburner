---
name: composition-metrics
description: Locate the player jet in gameplay frames and report its screen-position distribution, for composition gates (does the jet roam the frame like the arcade?). Shape-model detector that survives real gameplay backgrounds. Replaces the colour-threshold crop-then-centroid method, which measured terrain.
user-invocable: true
argument-hint: "'frames/frame_*.png' [--min-score 0.25] [--json out.json]"
allowed-tools: Bash, Read
---

# Composition Metrics

## Do not use the old detector

Any composition measurement that selects pixels by brightness and saturation
(`V > 0.72, S < 0.25`) and takes their centroid is **invalid on this project**.
That method is what #122 used and what #140 removed. Use `jet_detect.py`.

If you find that method quoted in a spec, an agent definition or an issue
comment, it is stale — measure with this skill and say so in your report.

## Why the old one had to go

It assumed our jet was the only large bright near-neutral object on screen.
Once the ground gained bright pale rocks, that stopped being true:

| frame | jet pixels | ground pixels selected |
|---|---|---|
| stage 1, mid-capture | 123 | 982 |
| stage 6, mid-capture | 174 | 2535 |

A 60-second capture reported `cx sd 3.05` — a confident, precise measurement of
a hillside. Every frame "detected"; none of them measured the aircraft.

**The control in use could not catch this.** It asked only "does a centred jet
read as cx ≈ 50?". Left–right symmetric terrain also reads cx ≈ 50, so it
passed for the wrong reason. A control whose wrong answer is symmetric cannot
detect a symmetric contaminant. That is the transferable lesson: a known-answer
control only validates the axis it varies.

## How this detector works

Masked template matching against a real template of the jet's silhouette, on
Sobel gradient-magnitude images:

1. **Edges, not colour.** A detector tuned over the blue stage-1 sky keeps
   working over orange desert, black night and pale snow. Absolute brightness —
   the thing the old threshold keyed on — is discarded.
2. **Masked `TM_SQDIFF_NORMED`**, so only jet pixels score. OpenCV supports
   masking for `TM_SQDIFF` and `TM_CCORR_NORMED` only — a mask passed to
   `TM_CCOEFF_NORMED` is silently accepted and returns garbage. `TM_CCORR_NORMED`
   was tried and rejected too: it scores correlation energy, so busy rocky
   ground scored 0.61 on frames with no jet in them at all.
3. **25 bank angles** at 4.75° steps spanning ±57°, the jet's own limit. The
   winning angle is reported as a by-product, accurate to within 2.5°.
4. **The frame is padded** so a jet hanging off the side of the screen can
   still be matched — see the section below, this one bit hard.
5. **It refuses.** Below `--min-score` a frame is reported as no detection
   rather than as a number. A detector that always answers is how the old one
   produced 120 confident measurements of terrain.

## The edge-clipping trap (read this before quoting a cx spread)

`cv2.matchTemplate` only places a template **wholly inside** its search image.
A 344-px-wide jet half off the side of the screen was therefore not a low
score, it was **no candidate position at all** — and those are exactly the
frames where the jet is furthest off centre. A detector built to answer "does
the jet roam the frame?" was structurally blind at the two places that answer
it.

Measured on 28 gameplay frames driven side to side with held input:

| | frames detected | cx range reported |
|---|---|---|
| before (no padding) | 13/28 | 30.9 – 67.8 |
| after (padded) | 28/28 | 8.3 – 91.7 |

The pre-fix tool would have reported a jet roaming **half as far as it does**,
with no warning — every refusal looked like the detector being appropriately
careful. This was found by looking at the refused frames instead of trusting
the refusal, and it is the same fault as #140 one level up: a control whose
cases all fit inside the frame cannot detect a detector that is blind at the
edges. `control/` now carries four deliberately clipped cases.

Two consequences worth knowing:

- The padding is a **void of zero gradient**, so the mask pixels hanging off
  the edge would otherwise be scored against nothing. Scores are recomputed
  over the **visible** mask only; unclipped frames are unaffected.
- The search still *ranks* by the penalised map, so a clipped jet's position
  can be pulled slightly toward the frame interior. The clipped control cases
  bound that at **0.05 pp** — measured, not assumed.

## Usage

```bash
PY=.reference-cache/venv-metrics/bin/python3     # any interpreter with cv2
$PY .claude/skills/composition-metrics/jet_detect.py 'frames/frame_*.png'
$PY .claude/skills/composition-metrics/jet_detect.py 'frames/*.png' --json out.json
```

Output reports detection count, cx/cy mean, sd and range in percent of frame,
the fraction of frames more than 5 pp off centre, and the **minimum match
score**. Exit codes: 0 ok, 2 usage, 3 too few detections for statistics.

## Reading the result honestly

- **Check the detection count.** Expect 70-80% on real gameplay; the jet is
  routinely overlapped by explosions, enemies and its own afterburner. A rate
  far below that means something changed — investigate before reporting numbers.
  Title screens and game-over frames correctly report nothing, so a capture
  that outlives the player's last life dilutes the rate; count only frames that
  contain a jet.
- **Refusals are not failures.** Every accepted detection lands within 0.05 pp
  of truth on the fixtures. Do not lower `--min-score` to raise the count.
- **An off-centre fraction from this tool is a FLOOR.** The remaining refusals
  are concentrated on poses that are heavily banked *and* clipped at once —
  off-centre poses. The tool cannot overstate how far the jet roams; it can
  still understate it.
- **Budget the time.** ~2.5 seconds per frame, so a 120-frame capture takes
  about five minutes.
- **The template is the current jet.** It was rendered from
  `tests/jet_silhouette_preview.gd`. If the jet art changes, regenerate
  `assets/jet_template.png` and `assets/jet_template_mask.png` from that rig and
  re-run the selftest, or scores will drift down and the detection rate with
  them.

## Selftest

```bash
bash .claude/skills/composition-metrics/selftest.sh
```

No arguments and no setup: it builds its own fixtures and ships its own
jet-free frames. Takes about seven minutes.

The headline test is a **two-way negative control** over real terrain, using
112 fixtures built by `make_control.py` — the jet composited onto jet-free
gameplay backgrounds at known offsets, so ground truth is exact:

| case | legacy detector | shape-model |
|---|---|---|
| jet centred (what the old control tested) | max err **1.73 pp** — passes | max err 0.00 pp |
| jet off-centre (the missing case) | max err **28.41 pp** — fails | max err 0.05 pp |
| jet banked between template samples | — | max err 0.05 pp |
| jet clipped by the frame edge | — | 26/32 seen, max err 0.05 pp |
| jet-free frames | reports a jet anyway | 0/12 detections |

The asymmetric row is the point. A control that only the new detector can pass
is the only kind that proves anything, so the suite asserts the old detector
**fails** it as well as asserting the new one passes.

Two of these rows exist because the test SUITE was wrong, not the detector:

- The jet-free row used to **skip** unless an environment variable pointed at
  frames someone had rendered by hand, so the suite's only false-positive guard
  was the one test that never ran. With the frames committed and the test on by
  default it immediately failed — `--min-score 0.25` was firing on stage 17's
  canyon rock, which is #140's own defect on terrain the first threshold sweep
  had not seen. Threshold is now 0.30.
- It also asserted the wrong string. Grepping the output for "too few to
  report" passes when the detector fires on one or two frames, because that
  message covers any run with under three detections. It asserts `0/N` now.

## Regenerating the control fixtures

`make_control.py` builds them, and `selftest.sh` calls it automatically; run it
by hand only to inspect the output:

```bash
$PY .claude/skills/composition-metrics/make_control.py --force
```

Only the INPUTS are committed — `control/backgrounds/` (8 jet-free stage
renders) and the jet sprite in `assets/`. The 112 composites are derived data
and gitignored: they are 58 MB, in a repo whose whole history is 38 MB, and
they go stale the moment the jet art changes. `make_control.py`'s docstring
carries the details of how to regenerate the inputs themselves.
