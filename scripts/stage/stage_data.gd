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
## GROUND colours are NOT yet verified against stage identity — they still carry
## the biome labels from #42/#108, which were assigned the same unverified way
## the skies were. The audit found real mismatches: the arcade's stage 1 is a
## coastal run over blue sea and green headland, but ours is labelled and
## coloured as desert. Fixing that means re-deriving ground_a/b/c against the
## verified spans above, which is a different subsystem (#42's terrain shader)
## and is deliberately left out of #123 rather than changed silently. Treat
## every "Stage N: <biome>" label below as unverified until that happens.
##
## ground_c: a third ground color for the terrain shader's material-cluster
## blend (see ground_terrain_2d.gdshader). Round-5 gate (#42) zeroed this out
## for desert/sunset (set equal to ground_a — a no-op) on a single-frame
## measurement claiming 0% olive presence. Round-6 gate re-examined a zoomed
## crop of burst-a-02/03 directly and found that claim was wrong: the
## reference clearly shows golden/olive scrub texture patches next to grey
## stone and reddish rock, not a flat two-tone field — the round-5 measurement
## must have sampled a region/threshold that missed it. Restored to the
## original distinct olive value here; the shader's round-6 patch/cluster
## system (grey stone + base rock + this accent + a derived pink) is what
## actually needs >=3 hue clusters per band to pass "shape regularity",
## so a no-op ground_c on desert/sunset would silently cap it at 2.
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
const STAGES := [
	# Stage 1 — VERIFIED arcade coast: blue sea + green headland, flat blue sky #009fff (t=88-120)
	{ "ground_a": Color(0.900, 0.632, 0.180), "ground_b": Color(0.550, 0.345, 0.083), "ground_c": Color(0.550, 0.550, 0.100), "sky_top": Color(0.000, 0.624, 1.000), "sky_horizon": Color(0.000, 0.624, 1.000), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 2 — VERIFIED arcade desert/autumn scrub, orange sky #e67100 glowing to gold #f0d100 at the horizon (t=124-156; this is burst-a)
	{ "ground_a": Color(0.900, 0.597, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.540, 0.520, 0.095), "sky_top": Color(0.902, 0.443, 0.000), "sky_horizon": Color(0.941, 0.820, 0.000), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 3 — VERIFIED arcade night, near-black sky #000005 (t=160-196)
	{ "ground_a": Color(0.900, 0.660, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.580, 0.600, 0.120), "sky_top": Color(0.000, 0.000, 0.020), "sky_horizon": Color(0.000, 0.000, 0.020), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 4 — VERIFIED arcade green forest under a flat teal sky #009f93 (t=200-240)
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.520, 0.480, 0.090), "sky_top": Color(0.000, 0.624, 0.576), "sky_horizon": Color(0.000, 0.624, 0.576), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 5 — VERIFIED arcade refuel runway, autumn trees; only a thin pale band of sky visible #f8e2d6 (t=244-256, LOW CONFIDENCE)
	{ "ground_a": Color(0.340, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.350, 0.260, 0.100), "sky_top": Color(0.973, 0.886, 0.839), "sky_horizon": Color(0.973, 0.886, 0.839), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 6 — VERIFIED arcade clouds over sea, flat deep blue #0045ff (t=260-304)
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.181, 0.550), "ground_c": Color(0.850, 0.900, 0.950), "sky_top": Color(0.000, 0.271, 1.000), "sky_horizon": Color(0.000, 0.271, 1.000), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true, "horizon_fraction": 0.625 },
	# Stage 7 — VERIFIED arcade green terrain, flat blue #0089fb (t=308-340)
	{ "ground_a": Color(0.590, 0.666, 0.720), "ground_b": Color(0.320, 0.367, 0.400), "ground_c": Color(0.830, 0.860, 0.890), "sky_top": Color(0.000, 0.537, 0.984), "sky_horizon": Color(0.000, 0.537, 0.984), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 8 — VERIFIED arcade canyon, flat cream #faecb0 (t=344-372; sky read directly at t=357, column scan kept hitting canyon wall)
	{ "ground_a": Color(0.590, 0.677, 0.720), "ground_b": Color(0.320, 0.373, 0.400), "ground_c": Color(0.830, 0.870, 0.890), "sky_top": Color(0.980, 0.925, 0.690), "sky_horizon": Color(0.980, 0.925, 0.690), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false, "horizon_fraction": 0.13 },
	# Stage 9 — VERIFIED arcade snow/arctic, flat pale blue-grey #b5cfd7 (t=376-424; this is burst-b)
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.164, 0.083), "ground_c": Color(0.550, 0.450, 0.100), "sky_top": Color(0.710, 0.812, 0.843), "sky_horizon": Color(0.710, 0.812, 0.843), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 10 — VERIFIED arcade dry scrub, flat pale cream #f6f1d5 (t=428-468)
	{ "ground_a": Color(0.900, 0.526, 0.180), "ground_b": Color(0.550, 0.160, 0.083), "ground_c": Color(0.550, 0.400, 0.100), "sky_top": Color(0.965, 0.945, 0.835), "sky_horizon": Color(0.965, 0.945, 0.835), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 11 — VERIFIED arcade night, flat dark slate #3f3f63 (t=472-508)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.238, 0.083, 0.550), "ground_c": Color(0.600, 0.300, 0.850), "sky_top": Color(0.247, 0.247, 0.388), "sky_horizon": Color(0.247, 0.247, 0.388), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 12 — VERIFIED arcade green terrain, flat blue #0097fa (t=512-548)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.199, 0.083, 0.550), "ground_c": Color(0.950, 0.850, 0.300), "sky_top": Color(0.000, 0.592, 0.980), "sky_horizon": Color(0.000, 0.592, 0.980), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true, "horizon_fraction": 0.625 },
	# Stage 13 — VERIFIED arcade refuel runway, palm trees; thin sage band #9fc9a5, same sky as stage 17 (t=555-566, LOW CONFIDENCE)
	{ "ground_a": Color(0.180, 0.450, 0.900), "ground_b": Color(0.083, 0.270, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.624, 0.788, 0.647), "sky_horizon": Color(0.624, 0.788, 0.647), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 14 — VERIFIED arcade flat gold #ffc600 shifting to orange #fd9008 at the horizon (t=572-608)
	{ "ground_a": Color(0.180, 0.480, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.800, 0.950), "sky_top": Color(1.000, 0.776, 0.000), "sky_horizon": Color(0.992, 0.565, 0.031), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 15 — VERIFIED arcade dry grass, flat pale lavender #a4a4d4 (t=612-652)
	{ "ground_a": Color(0.180, 0.746, 0.900), "ground_b": Color(0.083, 0.355, 0.550), "ground_c": Color(0.850, 0.950, 0.950), "sky_top": Color(0.643, 0.643, 0.831), "sky_horizon": Color(0.643, 0.643, 0.831), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 16 — VERIFIED arcade city, flat pale lavender #a9a8fd (t=656-692)
	{ "ground_a": Color(0.900, 0.792, 0.180), "ground_b": Color(0.550, 0.342, 0.083), "ground_c": Color(0.600, 0.620, 0.120), "sky_top": Color(0.663, 0.659, 0.992), "sky_horizon": Color(0.663, 0.659, 0.992), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 17 — VERIFIED arcade olive field with dark rock walls, sage #a4d3a5 desaturating to cream #fbf2d5 (t=696-724; this is burst-c)
	{ "ground_a": Color(0.396, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.300, 0.280, 0.080), "sky_top": Color(0.643, 0.827, 0.647), "sky_horizon": Color(0.984, 0.949, 0.835), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false, "horizon_fraction": 0.07 },
	# Stage 18 — VERIFIED arcade hazy, flat pale grey #c3c2b3 (t=728-764)
	{ "ground_a": Color(0.900, 0.612, 0.180), "ground_b": Color(0.550, 0.183, 0.083), "ground_c": Color(0.550, 0.420, 0.120), "sky_top": Color(0.765, 0.761, 0.702), "sky_horizon": Color(0.765, 0.761, 0.702), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true, "horizon_fraction": 0.625 },
	# Stage 19 — VERIFIED arcade autumn forest, flat blue #0089fb (t=768-808)
	{ "ground_a": Color(0.900, 0.402, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.950, 0.350, 0.050), "sky_top": Color(0.000, 0.537, 0.984), "sky_horizon": Color(0.000, 0.537, 0.984), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 20 — VERIFIED arcade flat grey-violet #797a9c brightening to #9a98bb at the horizon (t=812-852)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.316, 0.083, 0.550), "ground_c": Color(0.550, 0.280, 0.800), "sky_top": Color(0.475, 0.478, 0.612), "sky_horizon": Color(0.604, 0.596, 0.733), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 21 — VERIFIED arcade coast, flat cyan #00c1f9 (t=856-892)
	{ "ground_a": Color(0.180, 0.468, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.000, 0.757, 0.976), "sky_horizon": Color(0.000, 0.757, 0.976), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 22 — VERIFIED arcade green terrain, deep blue #000cff lightening toward cyan #006cf2 (t=896-932)
	{ "ground_a": Color(0.900, 0.450, 0.180), "ground_b": Color(0.550, 0.149, 0.083), "ground_c": Color(0.550, 0.380, 0.100), "sky_top": Color(0.000, 0.047, 1.000), "sky_horizon": Color(0.000, 0.424, 0.949), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false, "horizon_fraction": 0.625 },
	# Stage 23 — VERIFIED arcade ocean + carrier, flat blue #009eff (t=936-952)
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.210, 0.550), "ground_c": Color(0.850, 0.900, 0.980), "sky_top": Color(0.000, 0.620, 1.000), "sky_horizon": Color(0.000, 0.620, 1.000), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false, "horizon_fraction": 0.625 },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
