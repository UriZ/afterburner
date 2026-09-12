class_name SpawnPacing
extends RefCounted

## Pure enemy-spawn pacing math, factored out of game_manager_2d.gd so it stays
## dependency-free (no GameState autoload reference) and unit-testable in
## headless mode — mirrors depth_util.gd's role for screen-space math.

# Density cap: never let more than this many enemies be alive at once, no matter
# how many waves have queued up. This is what actually keeps the screen from
# filling instantly (#103) while a short, frequent dispense tick keeps a steady
# trickle flowing so the screen never sits empty either (#50).
const MAX_ON_SCREEN_ENEMIES := 5
const MIN_DISPENSE_INTERVAL := 0.3
const MAX_DISPENSE_INTERVAL := 0.7


## Maps a stage's difficulty (lower spawn_interval = harder) to a dispense
## cadence, clamped so it never drops below what MAX_ON_SCREEN_ENEMIES can
## absorb without bursting, and never rises high enough to leave gaps.
static func dispense_interval_for(spawn_interval: float) -> float:
	return clampf(spawn_interval * 0.5, MIN_DISPENSE_INTERVAL, MAX_DISPENSE_INTERVAL)
