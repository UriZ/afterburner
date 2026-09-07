class_name EnemySpriteGenerator
extends RefCounted

## Generates front-view enemy jet sprites at runtime.
## Enemies fly TOWARD the camera, so we see nose cone, forward-swept wings, intakes.
## 3D shading: light source top-left ~45 degrees, consistent with player jet.

const FRAME_SIZE := 48

# --- Fighter colors (Red) — with 3-tone shading ---
const FIGHTER_NOSE = Color(0.88, 0.16, 0.13)       # #E02820 bright red highlight
const FIGHTER_FUSELAGE = Color(0.70, 0.10, 0.08)   # #B31A14 deep red
const FIGHTER_FUSE_LIT = Color(0.88, 0.16, 0.13)   # lit fuselage left half (= NOSE)
const FIGHTER_FUSE_SHADOW = Color(0.45, 0.06, 0.05) # #731009 right side shadow
const FIGHTER_FUSE_DARK = Color(0.28, 0.04, 0.03)   # #470A08 far right edge
const FIGHTER_WING = Color(0.54, 0.08, 0.06)        # #891410 dark red wing surface
const FIGHTER_WING_MID = Color(0.42, 0.06, 0.04)    # #6B0F0A outer wing midtone
const FIGHTER_WING_SHADOW = Color(0.38, 0.06, 0.04) # Trailing edge / wingtip shadow
const FIGHTER_CANOPY = Color(0.14, 0.53, 0.80)      # #2488CC cyan-blue
const FIGHTER_CANOPY_HLT = Color(0.78, 0.91, 1.00)  # #C8E8FF white highlight
const FIGHTER_CANOPY_SPEC = Color(0.95, 0.98, 1.00) # near-white specular dot
const FIGHTER_INTAKE = Color(0.08, 0.06, 0.06)      # #141010 near-black
const FIGHTER_EDGE = Color(0.83, 0.25, 0.19)        # #D44030 bright red-orange edge

# --- Interceptor colors (Green) — with 3-tone shading ---
const INTERCEPTOR_NOSE = Color(0.09, 0.63, 0.24)    # #18A03C bright green highlight
const INTERCEPTOR_FUSE = Color(0.06, 0.44, 0.16)    # #0F7028 deep green
const INTERCEPTOR_FUSE_LIT = Color(0.09, 0.63, 0.24) # lit fuselage left half (= NOSE)
const INTERCEPTOR_FUSE_SHADOW = Color(0.03, 0.28, 0.11) # #074720 right side shadow
const INTERCEPTOR_FUSE_DARK = Color(0.02, 0.18, 0.07)   # #032E12 far right edge
const INTERCEPTOR_WING = Color(0.04, 0.31, 0.13)    # #0A5020 dark green wing
const INTERCEPTOR_WING_MID = Color(0.03, 0.22, 0.09) # existing as midtone
const INTERCEPTOR_WING_OUTER = Color(0.03, 0.17, 0.07) # #042B12 outer wing
const INTERCEPTOR_WING_SHADOW = Color(0.03, 0.22, 0.09) # Trailing edge shadow
const INTERCEPTOR_CANOPY = Color(0.14, 0.53, 0.80)  # #2488CC cyan-blue
const INTERCEPTOR_CANOPY_SPEC = Color(0.95, 0.98, 1.00) # near-white specular dot
const INTERCEPTOR_EDGE = Color(0.19, 0.82, 0.38)    # #30D060 bright green edge

# --- Bomber colors (Grey) — with 3-tone shading ---
const BOMBER_NOSE = Color(0.63, 0.64, 0.66)         # #A0A4A8 light nose
const BOMBER_FUSELAGE = Color(0.50, 0.52, 0.53)     # #808488 blue-grey body
const BOMBER_FUSE_LIT = Color(0.72, 0.73, 0.74)     # #B7BABB lit left column
const BOMBER_FUSE_SHADOW = Color(0.38, 0.39, 0.41)  # = BOMBER_BELLY
const BOMBER_FUSE_DARK = Color(0.22, 0.24, 0.26)    # #383D42 right edge shadow
const BOMBER_FUSELAGE_HLT = Color(0.66, 0.67, 0.69) # #A8ACAF highlight
const BOMBER_WING = Color(0.35, 0.36, 0.38)         # #585C60 darker wings
const BOMBER_WING_SHADOW = Color(0.25, 0.26, 0.28)  # Trailing edge shadow
const BOMBER_ENGINE = Color(0.22, 0.23, 0.24)       # #383A3C engine pods
const BOMBER_CANOPY = Color(0.14, 0.53, 0.80)       # #2488CC cyan-blue
const BOMBER_CANOPY_SPEC = Color(0.95, 0.98, 1.00)  # near-white specular dot
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
	# Left/right shading: left half brighter (FIGHTER_NOSE), right half base (FIGHTER_FUSELAGE)
	for row in range(2, 8):
		var t := float(row - 2) / 5.0
		var half_w := lerpf(0.5, 4.0, t)
		var cx := 23.5
		var x_left := roundi(cx - half_w)
		var x_right := roundi(cx + half_w)
		var x_mid := roundi(cx)
		# Right half: base color
		_draw_hline(img, x_mid, x_right, row, FIGHTER_FUSELAGE)
		# Left half: lit highlight
		_draw_hline(img, x_left, x_mid, row, FIGHTER_NOSE)
	# Nose tip highlight (top-left bright spot)
	_safe_pixel(img, 23, 2, FIGHTER_EDGE)
	_safe_pixel(img, 24, 2, FIGHTER_EDGE)
	_safe_pixel(img, 23, 3, FIGHTER_NOSE)  # extra bright on left side of nose

	# --- Fuselage with cross-axis shading ---
	# Rows 8-20 cols 19-28 (10px wide, cx ~ 23.5)
	_draw_shaded_rect(img, 19, 8, 28, 20, FIGHTER_FUSE_LIT, FIGHTER_FUSELAGE, FIGHTER_FUSE_SHADOW, FIGHTER_FUSE_DARK)
	# Rows 21-34 cols 18-29 (12px wide)
	_draw_shaded_rect(img, 18, 21, 29, 34, FIGHTER_FUSE_LIT, FIGHTER_FUSELAGE, FIGHTER_FUSE_SHADOW, FIGHTER_FUSE_DARK)
	# Rows 35-40 cols 20-27 (8px, narrows)
	_draw_shaded_rect(img, 20, 35, 27, 40, FIGHTER_FUSE_LIT, FIGHTER_FUSELAGE, FIGHTER_FUSE_SHADOW, FIGHTER_FUSE_DARK)

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

	# --- Cockpit canopy with specular ---
	_draw_rect(img, 21, 8, 26, 14, FIGHTER_CANOPY)
	_draw_rect(img, 22, 8, 25, 10, FIGHTER_CANOPY_HLT)
	# White specular core pixel (top-left of canopy)
	_safe_pixel(img, 22, 8, FIGHTER_CANOPY_SPEC)

	# --- Wings with zone-based shading ---
	# Left wing: fuselage at col 19, tip at col 2, leading edge row 10, trailing edge row 36
	_draw_shaded_wing_triangle(img, 19, 2, 10, 36,
		FIGHTER_WING, FIGHTER_WING_MID, FIGHTER_WING_SHADOW, FIGHTER_EDGE, true)
	# Right wing: fuselage at col 29, tip at col 46, leading edge row 10, trailing edge row 36
	_draw_shaded_wing_triangle(img, 29, 46, 10, 36,
		FIGHTER_WING, FIGHTER_WING_MID, FIGHTER_WING_SHADOW, FIGHTER_EDGE, false)

	# --- Engine intakes ---
	_draw_filled_oval(img, 18, 25, 2, 3, FIGHTER_INTAKE)
	_draw_filled_oval(img, 29, 25, 2, 3, FIGHTER_INTAKE)


# =============================================================================
# Interceptor (48x48) — Green, slimmer and more angular
# =============================================================================
static func _draw_interceptor(img: Image) -> void:
	# Longer nose: rows 2-10 with left/right shading
	for row in range(2, 11):
		var t := float(row - 2) / 8.0
		var half_w := lerpf(0.5, 3.5, t)
		var cx := 23.5
		var x_left := roundi(cx - half_w)
		var x_right := roundi(cx + half_w)
		var x_mid := roundi(cx)
		# Right half: base color
		_draw_hline(img, x_mid, x_right, row, INTERCEPTOR_FUSE)
		# Left half: lit highlight
		_draw_hline(img, x_left, x_mid, row, INTERCEPTOR_NOSE)
	# Nose tip highlight
	_safe_pixel(img, 23, 2, INTERCEPTOR_EDGE)
	_safe_pixel(img, 24, 2, INTERCEPTOR_EDGE)
	_safe_pixel(img, 23, 3, INTERCEPTOR_NOSE)  # bright spot top-left of nose

	# Narrower fuselage with cross-axis shading: cols 20-27 (8px), rows 11-34
	_draw_shaded_rect(img, 20, 11, 27, 34, INTERCEPTOR_FUSE_LIT, INTERCEPTOR_FUSE, INTERCEPTOR_FUSE_SHADOW, INTERCEPTOR_FUSE_DARK)
	# Tail taper rows 35-40
	_draw_shaded_rect(img, 21, 35, 26, 40, INTERCEPTOR_FUSE_LIT, INTERCEPTOR_FUSE, INTERCEPTOR_FUSE_SHADOW, INTERCEPTOR_FUSE_DARK)

	# Edge highlights
	for row in range(11, 41):
		if row <= 34:
			_safe_pixel(img, 20, row, INTERCEPTOR_EDGE)
			_safe_pixel(img, 27, row, INTERCEPTOR_EDGE)
		else:
			_safe_pixel(img, 21, row, INTERCEPTOR_EDGE)
			_safe_pixel(img, 26, row, INTERCEPTOR_EDGE)

	# Canopy with specular
	_draw_rect(img, 22, 11, 25, 16, INTERCEPTOR_CANOPY)
	_draw_rect(img, 22, 11, 24, 13, Color(0.80, 0.90, 1.00))
	# White specular core pixel (top-left of canopy)
	_safe_pixel(img, 22, 11, INTERCEPTOR_CANOPY_SPEC)

	# Wings with zone-based shading
	_draw_shaded_wing_triangle(img, 20, 5, 12, 34,
		INTERCEPTOR_WING, INTERCEPTOR_WING_MID, INTERCEPTOR_WING_OUTER, INTERCEPTOR_EDGE, true)
	_draw_shaded_wing_triangle(img, 27, 43, 12, 34,
		INTERCEPTOR_WING, INTERCEPTOR_WING_MID, INTERCEPTOR_WING_OUTER, INTERCEPTOR_EDGE, false)

	# Engine intakes
	_draw_filled_oval(img, 18, 24, 2, 3, Color(0.06, 0.06, 0.06))
	_draw_filled_oval(img, 29, 24, 2, 3, Color(0.06, 0.06, 0.06))


# =============================================================================
# Bomber (64x64) — Grey, wide-body heavy aircraft
# =============================================================================
static func _draw_bomber(img: Image) -> void:
	var w := img.get_width()  # 64

	# --- Rounded nose: 8px wide, rows 4-12 with left/right shading ---
	for row in range(4, 13):
		var t := float(row - 4) / 8.0
		var half_w := lerpf(1.0, 4.0, t)
		var cx := 31.5
		var x_left := roundi(cx - half_w)
		var x_right := roundi(cx + half_w)
		var x_mid := roundi(cx)
		# Right half: base color
		_draw_hline(img, x_mid, x_right, row, BOMBER_FUSELAGE)
		# Left half: lit highlight
		_draw_hline(img, x_left, x_mid, row, BOMBER_NOSE)
	# Nose tip highlight (top-left bright spot)
	_safe_pixel(img, 31, 4, BOMBER_EDGE)
	_safe_pixel(img, 32, 4, BOMBER_EDGE)
	_safe_pixel(img, 31, 5, BOMBER_FUSE_LIT)  # bright spot top-left of nose

	# --- Wide fuselage with cross-axis shading: cols 24-39 (16px), rows 13-48 ---
	_draw_shaded_rect(img, 24, 13, 39, 48, BOMBER_FUSE_LIT, BOMBER_FUSELAGE, BOMBER_FUSE_SHADOW, BOMBER_FUSE_DARK)
	# Taper at tail rows 49-56
	_draw_shaded_rect(img, 27, 49, 36, 56, BOMBER_FUSE_LIT, BOMBER_FUSELAGE, BOMBER_FUSE_SHADOW, BOMBER_FUSE_DARK)

	# Edge highlights
	for row in range(13, 57):
		if row <= 48:
			_safe_pixel(img, 24, row, BOMBER_EDGE)
			_safe_pixel(img, 39, row, BOMBER_EDGE)
		else:
			_safe_pixel(img, 27, row, BOMBER_EDGE)
			_safe_pixel(img, 36, row, BOMBER_EDGE)

	# --- Cockpit canopy with specular ---
	_draw_rect(img, 29, 13, 34, 19, BOMBER_CANOPY)
	_draw_rect(img, 30, 13, 33, 16, Color(0.80, 0.90, 1.00))
	# White specular core pixel (top-left of canopy)
	_safe_pixel(img, 30, 13, BOMBER_CANOPY_SPEC)

	# --- Wings with zone-based shading ---
	_draw_shaded_wing_triangle(img, 24, 2, 16, 40,
		BOMBER_WING, BOMBER_WING, BOMBER_WING_SHADOW, BOMBER_EDGE, true)
	_draw_shaded_wing_triangle(img, 39, 62, 16, 40,
		BOMBER_WING, BOMBER_WING, BOMBER_WING_SHADOW, BOMBER_EDGE, false)

	# --- Fuselage highlight stripe (shifted left per spec: cols 28-29) ---
	for row in range(13, 49):
		_safe_pixel(img, 28, row, BOMBER_FUSELAGE_HLT)
		_safe_pixel(img, 29, row, BOMBER_FUSELAGE_HLT)

	# --- Bomb bay belly stripe (rows 28-30) ---
	_draw_rect(img, 26, 28, 37, 30, BOMBER_BELLY)

	# --- Twin engine pods under wings ---
	# Left pod: cols 10-16, rows 28-38
	_draw_rect(img, 10, 28, 16, 38, BOMBER_ENGINE)
	_safe_pixel(img, 10, 28, BOMBER_EDGE)
	_safe_pixel(img, 16, 28, BOMBER_EDGE)
	_draw_filled_oval(img, 13, 31, 2, 2, Color(0.08, 0.08, 0.10))
	# Right pod: cols 47-53, rows 28-38
	_draw_rect(img, 47, 28, 53, 38, BOMBER_ENGINE)
	_safe_pixel(img, 47, 28, BOMBER_EDGE)
	_safe_pixel(img, 53, 28, BOMBER_EDGE)
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


## Draws a rectangle with left-to-right cross-axis shading (4 zones).
## Simulates cylindrical fuselage lit from top-left.
static func _draw_shaded_rect(
	img: Image, x0: int, y0: int, x1: int, y1: int,
	lit_color: Color, base_color: Color, shadow_color: Color, dark_color: Color
) -> void:
	var rect_w := x1 - x0 + 1
	if rect_w <= 0:
		return
	for y in range(maxi(0, y0), mini(img.get_height(), y1 + 1)):
		for x in range(maxi(0, x0), mini(img.get_width(), x1 + 1)):
			var frac := float(x - x0) / float(rect_w)
			var col: Color
			if frac < 0.30:
				col = lit_color
			elif frac < 0.65:
				col = base_color
			elif frac < 0.90:
				col = shadow_color
			else:
				col = dark_color
			img.set_pixel(x, y, col)


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


## Draws a wing triangle with zone-based shading across the span.
## is_left_wing: true for left wing (inner = brighter near fuselage),
##   false for right wing (inner slightly less lit since away from top-left light).
## Zones: inner 40% = fill_inner, middle 40% = fill_mid, outer 20% = fill_outer.
## Leading edge row gets edge_color highlight. Trailing 20% rows get fill_outer shadow.
static func _draw_shaded_wing_triangle(
	img: Image,
	fuselage_x: int,
	tip_x: int,
	lead_y: int,
	trail_y: int,
	fill_inner: Color,
	fill_mid: Color,
	fill_outer: Color,
	edge_color: Color,
	is_left_wing: bool
) -> void:
	var rows := trail_y - lead_y
	if rows <= 0:
		return

	for i in range(rows + 1):
		var t := float(i) / float(rows)
		var row := lead_y + i
		var x_out := roundi(lerpf(float(tip_x), float(fuselage_x), t))
		var x_start := mini(fuselage_x, x_out)
		var x_end := maxi(fuselage_x, x_out)
		var span := x_end - x_start
		if span <= 0:
			_safe_pixel(img, x_start, row, fill_inner)
			continue

		# Trailing 20% of rows get darkened
		var trailing_shadow := t > 0.80

		# Fill each pixel with zone-based color
		for x in range(maxi(0, x_start), mini(img.get_width(), x_end + 1)):
			if row < 0 or row >= img.get_height():
				break
			# Fraction across the span: 0.0 = inner (fuselage), 1.0 = outer (tip)
			var span_frac: float
			if is_left_wing:
				# Left wing: fuselage_x is on the right, tip_x is on the left
				span_frac = float(fuselage_x - x) / float(span) if span > 0 else 0.0
			else:
				# Right wing: fuselage_x is on the left, tip_x is on the right
				span_frac = float(x - fuselage_x) / float(span) if span > 0 else 0.0
			span_frac = clampf(span_frac, 0.0, 1.0)

			var col: Color
			if trailing_shadow:
				col = fill_outer
			elif span_frac < 0.40:
				col = fill_inner
			elif span_frac < 0.80:
				col = fill_mid
			else:
				col = fill_outer

			# Right wing inner zone is one step less lit (light is top-left)
			if not is_left_wing and span_frac < 0.40 and not trailing_shadow:
				col = fill_mid

			img.set_pixel(x, row, col)

		# Leading edge highlight: outermost pixel
		_safe_pixel(img, x_out, row, edge_color)
		# Top edge highlight on the first row (leading edge line)
		if i == 0:
			_draw_hline(img, x_start, x_end, row, edge_color)
