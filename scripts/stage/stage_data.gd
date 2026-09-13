extends RefCounted

## Stage definitions for After Burner's 23 stages.
## Each stage defines ground/sky colors, enemy difficulty, and whether it's a bonus stage.

## Color values are hue-preserved from the original palette but re-graded in HSV
## (#108): ground_a/sky_horizon target S~0.8 V~0.9, ground_b S~0.85 V~0.55,
## sky_top S~0.6 V~0.6. AB2's arcade frames are vivid and bright even in shadow
## and at night — a literal near-black "night" reads as washed-out on our
## renderer's measured saturation/value, not moody, so hue carries the "night"
## identity instead of darkness. See #108 for the measured targets.
const STAGES := [
	# Stage 1: Desert - warm sand vs dark brown (After Burner II opens over desert)
	{ "ground_a": Color(0.900, 0.632, 0.180), "ground_b": Color(0.550, 0.345, 0.083), "sky_top": Color(0.240, 0.240, 0.600), "sky_horizon": Color(0.900, 0.619, 0.288), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 2: Desert - richer orange sand vs dark sienna
	{ "ground_a": Color(0.900, 0.597, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "sky_top": Color(0.280, 0.240, 0.600), "sky_horizon": Color(0.900, 0.560, 0.288), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 3: Desert - bright tan vs dark brown
	{ "ground_a": Color(0.900, 0.660, 0.180), "ground_b": Color(0.550, 0.316, 0.083), "sky_top": Color(0.330, 0.240, 0.600), "sky_horizon": Color(0.900, 0.594, 0.288), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 4: Desert - reddish sand vs dark brown
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "sky_top": Color(0.480, 0.240, 0.600), "sky_horizon": Color(0.900, 0.533, 0.288), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 5: Forest - bright green vs dark green
	{ "ground_a": Color(0.340, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "sky_top": Color(0.240, 0.312, 0.600), "sky_horizon": Color(0.288, 0.900, 0.533), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 6: BONUS - Ocean flyover
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.181, 0.550), "sky_top": Color(0.240, 0.285, 0.600), "sky_horizon": Color(0.288, 0.594, 0.900), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 7: Mountain - steel-blue rock vs dark slate (grey source was achromatic; hue substituted so it isn't desaturated)
	{ "ground_a": Color(0.180, 0.554, 0.900), "ground_b": Color(0.083, 0.326, 0.550), "sky_top": Color(0.240, 0.240, 0.600), "sky_horizon": Color(0.288, 0.492, 0.900), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 8: Mountain - steel-blue rock vs dark slate (grey source was achromatic; hue substituted so it isn't desaturated)
	{ "ground_a": Color(0.180, 0.554, 0.900), "ground_b": Color(0.083, 0.326, 0.550), "sky_top": Color(0.240, 0.240, 0.600), "sky_horizon": Color(0.288, 0.492, 0.900), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 9: Sunset - bright orange vs dark red-brown
	{ "ground_a": Color(0.900, 0.540, 0.180), "ground_b": Color(0.550, 0.164, 0.083), "sky_top": Color(0.600, 0.240, 0.330), "sky_horizon": Color(0.900, 0.556, 0.288), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 10: Sunset - deep orange vs dark maroon
	{ "ground_a": Color(0.900, 0.526, 0.180), "ground_b": Color(0.550, 0.160, 0.083), "sky_top": Color(0.600, 0.240, 0.325), "sky_horizon": Color(0.900, 0.517, 0.288), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 11: Night - vivid purple vs deep violet (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.238, 0.083, 0.550), "sky_top": Color(0.240, 0.240, 0.600), "sky_horizon": Color(0.288, 0.288, 0.900), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 12: BONUS - Night city lights
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.199, 0.083, 0.550), "sky_top": Color(0.240, 0.240, 0.600), "sky_horizon": Color(0.441, 0.288, 0.900), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 13: Arctic - white vs medium blue
	{ "ground_a": Color(0.180, 0.450, 0.900), "ground_b": Color(0.083, 0.270, 0.550), "sky_top": Color(0.240, 0.312, 0.600), "sky_horizon": Color(0.288, 0.594, 0.900), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 14: Arctic - bright ice vs deep blue
	{ "ground_a": Color(0.180, 0.480, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "sky_top": Color(0.240, 0.305, 0.600), "sky_horizon": Color(0.288, 0.594, 0.900), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 15: Ocean - bright cyan vs dark teal
	{ "ground_a": Color(0.180, 0.746, 0.900), "ground_b": Color(0.083, 0.355, 0.550), "sky_top": Color(0.240, 0.300, 0.600), "sky_horizon": Color(0.288, 0.696, 0.900), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 16: Desert - bright white sand vs dark amber
	{ "ground_a": Color(0.900, 0.792, 0.180), "ground_b": Color(0.550, 0.342, 0.083), "sky_top": Color(0.287, 0.240, 0.600), "sky_horizon": Color(0.900, 0.696, 0.288), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 17: Forest - bright lime vs very dark green
	{ "ground_a": Color(0.396, 0.900, 0.180), "ground_b": Color(0.083, 0.550, 0.083), "sky_top": Color(0.240, 0.300, 0.600), "sky_horizon": Color(0.288, 0.900, 0.441), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 18: BONUS - Sunset paradise
	{ "ground_a": Color(0.900, 0.612, 0.180), "ground_b": Color(0.550, 0.183, 0.083), "sky_top": Color(0.600, 0.240, 0.312), "sky_horizon": Color(0.900, 0.550, 0.288), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 19: Volcanic - bright red-brown vs dark char
	{ "ground_a": Color(0.900, 0.402, 0.180), "ground_b": Color(0.550, 0.238, 0.083), "sky_top": Color(0.600, 0.240, 0.240), "sky_horizon": Color(0.900, 0.472, 0.288), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 20: Night - vivid blue-purple vs deep violet (hue carries "night", not near-black darkness)
	{ "ground_a": Color(0.420, 0.180, 0.900), "ground_b": Color(0.316, 0.083, 0.550), "sky_top": Color(0.312, 0.240, 0.600), "sky_horizon": Color(0.540, 0.288, 0.900), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 21: Arctic - blizzard white vs steel blue
	{ "ground_a": Color(0.180, 0.468, 0.900), "ground_b": Color(0.083, 0.238, 0.550), "sky_top": Color(0.240, 0.288, 0.600), "sky_horizon": Color(0.288, 0.492, 0.900), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 22: Sunset - bright orange vs dark red-brown
	{ "ground_a": Color(0.900, 0.450, 0.180), "ground_b": Color(0.550, 0.149, 0.083), "sky_top": Color(0.600, 0.240, 0.240), "sky_horizon": Color(0.900, 0.441, 0.288), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 23: Final - bright ocean blue vs near-black deep
	{ "ground_a": Color(0.180, 0.540, 0.900), "ground_b": Color(0.083, 0.210, 0.550), "sky_top": Color(0.240, 0.240, 0.600), "sky_horizon": Color(0.288, 0.410, 0.900), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
