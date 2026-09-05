extends Area3D

## A homing missile that tracks toward a target position.
## If no target is set, it flies straight into the screen.

const SPEED := 40.0
const TURN_SPEED := 4.0  # how fast it turns toward the target (radians-ish lerp weight)
const MAX_LIFETIME := 5.0
const SCALE_RATE := 2.0

var target: Node3D = null
var _velocity := Vector3(0, 0, -1)  # initial direction: into the screen
var _lifetime := 0.0
var _initial_scale := Vector3.ONE
var _start_position := Vector3.ZERO


func _ready() -> void:
	_initial_scale = scale
	_start_position = global_position
	_velocity = Vector3(0, 0, -1).normalized()


func _process(delta: float) -> void:
	_lifetime += delta

	if _lifetime >= MAX_LIFETIME:
		queue_free()
		return

	# Home toward target if one exists and is still valid
	if is_instance_valid(target):
		var to_target := (target.global_position - global_position).normalized()
		_velocity = _velocity.lerp(to_target, TURN_SPEED * delta).normalized()

	position += _velocity * SPEED * delta

	# Scale down as it flies away (distance from camera/start)
	var dist := global_position.distance_to(_start_position)
	var t := dist / (SPEED * MAX_LIFETIME)
	var s := maxf(1.0 - t * SCALE_RATE, 0.1)
	scale = _initial_scale * s
