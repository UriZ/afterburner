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

# --- #112 redraw geometry constants ---
const HS := 171.0          # half-span in px; full span 342 px = 35.6% of 960
const ANCHOR_Y := 28.0     # local origin offset so on-screen placement is unchanged
const OUTLINE_W := 2.0     # thin silhouette definition line, not a decal border

const V0_HILITE := Color8(255, 255, 245)
const V1_LIT := Color8(240, 220, 165)
const V2_MID := Color8(198, 192, 148)
const V3_SHADOW := Color8(138, 108, 92)
const OUTLINE := Color8(70, 48, 40)  # dark warm neutral silhouette line — NOT saturated red
const BLACK := Color8(0, 0, 0)
const CANOPY_GLASS := Color8(132, 197, 247)
const CANOPY_HI := Color8(197, 247, 247)

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
	_show_game_over_screen()


func _show_game_over_screen() -> void:
	if not get_tree():
		return
	var screen := Control.new()
	screen.set_script(preload("res://scripts/ui/game_over_screen.gd"))
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(screen)
	get_tree().root.add_child(canvas)


# --- Public interface ---

func get_screen_position() -> Vector2:
	return position


func get_collision_radius() -> float:
	return PLAYER_SCALE * 0.6


func get_bank_angle() -> float:
	return _bank_angle


# --- Drawing ---

## Geometry per #112 architect spec: half-span (HS) units, origin at the nozzle-line
## midpoint (the roll axis). Right-side coordinates are authored directly; left-side
## parts are produced by negating x and reversing the winding order. Banking is a pure
## image-plane rotation — no foreshortening, no relighting (measured: a de-rotated
## banked reference frame matches the level frame's span/nozzle-separation ratio).
func _draw_player(pos: Vector2, bank: float) -> void:
	var rad: float = deg_to_rad(bank)
	var origin: Vector2 = pos + Vector2(0.0, ANCHOR_Y)

	# --- Tailplanes ---
	var tail_r := [Vector2(0.380, -0.155), Vector2(0.810, -0.010), Vector2(0.800, 0.035), Vector2(0.360, -0.085)]
	var tail_le_r := [Vector2(0.380, -0.155), Vector2(0.810, -0.010), Vector2(0.808, 0.002), Vector2(0.378, -0.138)]
	_draw_tailplane(origin, rad, _mirror(tail_r), _mirror(tail_le_r))
	_draw_tailplane(origin, rad, tail_r, tail_le_r)

	# --- Wings ---
	# Roots pulled in to meet the narrowed fuselage neck (see below) so the
	# wing reads as the dominant mass sweeping almost from centerline to tip,
	# per reference — not a short blade bolted onto a fat body.
	var wing_r := [Vector2(0.085, -0.360), Vector2(0.700, -0.240), Vector2(1.000, -0.128), Vector2(0.940, -0.098), Vector2(0.718, -0.155), Vector2(0.100, -0.245)]
	var wing_le_r := [Vector2(0.085, -0.360), Vector2(0.700, -0.240), Vector2(1.000, -0.128), Vector2(0.986, -0.120), Vector2(0.692, -0.229), Vector2(0.087, -0.332)]
	var wing_te_r := [Vector2(0.095, -0.288), Vector2(0.704, -0.180), Vector2(0.956, -0.106), Vector2(0.940, -0.098), Vector2(0.718, -0.155), Vector2(0.100, -0.245)]
	_draw_wing(origin, rad, _mirror(wing_r), _mirror(wing_le_r), _mirror(wing_te_r))
	_draw_wing(origin, rad, wing_r, wing_le_r, wing_te_r)

	# --- Vertical tail fins (drawn before the fuselage so it covers their roots) ---
	# Rooted at the shoulder, rising steeply to near-canopy height with a raked
	# trailing edge — a distinct blade, not a sliver following the fuselage
	# taper (that read as body shading and made the fins disappear, #112).
	var fin_r := [Vector2(0.075, -0.230), Vector2(0.125, -0.560), Vector2(0.165, -0.510), Vector2(0.155, -0.195)]
	var fin_shadow_r := [Vector2(0.075, -0.230), Vector2(0.118, -0.548), Vector2(0.125, -0.540), Vector2(0.083, -0.230)]
	_draw_fin(origin, rad, _mirror(fin_r), _mirror(fin_shadow_r))
	_draw_fin(origin, rad, fin_r, fin_shadow_r)

	# --- Fuselage body: symmetric closed polygon, right half authored top-to-bottom ---
	# A slender neck from the canopy down to the wing root, flaring sharply into
	# the engine-nacelle bulge only in the last stretch above the nozzles. The
	# old design flared immediately below the canopy, filling the whole span
	# with one wide oval and burying the tail fins — see #112 feedback.
	var fuselage_half := [
		Vector2(0.030, -0.622),  # flat nose cap — nothing drawn above this row
		Vector2(0.050, -0.585), Vector2(0.065, -0.520), Vector2(0.080, -0.450),
		Vector2(0.095, -0.380), Vector2(0.110, -0.300), Vector2(0.120, -0.220),  # narrow neck — fin tips clear this
		Vector2(0.390, -0.155),  # sharp flare into the nacelle bulge
		Vector2(0.400, -0.080), Vector2(0.355, -0.005),
		Vector2(0.230, 0.035), Vector2(0.120, 0.048), Vector2(0.000, 0.052),
	]
	var fuselage: Array = _symmetric_poly(fuselage_half)
	_draw_hs_poly(origin, rad, fuselage, V0_HILITE)
	_stroke_hs_poly(origin, rad, fuselage, OUTLINE, OUTLINE_W)

	# (a) Lower-fuselage tone
	_draw_hs_poly(origin, rad, [
		Vector2(-0.400, -0.080), Vector2(0.400, -0.080), Vector2(0.355, -0.005), Vector2(0.230, 0.035),
		Vector2(0.120, 0.048), Vector2(0.000, 0.052), Vector2(-0.120, 0.048), Vector2(-0.230, 0.035),
		Vector2(-0.355, -0.005),
	], V1_LIT)

	# (b) Nacelle outer-wall shading, both sides — hugs the new bulge, not the
	# old (now-removed) high flare
	var nacelle_r := [Vector2(0.250, -0.150), Vector2(0.395, -0.100), Vector2(0.400, -0.080), Vector2(0.310, -0.080)]
	_draw_hs_poly(origin, rad, _mirror(nacelle_r), V3_SHADOW)
	_draw_hs_poly(origin, rad, nacelle_r, V3_SHADOW)

	# (c) Panel seams — four vertical bars, pulled down onto the bulge (the
	# narrow neck above no longer has the width to hold them)
	for sx in [-0.155, -0.040, 0.040, 0.155]:
		_draw_hs_poly(origin, rad, _seam_quad(sx, -0.140, -0.060, 0.0175), V2_MID)

	# (d) Aft-deck shadow bar
	_draw_hs_poly(origin, rad, [
		Vector2(-0.078, -0.101), Vector2(0.045, -0.101), Vector2(0.045, -0.076), Vector2(-0.078, -0.076),
	], V3_SHADOW)

	# (e) Glove chevrons — darkest marks on the airframe, both sides. Moved
	# down onto the nacelle shoulder to match the new bulge position.
	var chevron_r := [Vector2(0.230, -0.185), Vector2(0.370, -0.145), Vector2(0.370, -0.115), Vector2(0.280, -0.115), Vector2(0.230, -0.155)]
	_draw_hs_poly(origin, rad, _mirror(chevron_r), BLACK)
	_draw_hs_poly(origin, rad, chevron_r, BLACK)

	# --- Canopy ---
	var canopy := [Vector2(-0.055, -0.605), Vector2(0.055, -0.605), Vector2(0.062, -0.520), Vector2(0.000, -0.500), Vector2(-0.062, -0.520)]
	_draw_hs_poly(origin, rad, canopy, CANOPY_GLASS)
	_draw_hs_poly(origin, rad, [
		Vector2(-0.045, -0.600), Vector2(0.045, -0.600), Vector2(0.040, -0.565), Vector2(-0.040, -0.565),
	], CANOPY_HI)
	_stroke_hs_poly(origin, rad, canopy, OUTLINE, OUTLINE_W)

	# --- Nozzles: large black housing (measured ~13.7% of wingspan, up from a
	# previous 9.4% that read as too small) around a golden-yellow glow core.
	# No stroke needed — pure black against the white airframe / orange sky
	# already reads via value contrast alone.
	for x_n in [-0.315, 0.315]:
		var housing: Vector2 = Vector2(x_n, -0.040) * HS
		_draw_rotated_circle(origin, rad, housing, 0.135 * HS, BLACK)
		var glow: Vector2 = Vector2(x_n, 0.005) * HS
		_draw_rotated_circle(origin, rad, glow, 0.090 * HS, Color8(90, 45, 10))
		_draw_rotated_circle(origin, rad, glow, 0.065 * HS, Color8(225, 150, 25))
		_draw_rotated_circle(origin, rad, glow, 0.039 * HS, Color8(255, 220, 100))


func _draw_tailplane(origin: Vector2, rad: float, silhouette: Array, le_strip: Array) -> void:
	_draw_hs_poly(origin, rad, silhouette, V2_MID)
	_draw_hs_poly(origin, rad, le_strip, V0_HILITE)
	_stroke_hs_poly(origin, rad, silhouette, OUTLINE, OUTLINE_W)


func _draw_wing(origin: Vector2, rad: float, silhouette: Array, le_band: Array, te_band: Array) -> void:
	_draw_hs_poly(origin, rad, silhouette, V2_MID)
	_draw_hs_poly(origin, rad, le_band, V0_HILITE)
	_draw_hs_poly(origin, rad, te_band, V3_SHADOW)
	_stroke_hs_poly(origin, rad, silhouette, OUTLINE, OUTLINE_W)


func _draw_fin(origin: Vector2, rad: float, silhouette: Array, shadow: Array) -> void:
	_draw_hs_poly(origin, rad, silhouette, V1_LIT)
	_draw_hs_poly(origin, rad, shadow, V3_SHADOW)
	_stroke_hs_poly(origin, rad, silhouette, OUTLINE, OUTLINE_W)


func _seam_quad(x: float, y0: float, y1: float, half_width: float) -> Array:
	return [Vector2(x - half_width, y0), Vector2(x + half_width, y0), Vector2(x + half_width, y1), Vector2(x - half_width, y1)]


## Mirrors a right-side part to its left-side counterpart: negate x, reverse the
## winding order so the polygon stays counter-clockwise.
func _mirror(pts: Array) -> Array:
	var out: Array = []
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		out.append(Vector2(-p.x, p.y))
	return out


## Closes a symmetric polygon from a right-side half-scan (top-to-bottom). If the
## final point already sits on the centerline (x == 0) it is not duplicated.
func _symmetric_poly(half_pts: Array) -> Array:
	var full: Array = half_pts.duplicate()
	var start: int = half_pts.size() - 1
	if absf(half_pts[start].x) < 0.001:
		start -= 1
	for i in range(start, -1, -1):
		var p: Vector2 = half_pts[i]
		full.append(Vector2(-p.x, p.y))
	return full


func _scale(pts: Array, k: float) -> Array:
	var out: Array = []
	for p in pts:
		out.append(p * k)
	return out


func _draw_hs_poly(origin: Vector2, rad: float, pts: Array, color: Color) -> void:
	_draw_rotated_poly(origin, rad, _scale(pts, HS), color)


func _stroke_hs_poly(origin: Vector2, rad: float, pts: Array, color: Color, width: float) -> void:
	_stroke_rotated_poly(origin, rad, _scale(pts, HS), color, width)


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


## Strokes a closed polygon outline. antialiased = false: emulating pixel art.
func _stroke_rotated_poly(center: Vector2, angle: float, local_pts: Array, color: Color, width: float) -> void:
	var cs: float = cos(angle)
	var sn: float = sin(angle)
	var pts: PackedVector2Array = PackedVector2Array()
	for p in local_pts:
		var v: Vector2 = p
		pts.append(Vector2(center.x + v.x * cs - v.y * sn, center.y + v.x * sn + v.y * cs))
	pts.append(pts[0])  # close the loop
	draw_polyline(pts, color, width, false)


func _draw_rotated_circle(center: Vector2, angle: float, local_pos: Vector2, radius: float, color: Color) -> void:
	var cs: float = cos(angle)
	var sn: float = sin(angle)
	var rx: float = local_pos.x * cs - local_pos.y * sn
	var ry: float = local_pos.x * sn + local_pos.y * cs
	draw_circle(Vector2(center.x + rx, center.y + ry), radius, color)
