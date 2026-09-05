extends Node3D

@export var move_speed: float = 12.0
@export var acceleration: float = 25.0
@export var deceleration: float = 20.0

const MOVE_MIN := Vector2(-6.0, 1.5)
const MOVE_MAX := Vector2(6.0, 5.5)
const BANK_DEAD_ZONE := 0.1
const BANK_SOFT_THRESHOLD := 0.4

const RESPAWN_POSITION := Vector3(0.0, 3.0, -8.0)
const DEATH_DURATION := 2.0
const INVINCIBILITY_DURATION := 2.0
const FLASH_INTERVAL := 0.1

var _velocity := Vector2.ZERO
var _input_enabled := true
var _is_dying := false
var _is_invincible := false
var _death_timer := 0.0
var _invincibility_timer := 0.0
var _flash_timer := 0.0

@onready var _sprite: Sprite3D = $JetSprite
@onready var _hit_area: Area3D = $HitArea

static var _explosion_scene: PackedScene = null


func _ready() -> void:
	add_to_group("player")
	position = RESPAWN_POSITION
	_sprite.texture = JetSpriteGenerator.generate_sprite_sheet()
	_hit_area.area_entered.connect(_on_hit_area_entered)


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


func _update_banking(horizontal_input: float) -> void:
	var frame: int
	if horizontal_input < -BANK_SOFT_THRESHOLD:
		frame = 0  # hard left
	elif horizontal_input < -BANK_DEAD_ZONE:
		frame = 1  # soft left
	elif horizontal_input > BANK_SOFT_THRESHOLD:
		frame = 4  # hard right
	elif horizontal_input > BANK_DEAD_ZONE:
		frame = 3  # soft right
	else:
		frame = 2  # center
	_sprite.frame = frame


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
	_sprite.frame = 2  # center banking frame
	_velocity = Vector2.ZERO

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
		_sprite.visible = not _sprite.visible

	if _invincibility_timer <= 0.0:
		_is_invincible = false
		_sprite.visible = true
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
