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
## (0.379 full-sky mean vs reference ~0.90-0.99 for warm stages). Every
## reference sky (desert, coastal, city, arctic) is a single-hue gradient —
## darker/richer at the zenith, paler/hazier at the horizon — never a hue
## swap. Saturation target is stage-relative, not a flat floor: warm stages
## (desert/sunset/volcanic) measure S~0.85-0.95 in the references; arctic
## measures S~0.10-0.15 (near-white haze); mountain/night stay moderate.
##
## Mountain (7, 8) ground/sky were desaturated back toward slate-grey
## (S~0.15-0.20) — an earlier pass had turned achromatic rock blue to hit a
## flat saturation floor that no longer applies; rock reads as grey, not a
## vivid color, so it should measure grey.
const STAGES := [
	# Stage 1: Desert - warm sand vs dark brown (After Burner II opens over desert)
	{ "ground_a": Color(0.900, 0.632, 0.180), "ground_b": Color(0.550, 0.345, 0.083), "sky_top": Color(0.750, 0.499, 0.075), "sky_horizon": Color(0.950, 0.607, 0.029), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 2: Desert - richer orange sand vs dark sienna
	{ "ground_a": Color(0.900, 0.597, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "sky_top": Color(0.750, 0.466, 0.075), "sky_horizon": Color(0.950, 0.562, 0.029), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 3: Desert - bright tan vs dark brown
	{ "ground_a": Color(0.900, 0.660, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "sky_top": Color(0.750, 0.525, 0.075), "sky_horizon": Color(0.950, 0.643, 0.029), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 4: Desert - reddish sand vs dark brown
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "sky_top": Color(0.750, 0.413, 0.075), "sky_horizon": Color(0.950, 0.489, 0.029), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 5: Forest - bright green vs dark green
	{ "ground_a": Color(0.340, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "sky_top": Color(0.315, 0.550, 0.247), "sky_horizon": Color(0.655, 0.900, 0.585), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 6: BONUS - Ocean flyover
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.181, 0.550), "sky_top": Color(0.247, 0.399, 0.550), "sky_horizon": Color(0.690, 0.805, 0.920), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 7: Mountain - slate-grey rock, low saturation (rock reads as grey, not a vivid color)
	{ "ground_a": Color(0.590, 0.666, 0.720), "ground_b": Color(0.320, 0.367, 0.400), "sky_top": Color(0.468, 0.516, 0.550), "sky_horizon": Color(0.748, 0.807, 0.850), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 8: Mountain - slate-grey rock, low saturation (rock reads as grey, not a vivid color)
	{ "ground_a": Color(0.590, 0.677, 0.720), "ground_b": Color(0.320, 0.373, 0.400), "sky_top": Color(0.468, 0.522, 0.550), "sky_horizon": Color(0.748, 0.816, 0.850), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 9: Sunset - bright orange vs dark red-brown
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.164, 0.083), "sky_top": Color(0.580, 0.333, 0.087), "sky_horizon": Color(0.920, 0.483, 0.046), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 10: Sunset - deep orange vs dark maroon
	{ "ground_a": Color(0.900, 0.526, 0.180), "ground_b": Color(0.550, 0.160, 0.083), "sky_top": Color(0.580, 0.324, 0.087), "sky_horizon": Color(0.920, 0.466, 0.046), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 11: Night - vivid purple vs deep violet (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.238, 0.083, 0.550), "sky_top": Color(0.203, 0.144, 0.320), "sky_horizon": Color(0.252, 0.168, 0.420), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 12: BONUS - Night city lights
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.199, 0.083, 0.550), "sky_top": Color(0.203, 0.144, 0.320), "sky_horizon": Color(0.348, 0.247, 0.550), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 13: Arctic - white vs medium blue
	{ "ground_a": Color(0.180, 0.450, 0.900), "ground_b": Color(0.083, 0.270, 0.550), "sky_top": Color(0.704, 0.740, 0.800), "sky_horizon": Color(0.855, 0.891, 0.950), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 14: Arctic - bright ice vs deep blue
	{ "ground_a": Color(0.180, 0.480, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "sky_top": Color(0.704, 0.744, 0.800), "sky_horizon": Color(0.855, 0.895, 0.950), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 15: Ocean - bright cyan vs dark teal
	{ "ground_a": Color(0.180, 0.746, 0.900), "ground_b": Color(0.083, 0.355, 0.550), "sky_top": Color(0.247, 0.485, 0.550), "sky_horizon": Color(0.690, 0.871, 0.920), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 16: Desert - bright white sand vs dark amber
	{ "ground_a": Color(0.900, 0.792, 0.180), "ground_b": Color(0.550, 0.342, 0.083), "sky_top": Color(0.750, 0.649, 0.075), "sky_horizon": Color(0.950, 0.812, 0.029), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 17: Forest - bright lime vs very dark green
	{ "ground_a": Color(0.396, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "sky_top": Color(0.338, 0.550, 0.247), "sky_horizon": Color(0.679, 0.900, 0.585), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 18: BONUS - Sunset paradise
	{ "ground_a": Color(0.900, 0.612, 0.180), "ground_b": Color(0.550, 0.183, 0.083), "sky_top": Color(0.580, 0.383, 0.087), "sky_horizon": Color(0.920, 0.570, 0.046), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 19: Volcanic - bright red-brown vs dark char
	{ "ground_a": Color(0.900, 0.402, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "sky_top": Color(0.520, 0.211, 0.073), "sky_horizon": Color(0.880, 0.302, 0.044), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 20: Night - vivid blue-purple vs deep violet (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.316, 0.083, 0.550), "sky_top": Color(0.203, 0.144, 0.320), "sky_horizon": Color(0.252, 0.168, 0.420), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 21: Arctic - blizzard white vs steel blue
	{ "ground_a": Color(0.180, 0.468, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "sky_top": Color(0.704, 0.742, 0.800), "sky_horizon": Color(0.855, 0.893, 0.950), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 22: Sunset - bright orange vs dark red-brown
	{ "ground_a": Color(0.900, 0.450, 0.180), "ground_b": Color(0.550, 0.149, 0.083), "sky_top": Color(0.580, 0.272, 0.087), "sky_horizon": Color(0.920, 0.374, 0.046), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 23: Final - bright ocean blue vs near-black deep
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.210, 0.550), "sky_top": Color(0.247, 0.399, 0.550), "sky_horizon": Color(0.690, 0.805, 0.920), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
