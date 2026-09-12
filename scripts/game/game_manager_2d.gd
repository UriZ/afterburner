extends Node

## Main game controller for the 2D sprite-scaling After Burner.
## Handles enemy spawning (waves), stage progression, and scene wiring.

const StageData := preload("res://scripts/stage/stage_data.gd")
const SpawnPacing := preload("res://scripts/game/spawn_pacing.gd")

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
var _announce_label: Label = null


func _ready() -> void:
	# If launched directly (not from title screen), ensure phase is PLAYING
	if GameState.phase == GameState.Phase.TITLE:
		GameState.phase = GameState.Phase.PLAYING
	_create_announce_label()
	_apply_stage(GameState.current_stage)
	_dispense_timer = 0.0  # start dispensing immediately when announcement clears


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING and GameState.phase != GameState.Phase.BONUS_STAGE:
		return

	# Stage announcement
	if _is_announcing:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_is_announcing = false
			_announce_label.visible = false
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

	# Update GameWorld sky/ground colors
	var game_world: Node2D = get_parent().get_node_or_null("GameWorld")
	if game_world:
		game_world.sky_top_color = data["sky_top"]
		game_world.sky_horizon_color = data["sky_horizon"]
		game_world.ground_color_a = data["ground_a"]
		game_world.ground_color_b = data["ground_b"]

	# Update spawn difficulty — later/harder stages dispense enemies more often,
	# but always within a band that SpawnPacing.MAX_ON_SCREEN_ENEMIES can absorb.
	_dispense_interval = SpawnPacing.dispense_interval_for(data["spawn_interval"])

	_stage_timer = STAGE_DURATION

	if data["is_bonus"]:
		GameState.phase = GameState.Phase.BONUS_STAGE
		GameState.add_missiles(BONUS_MISSILE_REWARD)
		_show_announcement("BONUS STAGE")
	else:
		GameState.phase = GameState.Phase.PLAYING
		_show_announcement("STAGE %02d" % stage_number)


func _show_announcement(text: String) -> void:
	_announce_label.text = text
	_announce_label.visible = true
	_is_announcing = true
	_announce_timer = STAGE_ANNOUNCE_DURATION


func _create_announce_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	canvas.name = "StageAnnounceLayer"
	add_child(canvas)

	_announce_label = Label.new()
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce_label.anchors_preset = Control.PRESET_FULL_RECT
	_announce_label.anchor_right = 1.0
	_announce_label.anchor_bottom = 1.0

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Courier", "monospace"])
	_announce_label.add_theme_font_override("font", font)
	_announce_label.add_theme_font_size_override("font_size", 48)
	_announce_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_announce_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_announce_label.add_theme_constant_override("shadow_offset_x", 3)
	_announce_label.add_theme_constant_override("shadow_offset_y", 3)
	_announce_label.visible = false
	canvas.add_child(_announce_label)


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
		_pending_spawns.append([enemy_type, pos_data[0], pos_data[1], pos_data[2]])


func _calculate_formation(count: int, formation: String) -> Array:
	# Returns array of [logical_x, logical_depth, x_drift]
	var result: Array = []
	var center_x: float = randf_range(-0.6, 0.6)

	match formation:
		"v":
			result = _v_formation(count, center_x)
		"line":
			result = _line_formation(count, center_x)
		"scattered":
			result = _scattered_formation(count, center_x)
		_:
			result = _scattered_formation(count, center_x)

	return result


func _v_formation(count: int, cx: float) -> Array:
	var result: Array = []
	var x_spacing := 0.15
	var d_spacing := 0.03
	# Leader
	result.append([cx, 0.0, randf_range(-0.05, 0.05)])
	for i in range(1, count):
		var side: float = 1.0 if i % 2 == 1 else -1.0
		var rank: int = ceili(float(i) / 2.0)
		var x: float = cx + side * rank * x_spacing
		var d: float = -rank * d_spacing  # slightly behind
		var drift: float = randf_range(-0.08, 0.08)
		result.append([x, maxf(d, 0.0), drift])
	return result


func _line_formation(count: int, cx: float) -> Array:
	var result: Array = []
	var spacing := 0.2
	var total_w: float = (count - 1) * spacing
	var start_x: float = cx - total_w / 2.0
	for i in range(count):
		var x: float = start_x + i * spacing
		var drift: float = randf_range(-0.05, 0.05)
		result.append([x, 0.0, drift])
	return result


func _scattered_formation(count: int, cx: float) -> Array:
	var result: Array = []
	for i in range(count):
		var x: float = cx + randf_range(-0.4, 0.4)
		var d: float = randf_range(0.0, 0.05)
		var drift: float = randf_range(-0.12, 0.12)
		result.append([x, d, drift])
	return result
