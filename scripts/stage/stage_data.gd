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
## sky_top/sky_horizon share the SAME hue per stage (derived from ground_a,
## except mountain — see below). Earlier data gave sky_top an unrelated blue
## hue (~240) while sky_horizon carried the stage's warm hue; lerping between
## near-complementary hues passes through a desaturated grey band in the
## middle of the gradient, which is what tanked the measured sky saturation
## (0.379 full-sky mean vs reference ~0.90-0.99 for warm stages). Saturation
## target is stage-relative, not a flat floor: warm stages (desert/sunset/
## volcanic) measure S~0.85-0.95 in the references; arctic measures
## S~0.10-0.15 (near-white haze); mountain/night stay moderate.
##
## sky_top must be CLOSE to sky_horizon in value/saturation, not a darker
## "zenith" tone (#108 sky follow-up). Pixel-sampled 3 independent reference
## frames (burst-a-02/03, ab2-arcade-desert.png), each at 10+ heights, two
## methods (single column, median-of-row): every one shows the sky is FLAT —
## same RGB from the top of frame down to ~70-75% of sky height — then
## brightens (V 0.90->0.95-0.98, slight hue warm-shift) only in the final
## ~25-30% before the horizon. There is no continuous zenith->horizon darkening
## ramp; a previous version of this comment claimed one ("darker/richer at the
## zenith") without having sampled for it, and that assumption is what put
## sky_top's V at ~0.75 vs sky_horizon's ~0.90-0.95 — a gap the reference
## doesn't have. _draw_sky()'s smoothstep(0.75, 1.0) already reproduces the
## flat-then-brighten SHAPE correctly; the bug was purely in these endpoint
## values. Every sky_top below is now S/V-matched close to its sky_horizon
## (S ~50% of the way, V ~75% of the way), hue untouched.
##
## Mountain (7, 8) ground/sky were desaturated back toward slate-grey
## (S~0.15-0.20) — an earlier pass had turned achromatic rock blue to hit a
## flat saturation floor that no longer applies; rock reads as grey, not a
## vivid color, so it should measure grey.
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
## sky_top/sky_horizon for the ocean-family stages (6, 15, 23) were
## re-measured at round-6 gate: their hue (~193-210deg here) reads as pale
## steel blue at S=0.37-0.40 against AB2's coastal sky reference, a pure
## vivid cyan at RGB(0,174,254) = hue~199deg, S=1.00, V=0.996. Re-derived
## below at hue 199deg with S/V pushed to 1.0/0.98 (horizon) and 0.82/0.90
## (top, per the existing "close to horizon, not a darker zenith" rule
## above) — ground_a/b for these stages are untouched, only the sky.
const STAGES := [
	# Stage 1: Desert - warm sand vs dark brown, olive scrub accent restored (#42 round-6 gate; After Burner II opens over desert)
	{ "ground_a": Color(0.900, 0.632, 0.180), "ground_b": Color(0.550, 0.345, 0.083), "ground_c": Color(0.550, 0.550, 0.100), "sky_top": Color(0.900, 0.587, 0.059), "sky_horizon": Color(0.950, 0.607, 0.029), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 2: Desert - richer orange sand vs dark sienna, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.597, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.540, 0.520, 0.095), "sky_top": Color(0.900, 0.546, 0.059), "sky_horizon": Color(0.950, 0.562, 0.029), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 3: Desert - bright tan vs dark brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.660, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "ground_c": Color(0.580, 0.600, 0.120), "sky_top": Color(0.900, 0.620, 0.059), "sky_horizon": Color(0.950, 0.643, 0.029), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 4: Desert - reddish sand vs dark brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.520, 0.480, 0.090), "sky_top": Color(0.900, 0.480, 0.059), "sky_horizon": Color(0.950, 0.489, 0.029), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 5: Forest - bright green vs dark green, dark soil accent
	{ "ground_a": Color(0.340, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.350, 0.260, 0.100), "sky_top": Color(0.529, 0.812, 0.447), "sky_horizon": Color(0.655, 0.900, 0.585), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 6: BONUS - Ocean flyover, white foam/whitecap accent; sky recoloured to vivid cyan (#42 round-6 gate finding #8)
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.181, 0.550), "ground_c": Color(0.850, 0.900, 0.950), "sky_top": Color(0.162, 0.666, 0.900), "sky_horizon": Color(0.000, 0.670, 0.980), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 7: Mountain - slate-grey rock, low saturation, pale snow-fleck accent (rock reads as grey, not a vivid color)
	{ "ground_a": Color(0.590, 0.666, 0.720), "ground_b": Color(0.320, 0.367, 0.400), "ground_c": Color(0.830, 0.860, 0.890), "sky_top": Color(0.671, 0.732, 0.775), "sky_horizon": Color(0.748, 0.807, 0.850), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 8: Mountain - slate-grey rock, low saturation, pale snow-fleck accent (rock reads as grey, not a vivid color)
	{ "ground_a": Color(0.590, 0.677, 0.720), "ground_b": Color(0.320, 0.373, 0.400), "ground_c": Color(0.830, 0.870, 0.890), "sky_top": Color(0.671, 0.739, 0.775), "sky_horizon": Color(0.748, 0.816, 0.850), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 9: Sunset - bright orange vs dark red-brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.164, 0.083), "ground_c": Color(0.550, 0.450, 0.100), "sky_top": Color(0.835, 0.458, 0.083), "sky_horizon": Color(0.920, 0.483, 0.046), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 10: Sunset - deep orange vs dark maroon, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.526, 0.180), "ground_b": Color(0.550, 0.160, 0.083), "ground_c": Color(0.550, 0.400, 0.100), "sky_top": Color(0.835, 0.445, 0.083), "sky_horizon": Color(0.920, 0.466, 0.046), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 11: Night - vivid purple vs deep violet, brighter violet fleck accent (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.238, 0.083, 0.550), "ground_c": Color(0.600, 0.300, 0.850), "sky_top": Color(0.244, 0.168, 0.395), "sky_horizon": Color(0.252, 0.168, 0.420), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 12: BONUS - Night city lights, warm window-light accent
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.199, 0.083, 0.550), "ground_c": Color(0.950, 0.850, 0.300), "sky_top": Color(0.312, 0.221, 0.493), "sky_horizon": Color(0.348, 0.247, 0.550), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 13: Arctic - white vs medium blue, pale ice-crack accent
	{ "ground_a": Color(0.180, 0.450, 0.900), "ground_b": Color(0.083, 0.270, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.812, 0.850, 0.912), "sky_horizon": Color(0.855, 0.891, 0.950), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 14: Arctic - bright ice vs deep blue, pale ice-crack accent
	{ "ground_a": Color(0.180, 0.480, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.800, 0.950), "sky_top": Color(0.812, 0.854, 0.912), "sky_horizon": Color(0.855, 0.895, 0.950), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 15: Ocean - bright cyan vs dark teal, white foam accent; sky recoloured to vivid cyan (#42 round-6 gate finding #8)
	{ "ground_a": Color(0.180, 0.746, 0.900), "ground_b": Color(0.083, 0.355, 0.550), "ground_c": Color(0.850, 0.950, 0.950), "sky_top": Color(0.162, 0.666, 0.900), "sky_horizon": Color(0.000, 0.670, 0.980), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 16: Desert - bright white sand vs dark amber, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.792, 0.180), "ground_b": Color(0.550, 0.342, 0.083), "ground_c": Color(0.600, 0.620, 0.120), "sky_top": Color(0.900, 0.774, 0.059), "sky_horizon": Color(0.950, 0.812, 0.029), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 17: Forest - bright lime vs very dark green, dark soil accent
	{ "ground_a": Color(0.396, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "ground_c": Color(0.300, 0.280, 0.080), "sky_top": Color(0.556, 0.812, 0.447), "sky_horizon": Color(0.679, 0.900, 0.585), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 18: BONUS - Sunset paradise, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.612, 0.180), "ground_b": Color(0.550, 0.183, 0.083), "ground_c": Color(0.550, 0.420, 0.120), "sky_top": Color(0.835, 0.535, 0.083), "sky_horizon": Color(0.920, 0.570, 0.046), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 19: Volcanic - bright red-brown vs dark char, glowing ember accent
	{ "ground_a": Color(0.900, 0.402, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "ground_c": Color(0.950, 0.350, 0.050), "sky_top": Color(0.790, 0.296, 0.075), "sky_horizon": Color(0.880, 0.302, 0.044), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 20: Night - vivid blue-purple vs deep violet, brighter violet fleck accent (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.316, 0.083, 0.550), "ground_c": Color(0.550, 0.280, 0.800), "sky_top": Color(0.244, 0.168, 0.395), "sky_horizon": Color(0.252, 0.168, 0.420), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 21: Arctic - blizzard white vs steel blue, pale ice-crack accent
	{ "ground_a": Color(0.180, 0.468, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "ground_c": Color(0.620, 0.780, 0.950), "sky_top": Color(0.812, 0.852, 0.912), "sky_horizon": Color(0.855, 0.893, 0.950), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 22: Sunset - bright orange vs dark red-brown, olive scrub accent restored (#42 round-6 gate)
	{ "ground_a": Color(0.900, 0.450, 0.180), "ground_b": Color(0.550, 0.149, 0.083), "ground_c": Color(0.550, 0.380, 0.100), "sky_top": Color(0.835, 0.366, 0.083), "sky_horizon": Color(0.920, 0.374, 0.046), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 23: Final - bright ocean blue vs near-black deep, white foam accent; sky recoloured to vivid cyan (#42 round-6 gate finding #8)
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.210, 0.550), "ground_c": Color(0.850, 0.900, 0.980), "sky_top": Color(0.162, 0.666, 0.900), "sky_horizon": Color(0.000, 0.670, 0.980), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
