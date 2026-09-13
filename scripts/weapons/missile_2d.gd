extends Node2D

## 2D homing missile with smoke trail.
## Renders itself via _draw(). Position tracks the missile's screen position.
## Smoke trail is a ring buffer of past screen positions.

signal hit_target

const TRAIL_MAX := 40
const HOMING_DELAY := 0.3
const MAX_LIFETIME := 5.0
const LAUNCH_DEPTH := 0.9

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

# Launch state
var logical_x: float = 0.0
var logical_depth: float = LAUNCH_DEPTH
var logical_altitude: float = 0.0  # player/ground baseline; homes toward target's altitude below
var speed: float = 0.8

# Target
var target: Node = null

# Pylon offset (local space, applied at launch)
var pylon_offset: Vector2 = Vector2.ZERO

# Internal
var _lifetime: float = 0.0
var _frame_count: int = 0
var _trail: PackedVector2Array = PackedVector2Array()
var _trail_write: int = 0
var _trail_count: int = 0


func _ready() -> void:
	add_to_group("missiles")
	_trail.resize(TRAIL_MAX)
	for i in range(TRAIL_MAX):
		_trail[i] = Vector2.ZERO


func get_screen_position() -> Vector2:
	return _DepthUtil.to_screen(logical_x, logical_depth, logical_altitude)


func get_collision_radius() -> float:
	return _DepthUtil.depth_to_scale(logical_depth) * 15.0


func explode() -> void:
	_spawn_explosion()
	emit_signal("hit_target")
	queue_free()


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime > MAX_LIFETIME or logical_depth < -0.1:
		queue_free()
		return

	# Sample position every 2 frames for trail
	_frame_count += 1
	if _frame_count % 2 == 0:
		_trail[_trail_write] = get_screen_position()
		_trail_write = (_trail_write + 1) % TRAIL_MAX
		_trail_count = mini(_trail_count + 1, TRAIL_MAX)

	# Homing toward target — enemies live at altitude, not the ground plane
	# (#100). X still homes with a time-based lerp (the target drifts
	# laterally, so continuously re-aiming makes sense). Altitude uses
	# depth-progress instead: a time-based lerp can't reach a close target
	# in time (its depth is reached almost immediately after launch), so
	# convergence is tied to how much of the launch-to-target depth span has
	# been closed — that reaches the target's exact altitude precisely when
	# logical_depth reaches the target's depth, however little time that took.
	if is_instance_valid(target) and _lifetime > HOMING_DELAY:
		var target_x: float = target.logical_x if "logical_x" in target else 0.0
		logical_x = lerp(logical_x, target_x, 4.0 * delta)
		if "logical_altitude" in target and "logical_depth" in target:
			var span: float = maxf(LAUNCH_DEPTH - target.logical_depth, 0.001)
			var progress: float = clampf((LAUNCH_DEPTH - logical_depth) / span, 0.0, 1.0)
			logical_altitude = lerp(0.0, target.logical_altitude, progress)

	logical_depth -= speed * delta
	position = get_screen_position()
	queue_redraw()


func _draw() -> void:
	_draw_trail()
	_draw_body()


func _draw_trail() -> void:
	if _trail_count == 0:
		return

	for i in range(_trail_count):
		var sample_idx: int = (_trail_write - _trail_count + i + TRAIL_MAX) % TRAIL_MAX
		var pos: Vector2 = _trail[sample_idx] - position

		# tip_idx=0 is newest (nearest missile tip), tip_idx=max is oldest (tail)
		var tip_idx: int = _trail_count - 1 - i
		var inv_frac: float = float(tip_idx) / float(TRAIL_MAX)

		var r: float = 3.0 + inv_frac * 9.0
		var a: float = 0.95 * pow(1.0 - inv_frac, 1.5)

		var color: Color
		if tip_idx <= 8:
			color = Color(1.0, 1.0, 1.0, a)
		elif tip_idx <= 20:
			color = Color(0.95, 0.91, 0.88, a)
		else:
			color = Color(0.80, 0.78, 0.75, a)

		if a > 0.01:
			draw_circle(pos, maxf(r, 1.0), color)


func _draw_body() -> void:
	# t: 0=just launched (near player), 1=at horizon
	var t: float = clampf(1.0 - logical_depth / 0.9, 0.0, 1.0)
	var w: float = maxf(1.0, 5.0 * (1.0 - t))
	var h: float = maxf(2.0, 14.0 * (1.0 - t))

	var body_poly: PackedVector2Array = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5),
		Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5),
		Vector2(-w * 0.5, h * 0.5),
	])
	draw_colored_polygon(body_poly, Color(0.784, 0.784, 0.831))
	draw_line(Vector2(0.0, -h * 0.5), Vector2(0.0, h * 0.5), Color(1.0, 1.0, 1.0), 1.0)

	if w >= 2.0:
		draw_circle(Vector2(0.0, -h * 0.5), 2.0, Color(1.0, 0.910, 0.541))


func _spawn_explosion() -> void:
	var explosion_script: GDScript = preload("res://scripts/effects/explosion_2d.gd")
	var explosion := Node2D.new()
	explosion.set_script(explosion_script)
	explosion.position = get_screen_position()
	var base_r: float = _DepthUtil.depth_to_scale(logical_depth) * 80.0
	explosion.set("base_radius", maxf(base_r, 30.0))
	get_parent().add_child(explosion)
