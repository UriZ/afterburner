extends Node2D

## 2D homing missile with smoke trail.
## Renders itself via _draw(). Position tracks the missile's screen position.
## Smoke trail is a ring buffer of past screen positions.

signal hit_target

const TRAIL_MAX := 40
const HOMING_DELAY := 0.3
const MAX_LIFETIME := 5.0
const LAUNCH_DEPTH := 0.9
# Fallback climb target for missiles fired without a lock (see _acquire_fallback_aim
# below) — matches vulcan_bullet_2d.gd's DEFAULT_AIM_ALTITUDE/depth-ramp-endpoint
# pair so an unlocked shot reaches this altitude by the time it's near the horizon,
# same as an unlocked vulcan round (#100 convention).
const DEFAULT_AIM_ALTITUDE := 1.0
const DEFAULT_AIM_DEPTH := 0.05

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

# Launch state
var logical_x: float = 0.0
var logical_depth: float = LAUNCH_DEPTH
var logical_altitude: float = 0.0  # player/ground baseline; homes toward target's altitude below
var speed: float = 0.8

# Target
var target: Node = null

# Fallback climb endpoint used when `target` is invalid/unset — see
# _acquire_fallback_aim(). Defaults reproduce the pre-fallback ground-hugging
# behavior only if no enemy exists at all to aim at.
var _fallback_altitude: float = DEFAULT_AIM_ALTITUDE
var _fallback_depth: float = DEFAULT_AIM_DEPTH

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
	if not is_instance_valid(target):
		_acquire_fallback_aim()


func _acquire_fallback_aim() -> void:
	# A missile fired without a weapon-lock (target == null — common since
	# locking requires LOCK_RADIUS crosshair proximity, not just "an enemy
	# exists") previously left logical_altitude pinned at its 0.0 ground-plane
	# default for its whole flight: enemies fly at altitude (#100), so the
	# unhomed missile visually dove toward/along the ground while every
	# on-screen enemy sat in the sky above it. Snapping to the nearest actual
	# enemy's altitude/depth — same approach as vulcan_bullet_2d.gd's
	# _acquire_aim_target() — makes an unlocked shot climb into the sky like
	# a locked one does, instead of never climbing at all.
	if not is_inside_tree():
		return
	var tree := get_tree()
	var best: Node = null
	var best_dx: float = INF
	for enemy in tree.get_nodes_in_group("enemies"):
		if not ("logical_x" in enemy and "logical_altitude" in enemy and "logical_depth" in enemy):
			continue
		var dx: float = absf(enemy.logical_x - logical_x)
		if dx < best_dx:
			best_dx = dx
			best = enemy
	if best != null:
		_fallback_altitude = best.logical_altitude
		_fallback_depth = best.logical_depth


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

	logical_depth -= speed * delta

	# Altitude homing (#100): enemies live at altitude, not the ground plane,
	# so the missile must climb/dive to meet the target's altitude exactly
	# when their depths coincide. Uses depth-progress, not a time-based lerp
	# — a time-based lerp can't reach a close target in time (its depth is
	# reached almost immediately after launch). Progress must be computed
	# AFTER logical_depth advances above, and must NOT wait for
	# HOMING_DELAY: a target close to launch depth has a depth window
	# smaller than what HOMING_DELAY alone burns through, so gating this on
	# the delay meant the missile had already flown past the target's depth
	# before altitude tracking ever started. X-lead below stays gated on
	# HOMING_DELAY on purpose (visual "flies straight, then turns" feel);
	# altitude has no such visual requirement — it just needs to be correct.
	if is_instance_valid(target) and "logical_altitude" in target and "logical_depth" in target:
		var span: float = maxf(LAUNCH_DEPTH - target.logical_depth, 0.001)
		var progress: float = clampf((LAUNCH_DEPTH - logical_depth) / span, 0.0, 1.0)
		logical_altitude = lerp(0.0, target.logical_altitude, progress)
	else:
		# No lock — climb toward the fallback aim point acquired at launch
		# (see _acquire_fallback_aim) instead of staying on the ground plane.
		var span: float = maxf(LAUNCH_DEPTH - _fallback_depth, 0.001)
		var progress: float = clampf((LAUNCH_DEPTH - logical_depth) / span, 0.0, 1.0)
		logical_altitude = lerp(0.0, _fallback_altitude, progress)

	# X-lead homing — delayed so the missile visibly flies straight before
	# it starts turning toward the target, matching AB2 missile feel.
	if is_instance_valid(target) and _lifetime > HOMING_DELAY:
		var target_x: float = target.logical_x if "logical_x" in target else 0.0
		logical_x = lerp(logical_x, target_x, 4.0 * delta)

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
