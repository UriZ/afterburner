extends Node2D

## 2D vulcan cannon bullet using sprite-scaling depth system.
## Starts near player (depth ~0.9), flies toward horizon (depth 0.0).
## Renders as a small bright dot that shrinks with depth.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

const BULLET_SPEED := 3.5  # depth units per second — reaches mid-screen in ~0.3s
const MIN_DEPTH := 0.05    # despawn threshold
const LAUNCH_DEPTH := 0.9
const SCREEN_W := _DepthUtil.SCREEN_W
# Vulcan has no locked target (unlike missile_2d.gd) — it fires along the
# sight line, and weapon_manager_2d.gd doesn't forward the crosshair's
# vertical aim. Falls back to this altitude, ramped over the bullet's whole
# depth sweep, when no enemy is found near the sight line at spawn (#100).
const DEFAULT_AIM_ALTITUDE := 1.0

var logical_x: float = 0.0
var logical_depth: float = LAUNCH_DEPTH
var logical_altitude: float = 0.0
var aim_x: float = 0.0  # logical x of crosshair target
var aim_altitude: float = DEFAULT_AIM_ALTITUDE
var _aim_target_depth: float = MIN_DEPTH  # depth-progress ramp endpoint, see _process()


func _ready() -> void:
	add_to_group("player_bullets")
	_acquire_aim_target()


func _acquire_aim_target() -> void:
	# Enemies fly at altitude (#100). A time-based ramp toward a fixed
	# altitude can't reach a close, high-flying enemy in time — by the time
	# it's aimed high enough, the bullet's own depth has already swept past
	# where the enemy is. Snapping the ramp's endpoint to the nearest actual
	# enemy's altitude AND depth means logical_altitude below reaches that
	# enemy's altitude exactly when logical_depth reaches its depth,
	# regardless of how little flight time that takes.
	var tree := get_tree()
	if tree == null:
		return
	var best: Node = null
	var best_dx: float = INF
	for enemy in tree.get_nodes_in_group("enemies"):
		if not ("logical_x" in enemy and "logical_altitude" in enemy and "logical_depth" in enemy):
			continue
		var dx: float = absf(enemy.logical_x - aim_x)
		if dx < best_dx:
			best_dx = dx
			best = enemy
	if best != null:
		aim_altitude = best.logical_altitude
		_aim_target_depth = best.logical_depth


func get_screen_position() -> Vector2:
	return _DepthUtil.to_screen(logical_x, logical_depth, logical_altitude)


func get_collision_radius() -> float:
	return _DepthUtil.depth_to_scale(logical_depth) * 8.0


func _process(delta: float) -> void:
	# Drift toward aim_x as bullet travels (converging fire)
	logical_x = lerp(logical_x, aim_x, 4.0 * delta)
	var span: float = maxf(LAUNCH_DEPTH - _aim_target_depth, 0.001)
	var progress: float = clampf((LAUNCH_DEPTH - logical_depth) / span, 0.0, 1.0)
	logical_altitude = lerp(0.0, aim_altitude, progress)
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
