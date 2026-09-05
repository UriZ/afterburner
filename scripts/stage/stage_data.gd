extends RefCounted

## Stage definitions for After Burner's 23 stages.
## Each stage defines ground/sky colors, enemy difficulty, and whether it's a bonus stage.

const STAGES := [
	# Stage 1: Ocean - calm blue waters
	{ "ground_a": Color(0.1, 0.3, 0.7), "ground_b": Color(0.08, 0.25, 0.6), "sky_top": Color(0.05, 0.05, 0.3), "sky_horizon": Color(0.5, 0.7, 0.95), "spawn_interval": 3.0, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 2: Ocean - deeper blue
	{ "ground_a": Color(0.05, 0.2, 0.6), "ground_b": Color(0.04, 0.15, 0.5), "sky_top": Color(0.04, 0.04, 0.28), "sky_horizon": Color(0.45, 0.65, 0.9), "spawn_interval": 2.8, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 3: Desert - tan sand
	{ "ground_a": Color(0.76, 0.6, 0.42), "ground_b": Color(0.65, 0.5, 0.35), "sky_top": Color(0.15, 0.1, 0.3), "sky_horizon": Color(0.8, 0.6, 0.4), "spawn_interval": 2.7, "enemies_per_wave": 3, "is_bonus": false },
	# Stage 4: Desert - reddish
	{ "ground_a": Color(0.8, 0.5, 0.3), "ground_b": Color(0.7, 0.4, 0.25), "sky_top": Color(0.2, 0.1, 0.25), "sky_horizon": Color(0.85, 0.55, 0.35), "spawn_interval": 2.6, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 5: Forest - green
	{ "ground_a": Color(0.2, 0.5, 0.2), "ground_b": Color(0.15, 0.4, 0.15), "sky_top": Color(0.05, 0.08, 0.2), "sky_horizon": Color(0.4, 0.65, 0.5), "spawn_interval": 2.5, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 6: BONUS - Ocean flyover
	{ "ground_a": Color(0.0, 0.35, 0.8), "ground_b": Color(0.0, 0.28, 0.7), "sky_top": Color(0.1, 0.15, 0.5), "sky_horizon": Color(0.5, 0.75, 1.0), "spawn_interval": 2.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 7: Mountain - grey rock
	{ "ground_a": Color(0.45, 0.43, 0.4), "ground_b": Color(0.35, 0.33, 0.3), "sky_top": Color(0.08, 0.08, 0.25), "sky_horizon": Color(0.55, 0.6, 0.7), "spawn_interval": 2.4, "enemies_per_wave": 4, "is_bonus": false },
	# Stage 8: Mountain - dark grey
	{ "ground_a": Color(0.35, 0.33, 0.32), "ground_b": Color(0.25, 0.24, 0.23), "sky_top": Color(0.06, 0.06, 0.2), "sky_horizon": Color(0.5, 0.55, 0.65), "spawn_interval": 2.3, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 9: Sunset - orange glow
	{ "ground_a": Color(0.6, 0.35, 0.15), "ground_b": Color(0.5, 0.28, 0.1), "sky_top": Color(0.3, 0.1, 0.15), "sky_horizon": Color(1.0, 0.55, 0.2), "spawn_interval": 2.2, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 10: Sunset - deep orange
	{ "ground_a": Color(0.55, 0.3, 0.1), "ground_b": Color(0.45, 0.22, 0.08), "sky_top": Color(0.25, 0.08, 0.12), "sky_horizon": Color(0.95, 0.45, 0.15), "spawn_interval": 2.1, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 11: Night city - dark with hints of light
	{ "ground_a": Color(0.1, 0.1, 0.15), "ground_b": Color(0.15, 0.12, 0.2), "sky_top": Color(0.02, 0.02, 0.08), "sky_horizon": Color(0.1, 0.1, 0.2), "spawn_interval": 2.0, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 12: BONUS - Night city lights
	{ "ground_a": Color(0.08, 0.08, 0.18), "ground_b": Color(0.12, 0.1, 0.25), "sky_top": Color(0.02, 0.02, 0.1), "sky_horizon": Color(0.15, 0.1, 0.3), "spawn_interval": 2.0, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 13: Arctic - white/blue ice
	{ "ground_a": Color(0.8, 0.85, 0.9), "ground_b": Color(0.7, 0.78, 0.88), "sky_top": Color(0.1, 0.15, 0.35), "sky_horizon": Color(0.6, 0.75, 0.9), "spawn_interval": 1.9, "enemies_per_wave": 5, "is_bonus": false },
	# Stage 14: Arctic - frozen blue
	{ "ground_a": Color(0.65, 0.75, 0.88), "ground_b": Color(0.55, 0.65, 0.8), "sky_top": Color(0.08, 0.12, 0.3), "sky_horizon": Color(0.55, 0.7, 0.85), "spawn_interval": 1.8, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 15: Ocean - tropical green
	{ "ground_a": Color(0.05, 0.4, 0.55), "ground_b": Color(0.04, 0.3, 0.45), "sky_top": Color(0.05, 0.1, 0.35), "sky_horizon": Color(0.4, 0.7, 0.85), "spawn_interval": 1.7, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 16: Desert - white sand
	{ "ground_a": Color(0.85, 0.8, 0.7), "ground_b": Color(0.75, 0.7, 0.6), "sky_top": Color(0.15, 0.12, 0.35), "sky_horizon": Color(0.7, 0.65, 0.55), "spawn_interval": 1.6, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 17: Forest - dark green
	{ "ground_a": Color(0.12, 0.35, 0.12), "ground_b": Color(0.08, 0.28, 0.08), "sky_top": Color(0.03, 0.05, 0.15), "sky_horizon": Color(0.3, 0.5, 0.35), "spawn_interval": 1.5, "enemies_per_wave": 6, "is_bonus": false },
	# Stage 18: BONUS - Sunset paradise
	{ "ground_a": Color(0.9, 0.6, 0.3), "ground_b": Color(0.8, 0.5, 0.25), "sky_top": Color(0.4, 0.15, 0.2), "sky_horizon": Color(1.0, 0.6, 0.3), "spawn_interval": 1.5, "enemies_per_wave": 2, "is_bonus": true },
	# Stage 19: Mountain - volcanic
	{ "ground_a": Color(0.3, 0.2, 0.15), "ground_b": Color(0.4, 0.15, 0.1), "sky_top": Color(0.15, 0.05, 0.05), "sky_horizon": Color(0.6, 0.25, 0.1), "spawn_interval": 1.4, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 20: Night city - neon
	{ "ground_a": Color(0.08, 0.05, 0.15), "ground_b": Color(0.12, 0.08, 0.22), "sky_top": Color(0.02, 0.01, 0.06), "sky_horizon": Color(0.15, 0.08, 0.25), "spawn_interval": 1.3, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 21: Arctic - blizzard white
	{ "ground_a": Color(0.9, 0.92, 0.95), "ground_b": Color(0.82, 0.85, 0.9), "sky_top": Color(0.2, 0.22, 0.35), "sky_horizon": Color(0.7, 0.75, 0.85), "spawn_interval": 1.2, "enemies_per_wave": 7, "is_bonus": false },
	# Stage 22: Sunset - blood red
	{ "ground_a": Color(0.5, 0.15, 0.1), "ground_b": Color(0.4, 0.1, 0.08), "sky_top": Color(0.3, 0.05, 0.05), "sky_horizon": Color(0.9, 0.3, 0.1), "spawn_interval": 1.1, "enemies_per_wave": 8, "is_bonus": false },
	# Stage 23: Final - dark ocean
	{ "ground_a": Color(0.03, 0.1, 0.3), "ground_b": Color(0.02, 0.08, 0.25), "sky_top": Color(0.01, 0.01, 0.05), "sky_horizon": Color(0.15, 0.2, 0.4), "spawn_interval": 1.0, "enemies_per_wave": 8, "is_bonus": false },
]


static func get_stage(stage_number: int) -> Dictionary:
	var index := clampi(stage_number - 1, 0, STAGES.size() - 1)
	return STAGES[index]


static func stage_count() -> int:
	return STAGES.size()
