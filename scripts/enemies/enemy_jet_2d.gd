extends Node

## 2D enemy jet. Pure data/logic node — no visual transform.
## GameWorld reads its state and draws it via EnemySpriteRenderer.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

signal destroyed(score_value: int)

enum EnemyType { FIGHTER, INTERCEPTOR, BOMBER }

const TYPE_DATA: Dictionary = {
	0: {  # FIGHTER
		"speed": 0.35,
		"health": 1,
		"fire_interval": 1.5,
		"score": 100,
		"visual": 0,
	},
	1: {  # INTERCEPTOR
		"speed": 0.55,
		"health": 1,
		"fire_interval": 1.5,
		"score": 200,
		"visual": 1,
	},
	2: {  # BOMBER
		"speed": 0.25,
		"health": 2,
		"fire_interval": 2.0,
		"score": 500,
		"visual": 2,
	},
}

const DESPAWN_DEPTH: float = 0.92
# Asymptote for the saturating scale curve (see get_screen_scale()). A hard
# minf() clamp here would create a plateau — the curve below approaches this
# value but never reaches it, so size keeps growing (just decelerating) all
# the way to despawn instead of freezing at a fixed size (#105).
# K=25 puts the peak (at DESPAWN_DEPTH, raw=2.5692) at scale~2.330, which
# through the renderer's fixed pipeline (get_screen_scale()*35.0 draw scale,
# wingtip at +-1.55*s) reads as a ~253px wingspan on the 960px-wide screen —
# 26.3%, inside the 25-30% AB2-reference band from #105's reopen. K=3 (the
# first #105 fix) undershot at ~1.38 (13% wingspan) because it saturated too
# aggressively relative to raw's own ~2.57 ceiling at despawn.
const SCALE_SATURATION: float = 25.0
const BULLET_SPEED: float = 0.6
# Enemy must be visibly close before it's allowed to open fire — gives the
# player an approach window instead of getting shot at while still a distant dot.
const MIN_FIRE_DEPTH: float = 0.3
# Enemies fly at altitude, not on the ground plane — DepthUtil.to_screen()'s
# altitude param lifts them above the horizon as they approach instead of
# descending below it (#100). Per-instance jitter within this band spreads
# a formation across varied sky heights instead of one vertical column, and
# stays comfortably above the 0.4128 threshold where the lift term would
# stop being negative (see depth_util.gd), so the rise is always monotonic.
const ALTITUDE_MIN: float = 0.75
const ALTITUDE_MAX: float = 1.2
# Body-collision (ramming) eligibility floor, read by game_world.gd (#103
# regression fix). With ALTITUDE_MIN/MAX both above depth_util.gd's 0.4128
# break-even, every enemy's screen-Y sweeps monotonically from the horizon
# down through the player's fixed screen-Y (crossing it somewhere in
# d in [0.30, 0.45] depending on its own altitude roll) and on up into the
# sky. Right past that crossing, vertical separation from the player is
# still small and grows slowly (it's a parabola's near-flat region, not a
# sharp corner) — a gate immediately after the crossing (tried: 0.5) still
# leaves most of the player's own generous 78px collision radius as
# horizontal margin, so it barely narrows the hit corridor. Only once
# separation has grown enough that the player's radius can no longer bridge
# it — d>=0.85, close to DESPAWN_DEPTH=0.92 — does a body hit require a
# genuinely near-dead-center approach that also survived formation drift
# all the way in. That's a real but narrow near-despawn window (the enemy
# is huge and obviously in-your-face by then), not a guaranteed hit off of
# every spawn. Matches AB2, where ramming isn't really a mechanic; enemy
# bullets are the real threat.
const RAM_MIN_DEPTH: float = 0.85
# Bank angle correlates with lateral drift (#100 gate: reference frames
# burst-a-05/burst-a-08/burst-b-05 show enemies canted hard into their turn,
# never flat).
#
# WHICH CONSTANT BINDS (#131 amendment 1 — the original spec had this
# backwards, and the inversion is worth keeping on the record because the
# symptom is "the change did nothing"):
#   BANK_DRIFT_SCALE sets the CEILING.  MAX_BANK_RAD is a GUARD.
# Before #131 the widest formation drift (+-0.12, game_manager_2d.gd) gave
# 0.12 * 5.0 = 0.6000 rad = 34.38 deg against a 0.6109 rad = 35.00 deg clamp —
# 0.62 deg of headroom, so the clamp NEVER engaged and raising it alone would
# have changed no pixel. The arcade's large enemy banks at ~57 deg (wing axis
# on a 3x magnified crop of assets/reference/ab2-arcade-closeup-enemies.jpg,
# dx 705 / dy 1080), so the scale is set to put max drift exactly there:
#   0.12 * 8.3 = 0.9960 rad = 57.07 deg
# Raising the clamp is still NECESSARY — at the old 0.6109 that 57.07 deg peak
# would truncate straight back to 35.00 deg — it is just not SUFFICIENT.
const MAX_BANK_RAD: float = 1.0472  # 60 deg guard; 2.93 deg of headroom at max drift, does not bind
const BANK_DRIFT_SCALE: float = 8.3  # rad per unit of _x_drift — derived from the measured 57 deg ceiling

# Slow per-enemy roll oscillation, so an aircraft rolls INTO and OUT OF its
# turn instead of holding one angle from spawn to despawn (#131 G4: _x_drift is
# assigned once in configure() and never reassigned, which made every enemy a
# statue at its spawn bank).
#
# MULTIPLICATIVE, not additive. The additive form gives a zero-drift enemy a
# constant +-20.05 deg roll for no reason — an aircraft that is not turning
# must not be banked — so the oscillation modulates the characteristic bank
# rather than adding to it. Factor span is [BASE-AMOUNT, BASE+AMOUNT] =
# [0.10, 1.00].
#
# TUNING RULE, and it is not obvious from the values (#131 addendum): the
# SPLIT between BASE and AMOUNT is free — it sets how deeply an enemy rolls out
# of its turn — but their SUM is pinned, because the ceiling is
# max_drift * BANK_DRIFT_SCALE * (BASE + AMOUNT) and that ceiling is the
# measured 57 deg. AC 1a admits BASE + AMOUNT only in [0.9638, 1.0339] at
# scale 8.3, i.e. ~+-3.4% around 1.00. Retuning to 0.50 + 0.40 because the
# roll "felt too deep" looks purely cosmetic and silently drops the ceiling to
# 51.36 deg. If you need a different sum, move BANK_DRIFT_SCALE with it so the
# product still lands on 57 deg, and say so: the ceiling is measured, the split
# is not.
#
# BANK_OSC_RATE is genuinely free — it appears nowhere in the ceiling. All
# three OSC constants are VISUAL, not measured: no arcade bank-RATE measurement
# exists (the two characterised enemies give a range, not a rate, and the
# automated approaches that would have produced one failed — spec section 1.2).
# BANK_DRIFT_SCALE is the one that is arithmetically derived, and should move
# only if the 57 deg measurement does.
const BANK_OSC_BASE: float = 0.55    # factor floor+amplitude span [0.10, 1.00]
const BANK_OSC_AMOUNT: float = 0.45  # BASE + AMOUNT is pinned to ~1.00 — see above
const BANK_OSC_RATE: float = 0.55    # rad/s of phase; free

var enemy_type: int = 0  # EnemyType.FIGHTER
var logical_x: float = 0.0
var logical_depth: float = 0.0
var logical_altitude: float = 1.0
var speed: float = 0.35
var health: int = 1
var fire_interval: float = 4.0
var score_value: int = 100
var _x_drift: float = 0.0
var _fire_timer: float = 0.0
# Seeded per enemy in configure() so a formation does not roll in unison.
var _bank_phase: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_apply_type_data()
	_fire_timer = randf_range(1.2, 2.0)
	# Connect score signal in deferred call so autoloads are guaranteed available
	call_deferred("_connect_score_signal")


func _connect_score_signal() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		destroyed.connect(gs.add_score)


func configure(type: int, start_logical_x: float, start_logical_depth: float, x_drift_amount: float = 0.0) -> void:
	enemy_type = type
	logical_x = start_logical_x
	logical_depth = start_logical_depth
	_x_drift = x_drift_amount
	_bank_phase = randf_range(0.0, TAU)
	logical_altitude = randf_range(ALTITUDE_MIN, ALTITUDE_MAX)
	_apply_type_data()


func _apply_type_data() -> void:
	var data: Dictionary = TYPE_DATA[enemy_type]
	speed = data["speed"]
	health = data["health"]
	fire_interval = data["fire_interval"]
	score_value = data["score"]


func _process(delta: float) -> void:
	logical_depth += speed * delta
	logical_x += _x_drift * delta
	_bank_phase += BANK_OSC_RATE * delta

	if logical_depth > DESPAWN_DEPTH:
		queue_free()
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0 and logical_depth >= MIN_FIRE_DEPTH:
		_fire_timer = fire_interval
		_fire_bullet()


func get_screen_position() -> Vector2:
	return _DepthUtil.to_screen(logical_x, logical_depth, logical_altitude)


func get_screen_scale() -> float:
	# Saturating curve: raw*K/(K+raw) is strictly increasing in raw (and thus
	# in depth, since depth_to_scale() is strictly increasing) for all
	# raw >= 0, and approaches K asymptotically without ever reaching it. For
	# raw << K it's close to raw unchanged (distant enemies look the same as
	# before); as raw grows, growth decelerates smoothly instead of hitting a
	# hard wall.
	var raw: float = _DepthUtil.depth_to_scale(logical_depth)
	return raw * SCALE_SATURATION / (SCALE_SATURATION + raw)


func get_collision_radius() -> float:
	return _DepthUtil.scale_pixels(logical_depth, 20.0)


func get_visual_type() -> int:
	return TYPE_DATA[enemy_type]["visual"]


## The enemy's own, WORLD-LOCAL bank. Returns bank only — never the world roll.
##
## Enemies are plain Node, not CanvasItem: GameWorld._draw() draws them into ITS
## canvas (#128 amendment 2, with a runnable proof), so once world roll lands the
## drawn orientation becomes world_roll + bank_rad for free. Adding, subtracting
## or otherwise compensating for DepthUtil.roll_rad here double-counts it and
## enemies roll at twice the world's rate — invisible in a level-flight capture,
## which is why AC 6 carries a negative control.
##
## For the same reason bank derives from _x_drift, a WORLD-space lateral drift in
## logical_x units. Never derive it from a screen-space delta: a screen-space
## derivative already contains the world roll, so it double-counts silently.
func get_bank_angle() -> float:
	var osc: float = BANK_OSC_BASE + BANK_OSC_AMOUNT * sin(_bank_phase)
	return clampf(_x_drift * BANK_DRIFT_SCALE * osc, -MAX_BANK_RAD, MAX_BANK_RAD)


func take_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	destroyed.emit(score_value)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_explosion()
	_spawn_explosion()
	queue_free()


func _spawn_explosion() -> void:
	var explosion_script: GDScript = preload("res://scripts/effects/explosion_2d.gd")
	var explosion := Node2D.new()
	explosion.set_script(explosion_script)
	explosion.position = get_screen_position()
	explosion.z_index = 999
	var scale_val: float = _DepthUtil.depth_to_scale(logical_depth)
	explosion.set("base_radius", maxf(scale_val * 240.0, 90.0))
	# Into the rolling world layer (#128) — see the same call in missile_2d.gd.
	# The null guard stays: this runs on death, which can happen while the jet
	# is being torn down.
	if get_parent():
		_DepthUtil.world_layer_or(get_tree(), get_parent()).add_child(explosion)


func _fire_bullet() -> void:
	var player: Node = _find_player()
	if player == null:
		return
	var bullet := Node.new()
	bullet.set_script(preload("res://scripts/enemies/enemy_bullet_2d.gd"))
	bullet.set("logical_x", logical_x)
	bullet.set("logical_depth", logical_depth)
	bullet.set("logical_altitude", logical_altitude)
	bullet.set("speed", BULLET_SPEED)
	bullet.set("target_screen_pos", player.get_screen_position())
	get_parent().add_child(bullet)


func _find_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var players: Array = tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
