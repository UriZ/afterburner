extends Node2D

## 2D sprite-scaled F-14 player jet.
## Position is in screen pixel coordinates.
## Banking rotates the drawn sprite around the node's local origin.

const SCREEN_W := 960.0
const SCREEN_H := 672.0
const MOVE_MIN := Vector2(80.0, 280.0)
const MOVE_MAX := Vector2(880.0, 600.0)
const RESPAWN_POSITION := Vector2(480.0, 480.0)
const PLAYER_SCALE := 75.0
const MAX_BANK_ANGLE := 57.0

const DEATH_DURATION := 2.0
const INVINCIBILITY_DURATION := 6.0
const FLASH_INTERVAL := 0.1

@export var move_speed: float = 720.0
@export var acceleration: float = 2200.0
@export var deceleration: float = 1400.0

var _velocity: Vector2 = Vector2.ZERO
var _bank_angle: float = 0.0
var _input_enabled: bool = true
var _is_dying: bool = false
var _is_invincible: bool = true
var _death_timer: float = 0.0
var _invincibility_timer: float = 0.0
var _flash_timer: float = 0.0
var _visible_flag: bool = true  # separate from node .visible to allow flash
var _is_respawn: bool = false   # flash only on respawn, not initial spawn


func _ready() -> void:
	add_to_group("player")
	position = RESPAWN_POSITION
	_invincibility_timer = INVINCIBILITY_DURATION


func _process(delta: float) -> void:
	if _is_dying:
		_process_death(delta)
		queue_redraw()
		return

	if _is_invincible:
		_process_invincibility(delta)

	if _input_enabled:
		var input: Vector2 = _get_input_vector()
		_update_velocity(input, delta)
		_apply_movement(delta)
		_update_banking(input.x, delta)

	queue_redraw()


func _draw() -> void:
	if not _visible_flag:
		return
	_draw_player(Vector2.ZERO, _bank_angle)


# --- Input & movement ---

func _get_input_vector() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up")
	)


func _update_velocity(input: Vector2, delta: float) -> void:
	var target: Vector2 = input * move_speed
	for axis in 2:
		var rate: float
		if absf(input[axis]) > 0.01:
			rate = acceleration
		else:
			rate = deceleration
		_velocity[axis] = move_toward(_velocity[axis], target[axis], rate * delta)


func _apply_movement(delta: float) -> void:
	position.x += _velocity.x * delta
	position.y -= _velocity.y * delta  # input up = negative screen Y
	position.x = clampf(position.x, MOVE_MIN.x, MOVE_MAX.x)
	position.y = clampf(position.y, MOVE_MIN.y, MOVE_MAX.y)


func _update_banking(input_x: float, delta: float) -> void:
	var target_bank: float = input_x * MAX_BANK_ANGLE
	_bank_angle = move_toward(_bank_angle, target_bank, 460.0 * delta)


# --- Death & respawn ---

func hit() -> void:
	## Called by GameWorld collision detection when the player is struck.
	if _is_dying or _is_invincible:
		return
	_start_death()


func is_vulnerable() -> bool:
	return not _is_dying and not _is_invincible


func _start_death() -> void:
	var _has_lives: bool = GameState.lose_life()
	_is_dying = true
	_input_enabled = false
	_death_timer = DEATH_DURATION
	_velocity = Vector2.ZERO
	_spawn_death_explosion()
	if not _has_lives:
		_game_over()


func _spawn_death_explosion() -> void:
	var explosion_scene := preload("res://scenes/effects/explosion_2d.tscn")
	var explosion := explosion_scene.instantiate()
	explosion.position = position
	explosion.set("base_radius", 120.0)
	if get_parent():
		get_parent().add_child(explosion)


func _process_death(delta: float) -> void:
	_death_timer -= delta
	# Tumble: rotate and fall
	_bank_angle += 360.0 * delta
	position.y += 200.0 * delta

	if _death_timer <= 0.0:
		if GameState.lives >= 0:
			_respawn()
		else:
			_visible_flag = false
			_is_dying = false


func _respawn() -> void:
	_is_dying = false
	_input_enabled = true
	position = RESPAWN_POSITION
	_bank_angle = 0.0
	_velocity = Vector2.ZERO
	_is_invincible = true
	_is_respawn = true
	_invincibility_timer = INVINCIBILITY_DURATION
	_flash_timer = 0.0
	_visible_flag = true


func _process_invincibility(delta: float) -> void:
	_invincibility_timer -= delta
	if _is_respawn:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = FLASH_INTERVAL
			_visible_flag = not _visible_flag
	if _invincibility_timer <= 0.0:
		_is_invincible = false
		_is_respawn = false
		_visible_flag = true


func _game_over() -> void:
	GameState.phase = GameState.Phase.GAME_OVER
	var spawner: Node = get_parent().get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("set"):
		spawner.set("enabled", false)
	_show_game_over_label()


func _show_game_over_label() -> void:
	var label: Label = Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.anchors_preset = Control.PRESET_FULL_RECT
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(label)
	get_tree().root.add_child(canvas)


# --- Public interface ---

func get_screen_position() -> Vector2:
	return position


func get_collision_radius() -> float:
	return PLAYER_SCALE * 0.6


func get_bank_angle() -> float:
	return _bank_angle


# --- Drawing ---

func _draw_player(pos: Vector2, bank: float) -> void:
	var rad: float = deg_to_rad(bank)
	var s: float = PLAYER_SCALE
	var frame: int = Engine.get_frames_drawn()

	# Wing foreshortening factor (raised side appears shorter when banking)
	var ff_left: float = 1.0
	var ff_right: float = 1.0
	if bank < 0.0:
		ff_left = cos(deg_to_rad(absf(bank) * 0.7))
	elif bank > 0.0:
		ff_right = cos(deg_to_rad(absf(bank) * 0.7))

	# Flame lean: tips shift horizontally in bank direction (increased per spec)
	var flame_lean: float = bank * 0.18

	# Belly triangle alpha increases when banking (belly faces viewer)
	var belly_alpha: float = clampf(0.85 + absf(bank) / 30.0 * 0.15, 0.85, 1.0)

	var ny: float = s * 0.32  # nozzle exit Y

	# --- Layer 0: Afterburner flames (draw FIRST, behind everything) ---
	for i in range(2):
		var nox: float = [-20.0, 20.0][i]
		var fh_outer: float = s * (1.8 + sin(float(frame) * 0.35 + float(i) * 1.7) * 0.22)
		var fh_mid: float = fh_outer * 0.72
		var fh_inner: float = fh_outer * 0.52
		var fh_core: float = fh_outer * 0.35

		# Layer 0a — deep outer orange (widest, longest)
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 17.0, ny),
			Vector2(nox + 17.0, ny),
			Vector2(nox + 11.0, ny + fh_outer * 0.20),
			Vector2(nox + 3.0 + flame_lean,  ny + fh_outer),
			Vector2(nox - 3.0 + flame_lean,  ny + fh_outer),
			Vector2(nox - 11.0, ny + fh_outer * 0.20),
		], Color(1.0, 0.33, 0.0, 0.88))

		# Layer 0b — bright mid-orange
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 12.0, ny),
			Vector2(nox + 12.0, ny),
			Vector2(nox + 7.0,  ny + fh_mid * 0.25),
			Vector2(nox + 2.0 + flame_lean,  ny + fh_mid),
			Vector2(nox - 2.0 + flame_lean,  ny + fh_mid),
			Vector2(nox - 7.0,  ny + fh_mid * 0.25),
		], Color(1.0, 0.53, 0.0, 0.92))

		# Layer 0c — amber-yellow
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 8.0,  ny),
			Vector2(nox + 8.0,  ny),
			Vector2(nox + 4.0,  ny + fh_inner * 0.28),
			Vector2(nox + 1.5 + flame_lean, ny + fh_inner),
			Vector2(nox - 1.5 + flame_lean, ny + fh_inner),
			Vector2(nox - 4.0,  ny + fh_inner * 0.28),
		], Color(1.0, 0.80, 0.0, 0.94))

		# Layer 0d — pale yellow-white inner
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 5.0,  ny),
			Vector2(nox + 5.0,  ny),
			Vector2(nox + 1.5 + flame_lean, ny + fh_core),
			Vector2(nox - 1.5 + flame_lean, ny + fh_core),
		], Color(1.0, 0.94, 0.50, 0.96))

		# Layer 0e — WHITE CORE: circle at nozzle base + streak
		_draw_rotated_circle(pos, rad, Vector2(nox, ny), 7.0, Color(1.0, 1.0, 1.0, 1.0))
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 2.0, ny),
			Vector2(nox + 2.0, ny),
			Vector2(nox + 1.0 + flame_lean, ny + fh_core),
			Vector2(nox - 1.0 + flame_lean, ny + fh_core),
		], Color(1.0, 1.0, 1.0, 0.90))

	# --- Layer 1: Horizontal stabilizers (darker underside, behind main wings) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-11.0,     s * 0.14),
		Vector2(-s * 0.75, s * 0.38),
		Vector2(-s * 0.60, s * 0.44),
		Vector2(-9.0,      s * 0.22),
	], Color(0.42, 0.45, 0.50))
	_draw_rotated_poly(pos, rad, [
		Vector2(11.0,      s * 0.14),
		Vector2(s * 0.75,  s * 0.38),
		Vector2(s * 0.60,  s * 0.44),
		Vector2(9.0,       s * 0.22),
	], Color(0.42, 0.45, 0.50))

	# --- Layers 2-3: Wings ---
	# Left wing — main top surface
	_draw_rotated_poly(pos, rad, [
		Vector2(-22.0,               -s * 0.08),
		Vector2(-s * 1.75 * ff_left,  s * 0.20),
		Vector2(-s * 1.48 * ff_left,  s * 0.32),
		Vector2(-14.0,                s * 0.16),
	], Color(0.69, 0.72, 0.77))
	# Left wing — underside shadow strip (rear/inner half)
	if ff_left > 0.08:
		_draw_rotated_poly(pos, rad, [
			Vector2(-s * 0.55 * ff_left,  s * 0.08),
			Vector2(-s * 1.48 * ff_left,  s * 0.32),
			Vector2(-14.0,                s * 0.16),
		], Color(0.42, 0.45, 0.50, 0.55))
	# Left wing — leading edge bright strip (skip if nearly folded to avoid degenerate polygon)
	if ff_left > 0.15:
		_draw_rotated_poly(pos, rad, [
			Vector2(-22.0,               -s * 0.08),
			Vector2(-s * 1.75 * ff_left,  s * 0.20),
			Vector2(-s * 1.68 * ff_left,  s * 0.22),
			Vector2(-20.0,               -s * 0.06),
		], Color(0.60, 0.62, 0.66, 0.70))

	# Right wing — main top surface
	_draw_rotated_poly(pos, rad, [
		Vector2(22.0,                -s * 0.08),
		Vector2(s * 1.75 * ff_right,  s * 0.20),
		Vector2(s * 1.48 * ff_right,  s * 0.32),
		Vector2(14.0,                 s * 0.16),
	], Color(0.69, 0.72, 0.77))
	# Right wing — underside shadow strip
	if ff_right > 0.08:
		_draw_rotated_poly(pos, rad, [
			Vector2(s * 0.55 * ff_right,  s * 0.08),
			Vector2(s * 1.48 * ff_right,  s * 0.32),
			Vector2(14.0,                 s * 0.16),
		], Color(0.42, 0.45, 0.50, 0.55))
	# Right wing — leading edge bright strip (skip if nearly folded to avoid degenerate polygon)
	if ff_right > 0.15:
		_draw_rotated_poly(pos, rad, [
			Vector2(22.0,                -s * 0.08),
			Vector2(s * 1.75 * ff_right,  s * 0.20),
			Vector2(s * 1.68 * ff_right,  s * 0.22),
			Vector2(20.0,                -s * 0.06),
		], Color(0.60, 0.62, 0.66, 0.70))

	# --- Layers 4-5: Engine nacelles (dark charcoal-blue) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-28.0, -s * 0.02),
		Vector2(-12.0, -s * 0.02),
		Vector2(-10.0,  s * 0.32),
		Vector2(-30.0,  s * 0.32),
	], Color(0.23, 0.24, 0.28))
	# Left nacelle top highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-27.0, -s * 0.02),
		Vector2(-13.0, -s * 0.02),
		Vector2(-13.0,  s * 0.02),
		Vector2(-27.0,  s * 0.02),
	], Color(0.35, 0.37, 0.42, 0.6))

	_draw_rotated_poly(pos, rad, [
		Vector2(12.0,  -s * 0.02),
		Vector2(28.0,  -s * 0.02),
		Vector2(30.0,   s * 0.32),
		Vector2(10.0,   s * 0.32),
	], Color(0.23, 0.24, 0.28))
	# Right nacelle top highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(13.0,  -s * 0.02),
		Vector2(27.0,  -s * 0.02),
		Vector2(27.0,   s * 0.02),
		Vector2(13.0,   s * 0.02),
	], Color(0.35, 0.37, 0.42, 0.6))

	# --- Layers 7-8: Orange intake ramps ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-30.0, -s * 0.14),
		Vector2(-22.0, -s * 0.14),
		Vector2(-20.0, -s * 0.02),
		Vector2(-28.0, -s * 0.02),
	], Color(0.80, 0.25, 0.06))
	_draw_rotated_poly(pos, rad, [
		Vector2(-28.0, -s * 0.13),
		Vector2(-23.0, -s * 0.13),
		Vector2(-22.0, -s * 0.03),
		Vector2(-27.0, -s * 0.03),
	], Color(0.94, 0.38, 0.13, 0.6))

	_draw_rotated_poly(pos, rad, [
		Vector2(22.0,  -s * 0.14),
		Vector2(30.0,  -s * 0.14),
		Vector2(28.0,  -s * 0.02),
		Vector2(20.0,  -s * 0.02),
	], Color(0.80, 0.25, 0.06))
	_draw_rotated_poly(pos, rad, [
		Vector2(23.0,  -s * 0.13),
		Vector2(28.0,  -s * 0.13),
		Vector2(27.0,  -s * 0.03),
		Vector2(22.0,  -s * 0.03),
	], Color(0.94, 0.38, 0.13, 0.6))

	# --- Layer 9: Fuselage (silver-blue grey) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-4.0,  -s * 0.75),  # nose left
		Vector2(4.0,   -s * 0.75),  # nose right
		Vector2(22.0,  -s * 0.10),  # shoulder right
		Vector2(28.0,   s * 0.08),  # max width right
		Vector2(26.0,   s * 0.32),  # nozzle right
		Vector2(-26.0,  s * 0.32),  # nozzle left
		Vector2(-28.0,  s * 0.08),  # max width left
		Vector2(-22.0, -s * 0.10),  # shoulder left
	], Color(0.77, 0.79, 0.83))

	# Dorsal spine highlight (bright centerline strip, nose to tail)
	_draw_rotated_poly(pos, rad, [
		Vector2(-2.0,  -s * 0.74),
		Vector2(2.0,   -s * 0.74),
		Vector2(3.0,    s * 0.20),
		Vector2(-3.0,   s * 0.20),
	], Color(0.89, 0.90, 0.93, 0.75))

	# Panel line 1 (diagonal chine left)
	_draw_rotated_poly(pos, rad, [
		Vector2(-6.0,  -s * 0.60),
		Vector2(-3.0,  -s * 0.60),
		Vector2(2.0,   -s * 0.30),
		Vector2(-1.0,  -s * 0.30),
	], Color(0.53, 0.57, 0.63, 0.5))

	# Panel line 2 (horizontal mid-fuselage seam)
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,  s * 0.04),
		Vector2(20.0,   s * 0.04),
		Vector2(20.0,   s * 0.06),
		Vector2(-20.0,  s * 0.06),
	], Color(0.53, 0.57, 0.63, 0.5))

	# Belly shadow (rear underside)
	_draw_rotated_poly(pos, rad, [
		Vector2(-14.0,  s * 0.10),
		Vector2(14.0,   s * 0.10),
		Vector2(12.0,   s * 0.32),
		Vector2(-12.0,  s * 0.32),
	], Color(0.54, 0.57, 0.63, 0.45))

	# Orange belly triangle marking (distinctive AB2 feature)
	_draw_rotated_poly(pos, rad, [
		Vector2(0.0,   s * 0.02),
		Vector2(10.0,  s * 0.20),
		Vector2(-10.0, s * 0.20),
	], Color(0.88, 0.19, 0.06, belly_alpha))

	# --- Layers 10-11: Tail fins (increased height per spec) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,  s * 0.05),
		Vector2(-25.0, -s * 0.39),
		Vector2(-19.0, -s * 0.32),
		Vector2(-16.0,  s * 0.14),
	], Color(0.48, 0.52, 0.58))
	# Left fin highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,  s * 0.05),
		Vector2(-25.0, -s * 0.39),
		Vector2(-23.0, -s * 0.37),
		Vector2(-19.0,  s * 0.04),
	], Color(0.60, 0.64, 0.70, 0.6))

	_draw_rotated_poly(pos, rad, [
		Vector2(16.0,   s * 0.14),
		Vector2(19.0,  -s * 0.32),
		Vector2(25.0,  -s * 0.39),
		Vector2(20.0,   s * 0.05),
	], Color(0.48, 0.52, 0.58))
	# Right fin highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(19.0,   s * 0.04),
		Vector2(23.0,  -s * 0.37),
		Vector2(25.0,  -s * 0.39),
		Vector2(20.0,   s * 0.05),
	], Color(0.60, 0.64, 0.70, 0.6))

	# --- Layer 12: Nozzle rings (4 per engine) ---
	for nox_r in [-20.0, 20.0]:
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny), 12.0, Color(0.16, 0.17, 0.20))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny),  9.0, Color(0.23, 0.24, 0.28))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny),  6.0, Color(0.88, 0.42, 0.0))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny),  3.0, Color(0.94, 0.565, 0.0))
		# White core blazing out of nozzle center (drawn after rings to stay on top)
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny + 3.0), 5.0, Color(1.0, 1.0, 1.0, 1.0))

	# --- Layer 13: Canopy ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-6.0,  -s * 0.40),
		Vector2(6.0,   -s * 0.40),
		Vector2(9.0,   -s * 0.22),
		Vector2(0.0,   -s * 0.10),
		Vector2(-9.0,  -s * 0.22),
	], Color(0.047, 0.071, 0.141))
	# Canopy glint (electric blue slash)
	_draw_rotated_poly(pos, rad, [
		Vector2(-4.0,  -s * 0.38),
		Vector2(2.0,   -s * 0.32),
		Vector2(1.0,   -s * 0.26),
		Vector2(-5.0,  -s * 0.30),
	], Color(0.16, 0.27, 0.63, 0.55))


func _draw_rotated_poly(center: Vector2, angle: float, local_pts: Array, color: Color) -> void:
	var cs: float = cos(angle)
	var sn: float = sin(angle)
	var pts: PackedVector2Array = PackedVector2Array()
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
	var ry: float = local_pos.x * sn + local_pos.y * cs
	draw_circle(Vector2(center.x + rx, center.y + ry), radius, color)
