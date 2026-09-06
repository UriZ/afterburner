class_name EnemySpriteGenerator
extends RefCounted

## Generates front-view enemy jet sprites at runtime.
## Enemies fly TOWARD the camera, so we see nose cone, forward-swept wings, intakes.

const FRAME_SIZE := 48

# --- Fighter colors (Red) — saturated per UI spec ---
const FIGHTER_NOSE = Color(0.88, 0.16, 0.13)       # #E02820 bright red highlight
const FIGHTER_FUSELAGE = Color(0.70, 0.10, 0.08)   # #B31A14 deep red
const FIGHTER_WING = Color(0.54, 0.08, 0.06)        # #891410 dark red wing surface
const FIGHTER_WING_SHADOW = Color(0.38, 0.06, 0.04) # Trailing edge shadow
const FIGHTER_CANOPY = Color(0.14, 0.53, 0.80)      # #2488CC cyan-blue
const FIGHTER_CANOPY_HLT = Color(0.78, 0.91, 1.00)  # #C8E8FF white highlight
const FIGHTER_INTAKE = Color(0.08, 0.06, 0.06)      # #141010 near-black
const FIGHTER_EDGE = Color(0.83, 0.25, 0.19)        # #D44030 bright red-orange edge

# --- Interceptor colors (Green) — more saturated ---
const INTERCEPTOR_NOSE = Color(0.09, 0.63, 0.24)    # #18A03C bright green highlight
const INTERCEPTOR_FUSE = Color(0.06, 0.44, 0.16)    # #0F7028 deep green
const INTERCEPTOR_WING = Color(0.04, 0.31, 0.13)    # #0A5020 dark green wing
const INTERCEPTOR_WING_SHADOW = Color(0.03, 0.22, 0.09) # Trailing edge shadow
const INTERCEPTOR_CANOPY = Color(0.14, 0.53, 0.80)  # #2488CC cyan-blue
const INTERCEPTOR_EDGE = Color(0.19, 0.82, 0.38)    # #30D060 bright green edge

# --- Bomber colors (Grey) — higher contrast ---
const BOMBER_NOSE = Color(0.63, 0.64, 0.66)         # #A0A4A8 light nose
const BOMBER_FUSELAGE = Color(0.50, 0.52, 0.53)     # #808488 blue-grey body
const BOMBER_FUSELAGE_HLT = Color(0.66, 0.67, 0.69) # #A8ACAF highlight
const BOMBER_WING = Color(0.35, 0.36, 0.38)         # #585C60 darker wings
const BOMBER_WING_SHADOW = Color(0.25, 0.26, 0.28)  # Trailing edge shadow
const BOMBER_ENGINE = Color(0.22, 0.23, 0.24)       # #383A3C engine pods
const BOMBER_CANOPY = Color(0.14, 0.53, 0.80)       # #2488CC cyan-blue
const BOMBER_EDGE = Color(0.67, 0.67, 0.69)         # #AAAAAF light edge
const BOMBER_BELLY = Color(0.38, 0.39, 0.41)        # #606468 bomb bay stripe


enum EnemyVisual { FIGHTER, INTERCEPTOR, BOMBER }


static func generate_texture(visual: EnemyVisual) -> ImageTexture:
	var size := FRAME_SIZE
	if visual == EnemyVisual.BOMBER:
		size = 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	match visual:
		EnemyVisual.FIGHTER:
			_draw_fighter(image)
		EnemyVisual.INTERCEPTOR:
			_draw_interceptor(image)
		EnemyVisual.BOMBER:
			_draw_bomber(image)

	return ImageTexture.create_from_image(image)


# =============================================================================
# Fighter (48x48) — Red, delta-wing front view
# =============================================================================
static func _draw_fighter(img: Image) -> void:
	var w := img.get_width()

	# --- Nose cone: tip at cols 23-24 row 2, widens to 8px by row 7 ---
	for row in range(2, 8):
		var t := float(row - 2) / 5.0  # 0..1
		var half_w := lerpf(0.5, 4.0, t)
		var cx := 23.5
		_draw_hline(img, roundi(cx - half_w), roundi(cx + half_w), row, FIGHTER_NOSE)
	# Nose edge highlight on top row
	_safe_pixel(img, 23, 2, FIGHTER_EDGE)
	_safe_pixel(img, 24, 2, FIGHTER_EDGE)

	# --- Fuselage: rows 8-20 cols 19-28 (10px), rows 21-34 cols 18-29 (12px),
	#     rows 35-40 cols 20-27 (8px, narrows) ---
	_draw_rect(img, 19, 8, 28, 20, FIGHTER_FUSELAGE)
	_draw_rect(img, 18, 21, 29, 34, FIGHTER_FUSELAGE)
	_draw_rect(img, 20, 35, 27, 40, FIGHTER_FUSELAGE)
	# Edge highlights along fuselage sides
	for row in range(8, 41):
		if row <= 20:
			_safe_pixel(img, 19, row, FIGHTER_EDGE)
			_safe_pixel(img, 28, row, FIGHTER_EDGE)
		elif row <= 34:
			_safe_pixel(img, 18, row, FIGHTER_EDGE)
			_safe_pixel(img, 29, row, FIGHTER_EDGE)
		else:
			_safe_pixel(img, 20, row, FIGHTER_EDGE)
			_safe_pixel(img, 27, row, FIGHTER_EDGE)

	# --- Cockpit canopy: rows 8-14 cols 21-26, highlight rows 8-10 cols 22-25 ---
	_draw_rect(img, 21, 8, 26, 14, FIGHTER_CANOPY)
	_draw_rect(img, 22, 8, 25, 10, FIGHTER_CANOPY_HLT)

	# --- Wings: filled delta triangles ---
	# Left wing: fuselage at col 19, tip at col 2, leading edge row 10, trailing edge row 36
	_draw_filled_wing_triangle(img, 19, 2, 10, 36, FIGHTER_WING, FIGHTER_EDGE, FIGHTER_WING_SHADOW)
	# Right wing: fuselage at col 29, tip at col 46, leading edge row 10, trailing edge row 36
	_draw_filled_wing_triangle(img, 29, 46, 10, 36, FIGHTER_WING, FIGHTER_EDGE, FIGHTER_WING_SHADOW)

	# --- Engine intakes ---
	# Left oval cols 16-20 rows 22-28
	_draw_filled_oval(img, 18, 25, 2, 3, FIGHTER_INTAKE)
	# Right oval cols 27-31 rows 22-28
	_draw_filled_oval(img, 29, 25, 2, 3, FIGHTER_INTAKE)


# =============================================================================
# Interceptor (48x48) — Green, slimmer and more angular
# =============================================================================
static func _draw_interceptor(img: Image) -> void:
	# Longer nose: rows 2-10
	for row in range(2, 11):
		var t := float(row - 2) / 8.0
		var half_w := lerpf(0.5, 3.5, t)
		var cx := 23.5
		_draw_hline(img, roundi(cx - half_w), roundi(cx + half_w), row, INTERCEPTOR_NOSE)
	_safe_pixel(img, 23, 2, INTERCEPTOR_EDGE)
	_safe_pixel(img, 24, 2, INTERCEPTOR_EDGE)

	# Narrower fuselage: cols 20-27 (8px), rows 11-34
	_draw_rect(img, 20, 11, 27, 34, INTERCEPTOR_FUSE)
	# Tail taper rows 35-40
	_draw_rect(img, 21, 35, 26, 40, INTERCEPTOR_FUSE)
	# Edge highlights
	for row in range(11, 41):
		if row <= 34:
			_safe_pixel(img, 20, row, INTERCEPTOR_EDGE)
			_safe_pixel(img, 27, row, INTERCEPTOR_EDGE)
		else:
			_safe_pixel(img, 21, row, INTERCEPTOR_EDGE)
			_safe_pixel(img, 26, row, INTERCEPTOR_EDGE)

	# Canopy: rows 11-16 cols 22-25
	_draw_rect(img, 22, 11, 25, 16, INTERCEPTOR_CANOPY)
	# Highlight
	_draw_rect(img, 22, 11, 24, 13, Color(0.80, 0.90, 1.00))

	# Wings reach col 5 and col 43 — angular, thinner than fighter
	_draw_filled_wing_triangle(img, 20, 5, 12, 34, INTERCEPTOR_WING, INTERCEPTOR_EDGE, INTERCEPTOR_WING_SHADOW)
	_draw_filled_wing_triangle(img, 27, 43, 12, 34, INTERCEPTOR_WING, INTERCEPTOR_EDGE, INTERCEPTOR_WING_SHADOW)

	# Engine intakes (smaller, angular)
	_draw_filled_oval(img, 18, 24, 2, 3, Color(0.06, 0.06, 0.06))
	_draw_filled_oval(img, 29, 24, 2, 3, Color(0.06, 0.06, 0.06))


# =============================================================================
# Bomber (64x64) — Grey, wide-body heavy aircraft
# =============================================================================
static func _draw_bomber(img: Image) -> void:
	var w := img.get_width()  # 64

	# --- Rounded nose: 8px wide, rows 4-12 ---
	for row in range(4, 13):
		var t := float(row - 4) / 8.0
		var half_w := lerpf(1.0, 4.0, t)
		var cx := 31.5
		_draw_hline(img, roundi(cx - half_w), roundi(cx + half_w), row, BOMBER_NOSE)
	# Nose edge
	_safe_pixel(img, 31, 4, BOMBER_EDGE)
	_safe_pixel(img, 32, 4, BOMBER_EDGE)

	# --- Wide fuselage: cols 24-39 (16px), rows 13-48 ---
	_draw_rect(img, 24, 13, 39, 48, BOMBER_FUSELAGE)
	# Taper at tail rows 49-56
	_draw_rect(img, 27, 49, 36, 56, BOMBER_FUSELAGE)
	# Edge highlights
	for row in range(13, 57):
		if row <= 48:
			_safe_pixel(img, 24, row, BOMBER_EDGE)
			_safe_pixel(img, 39, row, BOMBER_EDGE)
		else:
			_safe_pixel(img, 27, row, BOMBER_EDGE)
			_safe_pixel(img, 36, row, BOMBER_EDGE)

	# --- Cockpit canopy ---
	_draw_rect(img, 29, 13, 34, 19, BOMBER_CANOPY)
	_draw_rect(img, 30, 13, 33, 16, Color(0.80, 0.90, 1.00))

	# --- Wings: wide span, tips reach col 2 and col 62 ---
	_draw_filled_wing_triangle(img, 24, 2, 16, 40, BOMBER_WING, BOMBER_EDGE, BOMBER_WING_SHADOW)
	_draw_filled_wing_triangle(img, 39, 62, 16, 40, BOMBER_WING, BOMBER_EDGE, BOMBER_WING_SHADOW)

	# --- Fuselage highlight stripe (center spine) ---
	for row in range(13, 49):
		_safe_pixel(img, 31, row, BOMBER_FUSELAGE_HLT)
		_safe_pixel(img, 32, row, BOMBER_FUSELAGE_HLT)

	# --- Bomb bay belly stripe (rows 28-30) ---
	_draw_rect(img, 26, 28, 37, 30, BOMBER_BELLY)

	# --- Twin engine pods under wings ---
	# Left pod: cols 10-16, rows 28-38
	_draw_rect(img, 10, 28, 16, 38, BOMBER_ENGINE)
	_safe_pixel(img, 10, 28, BOMBER_EDGE)
	_safe_pixel(img, 16, 28, BOMBER_EDGE)
	# Intake circle on left pod
	_draw_filled_oval(img, 13, 31, 2, 2, Color(0.08, 0.08, 0.10))
	# Right pod: cols 47-53, rows 28-38
	_draw_rect(img, 47, 28, 53, 38, BOMBER_ENGINE)
	_safe_pixel(img, 47, 28, BOMBER_EDGE)
	_safe_pixel(img, 53, 28, BOMBER_EDGE)
	# Intake circle on right pod
	_draw_filled_oval(img, 50, 31, 2, 2, Color(0.08, 0.08, 0.10))


# =============================================================================
# Drawing helpers
# =============================================================================

static func _safe_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)


static func _draw_hline(img: Image, x0: int, x1: int, y: int, color: Color) -> void:
	for x in range(maxi(0, x0), mini(img.get_width(), x1 + 1)):
		if y >= 0 and y < img.get_height():
			img.set_pixel(x, y, color)


static func _draw_rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(maxi(0, y0), mini(img.get_height(), y1 + 1)):
		for x in range(maxi(0, x0), mini(img.get_width(), x1 + 1)):
			img.set_pixel(x, y, color)


static func _draw_filled_oval(
	img: Image, cx: int, cy: int, rx: int, ry: int, color: Color
) -> void:
	if rx <= 0 or ry <= 0:
		return
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			var dist := float(dx * dx) / float(rx * rx) + float(dy * dy) / float(ry * ry)
			if dist <= 1.0:
				_safe_pixel(img, cx + dx, cy + dy, color)


static func _draw_filled_wing_triangle(
	img: Image,
	fuselage_x: int,
	tip_x: int,
	lead_y: int,
	trail_y: int,
	fill_color: Color,
	edge_color: Color,
	shadow_color: Color = Color(-1, -1, -1, -1)
) -> void:
	## Draws a filled delta-wing triangle using horizontal line fills.
	## Triangle vertices: (fuselage_x, lead_y), (tip_x, lead_y), (fuselage_x, trail_y)
	## At lead_y the wing is at maximum span (tip_x). At trail_y it tapers back to fuselage_x.
	## shadow_color is applied to the trailing 20% of rows for depth.
	var rows := trail_y - lead_y
	if rows <= 0:
		return
	var use_shadow := shadow_color.a >= 0.0

	for i in range(rows + 1):
		var t := float(i) / float(rows)
		var row := lead_y + i
		# Outboard edge sweeps from tip_x back to fuselage_x
		var x_out := roundi(lerpf(float(tip_x), float(fuselage_x), t))
		var x_start := mini(fuselage_x, x_out)
		var x_end := maxi(fuselage_x, x_out)
		# Choose fill: shadow for trailing 20% of rows
		var row_color := fill_color
		if use_shadow and t > 0.80:
			row_color = shadow_color
		_draw_hline(img, x_start, x_end, row, row_color)
		# Leading edge highlight: outermost pixel
		_safe_pixel(img, x_out, row, edge_color)
		# Top edge highlight on the first row (leading edge line)
		if i == 0:
			_draw_hline(img, x_start, x_end, row, edge_color)
