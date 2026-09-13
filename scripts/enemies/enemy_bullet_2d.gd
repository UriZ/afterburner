extends Node

## Enemy bullet fired by enemy_jet_2d. Advances toward camera (increasing depth)
## and drifts toward the player's captured screen position. Starts at the
## firer's altitude and decays it toward 0 (player/ground level) — the firer
## lives in the sky (#100), the player doesn't, so the shot must visually
## descend from one to the other instead of holding a fixed altitude.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")
const ALTITUDE_DECAY_RATE := 6.0  # fast enough to reach ~0 well before despawn

var logical_x: float = 0.0
var logical_depth: float = 0.0
var logical_altitude: float = 0.0
var speed: float = 0.6
var target_screen_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemy_bullets")


func _process(delta: float) -> void:
	logical_depth += speed * delta
	var target_logical_x: float = (target_screen_pos.x - _DepthUtil.SCREEN_W / 2.0) / (_DepthUtil.SCREEN_W * 0.47)
	logical_x = lerp(logical_x, target_logical_x, 2.0 * delta)
	logical_altitude = lerp(logical_altitude, 0.0, ALTITUDE_DECAY_RATE * delta)
	if logical_depth > 1.3:
		queue_free()


func get_screen_position() -> Vector2:
	return _DepthUtil.to_screen(logical_x, logical_depth, logical_altitude)


func get_collision_radius() -> float:
	return _DepthUtil.scale_pixels(logical_depth, 10.0)
