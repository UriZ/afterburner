extends Area3D

## A single vulcan cannon bullet that flies into the screen (-Z direction),
## scaling down to simulate depth, and auto-frees after max range.

const SPEED := 80.0
const MAX_DISTANCE := 200.0
const SCALE_RATE := 3.0  # how fast it shrinks as it flies away

var _distance_traveled := 0.0
var _initial_scale := Vector3.ONE


func _ready() -> void:
	_initial_scale = scale


func _process(delta: float) -> void:
	var move_amount := SPEED * delta
	position.z -= move_amount
	_distance_traveled += move_amount

	# Scale down to simulate flying into the distance
	var t := _distance_traveled / MAX_DISTANCE
	var s := maxf(1.0 - t * SCALE_RATE, 0.05)
	scale = _initial_scale * s

	if _distance_traveled >= MAX_DISTANCE:
		queue_free()
