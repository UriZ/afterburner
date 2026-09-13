extends Node2D

## Test scene for missile_2d.gd and explosion_2d.gd.
## Press SPACE to fire a missile toward the nearest target dot.
## Shows smoke trail, homing, and explosion on impact.

const SCREEN_W := 960.0
const SCREEN_H := 672.0
const HORIZON_Y := 420.0  # mirrors DepthUtil.HORIZON_Y (#108)

# Inline depth math (mirrors DepthUtil — avoids class_name dependency in test)
static func to_screen(x_offset: float, d: float) -> Vector2:
	var cx := SCREEN_W / 2.0
	var sx := cx + x_offset * (SCREEN_W * 0.47) * (0.1 + d * 0.9)
	var sy := HORIZON_Y + d * d * (SCREEN_H - HORIZON_Y) * 0.95
	return Vector2(sx, sy)

# Each target: Vector2(logical_x, logical_depth)
var _target_data: Array[Vector2] = [
	Vector2(-0.3, 0.3),
	Vector2(0.4, 0.5),
	Vector2(0.0, 0.2),
	Vector2(-0.6, 0.6),
	Vector2(0.6, 0.4),
]

var _missiles: Array = []
var _player_screen: Vector2 = Vector2(480.0, 480.0)


func _process(_delta: float) -> void:
	_missiles = _missiles.filter(func(m): return is_instance_valid(m))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_fire_missile()


func _fire_missile() -> void:
	var nearest_idx: int = -1
	var best_dist := INF
	for i in range(_target_data.size()):
		var tp: Vector2 = to_screen(_target_data[i].x, _target_data[i].y)
		var d: float = _player_screen.distance_to(tp)
		if d < best_dist:
			best_dist = d
			nearest_idx = i

	if nearest_idx < 0:
		return

	var target_lx: float = _target_data[nearest_idx].x
	var target_ld: float = _target_data[nearest_idx].y

	var missile_script: GDScript = preload("res://scripts/weapons/missile_2d.gd")
	var missile := Node2D.new()
	missile.set_script(missile_script)
	missile.logical_x = (_player_screen.x - SCREEN_W / 2.0) / (SCREEN_W * 0.47)
	missile.logical_depth = 0.9
	missile.speed = 0.7
	missile.position = _player_screen
	add_child(missile)
	_missiles.append(missile)

	# Drive homing toward the fake target
	var helper := _HomingHelper.new(missile, target_lx, target_ld)
	missile.add_child(helper)


func _draw() -> void:
	# Sky gradient
	var bands := 30
	var band_h: float = HORIZON_Y / float(bands)
	for i in range(bands):
		var t: float = float(i) / float(bands)
		var c: Color = Color(0.08, 0.12, 0.40).lerp(Color(0.45, 0.62, 0.88), t)
		draw_rect(Rect2(0.0, float(i) * band_h, SCREEN_W, band_h + 1.0), c)

	# Ground
	draw_rect(Rect2(0.0, HORIZON_Y, SCREEN_W, SCREEN_H - HORIZON_Y), Color(0.40, 0.28, 0.10))

	# Target dots
	for td in _target_data:
		var pos: Vector2 = to_screen(td.x, td.y)
		draw_circle(pos, 8.0, Color(1.0, 0.2, 0.2))
		draw_circle(pos, 4.0, Color(1.0, 0.8, 0.8))

	# Player dot
	draw_circle(_player_screen, 12.0, Color(0.2, 0.8, 1.0))

	# UI hints
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 30.0),
		"SPACE: fire missile  |  Red: targets  |  Blue: player",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 1.0, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 54.0),
		"Missiles in flight: %d" % _missiles.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 1.0, 0.4))


class _HomingHelper extends Node:
	var _missile: Node2D
	var _target_x: float
	var _target_depth: float

	func _init(m: Node2D, tx: float, td: float) -> void:
		_missile = m
		_target_x = tx
		_target_depth = td

	func _process(delta: float) -> void:
		if not is_instance_valid(_missile):
			queue_free()
			return
		_missile.logical_x = lerp(_missile.logical_x, _target_x, 4.0 * delta)
		if _missile.logical_depth <= _target_depth + 0.05 and _missile.logical_depth > 0.0:
			if _missile.has_method("explode"):
				_missile.explode()
			queue_free()
