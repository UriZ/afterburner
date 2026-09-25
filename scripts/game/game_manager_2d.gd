extends Node

## Main game controller for the 2D sprite-scaling After Burner.
## Handles enemy spawning (waves), stage progression, and scene wiring.

const StageData := preload("res://scripts/stage/stage_data.gd")
const SpawnPacing := preload("res://scripts/game/spawn_pacing.gd")
const DepthUtil := preload("res://scripts/game/depth_util.gd")

const STAGE_DURATION := 30.0
const STAGE_ANNOUNCE_DURATION := 2.0
const BONUS_MISSILE_REWARD := 30

# Wave definitions: type, count, formation pattern
var wave_definitions: Array[Dictionary] = [
	{"type": 0, "count": 4, "formation": "v"},
	{"type": 0, "count": 3, "formation": "line"},
	{"type": 1, "count": 4, "formation": "v"},
	{"type": 0, "count": 5, "formation": "v"},
	{"type": 2, "count": 4, "formation": "line"},
	{"type": 0, "count": 6, "formation": "scattered"},
	{"type": 1, "count": 5, "formation": "v"},
	{"type": 2, "count": 4, "formation": "line"},
	{"type": 0, "count": 6, "formation": "scattered"},
	{"type": 1, "count": 6, "formation": "v"},
	{"type": 2, "count": 4, "formation": "scattered"},
	{"type": 0, "count": 6, "formation": "scattered"},
]

var _dispense_timer: float = 0.0
var _dispense_interval: float = 0.5
var _pending_spawns: Array = []  # queued [enemy_type, logical_x, logical_depth, x_drift]
var _wave_index: int = 0
var _spawning_enabled: bool = true

var _stage_timer: float = 0.0
var _announce_timer: float = 0.0
var _is_announcing: bool = false


func _ready() -> void:
	# Godot's global RNG (randf_range etc., used throughout enemy spawn
	# placement) is NOT auto-seeded from entropy — without this, every
	# playthrough generates the exact same enemy formations, positions, and
	# altitudes in the exact same order every single time (discovered while
	# investigating #103: three "separate" zero-input trials were bit-for-bit
	# identical). Seed once here, the first node to run each game session.
	# Under --capture-seed the run must be reproducible instead (#114).
	if CaptureInput.requested_seed >= 0:
		seed(CaptureInput.requested_seed)
	else:
		randomize()
	# If launched directly (not from title screen), ensure phase is PLAYING
	if GameState.phase == GameState.Phase.TITLE:
		GameState.phase = GameState.Phase.PLAYING
	_apply_stage(GameState.current_stage)
	_dispense_timer = 0.0  # start dispensing immediately when announcement clears


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING and GameState.phase != GameState.Phase.BONUS_STAGE:
		return

	# Brief pause at stage start before spawning resumes. No visual overlay —
	# the reference has no centered banner; the persistent bottom-bar
	# "STAGE NN" text (hud_canvas.gd) is the only stage indicator AB2 shows.
	if _is_announcing:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_is_announcing = false
		return

	# Stage timer
	_stage_timer -= delta
	if _stage_timer <= 0.0:
		_advance_stage()

	# Enemy spawning — dispense one enemy at a time, gated by MAX_ON_SCREEN_ENEMIES
	if _spawning_enabled:
		_dispense_timer -= delta
		if _dispense_timer <= 0.0:
			_dispense_timer = _dispense_interval
			_dispense_next_enemy()


# --- Stage management ---

func _advance_stage() -> void:
	var next := GameState.current_stage + 1
	if next > StageData.stage_count():
		next = 1
	GameState.current_stage = next
	_apply_stage(next)


func _apply_stage(stage_number: int) -> void:
	var data := StageData.get_stage(stage_number)

	# Per-stage horizon (#120) — must land before GameWorld/ground quad read
	# DepthUtil.horizon_y in their next _process/_draw, which happens after
	# this function returns.
	DepthUtil.set_horizon_fraction(data["horizon_fraction"])

	# Update GameWorld sky/ground colors
	var game_world: Node2D = get_parent().get_node_or_null("GameWorld")
	if game_world:
		game_world.sky_top_color = data["sky_top"]
		game_world.sky_horizon_color = data["sky_horizon"]
		game_world.ground_color_a = data["ground_a"]
		game_world.ground_color_b = data["ground_b"]
		game_world.ground_color_c = data["ground_c"]

	# Update spawn difficulty — later/harder stages dispense enemies more often,
	# but always within a band that SpawnPacing.MAX_ON_SCREEN_ENEMIES can absorb.
	_dispense_interval = SpawnPacing.dispense_interval_for(data["spawn_interval"])

	_stage_timer = STAGE_DURATION

	if data["is_bonus"]:
		GameState.phase = GameState.Phase.BONUS_STAGE
		GameState.add_missiles(BONUS_MISSILE_REWARD)
	else:
		GameState.phase = GameState.Phase.PLAYING
	_show_announcement()


func _show_announcement() -> void:
	_is_announcing = true
	_announce_timer = STAGE_ANNOUNCE_DURATION


# --- Enemy spawning ---

func _dispense_next_enemy() -> void:
	if _pending_spawns.is_empty():
		_queue_next_wave()
	if _pending_spawns.is_empty():
		return

	var on_screen := get_tree().get_nodes_in_group("enemies").size()
	if on_screen >= SpawnPacing.MAX_ON_SCREEN_ENEMIES:
		return  # queued spawns wait; retried on the next tick once room opens

	var spawn_data: Array = _pending_spawns.pop_front()
	var enemy := Node.new()
	enemy.set_script(preload("res://scripts/enemies/enemy_jet_2d.gd"))
	# Add as child of Main2D so GameWorld can find via group
	get_parent().add_child(enemy)
	enemy.configure(spawn_data[0], spawn_data[1], spawn_data[2], spawn_data[3])


func _queue_next_wave() -> void:
	var wave_def := wave_definitions[_wave_index % wave_definitions.size()]
	_wave_index += 1

	var enemy_type: int = wave_def["type"]
	var count: int = wave_def["count"]
	var formation: String = wave_def["formation"]

	var positions := _calculate_formation(count, formation)
	for pos_data in positions:
		# Clamp here (not per-formation) since every formation's depth is
		# center_d + jitter and jitter alone can go negative — DESPAWN_DEPTH's
		# floor of 0.0 is the one invariant all callers share.
		_pending_spawns.append([enemy_type, pos_data[0], maxf(pos_data[1], 0.0), pos_data[2]])


# Enemies used to always spawn at logical_depth==0.0. DepthUtil's lateral
# spread factor (0.1 + d*0.9) is at its floor there, so every formation
# member — regardless of its logical_x — rendered at nearly the same screen
# x right at the horizon and only fanned out into its formation shape once
# already in flight. Concurrently, every wave entered the sky at the exact
# same size. Result (#100 gate): enemies read as a single stacked point at
# the horizon rather than the reference's spread of varied-size silhouettes.
# Randomizing each wave's center depth — and jittering each member's depth
# around it — fixes both: nonzero d gives immediate lateral separation, and
# different waves/members now enter at different points along the
# depth->scale curve, so concurrent on-screen enemies vary in size too.
const SPAWN_DEPTH_MIN := 0.05
const SPAWN_DEPTH_SPAN := 0.20


func _calculate_formation(count: int, formation: String) -> Array:
	# Returns array of [logical_x, logical_depth, x_drift]
	var result: Array = []
	var center_x: float = randf_range(-0.6, 0.6)
	var center_d: float = randf_range(SPAWN_DEPTH_MIN, SPAWN_DEPTH_MIN + SPAWN_DEPTH_SPAN)

	match formation:
		"v":
			result = _v_formation(count, center_x, center_d)
		"line":
			result = _line_formation(count, center_x, center_d)
		"scattered":
			result = _scattered_formation(count, center_x, center_d)
		_:
			result = _scattered_formation(count, center_x, center_d)

	return result


func _v_formation(count: int, cx: float, cd: float) -> Array:
	var result: Array = []
	# x_spacing/d_spacing raised (#100 round-6 gate: two stacks of 3-4 at
	# identical scale). Root cause: get_screen_scale() is a pure function of
	# depth, and DepthUtil.to_screen()'s lateral spread factor scales with
	# both x_offset AND depth, so a small FIXED x_spacing that looked fine
	# at spawn (small d, spread factor near its 0.1 floor) becomes visually
	# negligible once the formation is close (large d, spread factor near 1,
	# and the sprite's own wingspan has grown past 250px) — wingmen collapse
	# into an overlapping same-size blob right as they'd otherwise read as
	# distinct jets closing in. Old x_spacing=0.15/d_spacing=0.02 needed the
	# combined near-approach wingspan (3.1*s px) to fit inside ~2*0.15's
	# screen delta; it didn't. 0.30/0.06 keeps the V shape recognizable at
	# spawn while giving wingmen enough final-approach separation in both
	# axes to read as separate aircraft instead of stacked duplicates.
	var x_spacing := 0.30
	var d_spacing := 0.06
	# Leader
	result.append([cx, cd, randf_range(-0.05, 0.05)])
	for i in range(1, count):
		var side: float = 1.0 if i % 2 == 1 else -1.0
		var rank: int = ceili(float(i) / 2.0)
		var x: float = cx + side * rank * x_spacing
		# Left/right wingmen at the same rank used to compute the exact same
		# depth (cd + rank*d_spacing) — same input to get_screen_scale(),
		# same output, i.e. bit-identical size (the "identical within-stack
		# scale" gate finding). The side*0.02 term plus a wider per-member
		# jitter breaks that tie so no two on-screen enemies are ever an
		# exact size match, even within one rank.
		var d: float = cd + rank * d_spacing + side * 0.02 + randf_range(-0.02, 0.02)
		var drift: float = randf_range(-0.10, 0.10)
		result.append([x, d, drift])
	return result


func _line_formation(count: int, cx: float, cd: float) -> Array:
	var result: Array = []
	# spacing 0.2->0.35 and depth jitter +-0.02->+-0.06 for the same
	# collapse-at-close-range reason as _v_formation above: a line-abreast
	# formation with near-equal depth reads as one same-size row rather than
	# reference (burst-a-02/03) enemies at wildly varied depths.
	var spacing := 0.35
	var total_w: float = (count - 1) * spacing
	var start_x: float = cx - total_w / 2.0
	for i in range(count):
		var x: float = start_x + i * spacing
		var d: float = cd + randf_range(-0.06, 0.06)
		var drift: float = randf_range(-0.07, 0.07)
		result.append([x, d, drift])
	return result


func _scattered_formation(count: int, cx: float, cd: float) -> Array:
	var result: Array = []
	for i in range(count):
		var x: float = cx + randf_range(-0.5, 0.5)
		var d: float = cd + randf_range(-0.06, 0.10)
		var drift: float = randf_range(-0.12, 0.12)
		result.append([x, d, drift])
	return result
