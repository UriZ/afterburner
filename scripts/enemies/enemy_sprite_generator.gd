class_name EnemySpriteGenerator
extends RefCounted

## Generates front-view enemy jet sprites at runtime.
## Enemies fly TOWARD the camera, so we see nose cone, forward-swept wings, intakes.

const FRAME_SIZE := 48

# --- Fighter colors (Red) ---
const FIGHTER_NOSE = Color(0.85, 0.15, 0.12)
const FIGHTER_FUSELAGE = Color(0.70, 0.12, 0.10)
const FIGHTER_WING = Color(0.60, 0.10, 0.08)
const FIGHTER_CANOPY = Color(0.20, 0.55, 0.90)
const FIGHTER_CANOPY_HLT = Color(0.80, 0.90, 1.00)
const FIGHTER_INTAKE = Color(0.10, 0.08, 0.08)
const FIGHTER_EDGE = Color(1.00, 0.60, 0.60)

# --- Interceptor colors (Green) ---
const INTERCEPTOR_NOSE = Color(0.15, 0.75, 0.30)
const INTERCEPTOR_FUSE = Color(0.10, 0.55, 0.22)
const INTERCEPTOR_WING = Color(0.08, 0.40, 0.16)
const INTERCEPTOR_CANOPY = Color(0.20, 0.55, 0.90)
const INTERCEPTOR_EDGE = Color(0.60, 1.00, 0.70)

# --- Bomber colors (Grey) ---
const BOMBER_NOSE = Color(0.65, 0.65, 0.68)
const BOMBER_FUSELAGE = Color(0.45, 0.45, 0.48)
const BOMBER_WING = Color(0.35, 0.35, 0.38)
const BOMBER_ENGINE = Color(0.20, 0.20, 0.22)
const BOMBER_CANOPY = Color(0.20, 0.55, 0.90)
const BOMBER_EDGE = Color(0.85, 0.85, 0.90)


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

	# --- Wings: delta triangles ---
	# Left wing: from col 19 row 10 to col 2 row 35
	_draw_delta_wing(img, 19, 10, 2, 35, 4, FIGHTER_WING, FIGHTER_EDGE)
	# Right wing: mirror — from col 28 row 10 to col 45 row 35
	_draw_delta_wing(img, 28, 10, 45, 35, 4, FIGHTER_WING, FIGHTER_EDGE)

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

	# Wings reach col 6 and col 41 — more angular, thinner
	_draw_delta_wing(img, 20, 12, 6, 34, 3, INTERCEPTOR_WING, INTERCEPTOR_EDGE)
	_draw_delta_wing(img, 27, 12, 41, 34, 3, INTERCEPTOR_WING, INTERCEPTOR_EDGE)

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

	# --- Wings: wide span, tips reach col 4 and col 59 at row 36 ---
	_draw_delta_wing(img, 24, 16, 4, 36, 5, BOMBER_WING, BOMBER_EDGE)
	_draw_delta_wing(img, 39, 16, 59, 36, 5, BOMBER_WING, BOMBER_EDGE)

	# --- Twin engine pods under wings ---
	# Left pod: cols 10-16, rows 30-40
	_draw_rect(img, 10, 30, 16, 40, BOMBER_ENGINE)
	_safe_pixel(img, 10, 30, BOMBER_EDGE)
	_safe_pixel(img, 16, 30, BOMBER_EDGE)
	# Intake circle on left pod
	_draw_filled_oval(img, 13, 33, 2, 2, Color(0.08, 0.08, 0.10))
	# Right pod: cols 47-53, rows 30-40
	_draw_rect(img, 47, 30, 53, 40, BOMBER_ENGINE)
	_safe_pixel(img, 47, 30, BOMBER_EDGE)
	_safe_pixel(img, 53, 30, BOMBER_EDGE)
	# Intake circle on right pod
	_draw_filled_oval(img, 50, 33, 2, 2, Color(0.08, 0.08, 0.10))


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


static func _draw_delta_wing(
	img: Image,
	root_x: int, root_y: int,
	tip_x: int, tip_y: int,
	root_thickness: int,
	fill_color: Color,
	edge_color: Color
) -> void:
	## Draws a filled delta-wing triangle from (root_x, root_y) to (tip_x, tip_y).
	## Thickness tapers from root_thickness at the root to 1px at the tip.
	var rows := absi(tip_y - root_y)
	if rows == 0:
		return
	var y_dir := 1 if tip_y > root_y else -1
	for i in range(rows + 1):
		var t := float(i) / float(rows)
		var y := root_y + i * y_dir
		var x := roundi(lerpf(float(root_x), float(tip_x), t))
		var thickness := maxi(1, roundi(lerpf(float(root_thickness), 1.0, t)))
		# Draw vertical strip at this x,y
		for dy in range(-thickness / 2, (thickness + 1) / 2):
			_safe_pixel(img, x, y + dy, fill_color)
		# Edge pixel at leading edge
		_safe_pixel(img, x, y - thickness / 2, edge_color)
