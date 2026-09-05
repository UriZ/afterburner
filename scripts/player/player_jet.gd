extends Node3D

@export var move_speed: float = 12.0
@export var acceleration: float = 25.0
@export var deceleration: float = 20.0

const MOVE_MIN := Vector2(-6.0, 1.5)
const MOVE_MAX := Vector2(6.0, 5.5)
const BANK_DEAD_ZONE := 0.1
const BANK_SOFT_THRESHOLD := 0.4

var _velocity := Vector2.ZERO
@onready var _sprite: Sprite3D = $JetSprite


func _ready() -> void:
	position = Vector3(0.0, 3.0, -8.0)
	_sprite.texture = JetSpriteGenerator.generate_sprite_sheet()


func _process(delta: float) -> void:
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
