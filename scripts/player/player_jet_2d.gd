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

## Airframe value ramp, measured off the verified refuel-stage frame at t=557s
## in ab2-longplay.mp4 (stage 13 — identity proven per stage_data.gd's header).
## Sampling the body region there returns a clean greyscale ladder at
## V = 0.98 / 0.90 / 0.82 / 0.75, plus near-black nacelles at V ~ 0.33.
##
## #112 cycle-1: the previous ramp spanned a WIDER range than this and the jet
## still read as "a flat 2-tone skeletal dart" — because ~90% of the body area
## was painted V0_HILITE and the other stops only appeared in hairline panel
## lines. The gradient has to be applied across the body's area, not stored in
## constants. V4_DEEP and NACELLE_DARK below are what give the nacelles mass.
const V0_HILITE := Color8(255, 250, 246)
const V1_LIT := Color8(230, 224, 220)
const V2_MID := Color8(206, 198, 194)
const V3_SHADOW := Color8(168, 156, 152)  # warm-tinted grey (R > G=B), NOT brown — matches
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
const V4_DEEP := Color8(112, 100, 98)     # underside / nacelle-junction shadow
const NACELLE_DARK := Color8(40, 35, 44)  # the heavy housing the nozzles sit inside

## Canopy. Measured on ab2-arcade-reload-dorsal.jpg (astern, jet isolated on
## black): a saturated violet-magenta patch #9d3aca, four pixels wide on a
## 66px-wide jet = 0.12 half-span, and it is the TOPMOST part of the body —
## nothing of the airframe projects above it. #112 cycle-1 had it at 0.036 HS,
## which rendered as a dot nobody could see, and left the pale fuselage spine
## above it reading as a projecting grey needle nose. Widened to 0.12 HS and
## the spine above it removed entirely.
const CANOPY_GLASS := Color8(92, 48, 116)
const CANOPY_HI := Color8(150, 86, 186)

const DEATH_DURATION := 1.0
const INVINCIBILITY_DURATION := 2.0
const FLASH_INTERVAL := 0.1
## The respawn flash brightens the airframe instead of fading it (#92 / cycle-1
## gap 7). Two earlier versions were both wrong in opposite directions: a 50/50
## fully-invisible blink measured only 79.2% frame occupancy over 15s, and the
## fix for that dimmed `modulate.a` to 0.35 — which made the jet SEE-THROUGH,
## with ground and enemy sprites visible straight through the wings. AB2 never
## renders the player translucent.
##
## `modulate` is kept at alpha 1.0 permanently and the flash is carried by RGB
## gain above 1.0, which Godot applies as a multiply — so the jet stays fully
## opaque in every frame of the flash and still reads as flashing.
const FLASH_GAIN := 2.2
const FLASH_MIN_ALPHA := 1.0  # retained name: the floor is now "always opaque"

## Two-regime demo flight (#122 rework). The arcade's spread is situational,
## not constant: cx sd 12.88 pp in open cruise, 2.59 pp in a canyon run, and the
## combined 10.44 pp emerges from alternating between them - NOT from weaving at
## a constant amplitude, which reproduces neither regime.
##
## The regimes differ in CENTRE as well as amplitude: in a canyon the arcade
## player flies lower and straighter (cy 63.5 %H vs cruise 52.8 %H). That
## between-regime offset contributes f(1-f)(dmu)^2 = 26.3 of the combined cy
## variance, which the two regimes' internal spreads alone cannot account for
## (they pool to sd 11.03 against a measured 11.99).
@export var demo_flight: bool = false

const DEMO_CRUISE_SECS := 9.0      # f = 9/14 = 0.643 cruise fraction
const DEMO_STRAIGHT_SECS := 5.0    # matches the 11/17 cruise share of the reference sample
const DEMO_BLEND_SECS := 1.0       # cross-fade; a hard switch reads as a teleport

# Regime C - open cruise: wide lateral roaming, higher in frame
const C_CX := 480.0
## 360, not the measured 355. At 355 the cruise-y excursion bottoms out at 196,
## one pixel OUTSIDE MOVE_MIN.y = 200, so the clamp would shave the peak and
## silently depress the measured sd - the acceptance test would then be
## measuring the clamp rather than the flight path. At 360 the low point is 201.
## Re-check this if any amplitude changes.
const C_CY := 360.0
const C_AX1 := 148.0
const C_AX2 := 92.0
const C_AY1 := 98.0
const C_AY2 := 61.0
# Regime K - canyon/straight: nearly straight, lower in frame
const K_CX := 480.0
const K_CY := 427.0
const K_AX1 := 30.0
const K_AX2 := 18.0
const K_AY1 := 68.0
const K_AY2 := 42.0
# Shared angular rates (incommensurate; ratios 2.275 and 2.096) so the path
# never closes into a visible figure-eight.
const W_X1 := 0.91
const W_X2 := 2.07
const P_X2 := 1.7
const W_Y1 := 0.73
const P_Y1 := 0.9
const W_Y2 := 1.53
const P_Y2 := 2.4

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
var _demo_t: float = 0.0        # demo-flight clock; survives respawn (#122 risk 4)


func _ready() -> void:
	add_to_group("player")
	position = RESPAWN_POSITION
	_invincibility_timer = INVINCIBILITY_DURATION
	if "--demo-flight" in OS.get_cmdline_user_args():
		demo_flight = true


func _process(delta: float) -> void:
	if _is_dying:
		_process_death(delta)
		queue_redraw()
		return

	if _is_invincible:
		_process_invincibility(delta)

	# Live input ALWAYS wins, and wins permanently for the run. A demo that
	# fights the stick is a worse defect than a centred jet (#122 risk 1), so
	# this is checked before the demo branch rather than blended with it.
	if demo_flight and _input_enabled and _get_input_vector() != Vector2.ZERO:
		demo_flight = false

	if demo_flight and _input_enabled:
		_process_demo_flight(delta)
		queue_redraw()
		return

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


# --- Demo flight (#122) ---

## Regime weight: 1.0 = full cruise, 0.0 = full straight, smoothstep across the
## blend. A hard switch between regimes reads as a teleport.
func _demo_regime_weight(t: float) -> float:
	var period: float = DEMO_CRUISE_SECS + DEMO_STRAIGHT_SECS
	var p: float = fposmod(t, period)
	if p < DEMO_CRUISE_SECS - DEMO_BLEND_SECS:
		return 1.0
	if p < DEMO_CRUISE_SECS:
		return 1.0 - smoothstep(0.0, 1.0, (p - (DEMO_CRUISE_SECS - DEMO_BLEND_SECS)) / DEMO_BLEND_SECS)
	if p < period - DEMO_BLEND_SECS:
		return 0.0
	return smoothstep(0.0, 1.0, (p - (period - DEMO_BLEND_SECS)) / DEMO_BLEND_SECS)


## Demo-flight target position at time t. Both the centre and the amplitudes are
## regime-dependent; lerping between two in-bounds envelopes stays in bounds, so
## the blend cannot overshoot the movement clamps.
func _demo_position(t: float) -> Vector2:
	return _demo_position_at(t, _demo_regime_weight(t))


## The path formula with the regime weight supplied explicitly. Split out so a
## test can evaluate ONE pure regime over many full periods: the in-schedule
## straight window is only 4s long while the slowest y component's period is
## 8.6s, so measuring a regime's sd inside its own window measures the window,
## not the amplitudes. It is also what AC 1's falsification check needs — force
## w = 1.0 here and the straight-segment bound must fail, which is how we know
## the bound can fail at all.
func _demo_position_at(t: float, w: float) -> Vector2:
	var cx: float = lerpf(K_CX, C_CX, w)
	var cy: float = lerpf(K_CY, C_CY, w)
	var ax1: float = lerpf(K_AX1, C_AX1, w)
	var ax2: float = lerpf(K_AX2, C_AX2, w)
	var ay1: float = lerpf(K_AY1, C_AY1, w)
	var ay2: float = lerpf(K_AY2, C_AY2, w)
	return Vector2(
		cx + ax1 * sin(W_X1 * t) + ax2 * sin(W_X2 * t + P_X2),
		cy + ay1 * sin(W_Y1 * t + P_Y1) + ay2 * sin(W_Y2 * t + P_Y2)
	)


## `_demo_t` keeps accumulating across a respawn so the path stays phase-
## continuous rather than snapping back to the start of the cycle.
func _process_demo_flight(delta: float) -> void:
	var prev: Vector2 = position
	_demo_t += delta
	var target: Vector2 = _demo_position(_demo_t)
	position.x = clampf(target.x, MOVE_MIN.x, MOVE_MAX.x)
	position.y = clampf(target.y, MOVE_MIN.y, MOVE_MAX.y)
	_velocity = (position - prev) / maxf(delta, 0.0001)
	_update_banking(clampf(_velocity.x / move_speed, -1.0, 1.0), delta)


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
	_set_flash(false)


func _process_invincibility(delta: float) -> void:
	_invincibility_timer -= delta
	if _is_respawn:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = FLASH_INTERVAL
			_flash_dim = not _flash_dim
		_set_flash(_flash_dim)
	if _invincibility_timer <= 0.0:
		_is_invincible = false
		_is_respawn = false
		_set_flash(false)


## Single owner of `modulate`, so no path can leave the jet part-transparent.
## Alpha is pinned to 1.0 unconditionally; `lit` only raises RGB gain.
func _set_flash(lit: bool) -> void:
	var g: float = FLASH_GAIN if lit else 1.0
	modulate = Color(g, g, g, 1.0)


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

	# Draw order is back-to-front: surfaces that the body overlaps go down first,
	# so their roots disappear under the fuselage instead of butting against it.
	_draw_wings(origin, rad)
	_draw_tailplanes(origin, rad)
	_draw_fins(origin, rad)
	_draw_body(origin, rad)
	_draw_nacelles(origin, rad)
	_draw_canopy(origin, rad)


## Wings: a thin, near-horizontal blade at the nozzle line.
##
## Structure read off ab2-arcade-reload-dorsal.jpg, which shows the jet astern
## and isolated on black. Scanning it row by row, the wing occupies a band only
## ~0.08 HS thick running the full span, centred within 0.06 HS of the nozzle
## line — and the whole span from wingtip through nacelle to wingtip is one
## unbroken run of airframe pixels.
##
## #112 cycle-1 had the root at y=-0.355 and the tip at -0.125, so the wing
## climbed 0.23 HS from tip to root and attached high on the spine, well above
## the nacelles. That is what turned the nacelles into "disconnected floating"
## discs: nothing structural ran between them and the wing.
func _draw_wings(origin: Vector2, rad: float) -> void:
	# Chord ~0.09 HS at the root tapering to ~0.035 at the tip. The reference
	# wing is a thin layered band, not a slab: a first pass here used a uniform
	# 0.125-HS chord and read as a plank.
	var wing_r := [
		Vector2(0.150, -0.120), Vector2(1.000, -0.068),
		Vector2(1.000, -0.033), Vector2(0.150, -0.030),
	]
	# Leading-edge highlight and trailing-edge shadow: thin slivers, so the
	# blade reads as a lit surface with thickness rather than a flat cutout.
	var wing_le_r := [
		Vector2(0.150, -0.120), Vector2(1.000, -0.068),
		Vector2(1.000, -0.058), Vector2(0.150, -0.105),
	]
	var wing_te_r := [
		Vector2(0.150, -0.042), Vector2(1.000, -0.041),
		Vector2(1.000, -0.033), Vector2(0.150, -0.030),
	]
	for side in [-1.0, 1.0]:
		var sil: Array = wing_r if side > 0.0 else _mirror(wing_r)
		_draw_hs_poly(origin, rad, sil, V2_MID)
		_draw_hs_poly(origin, rad, wing_le_r if side > 0.0 else _mirror(wing_le_r), V0_HILITE)
		_draw_hs_poly(origin, rad, wing_te_r if side > 0.0 else _mirror(wing_te_r), V4_DEEP)
		_stroke_hs_poly(origin, rad, sil, OUTLINE, OUTLINE_W)


## Tailplane stubs below and behind the nozzles. The reference shows only small
## nubs here in this near-astern view, not a second full-span blade.
func _draw_tailplanes(origin: Vector2, rad: float) -> void:
	var tail_r := [
		Vector2(0.175, 0.045), Vector2(0.430, 0.062),
		Vector2(0.415, 0.098), Vector2(0.165, 0.086),
	]
	for side in [-1.0, 1.0]:
		var sil: Array = tail_r if side > 0.0 else _mirror(tail_r)
		_draw_hs_poly(origin, rad, sil, V3_SHADOW)
		_stroke_hs_poly(origin, rad, sil, OUTLINE, OUTLINE_W)


## Twin fins rising from the nacelle tops, canted outward — the tips sit further
## from the centreline than the roots. Reference rows put the fin at |x| ~ 0.27
## where it leaves the nacelle and |x| ~ 0.34 at the tip, ~0.09 HS thick, topping
## out at y=-0.455.
##
## The fins are the tallest features on the aircraft, but they are separated from
## the centreline, so they cannot read as a nose. The canopy stays the topmost
## thing on the BODY, which is the check that matters for the astern read.
func _draw_fins(origin: Vector2, rad: float) -> void:
	# Roots run down to y=-0.085, INSIDE the nacelle housing (top edge -0.108),
	# so the fin emerges from the engine mass instead of hovering above it. The
	# housing is drawn after the fins and covers the overlap.
	# Thickness ~0.055 HS. The reference's fin is 2-3px on a 66px-wide jet, and
	# it is a MID tone, not a highlight — a first pass here used 0.084 HS filled
	# with V2_MID plus a V0_HILITE edge, which made the fins the brightest thing
	# on the aircraft and pulled the eye off the fuselage.
	var fin_r := [
		Vector2(0.262, -0.085), Vector2(0.317, -0.085),
		Vector2(0.356, -0.455), Vector2(0.320, -0.455),
	]
	var fin_le_r := [
		Vector2(0.317, -0.085), Vector2(0.356, -0.455),
		Vector2(0.345, -0.455), Vector2(0.303, -0.085),
	]
	for side in [-1.0, 1.0]:
		var sil: Array = fin_r if side > 0.0 else _mirror(fin_r)
		_draw_hs_poly(origin, rad, sil, V3_SHADOW)
		_draw_hs_poly(origin, rad, fin_le_r if side > 0.0 else _mirror(fin_le_r), V1_LIT)
		_stroke_hs_poly(origin, rad, sil, OUTLINE, OUTLINE_W)


## The fuselage: ONE closed silhouette that runs from the canopy base out through
## both nacelles, so the nozzles are embedded in body mass rather than floating
## beside it.
##
## Half-widths are taken from the dorsal reference's row scan: ~0.09 HS just
## under the canopy, ~0.22 by the wing root, and ~0.42 at the outer nacelle wall,
## with the tailcone closing at the centreline below the nozzle line. #112
## cycle-1 capped the body at 0.100 HS and stopped above the nozzles entirely,
## which is the "no fuselage mass" finding.
##
## Shading is applied as AREA, not as panel lines: a bright central spine, mid
## flanks either side, and a deep shadow across the belly and the nacelle
## junction. The previous version stored a value ramp in constants but painted
## almost the whole body V0_HILITE, so it measured flat.
func _draw_body(origin: Vector2, rad: float) -> void:
	# Straight runs between few points, not a smooth curve: the reference body is
	# angular — flat shoulder, flat nacelle top, flat outer wall. A rounded
	# outline is what made the first pass read as an egg.
	var body_half := [
		Vector2(0.068, -0.244),  # neck, directly under the canopy base
		Vector2(0.135, -0.196),  # shoulder, single straight run outward
		Vector2(0.255, -0.150),  # glove, spreading toward the nacelle
		Vector2(0.400, -0.122),  # nacelle top, outer corner
		Vector2(0.425, -0.030),  # outer nacelle wall
		Vector2(0.405, 0.040),
		Vector2(0.300, 0.072),   # nacelle underside
		Vector2(0.190, 0.058),
		Vector2(0.120, 0.082),
		Vector2(0.000, 0.098),   # tailcone tip on the centreline
	]
	var body: Array = _symmetric_poly(body_half)
	_draw_hs_poly(origin, rad, body, V2_MID)

	# Mid-tone flanks over the base fill, leaving the spine to be lit separately.
	_draw_hs_poly(origin, rad, _symmetric_poly([
		Vector2(0.055, -0.240), Vector2(0.140, -0.180), Vector2(0.205, -0.150),
		Vector2(0.205, -0.020), Vector2(0.120, 0.040), Vector2(0.000, 0.062),
	]), V1_LIT)

	# Central lit spine. Deliberately a NARROW straight-sided wedge, not a broad
	# rounded one: the first pass at this used a 0.18-HS-wide rounded panel and
	# the body read as a white egg with a cap on it. The reference's lit area is
	# a slim strip down the spine with the shoulders left in mid-tone.
	_draw_hs_poly(origin, rad, _symmetric_poly([
		Vector2(0.030, -0.232), Vector2(0.052, -0.170), Vector2(0.058, -0.070),
		Vector2(0.040, 0.000), Vector2(0.000, 0.034),
	]), V0_HILITE)

	# Windscreen shadow: a dark band directly beneath the canopy. Without it the
	# canopy sits on an unbroken pale dome and reads as stuck on rather than set
	# into the airframe.
	_draw_hs_poly(origin, rad, _symmetric_poly([
		Vector2(0.075, -0.232), Vector2(0.105, -0.208), Vector2(0.100, -0.188),
		Vector2(0.000, -0.196),
	]), V3_SHADOW)

	# Belly shadow: the underside turns away from the light, which is what stops
	# the body reading as a flat cutout at the bottom edge.
	_draw_hs_poly(origin, rad, _symmetric_poly([
		Vector2(0.200, 0.020), Vector2(0.120, 0.082), Vector2(0.000, 0.098),
	]), V4_DEEP)

	# Nacelle-junction shadow, both sides: the crease where the nacelle meets the
	# fuselage. Sells the nacelles as attached volumes rather than stuck-on discs.
	var crease_r := [
		Vector2(0.215, -0.145), Vector2(0.255, -0.140),
		Vector2(0.250, 0.050), Vector2(0.205, 0.040),
	]
	_draw_hs_poly(origin, rad, _mirror(crease_r), V4_DEEP)
	_draw_hs_poly(origin, rad, crease_r, V4_DEEP)

	_stroke_hs_poly(origin, rad, body, OUTLINE, OUTLINE_W)


## Nacelle housings and the nozzles embedded in them.
##
## The reference shows each nozzle as a hot disc sunk into a near-black housing
## that extends above and below it — the dark mass is taller than the disc, which
## is what makes the engine read as buried in structure. Nozzle centres at
## |x| = 0.303 with a hot core of ~0.06 HS radius, both measured off the dorsal
## reference's pixel map.
func _draw_nacelles(origin: Vector2, rad: float) -> void:
	for x_n in [-0.303, 0.303]:
		var housing := [
			Vector2(x_n - 0.115, -0.108), Vector2(x_n + 0.115, -0.108),
			Vector2(x_n + 0.122, 0.030), Vector2(x_n + 0.070, 0.066),
			Vector2(x_n - 0.070, 0.066), Vector2(x_n - 0.122, 0.030),
		]
		_draw_hs_poly(origin, rad, housing, NACELLE_DARK)
		_stroke_hs_poly(origin, rad, housing, OUTLINE, OUTLINE_W)
		# Lip highlight along the top of the housing — catches the light and
		# separates the housing from the fuselage behind it.
		_draw_hs_poly(origin, rad, [
			Vector2(x_n - 0.108, -0.108), Vector2(x_n + 0.108, -0.108),
			Vector2(x_n + 0.100, -0.088), Vector2(x_n - 0.100, -0.088),
		], V3_SHADOW)
		# Hot core, three concentric stops.
		var c := Vector2(x_n, -0.018) * HS
		_draw_rotated_circle(origin, rad, c, 0.072 * HS, Color8(120, 42, 10))
		_draw_rotated_circle(origin, rad, c, 0.058 * HS, Color8(212, 96, 20))
		_draw_rotated_circle(origin, rad, c, 0.040 * HS, Color8(250, 160, 48))
		_draw_rotated_circle(origin, rad, c, 0.022 * HS, Color8(255, 226, 150))


## Canopy: the topmost element of the airframe. Nothing is drawn above it on the
## centreline — that is the whole point of the #112 cycle-1 fix, since the pale
## spine that used to sit above it was reading as a projecting grey needle nose
## from an astern view where no nose should be visible at all.
func _draw_canopy(origin: Vector2, rad: float) -> void:
	var canopy := [
		Vector2(-0.060, -0.244), Vector2(-0.052, -0.286),
		Vector2(-0.026, -0.308), Vector2(0.026, -0.308),
		Vector2(0.052, -0.286), Vector2(0.060, -0.244),
	]
	_draw_hs_poly(origin, rad, canopy, CANOPY_GLASS)
	# Glazing highlight on the port quarter, so the canopy reads as glass.
	_draw_hs_poly(origin, rad, [
		Vector2(-0.040, -0.258), Vector2(-0.034, -0.288),
		Vector2(-0.008, -0.302), Vector2(-0.004, -0.262),
	], CANOPY_HI)
	_stroke_hs_poly(origin, rad, canopy, OUTLINE, OUTLINE_W)


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
