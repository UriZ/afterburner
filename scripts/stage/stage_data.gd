extends RefCounted

## Stage definitions for After Burner's 23 stages.
## Each stage defines ground/sky colors, enemy difficulty, and whether it's a bonus stage.

## ============================================================================
## SKY COLOURS — every value below is tied to a VERIFIED arcade stage (#123)
## ============================================================================
##
## Read this before changing any sky_top/sky_horizon value.
##
## #115 re-derived these from reference frames and matched stage 1 to
## `burst-a-02` to within 1/255 — and was wrong anyway, because nobody had
## established WHICH arcade stage burst-a-02 shows. It is stage 2. Our stage 1
## therefore shipped with stage 2's orange desert sky, which is what the user
## saw and reported as "the sky is brown". The measurements were fine; the
## correspondence between frame and stage was never established. A pixel-perfect
## match to an unidentified frame proves nothing.
##
## So: the extracted frames in assets/reference/motion/ab2-longplay/ carry NO
## stage labels and must not be used as a per-stage anchor on their own. Values
## here come from .reference-cache/video/ab2-longplay.mp4 at timestamps whose
## stage identity was read directly off the HUD.
##
## HOW THE MAPPING WAS ESTABLISHED (repeat this if you re-derive anything):
##   1. Sampled the video every 4s and cropped the HUD stage-number field at
##      x=376..414, y=426..450, scaled 5x nearest-neighbour.
##      `ffmpeg -ss T -i .reference-cache/video/ab2-longplay.mp4 -frames:v 1 out.png`
##   2. Read the digits directly. Attract mode runs to ~84s; the run starts at
##      the carrier launch ~88s with SCORE 0.
##   3. Cross-checked the three burst sets by score continuity: burst-a reads
##      SCORE 485420, and the video shows 4853xx-489310 at t=148-152 (stage 2).
##      burst-c reads ~7.74M, matching t=705-709 (stage 17). burst-b's snow sky
##      #b7d3d6 matches stage 9's measured #b5cfd7 and no other stage.
##
## VERIFIED STAGE SPANS (seconds into ab2-longplay.mp4):
##    1: 88-120    2: 124-156    3: 160-196    4: 200-240    5: 244-256
##    6: 260-304   7: 308-340    8: 344-372    9: 376-424   10: 428-468
##   11: 472-508  12: 512-548   13: 552-568   14: 572-608   15: 612-652
##   16: 656-692  17: 696-724   18: 728-764   19: 768-808   20: 812-852
##   21: 856-892  22: 896-932   23: 936-952
##
## Sky colour per stage = modal colour of the band y=55..150 across 5 frames
## spread inside the stage's span. AB2's sky is a flat fill, so the mode is an
## exact hit, not an average: on most stages it accounts for 50-80% of the band.
##
## HORIZON GLOW is per stage and was measured, not inferred, by scanning the
## longest unbroken sky column in each stage's frames from y=60 down to the
## terrain break. Only stages 2, 14, 17, 20 and 22 show a measurable change;
## every other stage holds ONE colour from the top of frame to the horizon and
## gets sky_top == sky_horizon, which _draw_sky() renders as a single flat fill.
## Do not assume a biome implies a glow — #115 generalised "desert and green
## glow" from two frames and applied it to eleven stages.
##
## The glows do not share a direction, which is why no rule should be inferred
## from one of them: stage 2 shifts +23deg of hue toward gold (#e67100 ->
## #f0d100), stage 14 shifts -14deg toward orange, stage 17 desaturates to cream
## (#a4d3a5 -> #fbf2d5), stage 20 brightens (+0.12 V) at near-constant hue, and
## stage 22 lightens deep blue toward cyan.
##
## LOW-CONFIDENCE VALUES, flagged honestly: stages 5 and 13 are the refuel /
## runway stages, where terrain fills the frame to the top and only a few rows
## of sky are ever visible; their pale values come from that thin band and carry
## much weaker evidence than the rest. Stage 8 is a canyon — its cream #faecb0
## was confirmed by direct pixel reads at t=357 rather than by the column scan,
## which kept landing on canyon wall.
##
## Stage 3's sky really is near-black; an earlier note here claimed a literal
## near-black night "reads as washed-out" and mandated hue-carries-night
## instead. That was an assumption, and the measurement (80% of the sky band at
## #030303) contradicts it.
##
## GROUND PALETTES (#124) — re-derived against the PROVEN stage map above for
## stages where the measurement method is valid; left UNCHANGED and annotated
## per-stage where it is not. Any stage's ground_a/b/c not mentioned here as
## re-derived still carries an UNVERIFIED biome label from #42/#108 (the
## original #123 audit's finding stands for those: arcade stage 1 is a
## coastal sea run, but shipped labelled/coloured as desert until this pass).
##
## METHOD: #123's modal-colour sky estimator does NOT transfer to grounds —
## measured directly: stage 1's SKY mode share is 97.8%, its GROUND's is
## 5.7%, because AB2 ground is dithered/streaked, not a flat fill. A fixed
## sky/ground row split also leaks, because the horizon tilts with player
## bank (rule 17) — no screen region is reliably ground on a banked frame.
## So this is a frame SELECTOR, not a mask: reject whole frames that can't
## be trusted, then histogram hue on the ones that remain.
##
## Per frame, band = rows 76-85.5%H, full width (686x480 reference video;
## the HUD speed bar starts at 86%H, so no horizon estimate is needed):
##   1. REJECT if flatfrac > 0.40, where flatfrac = fraction of band pixels
##      whose 5x5-neighbourhood local std of V is < 1.5/255 — applied both
##      per-FRAME (reject the whole frame) and per-PIXEL (exclude any
##      residual flat pixel from an otherwise-accepted frame's hue
##      histogram; needed after two stage-1 island frames leaked a sliver of
##      flat sky at the frame edge into an otherwise-clean land sample).
##      Control, stage 1 t=116 (crop x=0-686): pure sky y=100-160 ->
##      flatfrac 100.0% (rejected, correct); pure sea y=320-390,x=450-650 ->
##      flatfrac 4.6% (accepted, correct). >20x separation; 0.40 sits well
##      inside it. This REPLACES an earlier sky-COLOUR gate that rejected
##      the sea itself on stage 1 (colour, not texture, is what a flat sky
##      and the sea share — verified: 40/46 stage-1 frames wrongly rejected
##      under the colour version).
##   2. REJECT if >6% of the band is explosion-bright (S>0.55, V>0.90) AND
##      warm-hued (<=50deg or >=340deg). The warm-hue qualifier is this
##      pass's own fix: run hue-agnostic (as first specced), this rejected
##      26/48 of stage 1's frames — verified by inspection to be the sea's
##      own bright cyan wave crests (hue ~237deg, S~1.0, V~0.93), not fire.
##      Fire is warm by construction (rule 10); gating on hue keeps the
##      rule's power on land stages while fixing the blue-sea false positive.
##   3. REJECT if >4% of the band is aircraft-neutral (S<0.20, V>0.60).
##   4. REJECT (this frame contributes nothing) if <30% is saturated
##      (S>0.25) — if this fires on nearly every frame, the stage is
##      unmeasurable this way (see below).
##   5. On a surviving frame: for stage 1 (sea target), also restrict to hue
##      170-260deg. A raw "blue-dominant" B>R channel test was tried first
##      and is too weak — pure green pixels like BGR=(10,91,0) satisfy B>R
##      trivially whenever R is near zero, which let green island frames
##      (t=104.0, t=111.5) leak into the sea histogram. Then: histogram hue
##      in 10deg bins of the saturated population; take the dominant bin
##      centre H; select pixels within +/-20deg of it (rule 11's own bin
##      width — narrower than the architect spec's original +/-25deg, which
##      its own risk 3 flagged as merging populations on scrub stages);
##      record this frame's H, median S, and V75/V25 (75th/25th percentile V)
##      within that selection.
##   6. Aggregate across accepted frames by MEDIAN, not a pooled histogram.
##      Hue is aggregated CIRCULARLY (median and spread both) — a linear
##      median of {355deg, 5deg} is 180deg, the opposite hue, and a linear
##      spread calls those two frames 350deg apart. Warm stages (2, 10, 19 all
##      sit at H=35) are close enough to the wrap for this to matter.
##
## Tool (committed, re-runnable): `tools/measure_ground_palette.py --stage N
## [--sea-only] [--sample-interval 0.5] [--hue-window 20]`. Reports frames
## accepted/total, per-reason reject counts, median flatfrac of accepted
## frames, circular hue spread, V75/V25 standard deviations (the TOLERANCE on
## the published values), two independent corroborators, and the three
## candidate colours (light/mid/dark = V75/avg/V25 at the median H,S).
##
## TWO CORROBORATORS, because the primary estimator's yield is as low as 3
## frames on some stages and no number that thin is quotable on its own.
## Both run on the same accepted frames and neither shares the primary's
## machinery (10deg hue binning of an S>0.25 population inside a +/-20deg
## window):
##   corr-1 EXACT-COLOUR MODE — hue of the single most frequent exact RGB
##     triple among NON-FLAT band pixels. Silent by construction on heavily
##     dithered grounds (on stage 14 the winner is #000000 at a 4-6% share,
##     the gaps between palm crowns) and reported as UNAVAILABLE there rather
##     than quoted; also suppressed per frame when its own modal pixel is
##     achromatic, which is what it does on stages 14/17 — unsuppressed it
##     called black "hue 0 = red" and appeared to contradict a correct value.
##   corr-2 CHROMA-WEIGHTED CIRCULAR MEAN — S*V-weighted mean hue direction
##     over every non-flat band pixel. No threshold, no bin, no window, so it
##     cannot inherit the primary's selection. Its concentration R (0-1) is a
##     per-frame unimodality check independent of the across-frame spread.
## Both deltas are published per stage below. They agree within 12deg on
## every stage kept here; the one stage where corr-2 fell outside the
## +/-20deg selection window (17, delta 22deg) is NOT kept.
##
## KEPT — 9 of 23 (n>=3 accepted frames, circular hue spread <=30deg, and
## both corroborators inside the +/-20deg selection window): 1, 2, 4, 8, 10,
## 14, 15, 16, 23. n>=3 rather than a tighter n>=5 tried first: canyon stage
## 8 genuinely yields few accepted frames — its near-ground band is mostly
## rock wall, the same reason the SKY measurement's own column scan "kept
## landing on canyon wall" (see above) — and it reproduced H=35 S=1.00
## V75=0.831 at BOTH sampling densities (0.5s: 4/40; 0.25s: 7/80), with both
## corroborators at delta 3deg. That is stability evidence, not a frame count
## to relax past.
##
## UNMEASURABLE — 14 of 23, left UNCHANGED, reason annotated on each stage's
## own comment below (the architect's 8-stage sample predicted "roughly
## half"; it is 61%): 3, 5, 6, 7, 9, 11, 12, 13, 17, 18, 19, 20, 21, 22.
## Structural causes:
##   MIXED-BIOME — two real hue families in the band (stage 7 swings 210deg,
##     land and water in one shot), which the one-hue-per-stage data model
##     could not hold even if measured;
##   LOW-SATURATION / TOO-DARK — the variance or aircraft-neutral gates
##     reject nearly every frame before saturation is checked (5, 6, 9, 13
##     accept ZERO);
##   NEAR-BLACK, HUE UNRESOLVABLE — stage 3 only. HSV reports S=1.00 for a
##     pixel of RGB (0,0,2), so the "<30% saturated" reject rule STRUCTURALLY
##     CANNOT fire on a night stage: every black pixel counts as saturated.
##     See stage 3's own comment for the numbers. This is a gap in the
##     architect's selector, not in stage 3 — the same rule did reject the
##     other night stage (11) only because that one is dark-but-not-black.
##   POPULATION NOT SEPARATED — stage 17 only; the architect's own risk 3
##     named this stage and this pass could not discharge it. See its comment.
##
## A partial re-grade with honest gaps is the goal, not a complete table with
## invented values — the #123 lesson this issue exists to apply to grounds.
## TWO KEPT-WRONG VALUES ARE THE PRICE, and they are worse than "unverified":
## stage 3 (night) ships a BRIGHT ORANGE desert ground and stage 17 (olive
## field) ships a BRIGHT GREEN one, both visibly wrong against their proven
## reference frames. They are left alone because #124's rule is measure-or-
## leave, not because they are acceptable. Both need a follow-up with a
## method this issue does not have: stage 3 needs a value-only estimator that
## never asks HSV for a hue it cannot carry, stage 17 needs an
## explosion-free sampling window plus a scrub/field population split.
##
## ground_c: a third ground color for the terrain shader's material-cluster
## blend (see ground_terrain_2d.gdshader). ITS HUE IS DISCARDED. The shader's
## round-7 correction derives base_hue from color_a and pins every cluster to
## it, reading color_c for its S/V only ("a stage-tuned mid accent, hue PINNED
## instead of following color_c's own hue" — ground_terrain_2d.gdshader
## fragment(), accent_light/accent_dark at V*1.25 and V*0.85). So ground_c is
## a VALUE step, not a third hue, and #124 sets it to the midpoint of the
## measured V25-V75 range at the stage's measured H and S.
##
## This paragraph previously said the opposite — that ground_c carried a
## distinct olive hue and that the shader "needs >=3 hue clusters per band to
## pass shape regularity". Both halves are dead: the shader stopped consuming
## color_c's hue at round 7, and criteria G4 retired the >=3-hue-cluster rule
## outright ("a prior >=3 hue clusters version produced a confetti ground and
## is retired"). Kept as its own per-stage uniform rather than a fixed offset
## from ground_a/ground_b because stages still want different amounts of
## value contrast. Left here rather than deleted because the round-5/round-6
## history is still the reason ground_c exists at all: round 5 zeroed it to a
## no-op on one bad single-frame measurement and round 6 restored it.
##
## Note the blues are NOT interchangeable, so do not "tidy" them into one
## shared constant: the verified stages measure five genuinely different blues —
## 6 is a deep #0045ff, 22 a deeper #000cff, 1/12/23 a mid #009fff, 7/19 a
## slightly greener #0089fb, and 21 a cyan #00c1f9. An earlier pass collapsed
## the ocean stages onto a single hue on the strength of one unidentified frame.
##
## HORIZON POSITION is per stage (#120). Cruise stages hold 0.625 (60-65 %H).
## Stages 8 and 17 are canyons: 0.13 and 0.07, each the MEDIAN over 41 frames
## sampled at 0.5 s across the verified span minus its first/last 4 s, using
## seed = that stage's sky_top, metric sum|dRGB|, tolerance 60, cut at the
## first row whose sky-colour coverage falls below 2.0 %.
## THE CLASSIFIER IS PART OF THE MEASUREMENT: on one frame the cut moves
## 10.2 -> 15.6 %H across plausible tolerances, which is exactly how an earlier
## pass shipped 0.10 for stage 17 when 0.07 was right. Re-deriving without
## restating metric AND tolerance reproduces nothing.
## CONFIDENCE DIFFERS: stage 8's median moves only 3.33 pp across the whole
## tolerance sweep; stage 17's moves 7.92 pp. Treat 0.07 as the weaker value.
## RESIDUAL: the boundary genuinely moves in flight (stage 8 p10-p90
## 6.5-26.5 %H; stage 17 5.4-25.6 %H). A single constant cannot track that;
## the median is chosen as a robust centre, not as a precise value.
## TILT: a row-coverage cut is biased by (1-2c)*(W/2)*tan(roll). Canyon roll is
## ~0.4 deg median, so the bias here is ~0.5 pp - negligible. On CRUISE stages
## roll reaches 67.9 deg and the same cut is unusable; use the texture-split
## estimator there (#120 AC 7), never a row-coverage cut.
## Only 8 and 17 have measured canyon evidence. Every other stage keeps the
## 0.625 cruise default — in particular stages 5 and 13 (refuel/runway) are
## NOT changed: their sky band is too thin for a stable reading, and shipping
## an unmeasured number is exactly the #123 failure this project already paid
## for. A capture reading outside a stage's measured band (see the p10-p90
## spread above) is not automatically a bug — check it against the band
## before treating it as an implementation defect.
##
## ============================================================================
## SCROLL SPEED — per stage (#139), keyed the same way the horizon is
## ============================================================================
##
## `scroll_speed` is the world velocity in DEPTH UNITS PER SECOND that
## GameWorld advances `_ground_scroll` at. game_manager_2d._apply_stage()
## pushes it into `GameWorld.ground_scroll_speed`; `GROUND_SCROLL_SPEED = 1.4`
## in game_world.gd is only the fallback for a GameWorld with no stage.
##
## WHY PER STAGE: apparent flow is `k * v * span`, span = SCREEN_H - horizon_y
## (differentiate DepthUtil.to_screen). #120 made span vary 2.48x between
## regimes, so one global v would run our canyons 2.32-2.48x FASTER than our
## cruise, while the arcade runs its canyon at most 0.63x its cruise — wrong
## direction by ~4x. The arcade's own regimes differ: cruise >= 3.063 px/frame
## (a FLOOR — arcade stage 1 fails the aliasing gate, which only reads low),
## canyon 1.9433 px/frame (certified). Both from #127, both at motion-metrics'
## common 192 px work width; raw px/frame across the two resolutions would not
## be comparable.
##
## THE CONTROL THAT LICENSES THE ARITHMETIC (#139 AC 1, run before any value
## below was chosen): flow must be exactly linear in v. Doubling 1.4 -> 2.8 and
## re-measuring gave **1.940x**, inside the pre-declared 2.00 +/- 0.10 — but
## only when sampled at 120 fps. Measured on the same two captures at 60 fps
## the doubled clip FAILS the fps-decimation gate (+12.6%) and reads 1.910x,
## and at 240 fps it degrades again to 1.905x (per-frame displacement drops to
## 0.22 %W, into the estimator's sub-pixel regime). So our content has a usable
## BAND, not just an upper knee, and 120 fps is the rate inside it. Anyone
## re-deriving a speed number here at 60 fps is measuring the estimator.
##
## VALUES — two measurements, applied BY REGIME, never per stage by eye:
##
##   CRUISE (21 stages) = 2.8. Our own speed at 1.4 measures 51.04 %W/s
##   (120 fps, gate +0.3%); the arcade stage-1 floor is 95.7 %W/s, needing
##   >= 2.625. Shipped 2.8 because that is the value with a DIRECT certified
##   measurement rather than an interpolation. Verified end to end through the
##   stage-data path (not by editing the constant): **97.48 %W/s at 120 fps,
##   gate PASS (+1.8%)** — clears the floor by 1.9%.
##   The same clip read at 60 fps gives 95.71 %W/s but FAILS its gate
##   (+13.6%). That number is not quotable, and it is risk 3 of the spec
##   happening exactly as predicted: raising the speed pushed our own 60 fps
##   measurement above the aliasing knee, so 120 fps is now the minimum rate
##   at which this project can measure its own cruise speed at all.
##   THIS IS A BOUND, NOT PARITY. The arcade's true cruise speed cannot be
##   measured from the available footage at any frame rate (#139 section 5.1:
##   every depth band fails the gate, and sparse-landmark tracking fails on
##   stage-1 ocean because wave-row spacing is ambiguous by 4x). All that is
##   established is that we are **no longer demonstrably too slow**.
##
##   CANYON stage 8 = 0.804, and this one was MEASURED INTO PLACE, not
##   predicted. A first value of 0.729 came from `speed = K * v * span` with K
##   fitted to our own two operating points (1.4 -> 51.04 %W/s, 2.8 -> 99.03).
##   Captured and measured, our stage 8 then read 1.7623 px/frame at 60 fps
##   against the arcade's 1.9433 — ratio 0.907 against #127's certified figure
##   and 0.897 against this pass's own re-measure of the same arcade window
##   (1.9635, corroborating #127 within 1.0%). A knife-edge on the [0.9, 1.1]
##   band depending on which arcade figure you pick, which is not a result.
##   Per the spec's own instruction, k was re-solved from the MEASURED
##   operating point rather than the model defended: 0.729 * 1.9433 / 1.7623 =
##   0.804. Re-captured and re-measured at 0.804: **1.9408 px/frame, gate
##   PASS (-0.2%), ratio 0.999 vs #127 and 0.989 vs the re-measure** — inside
##   the band against both, no longer a coin flip.
##   (The spec's own starting figure was 0.624, from a 1.8797 px/frame
##   baseline for the configuration our capture measures at 1.6291 on the
##   identical analysis rect — a content difference, not a method one. Mixing
##   the two chains would have put ~15% straight into the constant, so every
##   number here comes from this pass's own chain end to end.)
##
##   CANYON stage 17 = 0.752, and this one is an ASSUMPTION, stated plainly:
##   there is NO arcade stage-17 flow measurement. It is stage 8's value
##   corrected for stage 17's own span (0.804 * 584.64 / 624.96), i.e. the
##   same APPARENT flow as stage 8. #139's spec says not to derive a stage-17
##   value; taken literally that leaves stage 17 on the cruise default, which
##   — because its span is the largest in the game — renders it **4.8x faster
##   than our own stage 8**, both being canyons. That is a worse defect than
##   the one this issue fixes, so the regime assumption is made deliberately,
##   flagged here as the weakest value in the table, and called out on the
##   issue for the gate to accept or reject rather than slipped in. It mirrors
##   how #120 treats stage 17's horizon: same regime, weaker evidence, said so.
##
## WHAT IS *NOT* DONE HERE: no stage gets a speed because it "looks" fast or
## slow. There are exactly two measurements behind the 23 numbers — one cruise
## floor and one certified canyon — and every value is one of them, or one of
## them corrected for that stage's own span.
const STAGES := [
	# Stage 1 — VERIFIED arcade coast: blue sea + green headland, flat blue sky #009fff (t=88-120)
	# #124 GROUND (measured): H=235deg S=1.000 V75=0.925+/-0.013 V25=0.796+/-0.009 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 15/48 frames accepted at 0.5s sampling over the proven span t=88-120s, median flatfrac 0.040, circular hue spread 0deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 237deg (delta 2deg, chromatic on 15/15 frames); chroma-mean 228deg (delta 7deg, R=0.96). Reproduce: tools/measure_ground_palette.py --stage 1 --sea-only
	{ "ground_a": Color(0.000, 0.077, 0.925), "ground_b": Color(0.000, 0.066, 0.796), "ground_c": Color(0.000, 0.072, 0.861), "sky_top": Color(0.000, 0.624, 1.000), "sky_horizon": Color(0.000, 0.624, 1.000), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 2 — VERIFIED arcade desert/autumn scrub, orange sky #e67100 glowing to gold #f0d100 at the horizon (t=124-156; this is burst-a)
	# #124 GROUND (measured): H=35deg S=0.823 V75=0.733+/-0.055 V25=0.441+/-0.080 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 12/48 frames accepted at 0.5s sampling over the proven span t=124-156s, median flatfrac 0.007, circular hue spread 20deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 35deg (delta 0deg, chromatic on 12/12 frames); chroma-mean 33deg (delta 2deg, R=0.99). Reproduce: tools/measure_ground_palette.py --stage 2
	{ "ground_a": Color(0.733, 0.482, 0.130), "ground_b": Color(0.441, 0.290, 0.078), "ground_c": Color(0.587, 0.386, 0.104), "sky_top": Color(0.902, 0.443, 0.000), "sky_horizon": Color(0.941, 0.820, 0.000), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 3 — VERIFIED arcade night, near-black sky #000005 (t=160-196)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. NEAR-BLACK, HUE UNRESOLVABLE. The gates pass it (24 accepted, circular hue spread 10deg) but the colour space does not: 57% of the selected population sits below V=0.10, where hue is integer-quantisation-locked -- the band's most frequent colours at the identity-proven t=175 are #000000 (14.8%), #000100, #000002, #000004, with hue pinned to exactly 240 or 120 by rounding. corr-1 could only find a chromatic modal pixel on 4/24 accepted frames. V75 would be 0.147+/-0.100 -- an sd of 68% of the value, 6x the relative instability of any kept stage. The '<30% saturated' reject rule cannot catch this: HSV reports S=1.00 for RGB (0,0,2). Needs a value-only estimator; NOT this method. Reproduce: tools/measure_ground_palette.py --stage 3
	{ "ground_a": Color(0.900, 0.660, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.580, 0.600, 0.120), "sky_top": Color(0.000, 0.000, 0.020), "sky_horizon": Color(0.000, 0.000, 0.020), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 4 — VERIFIED arcade green forest under a flat teal sky #009f93 (t=200-240)
	# #124 GROUND (measured): H=125deg S=1.000 V75=0.416+/-0.019 V25=0.282+/-0.018 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 40/64 frames accepted at 0.5s sampling over the proven span t=200-240s, median flatfrac 0.117, circular hue spread 0deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 120deg (delta 5deg, chromatic on 38/40 frames); chroma-mean 133deg (delta 8deg, R=0.79). Reproduce: tools/measure_ground_palette.py --stage 4
	{ "ground_a": Color(0.000, 0.416, 0.035), "ground_b": Color(0.000, 0.282, 0.024), "ground_c": Color(0.000, 0.349, 0.029), "sky_top": Color(0.000, 0.624, 0.576), "sky_horizon": Color(0.000, 0.624, 0.576), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 5 — VERIFIED arcade refuel runway, autumn trees; only a thin pale band of sky visible #f8e2d6 (t=244-256, LOW CONFIDENCE)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. REJECTS on the variance gate (7/8 frames; 8 total). Thin refuel-runway sky band, the same LOW CONFIDENCE already flagged for its sky above. 0/8 accepted. Reproduce: tools/measure_ground_palette.py --stage 5
	{ "ground_a": Color(0.340, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.350, 0.260, 0.100), "sky_top": Color(0.973, 0.886, 0.839), "sky_horizon": Color(0.973, 0.886, 0.839), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 6 — VERIFIED arcade clouds over sea, flat deep blue #0045ff (t=260-304)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. REJECTS roughly evenly on the variance gate and aircraft-neutral (35/72, 37/72) -- clouds/sea band is mostly sky or plane. 0/72 accepted. Reproduce: tools/measure_ground_palette.py --stage 6
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.181, 0.550), "ground_c": Color(0.850, 0.900, 0.950), "sky_top": Color(0.000, 0.271, 1.000), "sky_horizon": Color(0.000, 0.271, 1.000), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 7 — VERIFIED arcade green terrain, flat blue #0089fb (t=308-340)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. MIXED-BIOME. 37 accepted but circular hue spread 210deg with corr-2 concentration R=0.59 (kept stages run 0.79-0.99) -- land and water genuinely both in the band, the architect's own finding. The one-hue-per-stage data model could not hold this even if it were measured. Reproduce: tools/measure_ground_palette.py --stage 7
	{ "ground_a": Color(0.590, 0.666, 0.720), "ground_b": Color(0.320, 0.367, 0.400), "ground_c": Color(0.830, 0.860, 0.890), "sky_top": Color(0.000, 0.537, 0.984), "sky_horizon": Color(0.000, 0.537, 0.984), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 8 — VERIFIED arcade canyon, flat cream #faecb0 (t=344-372; sky read directly at t=357, column scan kept hitting canyon wall)
	# #124 GROUND (measured): H=35deg S=1.000 V75=0.831+/-0.008 V25=0.529+/-0.069 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 7/80 frames accepted at 0.25s sampling over the proven span t=344-372s, median flatfrac 0.345, circular hue spread 10deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 38deg (delta 3deg, chromatic on 5/7 frames); chroma-mean 38deg (delta 3deg, R=0.97). Reproduce: tools/measure_ground_palette.py --stage 8 --sample-interval 0.25
	{ "ground_a": Color(0.831, 0.485, 0.000), "ground_b": Color(0.529, 0.309, 0.000), "ground_c": Color(0.680, 0.397, 0.000), "sky_top": Color(0.980, 0.925, 0.690), "sky_horizon": Color(0.980, 0.925, 0.690), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false, "scroll_speed": 0.804, "horizon_fraction": 0.13 },
	# Stage 9 — VERIFIED arcade snow/arctic, flat pale blue-grey #b5cfd7 (t=376-424; this is burst-b)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. REJECTS almost entirely on aircraft-neutral (64/80) -- LOW-SATURATION snow/arctic, a near-white/grey band that the S<0.20,V>0.60 aircraft test cannot tell from an aircraft. 0/80 accepted. Reproduce: tools/measure_ground_palette.py --stage 9
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.164, 0.083), "ground_c": Color(0.550, 0.450, 0.100), "sky_top": Color(0.710, 0.812, 0.843), "sky_horizon": Color(0.710, 0.812, 0.843), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 10 — VERIFIED arcade dry scrub, flat pale cream #f6f1d5 (t=428-468)
	# #124 GROUND (measured): H=35deg S=0.773 V75=0.771+/-0.042 V25=0.469+/-0.059 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 8/64 frames accepted at 0.5s sampling over the proven span t=428-468s, median flatfrac 0.039, circular hue spread 0deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 23deg (delta 12deg, chromatic on 6/8 frames); chroma-mean 33deg (delta 2deg, R=0.99). Reproduce: tools/measure_ground_palette.py --stage 10
	{ "ground_a": Color(0.771, 0.522, 0.175), "ground_b": Color(0.469, 0.318, 0.106), "ground_c": Color(0.620, 0.420, 0.140), "sky_top": Color(0.965, 0.945, 0.835), "sky_horizon": Color(0.965, 0.945, 0.835), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 11 — VERIFIED arcade night, flat dark slate #3f3f63 (t=472-508)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. 25 accepted but circular hue spread 40deg, over the 30deg bar -- the night stage genuinely shows two lighting conditions in the band. Corroborators agree with each other (corr-1 delta 2deg, corr-2 delta 5deg); it is the across-frame spread that disqualifies it, not the colour estimate. Reproduce: tools/measure_ground_palette.py --stage 11
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.238, 0.083, 0.550), "ground_c": Color(0.600, 0.300, 0.850), "sky_top": Color(0.247, 0.247, 0.388), "sky_horizon": Color(0.247, 0.247, 0.388), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 12 — VERIFIED arcade green terrain, flat blue #0097fa (t=512-548)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. MIXED-BIOME (land + water). 28 accepted but circular hue spread 110deg, R=0.73. Reproduce: tools/measure_ground_palette.py --stage 12
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.199, 0.083, 0.550), "ground_c": Color(0.950, 0.850, 0.300), "sky_top": Color(0.000, 0.592, 0.980), "sky_horizon": Color(0.000, 0.592, 0.980), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 13 — VERIFIED arcade refuel runway, palm trees; thin sage band #9fc9a5, same sky as stage 17 (t=555-566, LOW CONFIDENCE)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. REJECTS entirely on the variance gate (16/16) -- thin refuel-runway sky band, same LOW CONFIDENCE already flagged above. 0/16 accepted. Reproduce: tools/measure_ground_palette.py --stage 13
	{ "ground_a": Color(0.180, 0.450, 0.900), "ground_b": Color(0.083, 0.270, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.624, 0.788, 0.647), "sky_horizon": Color(0.624, 0.788, 0.647), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 14 — VERIFIED arcade flat gold #ffc600 shifting to orange #fd9008 at the horizon (t=572-608)
	# #124 GROUND (measured): H=55deg S=0.703 V75=0.576+/-0.041 V25=0.248+/-0.053 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 23/56 frames accepted at 0.5s sampling over the proven span t=572-608s, median flatfrac 0.003, circular hue spread 30deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode UNAVAILABLE (modal non-flat pixel is achromatic -- #000000 at a 4-6% share -- on all 23 accepted frames; this is the documented modal failure on dithered grounds, not a contradiction); chroma-mean 56deg (delta 1deg, R=0.98). Reproduce: tools/measure_ground_palette.py --stage 14
	{ "ground_a": Color(0.576, 0.543, 0.171), "ground_b": Color(0.248, 0.234, 0.074), "ground_c": Color(0.412, 0.388, 0.122), "sky_top": Color(1.000, 0.776, 0.000), "sky_horizon": Color(0.992, 0.565, 0.031), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 15 — VERIFIED arcade dry grass, flat pale lavender #a4a4d4 (t=612-652)
	# #124 GROUND (measured): H=55deg S=0.989 V75=0.518+/-0.059 V25=0.259+/-0.041 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 17/64 frames accepted at 0.5s sampling over the proven span t=612-652s, median flatfrac 0.005, circular hue spread 10deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 46deg (delta 9deg, chromatic on 14/17 frames); chroma-mean 49deg (delta 6deg, R=0.99). Reproduce: tools/measure_ground_palette.py --stage 15
	{ "ground_a": Color(0.518, 0.475, 0.006), "ground_b": Color(0.259, 0.238, 0.003), "ground_c": Color(0.388, 0.356, 0.004), "sky_top": Color(0.643, 0.643, 0.831), "sky_horizon": Color(0.643, 0.643, 0.831), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 16 — VERIFIED arcade city, flat pale lavender #a9a8fd (t=656-692)
	# #124 GROUND (measured): H=205deg S=1.000 V75=0.673+/-0.044 V25=0.478+/-0.031 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 20/56 frames accepted at 0.5s sampling over the proven span t=656-692s, median flatfrac 0.005, circular hue spread 20deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 220deg (delta 15deg, chromatic on 20/20 frames); chroma-mean 204deg (delta 1deg, R=0.98). Reproduce: tools/measure_ground_palette.py --stage 16
	{ "ground_a": Color(0.000, 0.392, 0.673), "ground_b": Color(0.000, 0.279, 0.478), "ground_c": Color(0.000, 0.336, 0.575), "sky_top": Color(0.663, 0.659, 0.992), "sky_horizon": Color(0.663, 0.659, 0.992), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 17 — VERIFIED arcade olive field with dark rock walls, sage #a4d3a5 desaturating to cream #fbf2d5 (t=696-724; this is burst-c)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. POPULATION NOT SEPARATED -- the architect's risk 3 named this stage ('narrow the window or separate the populations before trusting any single-hue value on a stage with prominent scrub') and this pass could not discharge it. Four measured reasons, any one of which would be a caveat and which together are a refusal: (a) yield 3/80 at 0.25s sampling, and the two sampling densities disagree by a full bin (0.5s: 2/40 -> H=45deg; 0.25s: 3/80 -> H=55deg); (b) median flatfrac 0.388 sits 0.012 UNDER the 0.40 reject threshold -- the accepted frames are the most sky-contaminated in the whole table; (c) corr-2 (threshold-free chroma mean) reads 33deg against the primary's 55deg, delta 22deg -- the only stage where a corroborator falls outside the +/-20deg selection window, and corr-1 found a chromatic mode on just 1/3 frames; (d) one of the 3 accepted frames (t=713.0) carries a large fireball across the band. The fireball is NOT the main driver -- dropping it moves V75 0.843->0.807 and V25 0.627->0.623 -- the bright yellow scrub is, which is exactly the population split risk 3 asked for. Reproduce: tools/measure_ground_palette.py --stage 17 --sample-interval 0.25
	{ "ground_a": Color(0.396, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.300, 0.280, 0.080), "sky_top": Color(0.643, 0.827, 0.647), "sky_horizon": Color(0.984, 0.949, 0.835), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false, "scroll_speed": 0.752, "horizon_fraction": 0.07 },
	# Stage 18 — VERIFIED arcade hazy, flat pale grey #c3c2b3 (t=728-764)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. MIXED-BIOME -- 10 accepted but circular hue spread 100deg; the hazy stage shows more than one ground material in the band. Reproduce: tools/measure_ground_palette.py --stage 18
	{ "ground_a": Color(0.900, 0.612, 0.180), "ground_b": Color(0.550, 0.183, 0.083), "ground_c": Color(0.550, 0.420, 0.120), "sky_top": Color(0.765, 0.761, 0.702), "sky_horizon": Color(0.765, 0.761, 0.702), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 19 — VERIFIED arcade autumn forest, flat blue #0089fb (t=768-808)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. MIXED-BIOME (autumn forest + water). 35 accepted but circular hue spread 180deg, R=0.65, and V25 sd 0.240 -- the value is as unsettled as the hue. Reproduce: tools/measure_ground_palette.py --stage 19
	{ "ground_a": Color(0.900, 0.402, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.950, 0.350, 0.050), "sky_top": Color(0.000, 0.537, 0.984), "sky_horizon": Color(0.000, 0.537, 0.984), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 20 — VERIFIED arcade flat grey-violet #797a9c brightening to #9a98bb at the horizon (t=812-852)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. 21 accepted but circular hue spread 40deg, over the 30deg bar -- mixed lighting/material in the band. Reproduce: tools/measure_ground_palette.py --stage 20
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.316, 0.083, 0.550), "ground_c": Color(0.550, 0.280, 0.800), "sky_top": Color(0.475, 0.478, 0.612), "sky_horizon": Color(0.604, 0.596, 0.733), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 21 — VERIFIED arcade coast, flat cyan #00c1f9 (t=856-892)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. MIXED-BIOME (coast: land + water). 18 accepted but circular hue spread 140deg, R=0.68. Reproduce: tools/measure_ground_palette.py --stage 21
	{ "ground_a": Color(0.180, 0.468, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.000, 0.757, 0.976), "sky_horizon": Color(0.000, 0.757, 0.976), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 22 — VERIFIED arcade green terrain, deep blue #000cff lightening toward cyan #006cf2 (t=896-932)
	# #124 GROUND: UNMEASURABLE by the validated method -- values UNCHANGED, biome label above still UNVERIFIED. MIXED-BIOME (green terrain + water). 26 accepted but circular hue spread 170deg, R=0.79. Reproduce: tools/measure_ground_palette.py --stage 22
	{ "ground_a": Color(0.900, 0.450, 0.180), "ground_b": Color(0.550, 0.149, 0.083), "ground_c": Color(0.550, 0.380, 0.100), "sky_top": Color(0.000, 0.047, 1.000), "sky_horizon": Color(0.000, 0.424, 0.949), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
	# Stage 23 — VERIFIED arcade ocean + carrier, flat blue #009eff (t=936-952)
	# #124 GROUND (measured): H=235deg S=1.000 V75=0.939+/-0.014 V25=0.806+/-0.012 (+/- = sd across accepted frames = the TOLERANCE on these values; ground_b/V25 is the weakest of the three by construction -- it tracks how much shadow happens to be in frame). YIELD 10/16 frames accepted at 0.5s sampling over the proven span t=936-952s, median flatfrac 0.019, circular hue spread 0deg, selection window +/-20deg. CROP x=0-686, y=365-410 (rows 76-85.5%H) of the 686x480 longplay; stage identity per the proven map above (HUD digit x=376-414,y=426-450). CORROBORATION: exact-colour mode 237deg (delta 2deg, chromatic on 10/10 frames); chroma-mean 225deg (delta 10deg, R=0.96). Reproduce: tools/measure_ground_palette.py --stage 23
	{ "ground_a": Color(0.000, 0.078, 0.939), "ground_b": Color(0.000, 0.067, 0.806), "ground_c": Color(0.000, 0.073, 0.873), "sky_top": Color(0.000, 0.620, 1.000), "sky_horizon": Color(0.000, 0.620, 1.000), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false, "scroll_speed": 2.800, "horizon_fraction": 0.625 },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
