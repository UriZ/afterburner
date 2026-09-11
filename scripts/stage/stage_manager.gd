extends Node

## Manages stage progression through 23 stages.
## Controls ground/sky colors, enemy difficulty, and stage transitions.

signal stage_started(stage_number: int)
signal bonus_stage_started(stage_number: int)

const StageData := preload("res://scripts/stage/stage_data.gd")

const STAGE_DURATION := 30.0  # seconds per stage
const STAGE_ANNOUNCE_DURATION := 2.0  # how long "STAGE XX" text shows
const BONUS_MISSILE_REWARD := 30

## Node references — set via _ready() by finding siblings in the scene tree.
var _ground: MeshInstance3D
var _environment: WorldEnvironment
var _enemy_spawner: Node3D

var _stage_timer: float = 0.0
var _announce_timer: float = 0.0
var _is_announcing: bool = false

## The overlay label for stage announcements, created at runtime.
var _announce_label: Label


func _ready() -> void:
	_ground = get_parent().get_node_or_null("Ground")
	_environment = get_parent().get_node_or_null("WorldEnvironment")
	_enemy_spawner = get_parent().get_node_or_null("EnemySpawner")
	_create_announce_label()
	_apply_stage(GameState.current_stage)


func _create_announce_label() -> void:
	# Create a CanvasLayer + Label for stage announcements
	var canvas := CanvasLayer.new()
	canvas.layer = 15  # above HUD
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


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING and GameState.phase != GameState.Phase.BONUS_STAGE:
		return

	# Handle announcement display
	if _is_announcing:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_is_announcing = false
			_announce_label.visible = false
		return  # Don't tick stage timer during announcement

	_stage_timer -= delta
	if _stage_timer <= 0.0:
		_advance_stage()


func _advance_stage() -> void:
	var next_stage := GameState.current_stage + 1
	if next_stage > StageData.stage_count():
		# Game complete — could loop or end. For now, loop back to 1.
		next_stage = 1

	GameState.current_stage = next_stage
	_apply_stage(next_stage)


func _apply_stage(stage_number: int) -> void:
	var data := StageData.get_stage(stage_number)

	# Apply ground shader colors
	if _ground and _ground.material_override is ShaderMaterial:
		var mat := _ground.material_override as ShaderMaterial
		mat.set_shader_parameter("color_a", data["ground_a"])
		mat.set_shader_parameter("color_b", data["ground_b"])
		mat.set_shader_parameter("sky_haze_color", data["sky_horizon"])

	# Apply sky shader colors via Environment Sky material
	if _environment and _environment.environment:
		var sky: Sky = _environment.environment.sky
		if sky and sky.sky_material is ShaderMaterial:
			var mat := sky.sky_material as ShaderMaterial
			mat.set_shader_parameter("color_top", data["sky_top"])
			mat.set_shader_parameter("color_horizon", data["sky_horizon"])

	# Apply difficulty to enemy spawner
	if _enemy_spawner:
		_enemy_spawner.spawn_interval = data["spawn_interval"]

	_stage_timer = STAGE_DURATION

	# Handle bonus stages
	if data["is_bonus"]:
		GameState.phase = GameState.Phase.BONUS_STAGE
		GameState.add_missiles(BONUS_MISSILE_REWARD)
		_show_announcement("BONUS STAGE")
		bonus_stage_started.emit(stage_number)
	else:
		GameState.phase = GameState.Phase.PLAYING
		_show_announcement("STAGE %02d" % stage_number)
		stage_started.emit(stage_number)


func _show_announcement(text: String) -> void:
	_announce_label.text = text
	_announce_label.visible = true
	_is_announcing = true
	_announce_timer = STAGE_ANNOUNCE_DURATION
