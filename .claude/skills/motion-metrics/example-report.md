<!-- Committed demo run for #113 AC5. Report TEXT ONLY — the strip PNGs contain
     frames of copyrighted arcade footage and live in gitignored
     .reference-cache/metrics/. Regenerate with the command at the bottom. -->

# Motion comparison — demo-1
Generated 2026-09-24T22:56:37Z

## Warnings
- Windows differ in length (reference 10.000s, game 9.981s); both truncated from their start to 9.981s so cells stay time-aligned rather than proportionally aligned.

## Inputs
| clip | path | resolution | container fps | true fps | true fps source | window (real) | analysed (real) |
|---|---|---|---|---|---|---|---|
| reference | `.reference-cache/video/ab2-longplay.mp4` | 686x480 | 30.0000 | 30.0000 | container fps (30.0000), no sidecar | 360.000-370.000s | 9.981s |
| game | `.reference-cache/captures/sd116-demo.mp4` | 960x672 | 10.0190 | 10.0190 | measured, sidecar .reference-cache/captures/sd116-demo.mp4.json | 0.000-9.981s | 9.981s |

## Normalization
- crop fractions (top,bottom,left,right): `0.12,0.12,0,0`, applied identically to both clips
- aspect policy `strict` — aspects within 0.12% (1.8846 vs 1.8824), no adjustment
- cell size: 180x96 px
- sampling interval (real time): 0.4159s (2.405 cells/s)
- strips produced: 3, up to 8 cells each, 24 cells total
- window held more cells than `--max-strips x --strip-cols` allows, so 24 cells were spread uniformly across it; the interval above is the widened one, folded into the extraction rate.
- windows differ in length (reference 10.000s, game 9.981s); both truncated from their start to 9.981s so cells stay time-aligned rather than proportionally aligned

## Time base
All windows and intervals above are in **real** seconds. Container time differs whenever a clip's
true rate differs from its container fps.

- **reference**: container 30.0000 fps, true 30.0000 fps (time scale 1.0000) — container fps (30.0000), no sidecar
- **game**: container 10.0190 fps, true 10.0190 fps (time scale 1.0000) — measured, sidecar .reference-cache/captures/sd116-demo.mp4.json

## Strips
| file | covers (real time) | cell interval |
|---|---|---|
| `strip-01.png` | +0.00s to +2.91s | 0.4159s |
| `strip-02.png` | +3.33s to +6.24s | 0.4159s |
| `strip-03.png` | +6.65s to +9.57s | 0.4159s |

What to look for: pick the same cell index in both rows and compare horizon height,
ground detail, object count, jet pose and explosion size.

## What this report does not contain
No speed, px/frame or ratio figures: AB2's ground texture temporally aliases below
~60fps sampling, so frame-to-frame motion estimates measure the estimator's ceiling
rather than actual speed (#113 finding). Quantitative speed is gated on 60fps capture (#114).

## Reproduce
```bash
bash .claude/skills/motion-metrics/compare.sh --ref .reference-cache/video/ab2-longplay.mp4 --ref-window 6:00-6:10 --game .reference-cache/captures/sd116-demo.mp4 --name demo-1 --out .reference-cache/metrics/demo-1
```
