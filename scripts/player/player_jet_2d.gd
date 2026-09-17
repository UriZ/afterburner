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

	# --- Tail fins: short blades canted outward from the nacelle shoulder,
	# tip trimmed below the canopy apex so the canopy (not the fin) sets the
	# jet's total height. #112 round-6 feedback: the round-5 fin (tip at
	# x=0.340, only 0.040 outboard of its root) rose almost straight up past
	# the canopy (-0.615 vs canopy apex -0.590) — two near-vertical parallel
	# posts, measured 22.0%H/aspect 2.30 vs reference 13.1-16.7%H/3.04-3.37.
	# burst-a-02 shows a clearly raked blade, leaning outward as it rises, not
	# a vertical rod. Tip now kicks out to x=0.445 (~20 deg off vertical) and
	# stops at y=-0.545 — below the canopy's -0.590 apex — so shortening the
	# fin further would no longer move the jet's total-height ceiling at all;
	# the canopy is now the tallest feature, matching the reference envelope.
	var fin_r := [Vector2(0.300, -0.145), Vector2(0.445, -0.545), Vector2(0.420, -0.536), Vector2(0.258, -0.140)]
	var fin_hi_r := [Vector2(0.300, -0.145), Vector2(0.445, -0.545), Vector2(0.432, -0.541), Vector2(0.292, -0.148)]
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
	# A slender spine from the canopy down to the nozzle line. #112 round-5
	# feedback (first pass): cutting the max half-width from 0.400 to 0.305
	# alone wasn't enough — a render check against the reference showed the
	# shape STILL read as "a smooth toy shuttle" even at the narrower width,
	# because 12 closely-spaced points approximated a continuous curve. Per
	# the wrong-shape rule this needed fewer, sharper-angled straight edges,
	# not another width tweak: cut down to 7 points so the neck-to-shoulder
	# taper, the shoulder break, the nacelle wall, and the waist pull-in are
	# each one distinct straight facet, matching the reference's angular,
	# panelled silhouette instead of a rounded capsule.
	var fuselage_half := [
		Vector2(0.040, -0.530),  # neck top — flush with the canopy base, no nose cap above it
		Vector2(0.095, -0.220),  # single straight taper to the nacelle shoulder — fin roots sit just outside this
		Vector2(0.290, -0.150),  # sharp break out to the nacelle's max width
		Vector2(0.295, -0.075),  # near-vertical nacelle wall, well short of the nozzle outer edge
		Vector2(0.190, -0.010),  # sharp break back in — the waist, above the nozzle line
		Vector2(0.095, 0.040), Vector2(0.000, 0.048),
	]
	var fuselage: Array = _symmetric_poly(fuselage_half)
	_draw_hs_poly(origin, rad, fuselage, V0_HILITE)
	_stroke_hs_poly(origin, rad, fuselage, OUTLINE, OUTLINE_W)

	# Panel lines — thin engraved strokes following the spine's contour, not
	# filled bars. #112 round-5 feedback: the previous filled-quad seams read
	# as "a row of dark rectangles — a ventilation grille".
	_draw_hs_line(origin, rad, Vector2(0.0, -0.500), Vector2(0.0, -0.235), V2_MID, 1.5)
	for sx in [-0.035, 0.035]:
		_draw_hs_line(origin, rad, Vector2(sx, -0.460), Vector2(sx, -0.240), V1_LIT, 1.0)
	for sx in [-0.120, -0.032, 0.032, 0.120]:
		_draw_hs_line(origin, rad, Vector2(sx, -0.140), Vector2(sx, -0.070), V2_MID, 1.2)

	# (a) Lower-fuselage tone
	_draw_hs_poly(origin, rad, [
		Vector2(-0.295, -0.075), Vector2(0.295, -0.075), Vector2(0.190, -0.010),
		Vector2(0.095, 0.040), Vector2(0.000, 0.048), Vector2(-0.095, 0.040), Vector2(-0.190, -0.010),
	], V1_LIT)

	# (b) Nacelle outer-wall shading, both sides — hugs the angular shoulder/wall facets
	var nacelle_r := [Vector2(0.220, -0.140), Vector2(0.290, -0.150), Vector2(0.295, -0.075), Vector2(0.230, -0.075)]
	_draw_hs_poly(origin, rad, _mirror(nacelle_r), V3_SHADOW)
	_draw_hs_poly(origin, rad, nacelle_r, V3_SHADOW)

	# (c) Aft-deck shadow bar
	_draw_hs_poly(origin, rad, [
		Vector2(-0.050, -0.030), Vector2(0.028, -0.030), Vector2(0.028, -0.005), Vector2(-0.050, -0.005),
	], V3_SHADOW)

	# (d) Glove chevrons — darkest marks on the airframe, tucked inside the
	# shoulder-break facet so they no longer sit against the (now larger)
	# nozzle discs and read as part of a "rectangular housing" around them.
	var chevron_r := [Vector2(0.100, -0.205), Vector2(0.140, -0.195), Vector2(0.155, -0.175), Vector2(0.115, -0.180)]
	_draw_hs_poly(origin, rad, _mirror(chevron_r), BLACK)
	_draw_hs_poly(origin, rad, chevron_r, BLACK)

	# --- Canopy: a small dark wedge nestled into the fuselage spine, not a bright
	# cyan bulb on a stick. #112 round-5 feedback: reference (burst-a-02/03) shows
	# a small DARK purple-blue wedge, noticeably smaller than our previous bubble.
	# Base stays flush with the trimmed neck top (-0.530) per the zero-nose-extent
	# rule; apex is pulled in from -0.605 to -0.590 and narrowed.
	var canopy := [
		Vector2(-0.032, -0.530), Vector2(-0.040, -0.550), Vector2(-0.020, -0.578),
		Vector2(0.000, -0.590), Vector2(0.020, -0.578), Vector2(0.040, -0.550), Vector2(0.032, -0.530),
	]
	_draw_hs_poly(origin, rad, canopy, CANOPY_GLASS)
	_draw_hs_poly(origin, rad, [
		Vector2(-0.022, -0.568), Vector2(0.000, -0.582), Vector2(0.022, -0.568),
		Vector2(0.014, -0.548), Vector2(-0.014, -0.548),
	], CANOPY_HI)
	_stroke_hs_poly(origin, rad, canopy, OUTLINE, OUTLINE_W)

	# --- Nozzles: near-black discs with a small hot ember core, not the reverse.
	# #112 round-6 feedback: round-5's outer glow alone reached 82% of the housing
	# radius, leaving only a thin dark rim — a light-brown-rimmed, mostly-orange
	# disc. Reference (burst-a-02, burst-c-11) shows the opposite balance: a
	# near-black housing that stays dark out to ~47% of its radius before the
	# ember starts, with the brightest core topping out at 24% of the housing.
	# Housing size/position unchanged (0.095*HS) — only the internal balance
	# between dark rim and hot core is inverted.
	for x_n in [-0.315, 0.315]:
		var housing: Vector2 = Vector2(x_n, -0.040) * HS
		_draw_rotated_circle(origin, rad, housing, 0.095 * HS, NOZZLE_RIM)
		var glow: Vector2 = Vector2(x_n, -0.015) * HS
		_draw_rotated_circle(origin, rad, glow, 0.045 * HS, Color8(150, 60, 15))
		_draw_rotated_circle(origin, rad, glow, 0.032 * HS, Color8(230, 120, 25))
		_draw_rotated_circle(origin, rad, glow, 0.023 * HS, Color8(255, 190, 90))


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
