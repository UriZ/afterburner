extends Control

## Draws the arcade-style HUD: winged SCORE/HIT emblems, the fixed scope box,
## the marked SPEED bar, STAGE, the two-size missile readout and jet-icon lives.
## All HUD state lives on the parent CanvasLayer (hud.gd); this node only reads
## it and draws — it holds no state of its own.
##
## LAYOUT IS MEASURED, NOT INVENTED (#129). Every rect below is expressed as a
## fraction of the viewport and comes from a per-pixel median composite of 25
## arcade frames at t=94-118s, all HUD-proven STAGE 1. Reference is 686x480 and
## our viewport is 960x672 — both exactly 10:7, so the fractions transfer with
## no aspect correction. Do not "tidy" these to round numbers; each one is an
## acceptance criterion (#129 AC 6, +/-2 %W and +/-2 %H).

const BlockFont = preload("res://scripts/ui/block_font.gd")

const SCREEN_W := 960.0
const SCREEN_H := 672.0

# --- Top band -----------------------------------------------------------
const SCORE_EMBLEM := Rect2(0.051, 0.067, 0.172, 0.043)
const SCORE_DIGITS := Rect2(0.327, 0.071, 0.116, 0.031)
const HIT_EMBLEM := Rect2(0.504, 0.071, 0.091, 0.033)
const HIT_DIGITS := Rect2(0.631, 0.071, 0.034, 0.031)

## The FIXED scope box. This is a different element from reticle_2d.gd's moving
## in-field lock brackets, which track the locked enemy anywhere on screen. Both
## exist in the arcade in every frame and both must ship (criteria rule 14, #129
## AC 4) — treating them as one element is what dropped this box before.
const SCOPE_RECT := Rect2(0.773, 0.104, 0.103, 0.113)
const SCOPE_BRACKET := Vector2(0.025, 0.035)  ## each L arm, %W x %H
const SCOPE_STROKE_FRAC := 0.0021             ## ~2 px at 960 wide

# --- Bottom band --------------------------------------------------------
const SPEED_LABEL := Rect2(0.052, 0.898, 0.079, 0.023)
const SPEED_MODE := Rect2(0.130, 0.894, 0.039, 0.035)
const BAR_MARK_0 := Rect2(0.175, 0.898, 0.012, 0.021)
const BAR_MARK_2 := Rect2(0.312, 0.898, 0.013, 0.021)
const BAR_MARK_3 := Rect2(0.385, 0.898, 0.012, 0.021)

## The gold run is a moving BAND, not a fill from the left: the reference shows
## unfilled pips on BOTH sides of it (pips 20.1-24.8 %W, gold 25.7-30.3, pips
## again past 33). Track end is set so the band's left edge lands on the
## measured 25.7 %W at the default ratio of 0.5, which is the state a capture
## sees. A prefix-fill model would sit 5.6 %W to the left and fail AC 6.
const BAR_TRACK := Vector2(0.201, 0.359)  ## x range the band travels within
const BAR_FILL_W := 0.046
const BAR_Y := 0.900
const BAR_H := 0.021
const BAR_PIP_W := 0.006
const BAR_PIP_PITCH := 0.0115

const STAGE_LABEL := Rect2(0.426, 0.892, 0.087, 0.033)
const STAGE_DIGIT := Rect2(0.580, 0.892, 0.010, 0.031)

## Missile readout: a MIXED-RADIX place-value counter (large=floor(n/8),
## small=n%8), not the "10 per large icon, max 3" model #129 shipped — that
## model appeared in no spec, and froze the readout for our entire
## DEFAULT_MISSILES 30-50 range (#147).
##
## Evidence: individual frames pulled from
## .reference-cache/video/ab2-longplay-60fps.mp4 across #129's own cited
## t=94-118 window show the large-icon count decrement 5->4->3 while the
## small-tick count simultaneously JUMPS UP to 7 and counts back down — the
## signature of a borrow, not two independent tallies:
##   t=94-96:  large=5, small=0   (n=40)
##   t=97:     large=4, small=7   (n=39 — one missile fired: 40->39 borrows
##                                 from the large digit)
##   t=100:    large=4, small=3   (n=35)
##   t=105:    large=3, small=7   (n=31 — the next borrow)
## Cross-checked on the lossless `ab2-arcade-desert.png` reference screenshot
## (no compression, exact pixels): 3 large + 7 small — base-8 consistent, and
## confirms MAX_SMALL_ICONS=7 (a full remainder run, counted directly).
##
## Position is also ONE CONTIGUOUS ROW from a single fixed left anchor, not
## two independently-positioned boxes: the first small icon's absolute pixel
## position moves a full large-icon pitch to the LEFT when the large count
## drops by one (748.5px at large=4 vs 725px at large=3, both measured in the
## same 1028px-wide reference frame) — it always sits immediately after the
## last drawn large icon. #129's separate MISSILE_SMALL rect was simply the
## position one blended median composite happened to show, not a semantic
## anchor — and treating it as fixed is what made a 4th large icon look like
## it would "collide" with the small run.
const MISSILE_ROW_X := 0.634          ## fixed left anchor — icon 0 always here
const MISSILE_LARGE_Y := 0.894
const MISSILE_LARGE_H := 0.064
const MISSILE_SMALL_Y := 0.904
const MISSILE_SMALL_H := 0.056
const MISSILE_LARGE_PITCH := 0.025
const MISSILE_SMALL_PITCH := 0.011
const MISSILE_LARGE_W := 0.0031
const MISSILE_SMALL_W := 0.0026
const MISSILES_PER_LARGE := 8
const MAX_SMALL_ICONS := 7            ## remainder 0..7 — 8 states, 7 icons max
## Six, not three: the reference itself shows 5 in this evidence window (more
## than #129's geometry assumed could fit), and DEFAULT_MISSILES=50 needs six
## large icons to render at all (50 = 6*8+2). Worst case (6 large + a full
## seven small) reaches ~83.6 %W — comfortably on-screen. Nothing else in the
## bottom band sits past the missile row (STAGE_DIGIT ends at 59 %W), and the
## fixed scope box is a DIFFERENT vertical band (10.4-21.7 %H vs this row's
## 89-96 %H), so %W overlap with it is not a collision — the old developer's
## "4 large icons collide with the small run" was about the small run itself,
## not the scope box.
const MAX_LARGE_ICONS := 6

## Life icons sit BELOW the SPEED label. The height cap is the operative half of
## AC 8: the containing band alone cannot reject an icon 1.5x too tall.
const LIFE_ROW := Rect2(0.060, 0.942, 0.036, 0.018)
const LIFE_ICON_W := 0.0145
const LIFE_PITCH := 0.018
const MAX_LIFE_ICONS := 8

# --- Colours ------------------------------------------------------------
## Core (modal) colours sampled inside the glyphs, not means: anti-aliased edges
## blend into the background and drag any average toward it (#129 §1.5).
const COLOR_EMBLEM_RED := Color8(255, 20, 0)
const COLOR_DIGIT_CREAM := Color8(255, 255, 210)
const COLOR_BAR_GOLD := Color8(255, 190, 40)
const COLOR_MISSILE := Color8(230, 230, 225)
const COLOR_SCOPE := Color8(255, 255, 255)
const COLOR_OUTLINE := Color8(0, 0, 0)
## SPEED mode letter (#147): sampled directly off the lossless
## `ab2-arcade-desert.png` reference (no compression, so this is exact, not a
## centroid) — the glyph's core pixels are (0,0,247), distinct from the
## plate (247,247,247), outline (0,0,0) and SPEED/STAGE red (247,0,0) sampled
## in the same crop. The shipped code drew this glyph in COLOR_OUTLINE
## (pure black), which is why it read as a black box.
const COLOR_MODE_LETTER := Color8(0, 0, 247)
const COLOR_WING_LIGHT := Color8(245, 245, 235)
const COLOR_PLATE := Color8(222, 222, 210)
const COLOR_PIP := Color8(90, 90, 80)
const COLOR_JET := Color8(230, 230, 225)


func _draw() -> void:
	var hud: Node = get_parent()
	_draw_emblem(_rect(SCORE_EMBLEM), "SCORE")
	_draw_digits(_rect(SCORE_DIGITS), "%08d" % int(hud.score), COLOR_DIGIT_CREAM)
	_draw_emblem(_rect(HIT_EMBLEM), "HIT")
	_draw_digits(_rect(HIT_DIGITS), "%02d" % int(hud.hit_count), COLOR_DIGIT_CREAM)
	_draw_scope_box()
	_draw_speed_bar(float(hud.speed_ratio))
	_draw_stage(int(hud.current_stage))
	_draw_missiles(int(hud.missile_count))
	_draw_lives(int(hud.lives))


## Fractions of the viewport -> pixels.
func _rect(frac: Rect2) -> Rect2:
	return Rect2(frac.position.x * SCREEN_W, frac.position.y * SCREEN_H,
		frac.size.x * SCREEN_W, frac.size.y * SCREEN_H)


## Draws text FILLING `box`, with independent horizontal and vertical cell
## sizes.
##
## BlockFont.draw_text uses one square `px` for both axes, so a glyph forced
## into a tall narrow box gets sized by the width and collapses: the arcade's
## stage digit is 1.0 %W x 3.1 %H, an aspect of 1:2.2 against the font's 5:7,
## and the square-pixel version rendered it at 1 px per cell — present in the
## source, invisible on screen. Stretching each cell to the measured box is what
## makes the element actually occupy its recorded extent in BOTH axes (AC 6).
func _draw_digits(box: Rect2, text: String, color: Color) -> void:
	var upper := text.to_upper()
	var n := upper.length()
	if n == 0:
		return
	var cell := Vector2(
		box.size.x / float(n * (BlockFont.COLS + 1) - 1),
		box.size.y / float(BlockFont.ROWS))
	# Cells are ceil-ed so adjacent lit pixels touch instead of leaving seams.
	var fill := Vector2(ceilf(cell.x), ceilf(cell.y))
	var x := box.position.x
	for ch in upper:
		var glyph: Array = BlockFont.GLYPHS.get(ch, BlockFont.GLYPHS[" "])
		for row in range(BlockFont.ROWS):
			var line: String = glyph[row]
			for col in range(BlockFont.COLS):
				if line[col] == "1":
					draw_rect(Rect2(
						Vector2(x + col * cell.x, box.position.y + row * cell.y),
						fill), color)
		x += float(BlockFont.COLS + 1) * cell.x


## Winged emblem: red block letters centred on a light plate, flanked by
## horizontal red/white striped wings, the whole thing dark-outlined. The
## measured extent covers the WINGS as well as the letters, so the wings are
## what make the element reach its recorded %W — they are not decoration.
func _draw_emblem(box: Rect2, text: String) -> void:
	draw_rect(box, COLOR_OUTLINE)
	var inner := box.grow(-2.0)
	draw_rect(inner, COLOR_PLATE)

	# Letters take the middle ~55% of the plate; the wings claim the rest.
	var letters_w := inner.size.x * 0.55
	var letters_h := inner.size.y * 0.72
	var letters_x := inner.position.x + (inner.size.x - letters_w) / 2.0
	var letters_y := inner.position.y + (inner.size.y - letters_h) / 2.0

	# Wings fill whatever the letters leave on each side.
	var wing_w := maxf(0.0, letters_x - inner.position.x - 2.0)
	if wing_w > 1.0:
		_draw_wing(Rect2(inner.position, Vector2(wing_w, inner.size.y)))
		_draw_wing(Rect2(Vector2(letters_x + letters_w + 2.0, inner.position.y),
			Vector2(wing_w, inner.size.y)))

	_draw_digits(Rect2(letters_x, letters_y, letters_w, letters_h), text, COLOR_EMBLEM_RED)


func _draw_wing(box: Rect2) -> void:
	var stripes := 5
	var stripe_h := box.size.y / float(stripes)
	for i in range(stripes):
		var color := COLOR_EMBLEM_RED if i % 2 == 0 else COLOR_WING_LIGHT
		draw_rect(Rect2(box.position + Vector2(0, i * stripe_h),
			Vector2(box.size.x, stripe_h)), color)


## The fixed scope box: four L-shaped corner brackets, arms pointing inward,
## interior empty. Drawn UNCONDITIONALLY — no target-dependent visibility. That
## is the defect criteria rule 14 exists to prevent, and #129 AC 3 tests it by
## capturing a frame with nothing locked.
func _draw_scope_box() -> void:
	var box := _rect(SCOPE_RECT)
	var arm := Vector2(SCOPE_BRACKET.x * SCREEN_W, SCOPE_BRACKET.y * SCREEN_H)
	var stroke := maxf(1.0, SCOPE_STROKE_FRAC * SCREEN_W)
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			var corner := Vector2(
				box.position.x if sx > 0.0 else box.end.x,
				box.position.y if sy > 0.0 else box.end.y)
			# Horizontal arm, then vertical arm, both growing inward.
			var hx := corner.x if sx > 0.0 else corner.x - arm.x
			var hy := corner.y if sy > 0.0 else corner.y - stroke
			draw_rect(Rect2(hx, hy, arm.x, stroke), COLOR_SCOPE)
			var vx := corner.x if sx > 0.0 else corner.x - stroke
			var vy := corner.y if sy > 0.0 else corner.y - arm.y
			draw_rect(Rect2(vx, vy, stroke, arm.y), COLOR_SCOPE)


func _draw_speed_bar(ratio: float) -> void:
	_draw_plate_text(_rect(SPEED_LABEL), "SPEED", COLOR_EMBLEM_RED)
	_draw_plate_text(_rect(SPEED_MODE), "H", COLOR_MODE_LETTER, Vector2(0.26, 0.16))
	_draw_digits(_rect(BAR_MARK_0), "0", COLOR_DIGIT_CREAM)
	_draw_digits(_rect(BAR_MARK_2), "2", COLOR_DIGIT_CREAM)
	_draw_digits(_rect(BAR_MARK_3), "3", COLOR_DIGIT_CREAM)

	var y := BAR_Y * SCREEN_H
	var h := BAR_H * SCREEN_H
	# Unfilled pips run the length of the track, so the bar reads as a scale
	# even where the gold band is not.
	var x := BAR_TRACK.x
	while x < BAR_MARK_3.position.x:
		draw_rect(Rect2(x * SCREEN_W, y + h * 0.3, BAR_PIP_W * SCREEN_W, h * 0.4), COLOR_PIP)
		x += BAR_PIP_PITCH

	var left := lerpf(BAR_TRACK.x, BAR_TRACK.y - BAR_FILL_W, clampf(ratio, 0.0, 1.0))
	draw_rect(Rect2(left * SCREEN_W, y, BAR_FILL_W * SCREEN_W, h), COLOR_BAR_GOLD)


## Block letters on a light plate — the treatment SPEED, H and STAGE share.
##
## `inset` shrinks the glyph inside the plate. The mode letter needs it: a
## single stretched H fills its whole plate and reads as a black box with two
## white slots rather than a letter. SPEED and STAGE are multi-character and
## carry their own internal spacing, so they sit flush.
func _draw_plate_text(box: Rect2, text: String, color: Color, inset := Vector2.ZERO) -> void:
	draw_rect(box.grow(1.0), COLOR_OUTLINE)
	draw_rect(box, COLOR_PLATE)
	var glyph_box := Rect2(
		box.position + Vector2(box.size.x * inset.x, box.size.y * inset.y),
		Vector2(box.size.x * (1.0 - 2.0 * inset.x), box.size.y * (1.0 - 2.0 * inset.y)))
	_draw_digits(glyph_box, text, color)


func _draw_stage(stage: int) -> void:
	_draw_plate_text(_rect(STAGE_LABEL), "STAGE", COLOR_EMBLEM_RED)
	_draw_digits(_rect(STAGE_DIGIT), str(stage), COLOR_DIGIT_CREAM)


func _draw_missiles(count: int) -> void:
	var large := clampi(count / MISSILES_PER_LARGE, 0, MAX_LARGE_ICONS)
	var small := clampi(count - large * MISSILES_PER_LARGE, 0, MAX_SMALL_ICONS)
	# One contiguous row: large icons first, small icons continuing immediately
	# after wherever the last large icon landed — see the const-block note.
	var x := MISSILE_ROW_X
	for i in range(large):
		_draw_missile_icon(Vector2(x * SCREEN_W, MISSILE_LARGE_Y * SCREEN_H),
			MISSILE_LARGE_W * SCREEN_W, MISSILE_LARGE_H * SCREEN_H)
		x += MISSILE_LARGE_PITCH
	for i in range(small):
		_draw_missile_icon(Vector2(x * SCREEN_W, MISSILE_SMALL_Y * SCREEN_H),
			MISSILE_SMALL_W * SCREEN_W, MISSILE_SMALL_H * SCREEN_H)
		x += MISSILE_SMALL_PITCH


func _draw_lives(lives: int) -> void:
	var shown := clampi(lives, 0, MAX_LIFE_ICONS)
	var row := _rect(LIFE_ROW)
	for i in range(shown):
		var x := (LIFE_ROW.position.x + i * LIFE_PITCH) * SCREEN_W
		_draw_life_icon(Vector2(x, row.position.y), LIFE_ICON_W * SCREEN_W, row.size.y)


## Tall, narrow silhouette — the reference's missiles span ~6 %H, so a flat tick
## row would satisfy the horizontal half of AC 6 and fail the vertical half.
func _draw_missile_icon(pos: Vector2, w: float, h: float) -> void:
	var points := PackedVector2Array([
		pos + Vector2(w / 2.0, 0),
		pos + Vector2(w, h * 0.22),
		pos + Vector2(w, h * 0.86),
		pos + Vector2(w * 1.4, h),
		pos + Vector2(-w * 0.4, h),
		pos + Vector2(0, h * 0.86),
		pos + Vector2(0, h * 0.22),
	])
	draw_colored_polygon(points, COLOR_MISSILE)


## Jet silhouette, not a chevron: nose, swept wings, tailplane. AC 8 asks that
## these read as aircraft, which needs a wing pair and a tail — a single wedge
## does not.
func _draw_life_icon(pos: Vector2, w: float, h: float) -> void:
	var points := PackedVector2Array([
		pos + Vector2(w * 0.50, 0.00 * h),   # nose
		pos + Vector2(w * 0.60, 0.42 * h),
		pos + Vector2(w * 1.00, 0.62 * h),   # right wing tip
		pos + Vector2(w * 1.00, 0.76 * h),
		pos + Vector2(w * 0.60, 0.70 * h),
		pos + Vector2(w * 0.64, 0.88 * h),
		pos + Vector2(w * 0.84, 1.00 * h),   # right tailplane
		pos + Vector2(w * 0.16, 1.00 * h),   # left tailplane
		pos + Vector2(w * 0.36, 0.88 * h),
		pos + Vector2(w * 0.40, 0.70 * h),
		pos + Vector2(w * 0.00, 0.76 * h),   # left wing tip
		pos + Vector2(w * 0.00, 0.62 * h),
		pos + Vector2(w * 0.40, 0.42 * h),
	])
	draw_colored_polygon(points, COLOR_JET)
