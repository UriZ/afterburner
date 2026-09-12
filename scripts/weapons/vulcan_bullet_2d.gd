extends Node2D

## 2D vulcan cannon bullet using sprite-scaling depth system.
## Starts near player (depth ~0.9), flies toward horizon (depth 0.0).
## Renders as a small bright dot that shrinks with depth.

const BULLET_SPEED := 3.5  # depth units per second — reaches mid-screen in ~0.3s
const MIN_DEPTH := 0.05    # despawn threshold
const SCREEN_W := 960.0

var logical_x: float = 0.0
var logical_depth: float = 0.9
var aim_x: float = 0.0  # logical x of crosshair target


func _ready() -> void:
	add_to_group("player_bullets")


func get_screen_position() -> Vector2:
	var cx := SCREEN_W * 0.5
	var sx := cx + logical_x * (SCREEN_W * 0.47) * (0.1 + logical_depth * 0.9)
	var sy := 268.8 + logical_depth * logical_depth * (672.0 - 268.8) * 0.95
	return Vector2(sx, sy)


func get_collision_radius() -> float:
	return (0.03 + logical_depth * logical_depth * 3.0) * 8.0


func _process(delta: float) -> void:
	# Drift toward aim_x as bullet travels (converging fire)
	logical_x = lerp(logical_x, aim_x, 4.0 * delta)
	logical_depth -= BULLET_SPEED * delta

	var sp := get_screen_position()
	if logical_depth < MIN_DEPTH or sp.x < 0.0 or sp.x > SCREEN_W or sp.y < 0.0:
		queue_free()
		return

	position = sp
	queue_redraw()


func _draw() -> void:
	var sc: float = 0.03 + logical_depth * logical_depth * 3.0
	var radius := maxf(1.0, sc * 8.0)
	# Outer glow
	draw_circle(Vector2.ZERO, radius * 1.8, Color(1.0, 1.0, 0.6, 0.35))
	# Core bright dot
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 0.9, 1.0))
