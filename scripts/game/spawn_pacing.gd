class_name SpawnPacing
extends RefCounted

## Pure enemy-spawn pacing math, factored out of game_manager_2d.gd so it stays
## dependency-free (no GameState autoload reference) and unit-testable in
## headless mode — mirrors depth_util.gd's role for screen-space math.

# Density cap: never let more than this many enemies be alive at once, no matter
# how many waves have queued up. This is what actually keeps the screen from
# filling instantly (#103) while a short, frequent dispense tick keeps a steady
# trickle flowing so the screen never sits empty either (#50).
#
# Raised from 5/[0.3,0.7] (#100 gate: 24% of captured frames had essentially no
# enemy pixels, 41% had <1000px — reference (burst-a-02/03) shows 4-6 visible
# every frame). Steady-state on-screen count is roughly
# (1/dispense_interval) * avg_enemy_lifetime; with DESPAWN_DEPTH=0.92 and
# fighter/interceptor/bomber speeds of 0.35/0.55/0.25 giving lifetimes of
# ~2.6/1.7/3.7s, a wave-weighted average lifetime is ~2.3s. At the new
# mid-band interval (~0.35s) that's ~6.6 in flight, comfortably filling the
# 4-6 band with the cap as a ceiling rather than the steady-state value.
const MAX_ON_SCREEN_ENEMIES := 7
const MIN_DISPENSE_INTERVAL := 0.2
const MAX_DISPENSE_INTERVAL := 0.5


## Maps a stage's difficulty (lower spawn_interval = harder) to a dispense
## cadence, clamped so it never drops below what MAX_ON_SCREEN_ENEMIES can
## absorb without bursting, and never rises high enough to leave gaps.
static func dispense_interval_for(spawn_interval: float) -> float:
	return clampf(spawn_interval * 0.5, MIN_DISPENSE_INTERVAL, MAX_DISPENSE_INTERVAL)
