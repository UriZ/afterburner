---
name: motion-metrics
description: Build time-aligned side-by-side strip images comparing AB2 arcade reference footage against one of our gameplay captures, sampled at the same REAL rate. For judge and QA motion/composition gates.
user-invocable: true
argument-hint: "--ref <mp4> --ref-window MM:SS-MM:SS --game <mp4> [--game-window MM:SS-MM:SS] [--name NAME]"
allowed-tools: Bash, Read
---

# Motion Metrics

## 1. What this does — and what it does not

**Does**: takes two mp4s and emits *aligned strips* — one image per batch of cells, reference
row above game row, both sampled at the same rate in **real** time — plus a `report.md`. The
strips are ordinary PNGs an agent can `Read`.

**Does not**: measure speed. There is no px/frame value, no flow ratio, no CSV and no plot in
v1, and `selftest.sh` mechanically asserts none appears in the report.

Why: AB2's repetitive dithered ground texture temporally aliases below ~60fps sampling. A
ground-truth decimation test (sample one window at 30/15/10/6 fps, where displacement is
exactly proportional to `1/fps`, so the true ratios are known) showed optical flow measures
a true 0.50 as 0.92 and a true 2.50 as 0.84 — sensitivity to actual speed is approximately
zero. Three algorithms, five resolutions, four prefilters and four image bands all fail the
same test, so it is a Nyquist limit, not a tuning problem. Quantitative speed is deferred to
a follow-up gated on 60fps capture (#114).

**So: do not infer speed from these strips.** Use them for horizon height, ground coverage,
object count, jet pose, scale and explosion size.

## 2. Quick start

Judge:

```bash
bash .claude/skills/motion-metrics/compare.sh \
  --ref .reference-cache/video/ab2-longplay.mp4 --ref-window 6:00-6:10 \
  --game /tmp/game-capture/judge-video.mp4 \
  --name judge-<issue>
```

QA:

```bash
bash .claude/skills/motion-metrics/compare.sh \
  --ref .reference-cache/video/ab2-longplay.mp4 --ref-window 6:00-6:10 \
  --game /tmp/game-capture/qa-video.mp4 \
  --name qa-<issue>
```

**Concurrency**: two runs sharing one `--out` are safe — they serialize on a lock and the
second cleanly replaces the first, so you always read one complete run's evidence (#119
fixed). The second run prints `Waiting for another compare.sh run to finish ...` and may
take a few seconds longer. A distinct `--name` per agent is still preferable when you want
*both* results, since the loser's output is replaced, not merged.

Then `Read` every `strip-NN.png` it prints, and `Read` the `report.md`.

First run bootstraps a ~140 MB venv under the gitignored `.reference-cache/venv-metrics/`;
subsequent runs take a few seconds.

## 3. Reading a strip

Each strip is `1468x286` at defaults:

- **Top row** — AB2 reference. Yellow label gives the window start and the clip name.
- **Bottom row** — our capture. Green label gives the same.
- **8 cells per row**, left to right in time order, `180x96` each.
- **Timestamps under every cell** (`+N.NNs`), in **real** seconds from the window start.
  The two rows carry identical timestamps by construction.

Compare **the same cell index across the two rows**. Cell 3 of the top row and cell 3 of the
bottom row are the same number of real seconds into their respective windows. Cite what
differs concretely: "AB2 cell 5 has ground filling ~85% of the cell below a high horizon;
ours has ~40% ground under an orange sky band."

For more detail per cell at the cost of coverage: `--strip-cols 6 --strip-cell-width 240`.
Do not go above 1568 px total width — agent image pipelines downscale past that and the
cells stop being crisp.

## 4. Choosing windows

**The tool aligns time, not content.** It will happily put AB2's cloud stage next to our
desert stage and produce a perfectly valid artifact describing the wrong thing. Picking
comparable action is the operator's job.

The documented reference window is **`6:00-6:10`** — Stage 8 desert canyon. Verified by
extracting frames at 358/360/.../372s: level flight throughout, ground filling the frame
below a high horizon, `STAGE 8` constant across all of them (no stage transition mid-window),
and score advancing normally. It semantically matches our desert stage, which is the point.

An earlier draft used `4:55-5:05`; that is the cloud-bank stage with the player hard-banked.
Do not use it.

## 5. Time base — why `--game-true-fps` exists

Before #116, `capture-video.sh` grabbed frames in an unpaced loop and encoded with
`-framerate <requested>`. The container fps was a label applied after the fact; the real rate
was ~17.3 fps against an 8 or 15 label, so those clips are 1.15x–2.2x slow motion.

That matters here specifically: sampling such a clip at "3 fps" of *container* time samples
it at `3 x nominal/true` fps of *real* time. The two rows would then be at mismatched real
intervals while the timestamps claimed otherwise — AC "same fps from both clips" true on
paper, false in fact. So every window and rate this tool takes is in **real** seconds, and it
resolves a true rate per clip before doing anything else:

1. A sidecar `<clip>.json` written by `capture-video.sh` (#116) → its `measured_fps`. This is
   the only *measured* answer.
2. Otherwise `--game-true-fps` / `--ref-true-fps` — a float, or the literal `container` to
   accept the label deliberately.
3. Otherwise **exit 2**. The game side has no default on purpose.

An explicitly passed flag overrides a sidecar (you may know the sidecar is stale). The
reference defaults to `container`, because a real video recording's container fps *is* its
time base.

**Legacy captures have no recoverable true rate.** Re-capture with `capture-video.sh` rather
than guessing. If you do pass `--game-true-fps container` on a pre-#116 clip, the report
prints a prominent declared-not-measured warning — take it seriously, it can hide a 2.2x
row-to-row misalignment.

## 6. Options

| Flag | Type | Default | Meaning |
|---|---|---|---|
| `--ref` | path | **required** | Reference (arcade) mp4 |
| `--ref-window` | `START-END` | **required** | Window in **real** time |
| `--game` | path | **required** | Game capture mp4 |
| `--game-window` | `START-END` | whole clip | Window in **real** time |
| `--out` | dir | `.reference-cache/metrics/<name>` | Output dir (created; contents overwritten) |
| `--name` | str | `run-YYYYMMDD-HHMMSS` | Run name, used in labels and the default `--out` |
| `--game-true-fps` | float \| `container` | **required unless a sidecar exists** | Real capture rate |
| `--ref-true-fps` | float \| `container` | `container` | Same for the reference |
| `--strip-fps` | float | `3.0` | Common sampling rate, **real** time, both clips |
| `--strip-cols` | int | `8` | Cells per strip image |
| `--strip-cell-width` | int | `180` | Cell width in px |
| `--max-strips` | int | `3` | Cap on strip images per run |
| `--crop` | `T,B,L,R` | `0.12,0.12,0,0` | Fractions cropped off each edge, **both** clips |
| `--aspect-policy` | `strict` \| `center-crop` | `strict` | On post-crop aspect mismatch |
| `--keep-frames` | flag | off | Keep extracted frames for debugging |

Window grammar: `START-END`, each side `[[HH:]MM:]SS[.frac]` or bare seconds.

`--crop` is deliberately a **single shared option**, not per-clip. Different crops retain
different portions of the play field and destroy row-to-row geometric alignment. The 12%
default clears both HUD bands: the reference's top HUD ends at 10.8% of height and its bottom
band starts at 88.5%; ours at 6.7% and 90.5%.

When more cells fit in the window than `--max-strips x --strip-cols` allows, the cells are
spread **uniformly across the whole window** rather than truncating its tail, and the widened
interval is folded back into the extraction rate — a single ffmpeg pass, nothing extracted
and discarded. The report states the effective interval.

Extracted frames are deleted by default because they are frames of copyrighted arcade
footage. Never commit strips; commit report text only.

**Re-running into the same `--out` is safe.** Because the agent inserts use a stable
`--name judge-<issue>` / `--name qa-<issue>`, a re-run after a fix lands in a populated
directory. The tool clears its own prior `strip-*.png`, `report.md` and `.frames/` before
extracting, so what you read is always one run's evidence — a shorter second window cannot
leave a `strip-03.png` behind showing the old one. Clearing happens **after** all validation
and **before** extraction, so a bad invocation never destroys a good previous run, but a run
that fails during extraction leaves the directory empty rather than stale. Files the tool
does not itself write are never touched.

**Concurrent runs into the same `--out` are also safe** (#119). Each run takes an exclusive
`flock` on `<out_dir>/.lock` for its whole working phase, so two processes serialize instead
of interleaving; the waiting one says so on stderr. Everything is built in a
`.staging-<token>` subdirectory and moved into place with `os.replace` only once complete, so
the paths you are told to read never hold a half-written file — not even if a run is killed
mid-compose. The lock is an `flock`, which the kernel drops when the process dies, so there
is no stale lock to clean up by hand.

The loser of a race is **replaced, not merged**: you get one complete run's evidence, never a
`strip-01.png` from one window beside a `strip-02.png` from another. Before the fix, that
mixed-provenance outcome was the *likelier* symptom (4 of 6 measured trials) and it decodes
perfectly — the torn PNGs everyone noticed first were the rarer half.

## 7. Troubleshooting

| Exit | Meaning | Do |
|---|---|---|
| 0 | ok | — |
| 2 | usage, window, or time base | Read the message; it names the offending value and the clip's true real duration |
| 3 | ffmpeg/ffprobe missing | `brew install ffmpeg` |
| 4 | venv bootstrap failed | Offline? Install manually, or set `MOTION_METRICS_PYTHON` to an interpreter that has `cv2` |
| 5 | input missing or unprobeable | Check the path; confirm the capture actually produced a video |
| 6 | post-crop aspect mismatch >2% under `strict` | `--aspect-policy center-crop`, or fix the capture resolution |
| 7 | fewer than 2 cells extractable | Widen the window or lower `--strip-fps` |
| 8 | waited over 5 min for another run's lock on this `--out` | Check nothing else is running against it; otherwise delete `<out>/.lock` or use a different `--name` |

`--strip-fps` above a clip's true rate is exit 2: the clip cannot supply distinct frames that
fast, and upsampling would duplicate cells that look like a frozen game.

## 8. Limits

- **No speed numbers**, by design (§1). If a gate needs a speed claim, it is blocked on #114.
- **Concurrent runs on a shared `--out` serialize, they do not merge** (#119). Both succeed,
  but only the last one's strips and report survive. Use a distinct `--name` when you need
  both results side by side.
- **Content alignment is the operator's job** (§4). The tool guarantees time alignment only.
- Runtime is a few seconds per clip; long windows are bounded by `--max-strips`.
- A `--game-true-fps container` declaration on a pre-#116 clip is only as good as the label.
- Under `strict`, the two rows may differ in aspect by up to 2%; cell height is taken from the
  reference, so the game row carries that (bounded, sub-2%) vertical distortion.

## 9. Validation

```bash
bash .claude/skills/motion-metrics/selftest.sh
```

64 assertions: pure-function unit tests (window parsing, crop geometry, aspect resolution,
sampling plan, and the §3.4 time-base worked example used as a known-answer oracle) plus 14
end-to-end tests against generated fixtures — strip geometry, row alignment, real-time
equalization on a deliberately mislabeled clip, sidecar precedence, every error path, frame
cleanup, sequential re-run idempotency, concurrent-run safety, and the lock timeout.

Two of those carry **negative controls proving the guard can fail**: the scope-boundary
check is run against a report that does contain speed figures, and the concurrency check's
PNG-decode assertion is run against a deliberately torn PNG. The concurrency test itself was
verified against the pre-fix code, where it fails 3 times out of 3.

`example-report.md` in this directory is the committed demo run (report text only).
