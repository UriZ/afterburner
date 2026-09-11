extends RefCounted

## Stage definitions for After Burner's 23 stages.
## Each stage defines ground/sky colors, enemy difficulty, and whether it's a bonus stage.

const STAGES := [
	# Stage 1: Desert - warm sand vs dark brown (After Burner II opens over desert)
	{ "ground_a": Color(0.88, 0.72, 0.45), "ground_b": Color(0.42, 0.28, 0.10), "sky_top": Color(0.08, 0.08, 0.28), "sky_horizon": Color(0.75, 0.58, 0.38), "spawn_interval": 1.5, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 2: Desert - richer orange sand vs dark sienna
	{ "ground_a": Color(0.92, 0.68, 0.35), "ground_b": Color(0.38, 0.22, 0.06), "sky_top": Color(0.10, 0.08, 0.26), "sky_horizon": Color(0.80, 0.55, 0.35), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 3: Desert - bright tan vs dark brown
	{ "ground_a": Color(0.9, 0.75, 0.45), "ground_b": Color(0.35, 0.2, 0.05), "sky_top": Color(0.15, 0.1, 0.3), "sky_horizon": Color(0.8, 0.6, 0.4), "spawn_interval": 1.2, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 4: Desert - reddish sand vs dark brown
	{ "ground_a": Color(0.9, 0.6, 0.3), "ground_b": Color(0.35, 0.15, 0.05), "sky_top": Color(0.2, 0.1, 0.25), "sky_horizon": Color(0.85, 0.55, 0.35), "spawn_interval": 1.3, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 5: Forest - bright green vs dark green
	{ "ground_a": Color(0.35, 0.7, 0.25), "ground_b": Color(0.05, 0.2, 0.05), "sky_top": Color(0.05, 0.08, 0.2), "sky_horizon": Color(0.4, 0.65, 0.5), "spawn_interval": 1.1, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 6: BONUS - Ocean flyover
	{ "ground_a": Color(0.2, 0.55, 0.9), "ground_b": Color(0.02, 0.1, 0.4), "sky_top": Color(0.1, 0.15, 0.5), "sky_horizon": Color(0.5, 0.75, 1.0), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 7: Mountain - light grey vs dark grey
	{ "ground_a": Color(0.7, 0.7, 0.7), "ground_b": Color(0.2, 0.2, 0.2), "sky_top": Color(0.08, 0.08, 0.25), "sky_horizon": Color(0.55, 0.6, 0.7), "spawn_interval": 0.7, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 8: Mountain - silver vs charcoal
	{ "ground_a": Color(0.65, 0.65, 0.65), "ground_b": Color(0.15, 0.15, 0.15), "sky_top": Color(0.06, 0.06, 0.2), "sky_horizon": Color(0.5, 0.55, 0.65), "spawn_interval": 0.65, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 9: Sunset - bright orange vs dark red-brown
	{ "ground_a": Color(0.9, 0.5, 0.1), "ground_b": Color(0.25, 0.06, 0.02), "sky_top": Color(0.3, 0.1, 0.15), "sky_horizon": Color(1.0, 0.55, 0.2), "spawn_interval": 0.6, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 10: Sunset - deep orange vs dark maroon
	{ "ground_a": Color(0.85, 0.45, 0.08), "ground_b": Color(0.2, 0.05, 0.02), "sky_top": Color(0.25, 0.08, 0.12), "sky_horizon": Color(0.95, 0.45, 0.15), "spawn_interval": 0.55, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 11: Night - medium purple vs near-black
	{ "ground_a": Color(0.3, 0.2, 0.5), "ground_b": Color(0.04, 0.02, 0.08), "sky_top": Color(0.02, 0.02, 0.08), "sky_horizon": Color(0.1, 0.1, 0.2), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 12: BONUS - Night city lights
	{ "ground_a": Color(0.28, 0.18, 0.48), "ground_b": Color(0.04, 0.02, 0.1), "sky_top": Color(0.02, 0.02, 0.1), "sky_horizon": Color(0.15, 0.1, 0.3), "spawn_interval": 1.2, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 13: Arctic - white vs medium blue
	{ "ground_a": Color(0.92, 0.95, 1.0), "ground_b": Color(0.2, 0.4, 0.7), "sky_top": Color(0.1, 0.15, 0.35), "sky_horizon": Color(0.6, 0.75, 0.9), "spawn_interval": 0.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 14: Arctic - bright ice vs deep blue
	{ "ground_a": Color(0.88, 0.93, 1.0), "ground_b": Color(0.15, 0.3, 0.6), "sky_top": Color(0.08, 0.12, 0.3), "sky_horizon": Color(0.55, 0.7, 0.85), "spawn_interval": 0.45, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 15: Ocean - bright cyan vs dark teal
	{ "ground_a": Color(0.1, 0.65, 0.8), "ground_b": Color(0.01, 0.15, 0.25), "sky_top": Color(0.05, 0.1, 0.35), "sky_horizon": Color(0.4, 0.7, 0.85), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 16: Desert - bright white sand vs dark amber
	{ "ground_a": Color(0.95, 0.92, 0.75), "ground_b": Color(0.38, 0.22, 0.02), "sky_top": Color(0.15, 0.12, 0.35), "sky_horizon": Color(0.7, 0.65, 0.55), "spawn_interval": 0.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 17: Forest - bright lime vs very dark green
	{ "ground_a": Color(0.3, 0.65, 0.15), "ground_b": Color(0.03, 0.12, 0.03), "sky_top": Color(0.03, 0.05, 0.15), "sky_horizon": Color(0.3, 0.5, 0.35), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 18: BONUS - Sunset paradise
	{ "ground_a": Color(0.95, 0.65, 0.2), "ground_b": Color(0.3, 0.08, 0.02), "sky_top": Color(0.4, 0.15, 0.2), "sky_horizon": Color(1.0, 0.6, 0.3), "spawn_interval": 1.0, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 19: Volcanic - bright red-brown vs dark char
	{ "ground_a": Color(0.7, 0.25, 0.05), "ground_b": Color(0.08, 0.04, 0.02), "sky_top": Color(0.15, 0.05, 0.05), "sky_horizon": Color(0.6, 0.25, 0.1), "spawn_interval": 0.35, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 20: Night - medium blue-purple vs near-black
	{ "ground_a": Color(0.25, 0.15, 0.45), "ground_b": Color(0.03, 0.01, 0.05), "sky_top": Color(0.02, 0.01, 0.06), "sky_horizon": Color(0.15, 0.08, 0.25), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 21: Arctic - blizzard white vs steel blue
	{ "ground_a": Color(0.95, 0.97, 1.0), "ground_b": Color(0.2, 0.35, 0.65), "sky_top": Color(0.2, 0.22, 0.35), "sky_horizon": Color(0.7, 0.75, 0.85), "spawn_interval": 0.3, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 22: Sunset - bright orange vs dark red-brown
	{ "ground_a": Color(0.85, 0.35, 0.05), "ground_b": Color(0.15, 0.03, 0.01), "sky_top": Color(0.3, 0.05, 0.05), "sky_horizon": Color(0.9, 0.3, 0.1), "spawn_interval": 0.28, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 23: Final - bright ocean blue vs near-black deep
	{ "ground_a": Color(0.15, 0.45, 0.75), "ground_b": Color(0.01, 0.04, 0.12), "sky_top": Color(0.01, 0.01, 0.05), "sky_horizon": Color(0.15, 0.2, 0.4), "spawn_interval": 0.25, "enemies_per_wave": 9, "is_bonus": false },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
