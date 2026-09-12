extends Node2D

# Super Scaler demo — AB2-style sprite scaling with banking

var enemies: Array = []
var player_pos := Vector2(480, 480)
var bank_angle: float = 0.0  # current bank in degrees
var input_x: float = 0.0
var wave_timer: float = 0.0

class FakeEnemy:
	var x_offset: float
	var depth: float
	var speed: float
	var lane: float  # drift direction

	func _init(x: float, spd: float, dr: float = 0.0):
		x_offset = x
		depth = 0.0
		speed = spd
		lane = dr

func _ready():
	_spawn_wave()

func _spawn_wave():
	enemies.append(FakeEnemy.new(-0.4, 0.35, 0.05))
	enemies.append(FakeEnemy.new(-0.1, 0.4, -0.02))
	enemies.append(FakeEnemy.new(0.15, 0.38, 0.03))
	enemies.append(FakeEnemy.new(0.35, 0.32, -0.04))
	enemies.append(FakeEnemy.new(0.0, 0.45, 0.0))

func _process(delta: float):
	# Move enemies
	for e in enemies:
		e.depth += e.speed * delta
		var drift: float = e.lane
		e.x_offset += drift * delta

	enemies = enemies.filter(func(e): return e.depth < 1.3)

	wave_timer += delta
	if wave_timer > 2.5:
		wave_timer = 0.0
		_spawn_wave()

	# Player input
	var ix: float = 0.0
	var iy: float = 0.0
	if Input.is_action_pressed("move_left"): ix -= 1.0
	if Input.is_action_pressed("move_right"): ix += 1.0
	if Input.is_action_pressed("move_up"): iy -= 1.0
	if Input.is_action_pressed("move_down"): iy += 1.0

	input_x = lerp(input_x, ix, 8.0 * delta)
	player_pos.x += input_x * 500.0 * delta
	player_pos.y += iy * 350.0 * delta
	player_pos.x = clamp(player_pos.x, 80, 880)
	player_pos.y = clamp(player_pos.y, 280, 560)

	# Banking — fast roll into bank, slower roll out
	var target_bank: float = -input_x * 45.0
	bank_angle = lerp(bank_angle, target_bank, 10.0 * delta)

	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	queue_redraw()

func _draw():
	var sw: float = 960.0
	var sh: float = 600.0
	var horizon: float = 240.0

	# Sky
	for i in range(50):
		var t: float = float(i) / 50.0
		var c := Color(0.15 + t * 0.4, 0.2 + t * 0.35, 0.65 + t * 0.25)
		draw_rect(Rect2(0, i * (horizon / 50.0), sw, horizon / 50.0 + 1), c)

	# Ground — perspective stripes that scroll
	var scroll: float = fmod(Engine.get_frames_drawn() * 0.8, 60.0)
	for i in range(80):
		var raw: float = float(i) + scroll
		var t: float = float(i) / 80.0
		var y_start: float = horizon + t * t * (sh - horizon)
		var t2: float = (float(i) + 1.0) / 80.0
		var y_end: float = horizon + t2 * t2 * (sh - horizon)
		var c: Color
		if int(raw) % 2 == 0:
			c = Color(0.65, 0.45, 0.25)
		else:
			c = Color(0.55, 0.38, 0.2)
		draw_rect(Rect2(0, y_start, sw, y_end - y_start + 1), c)

	# Enemies sorted far-to-near
	var sorted: Array = enemies.duplicate()
	sorted.sort_custom(func(a, b): return a.depth < b.depth)
	for e in sorted:
		_draw_enemy(e, horizon, sw)

	# Player jet with banking
	_draw_player(player_pos, bank_angle)

func _draw_enemy(e, horizon: float, sw: float) -> void:
	var d: float = e.depth
	var xo: float = e.x_offset
	var sc: float = 0.03 + d * d * 3.0
	var cx: float = sw / 2.0
	var sx: float = cx + xo * 450.0 * (0.1 + d * 0.9)
	var sy: float = horizon + d * d * 320.0
	var s: float = sc * 35.0

	if s < 1.5:
		# Tiny dot at distance
		draw_circle(Vector2(sx, sy), maxf(1.0, s * 0.5), Color(0.95, 0.15, 0.1))
		return

	# Fuselage
	draw_polygon(PackedVector2Array([
		Vector2(sx, sy - s * 1.0),
		Vector2(sx + s * 0.25, sy),
		Vector2(sx + s * 0.15, sy + s * 0.4),
		Vector2(sx - s * 0.15, sy + s * 0.4),
		Vector2(sx - s * 0.25, sy),
	]), [Color(0.92, 0.18, 0.1)])

	# Wings
	draw_polygon(PackedVector2Array([
		Vector2(sx - s * 0.15, sy - s * 0.05),
		Vector2(sx - s * 1.4, sy + s * 0.25),
		Vector2(sx - s * 1.1, sy + s * 0.4),
		Vector2(sx - s * 0.1, sy + s * 0.15),
	]), [Color(0.85, 0.14, 0.08)])
	draw_polygon(PackedVector2Array([
		Vector2(sx + s * 0.15, sy - s * 0.05),
		Vector2(sx + s * 1.4, sy + s * 0.25),
		Vector2(sx + s * 1.1, sy + s * 0.4),
		Vector2(sx + s * 0.1, sy + s * 0.15),
	]), [Color(0.85, 0.14, 0.08)])

	# Yellow canopy
	if s > 8:
		draw_polygon(PackedVector2Array([
			Vector2(sx, sy - s * 0.6),
			Vector2(sx + s * 0.1, sy - s * 0.3),
			Vector2(sx - s * 0.1, sy - s * 0.3),
		]), [Color(0.95, 0.8, 0.2)])

func _draw_player(pos: Vector2, bank: float) -> void:
	# Transform all points by bank angle rotation around pos
	var rad: float = deg_to_rad(bank)
	var cs: float = cos(rad)
	var sn: float = sin(rad)
	var s: float = 75.0

	# Helper: rotate point around pos
	# We'll build all points relative to (0,0) then rotate+translate

	# Afterburner flames
	var frame: int = Engine.get_frames_drawn()
	for i in range(2):
		var nox: float = [-20.0, 20.0][i]
		var fh: float = s * (0.9 + sin(frame * 0.4 + i * 1.5) * 0.2)
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 9, s * 0.38),
			Vector2(nox + 9, s * 0.38),
			Vector2(nox + 2, s * 0.38 + fh),
			Vector2(nox - 2, s * 0.38 + fh),
		], Color(1.0, 0.5, 0.1, 0.85))
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 5, s * 0.38),
			Vector2(nox + 5, s * 0.38),
			Vector2(nox + 1, s * 0.38 + fh * 0.65),
			Vector2(nox - 1, s * 0.38 + fh * 0.65),
		], Color(1.0, 0.9, 0.4))

	# Wings
	_draw_rotated_poly(pos, rad, [
		Vector2(-14, -s * 0.05),
		Vector2(-s * 1.9, s * 0.22),
		Vector2(-s * 1.6, s * 0.35),
		Vector2(-12, s * 0.12),
	], Color(0.78, 0.80, 0.83))
	_draw_rotated_poly(pos, rad, [
		Vector2(14, -s * 0.05),
		Vector2(s * 1.9, s * 0.22),
		Vector2(s * 1.6, s * 0.35),
		Vector2(12, s * 0.12),
	], Color(0.78, 0.80, 0.83))

	# Horizontal stabilizers
	_draw_rotated_poly(pos, rad, [
		Vector2(-10, s * 0.18),
		Vector2(-s * 0.75, s * 0.38),
		Vector2(-s * 0.6, s * 0.43),
		Vector2(-8, s * 0.26),
	], Color(0.70, 0.72, 0.75))
	_draw_rotated_poly(pos, rad, [
		Vector2(10, s * 0.18),
		Vector2(s * 0.75, s * 0.38),
		Vector2(s * 0.6, s * 0.43),
		Vector2(8, s * 0.26),
	], Color(0.70, 0.72, 0.75))

	# Fuselage
	_draw_rotated_poly(pos, rad, [
		Vector2(0, -s * 0.7),
		Vector2(20, -s * 0.12),
		Vector2(24, s * 0.1),
		Vector2(22, s * 0.38),
		Vector2(-22, s * 0.38),
		Vector2(-24, s * 0.1),
		Vector2(-20, -s * 0.12),
	], Color(0.88, 0.89, 0.92))

	# Fuselage center stripe (darker)
	_draw_rotated_poly(pos, rad, [
		Vector2(-4, -s * 0.5),
		Vector2(4, -s * 0.5),
		Vector2(5, s * 0.38),
		Vector2(-5, s * 0.38),
	], Color(0.82, 0.83, 0.86))

	# Intake ramps (orange)
	_draw_rotated_poly(pos, rad, [
		Vector2(-24, -s * 0.05),
		Vector2(-16, -s * 0.05),
		Vector2(-16, s * 0.15),
		Vector2(-24, s * 0.15),
	], Color(0.92, 0.42, 0.1))
	_draw_rotated_poly(pos, rad, [
		Vector2(16, -s * 0.05),
		Vector2(24, -s * 0.05),
		Vector2(24, s * 0.15),
		Vector2(16, s * 0.15),
	], Color(0.92, 0.42, 0.1))

	# Nacelles
	for nox in [-20.0, 20.0]:
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 10, s * 0.05),
			Vector2(nox + 10, s * 0.05),
			Vector2(nox + 12, s * 0.38),
			Vector2(nox - 12, s * 0.38),
		], Color(0.48, 0.50, 0.54))
		# Nozzle ring
		_draw_rotated_circle(pos, rad, Vector2(nox, s * 0.38), 10, Color(0.22, 0.22, 0.26))
		_draw_rotated_circle(pos, rad, Vector2(nox, s * 0.38), 6, Color(0.9, 0.5, 0.15))

	# Canopy
	_draw_rotated_poly(pos, rad, [
		Vector2(0, -s * 0.38),
		Vector2(8, -s * 0.15),
		Vector2(6, s * 0.02),
		Vector2(-6, s * 0.02),
		Vector2(-8, -s * 0.15),
	], Color(0.08, 0.12, 0.38))
	# Canopy highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-2, -s * 0.34),
		Vector2(3, -s * 0.22),
		Vector2(2, -s * 0.16),
		Vector2(-3, -s * 0.25),
	], Color(0.25, 0.35, 0.6, 0.5))

	# Tail fins
	_draw_rotated_poly(pos, rad, [
		Vector2(-14, s * 0.05),
		Vector2(-18, -s * 0.28),
		Vector2(-14, -s * 0.22),
		Vector2(-12, s * 0.12),
	], Color(0.58, 0.60, 0.64))
	_draw_rotated_poly(pos, rad, [
		Vector2(14, s * 0.05),
		Vector2(18, -s * 0.28),
		Vector2(14, -s * 0.22),
		Vector2(12, s * 0.12),
	], Color(0.58, 0.60, 0.64))

func _draw_rotated_poly(center: Vector2, angle: float, local_pts: Array, color: Color) -> void:
	var cs: float = cos(angle)
	var sn: float = sin(angle)
	var pts := PackedVector2Array()
	for p in local_pts:
		var v: Vector2 = p
		var rx: float = v.x * cs - v.y * sn
		var ry: float = v.x * sn + v.y * cs
		pts.append(Vector2(center.x + rx, center.y + ry))
	draw_polygon(pts, [color])

func _draw_rotated_circle(center: Vector2, angle: float, local_pos: Vector2, radius: float, color: Color) -> void:
	var cs: float = cos(angle)
	var sn: float = sin(angle)
	var rx: float = local_pos.x * cs - local_pos.y * sn
	var ry: float = local_pos.x * sn + local_pos.y * cos(angle)
	draw_circle(Vector2(center.x + rx, center.y + ry), radius, color)
