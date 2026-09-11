extends Node3D

@export var move_speed: float = 32.0
@export var acceleration: float = 80.0
@export var deceleration: float = 60.0

# Camera at (0,5,0) with 5deg downward tilt, FOV 70 (vertical), aspect 16:9.
# Jet at Z=-8.0. Godot FOV is vertical: half-angle=35deg, tan(35deg)=0.700.
# At depth 8: vertical half=5.6, horizontal half=5.6*(16/9)=9.96.
# Screen center Y ≈ 5 - tan(5deg)*8 = 4.3.
# Full vertical range: 4.3 ± 5.6 = (-1.3, 9.9). Extended bounds for better reach.
# Full horizontal range: ±9.96. 85% → ±8.5.
const MOVE_MIN := Vector2(-8.5, 0.2)
const MOVE_MAX := Vector2(8.5, 8.5)
const BANK_DEAD_ZONE := 0.1
const BANK_SOFT_THRESHOLD := 0.4

const RESPAWN_POSITION := Vector3(0.0, 2.5, -8.0)
const DEATH_DURATION := 2.0
const INVINCIBILITY_DURATION := 4.0
const FLASH_INTERVAL := 0.1

var _velocity := Vector2.ZERO
var _input_enabled := true
var _is_dying := false
var _is_invincible := false
var _death_timer := 0.0
var _invincibility_timer := 0.0
var _flash_timer := 0.0
var _camera: Camera3D
var _jet_mesh: Node3D
var _central_flame: MeshInstance3D
var _central_flame_mid: MeshInstance3D
var _central_flame_glow: MeshInstance3D

@onready var _hit_area: Area3D = $HitArea

static var _explosion_scene: PackedScene = null


func _ready() -> void:
	add_to_group("player")
	position = RESPAWN_POSITION
	# Build 3D mesh jet at runtime
	var Builder := preload("res://scripts/player/jet_mesh_builder.gd")
	_jet_mesh = Builder.build_player_jet()
	add_child(_jet_mesh)
	_central_flame = _jet_mesh.get_node("CentralFlameCore")
	_central_flame_mid = _jet_mesh.get_node("CentralFlameMid")
	_central_flame_glow = _jet_mesh.get_node("CentralFlameGlow")
	_hit_area.area_entered.connect(_on_hit_area_entered)
	# Grant invincibility at game start so the player isn't killed immediately
	_is_invincible = true
	_invincibility_timer = 6.0
	_hit_area.collision_mask = 0
	_camera = get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	if _is_dying:
		_process_death(delta)
		return

	if _is_invincible:
		_process_invincibility(delta)

	if _input_enabled:
		var input := _get_input_vector()
		_update_velocity(input, delta)
		_apply_movement(delta)
		_update_banking(input.x)

	# Pulse afterburner flames
	var pulse := 0.8 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
	if _central_flame:
		_central_flame.scale = Vector3(pulse, pulse, pulse)
	if _central_flame_mid:
		_central_flame_mid.scale = Vector3(pulse, pulse, pulse)
	if _central_flame_glow:
		_central_flame_glow.scale = Vector3(pulse, pulse, pulse)


func _get_input_vector() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up")
	)


func _update_velocity(input: Vector2, delta: float) -> void:
	var target_velocity := input * move_speed
	for axis in 2:
		var rate: float
		if abs(input[axis]) > 0.01:
			rate = acceleration
		else:
			rate = deceleration
		_velocity[axis] = move_toward(
			_velocity[axis], target_velocity[axis], rate * delta
		)


func _apply_movement(delta: float) -> void:
	position.x += _velocity.x * delta
	position.y += _velocity.y * delta
	position.x = clampf(position.x, MOVE_MIN.x, MOVE_MAX.x)
	position.y = clampf(position.y, MOVE_MIN.y, MOVE_MAX.y)

	# Subtle camera parallax: shift opposite to player for depth illusion
	if _camera:
		var norm_x := position.x / MOVE_MAX.x
		var norm_y := (position.y - 4.3) / (MOVE_MAX.y - 4.3)
		var target_cx := -norm_x * 0.4
		var target_cy := 5.0 - norm_y * 0.3
		_camera.position.x = move_toward(_camera.position.x, target_cx, 2.0 * delta)
		_camera.position.y = move_toward(_camera.position.y, target_cy, 2.0 * delta)


func _update_banking(horizontal_input: float) -> void:
	# Bank the 3D mesh based on horizontal input
	var target_bank := -horizontal_input * 55.0
	_jet_mesh.rotation_degrees.z = move_toward(
		_jet_mesh.rotation_degrees.z, target_bank, 320.0 * get_process_delta_time()
	)

	if _camera:
		var target_roll := -horizontal_input * 8.0
		_camera.rotation_degrees.z = move_toward(
			_camera.rotation_degrees.z, target_roll, 100.0 * get_process_delta_time()
		)


func _on_hit_area_entered(area: Area3D) -> void:
	if _is_dying or _is_invincible:
		return

	# Check if hit by enemy (layer 3 = bit 4) or enemy bullet (layer 4 = bit 8)
	if area.collision_layer & 12:  # layers 3 or 4
		# If it's an enemy bullet, free it
		if area.collision_layer & 8:
			area.queue_free()
		# If it's an enemy, deal damage to it too
		if area.collision_layer & 4 and area.has_method("take_damage"):
			area.take_damage(1)
		_start_death()


func _start_death() -> void:
	var has_lives := GameState.lose_life()
	_is_dying = true
	_input_enabled = false
	_death_timer = DEATH_DURATION
	_velocity = Vector2.ZERO

	# Disable collision during death
	_hit_area.collision_mask = 0

	if not has_lives:
		_game_over()


func _process_death(delta: float) -> void:
	_death_timer -= delta

	# Tumble animation: rotate and fall toward the ground
	rotation_degrees.z += 360.0 * delta
	rotation_degrees.x += 90.0 * delta
	position.y -= 3.0 * delta

	if _death_timer <= 0.0:
		_spawn_explosion()
		if GameState.lives >= 0:
			_respawn()
		else:
			# Game over: hide the player
			visible = false
			_is_dying = false


func _respawn() -> void:
	_is_dying = false
	_input_enabled = true
	position = RESPAWN_POSITION
	rotation_degrees = Vector3.ZERO
	_jet_mesh.rotation_degrees = Vector3.ZERO
	_velocity = Vector2.ZERO
	if _camera:
		_camera.rotation_degrees.z = 0.0
		_camera.position = Vector3(0.0, 5.0, 0.0)

	# Start invincibility
	_is_invincible = true
	_invincibility_timer = INVINCIBILITY_DURATION
	_flash_timer = 0.0
	# During invincibility, don't collide with enemies/bullets
	_hit_area.collision_mask = 0


func _process_invincibility(delta: float) -> void:
	_invincibility_timer -= delta
	_flash_timer -= delta

	# Flash the sprite to indicate invincibility
	if _flash_timer <= 0.0:
		_flash_timer = FLASH_INTERVAL
		_jet_mesh.visible = not _jet_mesh.visible

	if _invincibility_timer <= 0.0:
		_is_invincible = false
		_jet_mesh.visible = true
		# Re-enable collision: mask layers 3 (enemies) + 4 (enemy bullets) = 12
		_hit_area.collision_mask = 12


func _spawn_explosion() -> void:
	if _explosion_scene == null:
		_explosion_scene = load("res://scenes/effects/explosion.tscn")
	var explosion := _explosion_scene.instantiate()
	explosion.position = position
	get_parent().add_child(explosion)


func _game_over() -> void:
	GameState.phase = GameState.Phase.GAME_OVER
	# Stop enemy spawning
	var spawner := get_parent().get_node_or_null("EnemySpawner")
	if spawner:
		spawner.enabled = false
	# Show game over label
	_show_game_over_label()


func _show_game_over_label() -> void:
	var label := Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.anchors_preset = Control.PRESET_FULL_RECT
	# Add through a CanvasLayer so it renders on screen
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(label)
	get_tree().root.add_child(canvas)
