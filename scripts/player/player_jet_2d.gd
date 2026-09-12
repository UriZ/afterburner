extends Node2D

## 2D sprite-scaled F-14 player jet.
## Position is in screen pixel coordinates.
## Banking rotates the drawn sprite around the node's local origin.

const SCREEN_W := 960.0
const SCREEN_H := 672.0
const MOVE_MIN := Vector2(80.0, 200.0)
const MOVE_MAX := Vector2(880.0, 600.0)
const RESPAWN_POSITION := Vector2(480.0, 380.0)
const PLAYER_SCALE := 130.0
const MAX_BANK_ANGLE := 57.0

const DEATH_DURATION := 2.0
const INVINCIBILITY_DURATION := 6.0
const FLASH_INTERVAL := 0.1

# Flame animation speed multipliers
const FLAME_SPEED_OUTER := 0.30
const FLAME_SPEED_MID := 0.45
const FLAME_SPEED_INNER := 0.55
const FLAME_JITTER_POINTS := 5  # ragged edge segments per flame side

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

	# Flame lean: tips shift horizontally in bank direction
	var flame_lean: float = bank * 0.22

	# Belly triangle alpha increases when banking (belly faces viewer)
	var belly_alpha: float = clampf(0.85 + absf(bank) / 30.0 * 0.15, 0.85, 1.0)

	var ny: float = s * 0.32  # nozzle exit Y
	var cant: float = s * 0.06  # tail fin outward cant

	# --- Layer 0: Afterburner flames (draw FIRST, behind everything) ---
	for i in range(2):
		var nox: float = [-20.0, 20.0][i]
		var fh_outer: float = s * (3.0 + sin(float(frame) * FLAME_SPEED_OUTER + float(i) * 1.7) * 0.35
				+ sin(float(frame) * 0.17 + float(i) * 3.1) * 0.15)
		var fh_mid: float = fh_outer * 0.70
		var fh_inner: float = fh_outer * 0.48
		var fh_core: float = fh_outer * 0.32
		var fh_hot: float = fh_outer * 0.18

		# Layer 0a — deep red outer fringe (ragged edges)
		# Clamp left-side points to stay left of nox, right-side to stay right of nox
		# to prevent self-intersecting polygons that break the triangulator.
		var pts_0a: Array = []
		pts_0a.append(Vector2(nox - 22.0, ny))
		for j in range(FLAME_JITTER_POINTS):
			var t_j: float = float(j + 1) / float(FLAME_JITTER_POINTS + 1)
			var base_x: float = lerp(-22.0, -2.0, t_j * t_j)
			var jitter_x: float = sin(float(frame) * 0.5 + float(j) * 2.3 + float(i) * 4.0) * (4.0 + float(j) * 1.0)
			pts_0a.append(Vector2(nox + minf(base_x + jitter_x, -1.5) + flame_lean * t_j, ny + fh_outer * t_j))
		pts_0a.append(Vector2(nox + flame_lean, ny + fh_outer))
		for j in range(FLAME_JITTER_POINTS - 1, -1, -1):
			var t_j: float = float(j + 1) / float(FLAME_JITTER_POINTS + 1)
			var base_x: float = lerp(22.0, 2.0, t_j * t_j)
			var jitter_x: float = sin(float(frame) * 0.7 + float(j) * 1.9 + float(i) * 5.0) * (4.0 + float(j) * 1.0)
			pts_0a.append(Vector2(nox + maxf(base_x + jitter_x, 1.5) + flame_lean * t_j, ny + fh_outer * t_j))
		pts_0a.append(Vector2(nox + 22.0, ny))
		_draw_rotated_poly(pos, rad, pts_0a, Color(0.85, 0.15, 0.0, 0.80))

		# Layer 0b — bright orange mid layer (ragged)
		var pts_0b: Array = []
		pts_0b.append(Vector2(nox - 16.0, ny))
		for j in range(FLAME_JITTER_POINTS):
			var t_j: float = float(j + 1) / float(FLAME_JITTER_POINTS + 1)
			var base_x: float = lerp(-16.0, -2.0, t_j * t_j)
			var jitter_x: float = sin(float(frame) * 0.65 + float(j) * 2.7 + float(i) * 3.5) * (3.0 + float(j) * 0.8)
			pts_0b.append(Vector2(nox + minf(base_x + jitter_x, -1.5) + flame_lean * t_j, ny + fh_mid * t_j))
		pts_0b.append(Vector2(nox + flame_lean, ny + fh_mid))
		for j in range(FLAME_JITTER_POINTS - 1, -1, -1):
			var t_j: float = float(j + 1) / float(FLAME_JITTER_POINTS + 1)
			var base_x: float = lerp(16.0, 2.0, t_j * t_j)
			var jitter_x: float = sin(float(frame) * 0.8 + float(j) * 2.1 + float(i) * 4.3) * (3.0 + float(j) * 0.8)
			pts_0b.append(Vector2(nox + maxf(base_x + jitter_x, 1.5) + flame_lean * t_j, ny + fh_mid * t_j))
		pts_0b.append(Vector2(nox + 16.0, ny))
		_draw_rotated_poly(pos, rad, pts_0b, Color(1.0, 0.45, 0.0, 0.88))

		# Layer 0c — yellow fire (ragged, smaller jitter)
		var pts_0c: Array = []
		pts_0c.append(Vector2(nox - 10.0, ny))
		for j in range(FLAME_JITTER_POINTS):
			var t_j: float = float(j + 1) / float(FLAME_JITTER_POINTS + 1)
			var base_x: float = lerp(-10.0, -2.0, t_j * t_j)
			var jitter_x: float = sin(float(frame) * 0.8 + float(j) * 3.1) * (2.0 + float(j) * 0.6)
			pts_0c.append(Vector2(nox + minf(base_x + jitter_x, -1.5) + flame_lean * t_j, ny + fh_inner * t_j))
		pts_0c.append(Vector2(nox + flame_lean, ny + fh_inner))
		for j in range(FLAME_JITTER_POINTS - 1, -1, -1):
			var t_j: float = float(j + 1) / float(FLAME_JITTER_POINTS + 1)
			var base_x: float = lerp(10.0, 2.0, t_j * t_j)
			var jitter_x: float = sin(float(frame) * 0.95 + float(j) * 2.5) * (2.0 + float(j) * 0.6)
			pts_0c.append(Vector2(nox + maxf(base_x + jitter_x, 1.5) + flame_lean * t_j, ny + fh_inner * t_j))
		pts_0c.append(Vector2(nox + 10.0, ny))
		_draw_rotated_poly(pos, rad, pts_0c, Color(1.0, 0.78, 0.0, 0.92))

		# Layer 0d — pale yellow-white (smooth — inner layers are smoother)
		var lean_d: float = clampf(flame_lean, -6.0, 6.0)
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 6.0, ny),
			Vector2(nox + 6.0, ny),
			Vector2(nox + 3.0, ny + fh_core * 0.3),
			Vector2(nox + lean_d, ny + fh_core),
			Vector2(nox - lean_d, ny + fh_core),
			Vector2(nox - 3.0, ny + fh_core * 0.3),
		], Color(1.0, 0.93, 0.55, 0.95))

		# Layer 0e — white-hot core circle + streak
		var lean_e: float = clampf(flame_lean, -3.0, 3.0)
		_draw_rotated_circle(pos, rad, Vector2(nox, ny), 8.0, Color(1.0, 1.0, 1.0, 1.0))
		_draw_rotated_poly(pos, rad, [
			Vector2(nox - 3.0, ny),
			Vector2(nox + 3.0, ny),
			Vector2(nox + lean_e, ny + fh_hot),
			Vector2(nox - lean_e, ny + fh_hot),
		], Color(1.0, 1.0, 1.0, 0.92))

	# Layer 0f — nozzle heat glow (between the two nozzles)
	var glow_alpha: float = 0.20 + sin(float(frame) * 0.4) * 0.08
	_draw_rotated_poly(pos, rad, [
		Vector2(-12.0, ny - 4.0),
		Vector2(12.0,  ny - 4.0),
		Vector2(14.0,  ny + s * 0.15),
		Vector2(-14.0, ny + s * 0.15),
	], Color(1.0, 0.5, 0.1, glow_alpha))

	# --- Layer 1: Horizontal stabilizers ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-13.0,     s * 0.14),
		Vector2(-s * 0.72, s * 0.36),
		Vector2(-s * 0.55, s * 0.42),
		Vector2(-11.0,     s * 0.22),
	], Color(0.55, 0.58, 0.65))
	_draw_rotated_poly(pos, rad, [
		Vector2(13.0,      s * 0.14),
		Vector2(s * 0.72,  s * 0.36),
		Vector2(s * 0.55,  s * 0.42),
		Vector2(11.0,      s * 0.22),
	], Color(0.55, 0.58, 0.65))

	# --- Layer 2: Main wings ---
	# Left wing — main surface
	_draw_rotated_poly(pos, rad, [
		Vector2(-24.0,               -s * 0.12),
		Vector2(-s * 1.85 * ff_left,  s * 0.18),
		Vector2(-s * 1.55 * ff_left,  s * 0.34),
		Vector2(-16.0,                s * 0.22),
	], Color(0.88, 0.89, 0.92))
	# Left wing — underside shadow
	if ff_left > 0.25:
		_draw_rotated_poly(pos, rad, [
			Vector2(-s * 0.50 * ff_left,  s * 0.06),
			Vector2(-s * 1.55 * ff_left,  s * 0.34),
			Vector2(-16.0,                s * 0.22),
		], Color(0.52, 0.55, 0.60, 0.50))
	# Left wing — leading edge highlight
	if ff_left > 0.25:
		_draw_rotated_poly(pos, rad, [
			Vector2(-24.0,               -s * 0.12),
			Vector2(-s * 1.85 * ff_left,  s * 0.18),
			Vector2(-s * 1.78 * ff_left,  s * 0.20),
			Vector2(-22.0,               -s * 0.10),
		], Color(0.96, 0.97, 1.0, 0.65))

	# Right wing — main surface
	_draw_rotated_poly(pos, rad, [
		Vector2(24.0,                -s * 0.12),
		Vector2(s * 1.85 * ff_right,  s * 0.18),
		Vector2(s * 1.55 * ff_right,  s * 0.34),
		Vector2(16.0,                 s * 0.22),
	], Color(0.88, 0.89, 0.92))
	# Right wing — underside shadow
	if ff_right > 0.25:
		_draw_rotated_poly(pos, rad, [
			Vector2(s * 0.50 * ff_right,  s * 0.06),
			Vector2(s * 1.55 * ff_right,  s * 0.34),
			Vector2(16.0,                 s * 0.22),
		], Color(0.52, 0.55, 0.60, 0.50))
	# Right wing — leading edge highlight
	if ff_right > 0.25:
		_draw_rotated_poly(pos, rad, [
			Vector2(24.0,                -s * 0.12),
			Vector2(s * 1.85 * ff_right,  s * 0.18),
			Vector2(s * 1.78 * ff_right,  s * 0.20),
			Vector2(22.0,                -s * 0.10),
		], Color(0.96, 0.97, 1.0, 0.65))

	# --- Layer 3: Engine nacelles ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-30.0, -s * 0.04),
		Vector2(-12.0, -s * 0.04),
		Vector2(-10.0,  s * 0.32),
		Vector2(-32.0,  s * 0.32),
	], Color(0.30, 0.32, 0.38))
	_draw_rotated_poly(pos, rad, [
		Vector2(-29.0, -s * 0.04),
		Vector2(-13.0, -s * 0.04),
		Vector2(-13.0,  s * 0.01),
		Vector2(-29.0,  s * 0.01),
	], Color(0.45, 0.48, 0.55, 0.55))

	_draw_rotated_poly(pos, rad, [
		Vector2(12.0,  -s * 0.04),
		Vector2(30.0,  -s * 0.04),
		Vector2(32.0,   s * 0.32),
		Vector2(10.0,   s * 0.32),
	], Color(0.30, 0.32, 0.38))
	_draw_rotated_poly(pos, rad, [
		Vector2(13.0,  -s * 0.04),
		Vector2(29.0,  -s * 0.04),
		Vector2(29.0,   s * 0.01),
		Vector2(13.0,   s * 0.01),
	], Color(0.45, 0.48, 0.55, 0.55))

	# --- Layer 4: Intake ramps (orange/red — distinctive AB2 feature) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-32.0, -s * 0.18),
		Vector2(-22.0, -s * 0.18),
		Vector2(-20.0, -s * 0.04),
		Vector2(-30.0, -s * 0.04),
	], Color(0.85, 0.22, 0.04))
	_draw_rotated_poly(pos, rad, [
		Vector2(-30.0, -s * 0.17),
		Vector2(-24.0, -s * 0.17),
		Vector2(-22.0, -s * 0.05),
		Vector2(-28.0, -s * 0.05),
	], Color(0.96, 0.42, 0.10, 0.65))

	_draw_rotated_poly(pos, rad, [
		Vector2(22.0,  -s * 0.18),
		Vector2(32.0,  -s * 0.18),
		Vector2(30.0,  -s * 0.04),
		Vector2(20.0,  -s * 0.04),
	], Color(0.85, 0.22, 0.04))
	_draw_rotated_poly(pos, rad, [
		Vector2(24.0,  -s * 0.17),
		Vector2(30.0,  -s * 0.17),
		Vector2(28.0,  -s * 0.05),
		Vector2(22.0,  -s * 0.05),
	], Color(0.96, 0.42, 0.10, 0.65))

	# --- Layer 5: Fuselage (BRIGHT WHITE) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-6.0,  -s * 0.78),  # nose left
		Vector2(6.0,   -s * 0.78),  # nose right
		Vector2(24.0,  -s * 0.12),  # shoulder right
		Vector2(30.0,   s * 0.06),  # max width right
		Vector2(28.0,   s * 0.32),  # nozzle right
		Vector2(-28.0,  s * 0.32),  # nozzle left
		Vector2(-30.0,  s * 0.06),  # max width left
		Vector2(-24.0, -s * 0.12),  # shoulder left
	], Color(0.93, 0.94, 0.96))

	# Dorsal spine highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-2.5,  -s * 0.76),
		Vector2(2.5,   -s * 0.76),
		Vector2(3.5,    s * 0.15),
		Vector2(-3.5,   s * 0.15),
	], Color(0.98, 0.98, 1.0, 0.60))

	# Left fuselage shadow (triangle — subtle left-side depth shading)
	_draw_rotated_poly(pos, rad, [
		Vector2(-6.0,  -s * 0.78),
		Vector2(-24.0, -s * 0.12),
		Vector2(-28.0,  s * 0.32),
	], Color(0.72, 0.74, 0.78, 0.30))

	# Panel line — diagonal chine
	_draw_rotated_poly(pos, rad, [
		Vector2(-7.0,  -s * 0.62),
		Vector2(-4.0,  -s * 0.62),
		Vector2(1.0,   -s * 0.32),
		Vector2(-2.0,  -s * 0.32),
	], Color(0.60, 0.63, 0.70, 0.40))

	# Panel line — horizontal mid-fuselage seam
	_draw_rotated_poly(pos, rad, [
		Vector2(-22.0,  s * 0.04),
		Vector2(22.0,   s * 0.04),
		Vector2(22.0,   s * 0.06),
		Vector2(-22.0,  s * 0.06),
	], Color(0.60, 0.63, 0.70, 0.40))

	# Belly shadow
	_draw_rotated_poly(pos, rad, [
		Vector2(-16.0,  s * 0.10),
		Vector2(16.0,   s * 0.10),
		Vector2(14.0,   s * 0.32),
		Vector2(-14.0,  s * 0.32),
	], Color(0.62, 0.65, 0.70, 0.40))

	# Orange belly triangle marking
	_draw_rotated_poly(pos, rad, [
		Vector2(0.0,   s * 0.02),
		Vector2(12.0,  s * 0.22),
		Vector2(-12.0, s * 0.22),
	], Color(0.90, 0.20, 0.05, belly_alpha))

	# --- Layer 6: Vertical tail fins (canted outward) ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,           s * 0.05),
		Vector2(-25.0 - cant,   -s * 0.52),
		Vector2(-19.0 - cant,   -s * 0.42),
		Vector2(-16.0,           s * 0.14),
	], Color(0.58, 0.62, 0.68))
	_draw_rotated_poly(pos, rad, [
		Vector2(-20.0,           s * 0.05),
		Vector2(-25.0 - cant,   -s * 0.52),
		Vector2(-23.0 - cant,   -s * 0.49),
		Vector2(-19.0,           s * 0.04),
	], Color(0.72, 0.75, 0.80, 0.55))
	# Left fin tip accent
	_draw_rotated_poly(pos, rad, [
		Vector2(-25.0 - cant,  -s * 0.52),
		Vector2(-23.0 - cant,  -s * 0.49),
		Vector2(-24.0 - cant,  -s * 0.52),
	], Color(0.85, 0.15, 0.05, 0.70))

	_draw_rotated_poly(pos, rad, [
		Vector2(20.0,            s * 0.05),
		Vector2(25.0 + cant,    -s * 0.52),
		Vector2(19.0 + cant,    -s * 0.42),
		Vector2(16.0,            s * 0.14),
	], Color(0.58, 0.62, 0.68))
	_draw_rotated_poly(pos, rad, [
		Vector2(20.0,            s * 0.05),
		Vector2(25.0 + cant,    -s * 0.52),
		Vector2(23.0 + cant,    -s * 0.49),
		Vector2(19.0,            s * 0.04),
	], Color(0.72, 0.75, 0.80, 0.55))
	# Right fin tip accent
	_draw_rotated_poly(pos, rad, [
		Vector2(25.0 + cant,   -s * 0.52),
		Vector2(23.0 + cant,   -s * 0.49),
		Vector2(24.0 + cant,   -s * 0.52),
	], Color(0.85, 0.15, 0.05, 0.70))

	# --- Layer 7: Nozzle rings ---
	for nox_r in [-20.0, 20.0]:
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny), 13.0, Color(0.14, 0.15, 0.18))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny), 10.0, Color(0.25, 0.26, 0.30))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny),  7.0, Color(0.90, 0.45, 0.0))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny),  4.0, Color(0.96, 0.60, 0.0))
		_draw_rotated_circle(pos, rad, Vector2(nox_r, ny + 3.0), 5.5, Color(1.0, 1.0, 1.0, 1.0))

	# --- Layer 8: Canopy ---
	_draw_rotated_poly(pos, rad, [
		Vector2(-7.0,  -s * 0.48),
		Vector2(7.0,   -s * 0.48),
		Vector2(10.0,  -s * 0.24),
		Vector2(0.0,   -s * 0.12),
		Vector2(-10.0, -s * 0.24),
	], Color(0.04, 0.06, 0.14))
	_draw_rotated_poly(pos, rad, [
		Vector2(-5.0,  -s * 0.46),
		Vector2(3.0,   -s * 0.38),
		Vector2(2.0,   -s * 0.30),
		Vector2(-6.0,  -s * 0.36),
	], Color(0.18, 0.30, 0.65, 0.50))
	# Canopy rear edge highlight
	_draw_rotated_poly(pos, rad, [
		Vector2(-10.0, -s * 0.24),
		Vector2(10.0,  -s * 0.24),
		Vector2(9.0,   -s * 0.22),
		Vector2(-9.0,  -s * 0.22),
	], Color(0.80, 0.82, 0.86, 0.45))


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
