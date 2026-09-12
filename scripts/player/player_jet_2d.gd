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
const MAX_BANK_ANGLE := 45.0

const DEATH_DURATION := 2.0
const INVINCIBILITY_DURATION := 4.0
const FLASH_INTERVAL := 0.1

@export var move_speed: float = 500.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 900.0

var _velocity: Vector2 = Vector2.ZERO
var _bank_angle: float = 0.0
var _input_enabled: bool = true
var _is_dying: bool = false
var _is_invincible: bool = true
var _death_timer: float = 0.0
var _invincibility_timer: float = 0.0
var _flash_timer: float = 0.0
var _visible_flag: bool = true  # separate from node .visible to allow flash


func _ready() -> void:
	add_to_group("player")
	position = RESPAWN_POSITION
	_invincibility_timer = 6.0


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
	_bank_angle = move_toward(_bank_angle, target_bank, 320.0 * delta)


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
	_invincibility_timer = INVINCIBILITY_DURATION
	_flash_timer = 0.0
	_visible_flag = true


func _process_invincibility(delta: float) -> void:
	_invincibility_timer -= delta
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = FLASH_INTERVAL
		_visible_flag = not _visible_flag
	if _invincibility_timer <= 0.0:
		_is_invincible = false
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
	if bank < 0.0:  # banking left — left wing raises, foreshorten it
		ff_left = cos(deg_to_rad(absf(bank) * 0.7))
	elif bank > 0.0:  # banking right — right wing raises, foreshorten it
		ff_right = cos(deg_to_rad(absf(bank) * 0.7))

	# Flame lean: tips shift horizontally in bank direction
	var flame_lean: float = bank * 0.15

	# --- Layer 0: Afterburner flames (draw FIRST, behind everything) ---
	for i in range(2):
		var nox: float = [-20.0, 20.0][i]
		var fh: float = s * (1.5 + sin(float(frame) * 0.35 + float(i) * 1.7) * 0.22)
		var fh_mid: float = fh * 0.72
		var fh_core: float = fh * 0.50
		var ny: float = s * 0.30

		# Outer flame (6-vertex non-linear taper)
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 14.0, ny),
			Vector2(nox + 14.0, ny),
			Vector2(nox + 9.0,  ny + fh * 0.25),
			Vector2(nox + 2.5 + flame_lean,  ny + fh),
			Vector2(nox - 2.5 + flame_lean,  ny + fh),
			Vector2(nox - 9.0,  ny + fh * 0.25),
		], Color(1.0, 0.55, 0.1, 0.90))

		# Mid flame
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 9.0, ny),
			Vector2(nox + 9.0, ny),
			Vector2(nox + 5.0, ny + fh_mid * 0.3),
			Vector2(nox + 1.5 + flame_lean, ny + fh_mid),
			Vector2(nox - 1.5 + flame_lean, ny + fh_mid),
			Vector2(nox - 5.0, ny + fh_mid * 0.3),
		], Color(1.0, 0.75, 0.2, 0.92))

		# Core flame (4-vertex)
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 5.0, ny),
			Vector2(nox + 5.0, ny),
			Vector2(nox + 1.5 + flame_lean, ny + fh_core),
			Vector2(nox - 1.5 + flame_lean, ny + fh_core),
		], Color(1.0, 0.95, 0.6, 0.95))

		# Bright core dot
		_draw_rotated_circle(pos, rad, Vector2(nox, ny + 2.0), 5.5, Color(1.0, 0.98, 0.85, 1.00))

	# --- Layer 1 & 2: Wings ---
	# Left wing
	_draw_rotated_poly(pos, rad, [
		Vector2(-18.0,                  -s * 0.08),
		Vector2(-s * 1.6 * ff_left,     s * 0.20),
		Vector2(-s * 1.35 * ff_left,    s * 0.32),
		Vector2(-14.0,                   s * 0.16),
	], Color(0.83, 0.85, 0.88))
	# Left wing shadow
	_draw_rotated_poly(pos, rad, [
		Vector2(-s * 0.6 * ff_left,     s * 0.06),
		Vector2(-s * 1.35 * ff_left,    s * 0.32),
		Vector2(-14.0,                   s * 0.16),
	], Color(0.60, 0.63, 0.68, 0.4))

	# Right wing
	_draw_rotated_poly(pos, rad, [
		Vector2(18.0,                   -s * 0.08),
		Vector2(s * 1.6 * ff_right,     s * 0.20),
		Vector2(s * 1.35 * ff_right,    s * 0.32),
		Vector2(14.0,                    s * 0.16),
	], Color(0.83, 0.85, 0.88))
	# Right wing shadow
	_draw_rotated_poly(pos, rad, [
		Vector2(s * 0.6 * ff_right,     s * 0.06),
		Vector2(s * 1.35 * ff_right,    s * 0.32),
		Vector2(14.0,                    s * 0.16),
	], Color(0.60, 0.63, 0.68, 0.4))

	# --- Layer 3 & 4: Horizontal stabilizers ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-11.0,    s * 0.14),
		Vector2(-s * 0.72, s * 0.33),
		Vector2(-s * 0.58, s * 0.40),
		Vector2(-9.0,     s * 0.22),
	], Color(0.77, 0.78, 0.82))
	_draw_rotated_poly(pos, rad, [
		Vector2(11.0,     s * 0.14),
		Vector2(s * 0.72, s * 0.33),
		Vector2(s * 0.58, s * 0.40),
		Vector2(9.0,      s * 0.22),
	], Color(0.77, 0.78, 0.82))

	# --- Layers 5 & 6: Engine nacelles ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-28.0, -s * 0.02),
		Vector2(-12.0, -s * 0.02),
		Vector2(-10.0,  s * 0.30),
		Vector2(-30.0,  s * 0.30),
	], Color(0.35, 0.38, 0.44))
	_draw_rotated_poly(pos, rad, [
		Vector2(12.0,  -s * 0.02),
		Vector2(28.0,  -s * 0.02),
		Vector2(30.0,   s * 0.30),
		Vector2(10.0,   s * 0.30),
	], Color(0.35, 0.38, 0.44))

	# --- Layers 7 & 8: Orange intake ramps (defining AB2 feature) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-30.0, -s * 0.14),
		Vector2(-22.0, -s * 0.14),
		Vector2(-20.0, -s * 0.02),
		Vector2(-28.0, -s * 0.02),
	], Color(0.83, 0.25, 0.06))
	# Left intake highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-28.0, -s * 0.13),
		Vector2(-23.0, -s * 0.13),
		Vector2(-22.0, -s * 0.03),
		Vector2(-27.0, -s * 0.03),
	], Color(0.94, 0.41, 0.13, 0.6))

	_draw_rotated_poly(pos, rad, [
		Vector2(22.0,  -s * 0.14),
		Vector2(30.0,  -s * 0.14),
		Vector2(28.0,  -s * 0.02),
		Vector2(20.0,  -s * 0.02),
	], Color(0.83, 0.25, 0.06))
	# Right intake highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(23.0,  -s * 0.13),
		Vector2(28.0,  -s * 0.13),
		Vector2(27.0,  -s * 0.03),
		Vector2(22.0,  -s * 0.03),
	], Color(0.94, 0.41, 0.13, 0.6))

	# --- Layer 9: Fuselage (wide bullet nose, 8 vertices) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-4.0,  -s * 0.75),  # nose left
		Vector2(4.0,   -s * 0.75),  # nose right (8px wide — not a spike)
		Vector2(22.0,  -s * 0.10),  # shoulder right
		Vector2(28.0,   s * 0.08),  # max width right
		Vector2(26.0,   s * 0.30),  # nozzle right
		Vector2(-26.0,  s * 0.30),  # nozzle left
		Vector2(-28.0,  s * 0.08),  # max width left
		Vector2(-22.0, -s * 0.10),  # shoulder left
	], Color(0.91, 0.92, 0.94))

	# Fuselage panel line 1 (diagonal)
	_draw_rotated_poly(pos, rad, [
		Vector2(-6.0,  -s * 0.60),
		Vector2(-3.0,  -s * 0.60),
		Vector2(2.0,   -s * 0.30),
		Vector2(-1.0,  -s * 0.30),
	], Color(0.77, 0.78, 0.82))

	# Fuselage panel line 2 (horizontal mid)
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,  s * 0.04),
		Vector2(20.0,   s * 0.04),
		Vector2(20.0,   s * 0.06),
		Vector2(-20.0,  s * 0.06),
	], Color(0.77, 0.78, 0.82, 0.7))

	# Fuselage belly shadow
	_draw_rotated_poly(pos, rad, [
		Vector2(-14.0,  s * 0.10),
		Vector2(14.0,   s * 0.10),
		Vector2(12.0,   s * 0.30),
		Vector2(-12.0,  s * 0.30),
	], Color(0.66, 0.69, 0.75, 0.45))

	# --- Layers 10 & 11: Tail fins (mounted on nacelles, outboard) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,  s * 0.05),
		Vector2(-24.0, -s * 0.32),
		Vector2(-18.0, -s * 0.26),
		Vector2(-16.0,  s * 0.14),
	], Color(0.50, 0.56, 0.66))
	# Left fin highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,  s * 0.05),
		Vector2(-24.0, -s * 0.32),
		Vector2(-22.0, -s * 0.30),
		Vector2(-19.0,  s * 0.04),
	], Color(0.63, 0.69, 0.78, 0.6))

	_draw_rotated_poly(pos, rad, [
		Vector2(16.0,   s * 0.14),
		Vector2(18.0,  -s * 0.26),
		Vector2(24.0,  -s * 0.32),
		Vector2(20.0,   s * 0.05),
	], Color(0.50, 0.56, 0.66))
	# Right fin highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(19.0,   s * 0.04),
		Vector2(22.0,  -s * 0.30),
		Vector2(24.0,  -s * 0.32),
		Vector2(20.0,   s * 0.05),
	], Color(0.63, 0.69, 0.78, 0.6))

	# --- Layer 12: Nozzle rings (3 per engine) ---
	for nox in [-20.0, 20.0]:
		var ny: float = s * 0.30
		_draw_rotated_circle(pos, rad, Vector2(nox, ny), 11.0, Color(0.17, 0.17, 0.19))
		_draw_rotated_circle(pos, rad, Vector2(nox, ny),  8.0, Color(0.35, 0.38, 0.44))
		_draw_rotated_circle(pos, rad, Vector2(nox, ny),  5.0, Color(0.88, 0.47, 0.13))

	# --- Layer 13: Canopy ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-6.0,  -s * 0.40),
		Vector2(6.0,   -s * 0.40),
		Vector2(9.0,   -s * 0.22),
		Vector2(0.0,   -s * 0.10),
		Vector2(-9.0,  -s * 0.22),
	], Color(0.06, 0.09, 0.22))
	# Canopy glint highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-4.0,  -s * 0.38),
		Vector2(2.0,   -s * 0.32),
		Vector2(1.0,   -s * 0.26),
		Vector2(-5.0,  -s * 0.30),
	], Color(0.19, 0.31, 0.63, 0.55))


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
