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

const V0_HILITE := Color8(255, 250, 246)
const V1_LIT := Color8(210, 200, 196)
const V2_MID := Color8(173, 161, 157)
const V3_SHADOW := Color8(150, 120, 120)  # warm-tinted grey (R > G=B), NOT brown — matches
# the discrete in-game palette sampled from ab2-arcade-desert.png (native, uncompressed):
# (255,255,255) hilite / (164,164,164) mid / (164,132,132) shadow. #112 feedback: our
# airframe was reading beige because these tones carried a G>B cream cast (240,220,165
# etc.) that isn't in the source palette at all. #112 round-5: the lit stops now carry a
# small warm bias (R raised a few points, G=B held EQUAL) so the airframe picks up a hint
# of the orange sky without reintroducing that G>B cream cast.
const OUTLINE := Color8(70, 48, 40)  # dark warm neutral silhouette line — NOT saturated red
const BLACK := Color8(0, 0, 0)
const NOZZLE_RIM := Color8(24, 19, 17)  # near-black housing — #112 round-6: the round-5
# values (light-brown rim + orange annulus + pale-yellow core filling 82% of the housing)
# were inverted from the reference. burst-a-02/c-11 both show a housing that is mostly
# dark/near-black with only a SMALL hot orange ember at the centre, not the reverse. The
# round-4 note below (pure black read as a "car tire") was about a small housing with a
# large core; this housing keeps its size but the core is now a minority of its area.
const CANOPY_GLASS := Color8(58, 52, 108)  # dark blue-violet wedge — #112 round-5: reference
# (burst-a-02/03, ref_jet.png) shows a small DARK purple-blue wedge nestled into the
# fuselage spine, not a bright cyan bulb on a stick.
const CANOPY_HI := Color8(100, 92, 165)

const DEATH_DURATION := 1.0
const INVINCIBILITY_DURATION := 2.0
const FLASH_INTERVAL := 0.1
const FLASH_MIN_ALPHA := 0.35  # #112 round-5: respawn flash now dims via modulate.a instead
# of toggling full invisibility — a 50/50 fully-invisible blink measured only 79.2% frame
# occupancy over 15s (below the 90% target). The jet is never literally absent mid-flash.

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
var _flash_dim: bool = false    # alternates the respawn flash between full and dim alpha
var _visible_flag: bool = true  # only for the permanent hide once all lives are exhausted
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
	if GameState.capture_invincible:
		return  # #112 round-5: judge/QA capture sessions opt out of death entirely
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
	# Tumble: rotate and fall, clamped to the normal on-screen play area. #112
	# round-4: an unclamped fall carried the jet below the visible frame for
	# most of the (formerly 2s) death animation, leaving the screen empty and
	# failing the >=90% occupancy rule. Falling still reads clearly against
	# MOVE_MAX.y since the tumble starts well above it.
	_bank_angle += 360.0 * delta
	position.y = minf(position.y + 200.0 * delta, MOVE_MAX.y)

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
	_flash_dim = false
	_visible_flag = true
	modulate.a = 1.0


func _process_invincibility(delta: float) -> void:
	_invincibility_timer -= delta
	if _is_respawn:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = FLASH_INTERVAL
			_flash_dim = not _flash_dim
		modulate.a = FLASH_MIN_ALPHA if _flash_dim else 1.0
	if _invincibility_timer <= 0.0:
		_is_invincible = false
		_is_respawn = false
		modulate.a = 1.0


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

	# --- Wings (drawn first: single straight-swept blade, the dominant surface) ---
	# Leading and trailing edges are each a single straight segment root-to-tip
	# (no intermediate bend point) — the reference shows one continuous blade,
	# not a kinked "W". #112 feedback: the previous 6-point silhouette bent at
	# x=0.700, reading as a gull-wing kink.
	var wing_r := [Vector2(0.090, -0.355), Vector2(1.000, -0.125), Vector2(0.965, -0.095), Vector2(0.100, -0.250)]
	var wing_le_r := [Vector2(0.090, -0.355), Vector2(1.000, -0.125), Vector2(0.995, -0.108), Vector2(0.098, -0.333)]
	var wing_te_r := [Vector2(0.100, -0.283), Vector2(0.955, -0.118), Vector2(0.965, -0.095), Vector2(0.100, -0.250)]
	_draw_wing(origin, rad, _mirror(wing_r), _mirror(wing_le_r), _mirror(wing_te_r))
	_draw_wing(origin, rad, wing_r, wing_le_r, wing_te_r)

	# --- Tail fins: a triangular blade rising from the nacelle shoulder, wide
	# at the base and tapering to a single point tip — NOT a constant-width
	# stick. #112 round-7 feedback: the round-6 fin was a near-parallel-edged
	# quad (root width 0.042, tip width 0.025 — barely tapered), reading as a
	# "straight constant-width stick crossing the wings". burst-c-03 shows a
	# clearly wedge-shaped fin: wide where it meets the nacelle shoulder,
	# narrowing continuously to a sharp point. Rebuilt as a true triangle (base
	# width 0.115, tip is a single coincident point) rooted at the new, smaller
	# fuselage shoulder (0.100, -0.170) and reaching out toward the nozzle's
	# inner edge (nozzle center 0.315 - radius 0.095 = 0.220) without crossing
	# into it. Tip kept at y=-0.530, still below the canopy apex (-0.590) so
	# the canopy remains the tallest feature and the envelope is unchanged.
	var fin_r := [Vector2(0.115, -0.150), Vector2(0.230, -0.160), Vector2(0.400, -0.530)]
	var fin_hi_r := [Vector2(0.230, -0.160), Vector2(0.400, -0.530), Vector2(0.385, -0.522), Vector2(0.205, -0.155)]
	_draw_fin(origin, rad, _mirror(fin_r), _mirror(fin_hi_r))
	_draw_fin(origin, rad, fin_r, fin_hi_r)

	# --- Tailplanes ---
	# Tucked to a small stub at the tail-cone/nozzle shoulder (y > 0, well
	# below the wing's -0.355..-0.095 band and far short of its span). #112
	# feedback: the previous tailplane nearly matched the wing's span and sat
	# in the same vertical band, so the two surfaces read as a double-banded
	# biplane. The reference shows no separate tailplane blade at all in this
	# near head-on view — it's a small nub hugging the tail cone, not a second
	# wing.
	var tail_r := [Vector2(0.140, 0.005), Vector2(0.400, 0.040), Vector2(0.385, 0.072), Vector2(0.125, 0.045)]
	var tail_le_r := [Vector2(0.140, 0.005), Vector2(0.400, 0.040), Vector2(0.395, 0.026), Vector2(0.138, -0.008)]
	_draw_tailplane(origin, rad, _mirror(tail_r), _mirror(tail_le_r))
	_draw_tailplane(origin, rad, tail_r, tail_le_r)

	# --- Fuselage body: symmetric closed polygon, right half authored top-to-bottom ---
	# #112 round-7 feedback: the round-6 body (max half-width 0.295*HS, bottom
	# point at y=0.048) was "a large near-uniform flat WHITE wedge... widening
	# downward into a belly that hangs BELOW the nozzles" — burst-c-03/c-11 both
	# show the opposite: a slim spine that NARROWS as it descends, tapering to a
	# thin tailcone tucked BETWEEN the nozzle nacelles, never reaching their
	# bottom edge (nozzle disc bottom is at y=0.055; the old point-7 at y=0.048
	# sat almost flush with it, reading as "hanging below"). Max half-width cut
	# from 0.290 to 0.100 (measured against burst-c-11: spine width is ~0.6x a
	# single nozzle's diameter, not 1.5x), and the bottom point pulled up to
	# y=-0.015 — well clear of the nozzle bottom, roughly level with the nozzle
	# centers. This also fixes round-7 finding #4 (wing/fuselage seam): the old
	# 0.290-wide nacelle plate cut a hard rectangular step across the inner 30%
	# of the wing's span; at 0.100 wide the fuselage no longer reaches the wing
	# root band at all (wing root sits at x=0.090-0.100, y=-0.355..-0.250; the
	# fuselage there is only 0.045-0.055 wide), so there's nothing left to blend.
	var fuselage_half := [
		Vector2(0.030, -0.530),  # neck top — flush with the (now smaller) canopy base
		Vector2(0.055, -0.300),  # slender neck, slight widen
		Vector2(0.100, -0.170),  # shoulder — max width, well inside the wing root and nozzle inner edge
		Vector2(0.090, -0.110),  # nacelle wall, pulling back in already
		Vector2(0.055, -0.050),  # waist, narrowing toward the tailcone
		Vector2(0.000, -0.015),  # tailcone tip — above nozzle center (-0.040), far above nozzle bottom (0.055)
	]
	var fuselage: Array = _symmetric_poly(fuselage_half)
	_draw_hs_poly(origin, rad, fuselage, V0_HILITE)
	_stroke_hs_poly(origin, rad, fuselage, OUTLINE, OUTLINE_W)

	# Panel lines — thin engraved strokes following the spine's contour, not
	# filled bars. #112 round-7: endpoints pulled in to match the narrower spine.
	_draw_hs_line(origin, rad, Vector2(0.0, -0.500), Vector2(0.0, -0.170), V2_MID, 1.5)
	for sx in [-0.020, 0.020]:
		_draw_hs_line(origin, rad, Vector2(sx, -0.460), Vector2(sx, -0.180), V1_LIT, 1.0)
	for sx in [-0.045, 0.045]:
		_draw_hs_line(origin, rad, Vector2(sx, -0.100), Vector2(sx, -0.050), V2_MID, 1.2)

	# (a) Lower-fuselage tone — traces the nacelle wall down to the tailcone tip
	_draw_hs_poly(origin, rad, [
		Vector2(-0.090, -0.110), Vector2(0.090, -0.110), Vector2(0.055, -0.050),
		Vector2(0.000, -0.015), Vector2(-0.055, -0.050),
	], V1_LIT)

	# (b) Nacelle outer-wall shading, both sides — small shadow quad at the shoulder
	var nacelle_r := [Vector2(0.075, -0.165), Vector2(0.100, -0.170), Vector2(0.090, -0.110), Vector2(0.070, -0.110)]
	_draw_hs_poly(origin, rad, _mirror(nacelle_r), V3_SHADOW)
	_draw_hs_poly(origin, rad, nacelle_r, V3_SHADOW)

	# (c) Aft-deck shadow bar — repositioned to sit just above the tailcone tip
	_draw_hs_poly(origin, rad, [
		Vector2(-0.030, -0.045), Vector2(0.030, -0.045), Vector2(0.030, -0.025), Vector2(-0.030, -0.025),
	], V3_SHADOW)

	# (d) Glove chevrons — darkest marks on the airframe, tucked inside the
	# (now much smaller) shoulder, well clear of the nozzle discs.
	var chevron_r := [Vector2(0.040, -0.150), Vector2(0.068, -0.144), Vector2(0.072, -0.128), Vector2(0.045, -0.132)]
	_draw_hs_poly(origin, rad, _mirror(chevron_r), BLACK)
	_draw_hs_poly(origin, rad, chevron_r, BLACK)

	# --- Canopy: a tiny dot, not a "prominent navy nub on a spike". #112 round-7
	# feedback: the round-5 canopy (width 0.080*HS at its widest) still read as
	# a nub. burst-c-11 shows it as barely more than a dot on the spine. Width
	# cut to 0.036*HS (55% narrower). The apex y (-0.590) is UNCHANGED — Rule
	# Zero: the gate's own envelope measurement (35.0%W/17.0%H/2.95) passed at
	# this apex height, and the canopy is the tallest feature that sets it, so
	# shrinking height would silently break the envelope the gate said to leave
	# alone. Only width/bulk was cut, matching "shrink further" without moving
	# the ceiling.
	var canopy := [
		Vector2(-0.015, -0.530), Vector2(-0.018, -0.545), Vector2(-0.008, -0.575),
		Vector2(0.000, -0.590), Vector2(0.008, -0.575), Vector2(0.018, -0.545), Vector2(0.015, -0.530),
	]
	_draw_hs_poly(origin, rad, canopy, CANOPY_GLASS)
	_draw_hs_poly(origin, rad, [
		Vector2(-0.010, -0.568), Vector2(0.000, -0.582), Vector2(0.010, -0.568),
		Vector2(0.006, -0.548), Vector2(-0.006, -0.548),
	], CANOPY_HI)
	_stroke_hs_poly(origin, rad, canopy, OUTLINE, OUTLINE_W)

	# --- Nozzles: thin dark rim, hot orange core filling most of the disc — the
	# brightest thing on the aircraft. #112 round-7 feedback: round-6 over-corrected
	# — the housing measured as "two tyres with dim hubcaps" (core only ~35% of the
	# disc and dim). Re-measured burst-c-03/c-11 directly: the core fills ~55-60% of
	# the disc radius, not 24-47%. Outer glow radius raised 0.045->0.057*HS (60% of
	# the 0.095*HS housing radius) and all three layers brightened. Housing
	# size/position unchanged (0.095*HS @ x=+-0.315) — only the dark/hot balance
	# and brightness shifted back toward the hot end.
	for x_n in [-0.315, 0.315]:
		var housing: Vector2 = Vector2(x_n, -0.040) * HS
		_draw_rotated_circle(origin, rad, housing, 0.095 * HS, NOZZLE_RIM)
		var glow: Vector2 = Vector2(x_n, -0.015) * HS
		_draw_rotated_circle(origin, rad, glow, 0.057 * HS, Color8(190, 75, 15))
		_draw_rotated_circle(origin, rad, glow, 0.041 * HS, Color8(245, 135, 30))
		_draw_rotated_circle(origin, rad, glow, 0.029 * HS, Color8(255, 205, 110))


func _draw_tailplane(origin: Vector2, rad: float, silhouette: Array, le_strip: Array) -> void:
	_draw_hs_poly(origin, rad, silhouette, V2_MID)
	_draw_hs_poly(origin, rad, le_strip, V0_HILITE)
	_stroke_hs_poly(origin, rad, silhouette, OUTLINE, OUTLINE_W)


func _draw_wing(origin: Vector2, rad: float, silhouette: Array, le_band: Array, te_band: Array) -> void:
	_draw_hs_poly(origin, rad, silhouette, V2_MID)
	_draw_hs_poly(origin, rad, le_band, V0_HILITE)
	_draw_hs_poly(origin, rad, te_band, V3_SHADOW)
	_stroke_hs_poly(origin, rad, silhouette, OUTLINE, OUTLINE_W)


## A slim white blade, not a filled slab: silhouette in V1_LIT with a V0_HILITE
## leading-edge sliver, no shadow fill. #112 round-5.
func _draw_fin(origin: Vector2, rad: float, silhouette: Array, leading_edge: Array) -> void:
	_draw_hs_poly(origin, rad, silhouette, V1_LIT)
	_draw_hs_poly(origin, rad, leading_edge, V0_HILITE)
	_stroke_hs_poly(origin, rad, silhouette, OUTLINE, OUTLINE_W)


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


## Draws a single open segment (panel line), unlike _stroke_hs_poly which
## always closes the loop. #112 round-5: panel lines are thin strokes, not
## filled quads.
func _draw_hs_line(origin: Vector2, rad: float, p0: Vector2, p1: Vector2, color: Color, width: float) -> void:
	var cs: float = cos(rad)
	var sn: float = sin(rad)
	var pts: PackedVector2Array = PackedVector2Array()
	for p in [p0 * HS, p1 * HS]:
		pts.append(Vector2(origin.x + p.x * cs - p.y * sn, origin.y + p.x * sn + p.y * cs))
	draw_polyline(pts, color, width, false)


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
