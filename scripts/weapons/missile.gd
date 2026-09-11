extends Area3D

## A homing missile that tracks toward a target position.
## If no target is set, it flies straight into the screen.

const ExplosionScene := preload("res://scenes/effects/explosion.tscn")

const SPEED := 45.0
const TURN_SPEED_INITIAL := 1.5   # sluggish launch arc for first 0.3s
const TURN_SPEED_HOMING := 6.0    # aggressive homing after initial arc
const HOMING_DELAY := 0.3         # seconds before full homing kicks in
const MAX_LIFETIME := 5.0
const SCALE_RATE := 2.0

var target: Node3D = null
var _velocity := Vector3(0, 0, -1)
var _lifetime := 0.0
var _initial_scale := Vector3.ONE
var _start_position := Vector3.ZERO


func _ready() -> void:
	_initial_scale = scale
	_start_position = global_position
	if is_instance_valid(target):
		var to_target := (target.global_position - global_position).normalized()
		_velocity = (Vector3(0, 0, -1) * 0.4 + to_target * 0.6).normalized()
	else:
		_velocity = Vector3(0, 0, -1)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_lifetime += delta

	if _lifetime >= MAX_LIFETIME:
		queue_free()
		return

	if is_instance_valid(target):
		var turn := TURN_SPEED_INITIAL if _lifetime < HOMING_DELAY else TURN_SPEED_HOMING
		var to_target := (target.global_position - global_position).normalized()
		_velocity = _velocity.lerp(to_target, turn * delta).normalized()

	position += _velocity * SPEED * delta

	var dist := global_position.distance_to(_start_position)
	var t := dist / (SPEED * MAX_LIFETIME)
	var s := maxf(1.0 - t * SCALE_RATE, 0.1)
	scale = _initial_scale * s


func _on_area_entered(area: Area3D) -> void:
	if area.collision_layer & 4 and area.has_method("take_damage"):
		area.take_damage(1)
	_spawn_explosion()
	queue_free()


func _spawn_explosion() -> void:
	var explosion := ExplosionScene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
