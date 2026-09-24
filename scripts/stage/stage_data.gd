extends RefCounted

## Stage definitions for After Burner's 23 stages.
## Each stage defines ground/sky colors, enemy difficulty, and whether it's a bonus stage.

## Color values are hue-preserved from the original palette but re-graded in HSV
## (#108): ground_a/sky_horizon target S~0.8 V~0.9, ground_b S~0.85 V~0.55.
## AB2's arcade frames are vivid and bright even in shadow and at night — a
## literal near-black "night" reads as washed-out on our renderer's measured
## saturation/value, not moody, so hue carries the "night" identity instead
## of darkness. See #108 for the measured targets.
##
## sky_top/sky_horizon are now taken directly from the reference rather than
## derived from ground_a (#115). Method: median colour of the sky band in all
## 50 frames of assets/reference/motion/ab2-longplay, plus fine per-scanline
## column scans through the horizon on one frame per biome. Two findings
## overturned the previous rule that "sky_top and sky_horizon share the same
## hue":
##
## 1. Whether a stage has a horizon glow AT ALL is per-biome, not universal.
##    Snow (burst-b-08) holds #b7d3d6 and blue day (stage-12) holds #0092f7
##    pixel-identical from the top of frame right down to the ground. Those
##    stages get sky_top == sky_horizon here, and _draw_sky() renders them as a
##    single flat fill. Desert (burst-a-02) and the olive/green stage
##    (burst-c-02) do glow, over the final ~20% of sky height only.
##
## 2. Where a glow exists it is a HUE shift at constant saturation, not a
##    brightness ramp: desert runs 29deg -> 52deg (#e67100 -> #f0d100) with
##    S pinned at 1.00 and V only 0.90 -> 0.98. The previous data gave every
##    stage's sky_top and sky_horizon the same hue and differed them by ~0.05 V,
##    so the glow was invisible and the whole sky sat at the horizon's gold hue
##    (stage 1 was H=37 S=0.93 end to end). Against a gold/tan desert ground
##    that left nothing separating sky from ground — the literal complaint on
##    #115. sky_top is the deep base hue; sky_horizon is the glow.
##
## Measured per-biome sky, HSV, for anyone re-grading these:
##   desert    (29, 1.00, 0.90) -> (52, 1.00, 0.98)
##   sunset    (16, 1.00, 0.86) -> (40, 1.00, 0.98)
##   volcanic  (10, 1.00, 0.82) -> (38, 1.00, 0.98)
##   forest   (121, 0.22, 0.83) -> (46, 0.15, 0.98)
##   blue day (202, 1.00, 0.96)    flat
##   teal sea (169, 1.00, 0.70)    flat
##   snow/ice (185, 0.15, 0.84)    flat
##   night    (240, 0.34, 0.42)    flat
##   yellow    (51, 1.00, 0.97)    flat
## Stage-to-stage variation is a few degrees of hue / a few points of V around
## those anchors, so neighbouring stages in the same biome stay distinguishable.
##
## Mountain (7, 8) GROUND stays desaturated slate-grey (S~0.15-0.20) — an
## earlier pass had turned achromatic rock blue to hit a flat saturation floor
## that no longer applies; rock reads as grey, not a vivid color, so it should
## measure grey. Their SKY is the pale snow-haze anchor above, which the
## reference's snowy mountain frames (burst-b-*) measure at S=0.14-0.15.
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
## The ocean-family stages (6, 15, 23) split into two distinct reference skies
## rather than sharing one (#115): stage-08/stage-12 measure a vivid mid-blue
## #00a2f5 / #0092f7 (H~202-205, S=1.00) and stage-03 measures a deeper cyan-
## teal #00b292 (H=169, S=1.00, V=0.70). 6 and 23 take the blue, 15 takes the
## teal — ground_a/b for these stages are untouched, only the sky.
const STAGES := [
	# Stage 1: Desert - warm sand vs dark brown, olive scrub accent restored (#42 round-6 gate; After Burner II opens over desert)
	{ "ground_a": Color(0.900, 0.632, 0.180), "ground_b": Color(0.550, 0.345, 0.083), "ground_c": Color(0.550, 0.550, 0.100), "sky_top": Color(0.900, 0.435, 0.000), "sky_horizon": Color(0.980, 0.849, 0.000), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 2: Desert - richer orange sand vs dark sienna, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.597, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.540, 0.520, 0.095), "sky_top": Color(0.900, 0.390, 0.000), "sky_horizon": Color(0.980, 0.817, 0.000), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 3: Desert - bright tan vs dark brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.660, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.580, 0.600, 0.120), "sky_top": Color(0.910, 0.485, 0.000), "sky_horizon": Color(0.980, 0.882, 0.000), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 4: Desert - reddish sand vs dark brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.520, 0.480, 0.090), "sky_top": Color(0.890, 0.326, 0.000), "sky_horizon": Color(0.970, 0.776, 0.000), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 5: Forest - bright green vs dark green, dark soil accent
	{ "ground_a": Color(0.340, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.350, 0.260, 0.100), "sky_top": Color(0.647, 0.830, 0.650), "sky_horizon": Color(0.980, 0.946, 0.833), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 6: BONUS - Ocean flyover, white foam/whitecap accent; sky recoloured to vivid cyan (#42 round-6 gate finding #8)
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.181, 0.550), "ground_c": Color(0.850, 0.900, 0.950), "sky_top": Color(0.000, 0.608, 0.960), "sky_horizon": Color(0.000, 0.608, 0.960), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 7: Mountain - slate-grey rock, low saturation, pale snow-fleck accent (rock reads as grey, not a vivid color)
	{ "ground_a": Color(0.590, 0.666, 0.720), "ground_b": Color(0.320, 0.367, 0.400), "ground_c": Color(0.830, 0.860, 0.890), "sky_top": Color(0.714, 0.827, 0.840), "sky_horizon": Color(0.714, 0.827, 0.840), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 8: Mountain - slate-grey rock, low saturation, pale snow-fleck accent (rock reads as grey, not a vivid color)
	{ "ground_a": Color(0.590, 0.677, 0.720), "ground_b": Color(0.320, 0.373, 0.400), "ground_c": Color(0.830, 0.870, 0.890), "sky_top": Color(0.714, 0.827, 0.850), "sky_horizon": Color(0.714, 0.827, 0.850), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 9: Sunset - bright orange vs dark red-brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.164, 0.083), "ground_c": Color(0.550, 0.450, 0.100), "sky_top": Color(0.860, 0.229, 0.000), "sky_horizon": Color(0.980, 0.653, 0.000), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 10: Sunset - deep orange vs dark maroon, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.526, 0.180), "ground_b": Color(0.550, 0.160, 0.083), "ground_c": Color(0.550, 0.400, 0.100), "sky_top": Color(0.840, 0.168, 0.000), "sky_horizon": Color(0.980, 0.588, 0.000), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 11: Night - vivid purple vs deep violet, brighter violet fleck accent (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.238, 0.083, 0.550), "ground_c": Color(0.600, 0.300, 0.850), "sky_top": Color(0.277, 0.277, 0.420), "sky_horizon": Color(0.277, 0.277, 0.420), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 12: BONUS - Night city lights, warm window-light accent
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.199, 0.083, 0.550), "ground_c": Color(0.950, 0.850, 0.300), "sky_top": Color(0.355, 0.343, 0.520), "sky_horizon": Color(0.355, 0.343, 0.520), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 13: Arctic - white vs medium blue, pale ice-crack accent
	{ "ground_a": Color(0.180, 0.450, 0.900), "ground_b": Color(0.083, 0.270, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.714, 0.832, 0.840), "sky_horizon": Color(0.714, 0.832, 0.840), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 14: Arctic - bright ice vs deep blue, pale ice-crack accent
	{ "ground_a": Color(0.180, 0.480, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.800, 0.950), "sky_top": Color(0.740, 0.844, 0.860), "sky_horizon": Color(0.740, 0.844, 0.860), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 15: Ocean - bright cyan vs dark teal, white foam accent; sky recoloured to vivid cyan (#42 round-6 gate finding #8)
	{ "ground_a": Color(0.180, 0.746, 0.900), "ground_b": Color(0.083, 0.355, 0.550), "ground_c": Color(0.850, 0.950, 0.950), "sky_top": Color(0.000, 0.700, 0.572), "sky_horizon": Color(0.000, 0.700, 0.572), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 16: Desert - bright white sand vs dark amber, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.792, 0.180), "ground_b": Color(0.550, 0.342, 0.083), "ground_c": Color(0.600, 0.620, 0.120), "sky_top": Color(0.970, 0.825, 0.000), "sky_horizon": Color(0.970, 0.825, 0.000), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 17: Forest - bright lime vs very dark green, dark soil accent
	{ "ground_a": Color(0.396, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.300, 0.280, 0.080), "sky_top": Color(0.633, 0.820, 0.623), "sky_horizon": Color(0.980, 0.949, 0.823), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 18: BONUS - Sunset paradise, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.612, 0.180), "ground_b": Color(0.550, 0.183, 0.083), "ground_c": Color(0.550, 0.420, 0.120), "sky_top": Color(0.880, 0.293, 0.000), "sky_horizon": Color(0.980, 0.719, 0.000), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 19: Volcanic - bright red-brown vs dark char, glowing ember accent
	{ "ground_a": Color(0.900, 0.402, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.950, 0.350, 0.050), "sky_top": Color(0.820, 0.137, 0.000), "sky_horizon": Color(0.980, 0.621, 0.000), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 20: Night - vivid blue-purple vs deep violet, brighter violet fleck accent (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.316, 0.083, 0.550), "ground_c": Color(0.550, 0.280, 0.800), "sky_top": Color(0.256, 0.266, 0.400), "sky_horizon": Color(0.256, 0.266, 0.400), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 21: Arctic - blizzard white vs steel blue, pale ice-crack accent
	{ "ground_a": Color(0.180, 0.468, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.757, 0.859, 0.870), "sky_horizon": Color(0.757, 0.859, 0.870), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 22: Sunset - bright orange vs dark red-brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.450, 0.180), "ground_b": Color(0.550, 0.149, 0.083), "ground_c": Color(0.550, 0.380, 0.100), "sky_top": Color(0.850, 0.198, 0.000), "sky_horizon": Color(0.980, 0.621, 0.000), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 23: Final - bright ocean blue vs near-black deep, white foam accent; sky recoloured to vivid cyan (#42 round-6 gate finding #8)
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.210, 0.550), "ground_c": Color(0.850, 0.900, 0.980), "sky_top": Color(0.000, 0.566, 0.970), "sky_horizon": Color(0.000, 0.566, 0.970), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
