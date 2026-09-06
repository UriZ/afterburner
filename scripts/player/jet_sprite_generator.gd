class_name JetSpriteGenerator
extends RefCounted

## Generates a 320x48 sprite sheet with 5 rear-view F-14 banking frames.
## Bank angles: [-35, -15, 0, 15, 35] degrees (hard-left to hard-right).

const FRAME_W := 64
const FRAME_H := 48
const FRAME_COUNT := 5
const SHEET_WIDTH := FRAME_W * FRAME_COUNT

const BANK_ANGLES := [-35.0, -15.0, 0.0, 15.0, 35.0]

# Palette
const COLOR_FUSELAGE := Color(0.55, 0.60, 0.70)
const COLOR_FUSELAGE_LIT := Color(0.65, 0.70, 0.80)
const COLOR_FIN := Color(0.45, 0.50, 0.60)
const COLOR_STABILIZER := Color(0.40, 0.45, 0.55)
const COLOR_NOZZLE_OUTER := Color(0.20, 0.20, 0.22)
const COLOR_NOZZLE_INNER := Color(0.85, 0.45, 0.10)
const COLOR_AFTERBURN_1 := Color(1.00, 0.75, 0.10)
const COLOR_AFTERBURN_2 := Color(1.00, 0.45, 0.05)
const COLOR_AFTERBURN_3 := Color(0.80, 0.20, 0.05)
const COLOR_SPINE_LIGHT := Color(0.70, 0.75, 0.85)


static func generate_sprite_sheet() -> ImageTexture:
	var image := Image.create(SHEET_WIDTH, FRAME_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	for i in range(FRAME_COUNT):
		_draw_jet_frame(image, i, BANK_ANGLES[i])

	return ImageTexture.create_from_image(image)


static func _draw_jet_frame(image: Image, frame_index: int, bank_angle: float) -> void:
	var ox := frame_index * FRAME_W
	var bank_rad := deg_to_rad(bank_angle)
	var cos_b := cos(bank_rad)
	var sin_b := sin(bank_rad)
	var shift_x := roundi(sin_b * 8.0)
	var is_hard_bank := absf(bank_angle) > 30.0

	# All coordinates are relative to frame origin (ox, 0).
	# Center frame reference: fuselage centered around col 32.
	# h_offset shifts the whole jet horizontally based on bank angle.
	var h_offset := shift_x

	# Fuselage main rect
	_draw_rect_banked(image, ox, 24, 39, 8, 38, cos_b, h_offset, COLOR_FUSELAGE)
	# Top narrows
	_draw_rect_banked(image, ox, 27, 36, 6, 8, cos_b, h_offset, COLOR_FUSELAGE)
	# Rounded bottom
	_draw_rect_banked(image, ox, 26, 37, 39, 41, cos_b, h_offset, COLOR_FUSELAGE)

	# --- Cockpit spine ---
	_draw_rect_banked(image, ox, 29, 34, 8, 16, cos_b, h_offset, COLOR_SPINE_LIGHT)

	# --- Tail fins ---
	# In hard bank, only the upward fin is visible (the other hides behind fuselage).
	var draw_left_fin := true
	var draw_right_fin := true
	if is_hard_bank:
		if bank_angle < 0:
			draw_right_fin = false  # banking left, right fin hidden
		else:
			draw_left_fin = false   # banking right, left fin hidden

	if draw_left_fin:
		# Left fin: cols 22-26, rows 4-22; base widens 21-26, rows 18-22; tip 23-25, rows 4-6
		var fin_scale := 1.0 if bank_angle <= 0 else cos_b
		_draw_fin(image, ox, 22, 26, 4, 22, 21, 26, 18, 22, 23, 25, 4, 6, cos_b, h_offset, fin_scale, COLOR_FIN)

	if draw_right_fin:
		# Right fin: cols 37-41, rows 4-22; base 37-42, rows 18-22; tip 38-40, rows 4-6
		var fin_scale := 1.0 if bank_angle >= 0 else cos_b
		_draw_fin(image, ox, 37, 41, 4, 22, 37, 42, 18, 22, 38, 40, 4, 6, cos_b, h_offset, fin_scale, COLOR_FIN)

	# For soft bank, make the "near" fin slightly taller
	if not is_hard_bank and absf(bank_angle) > 5.0:
		if bank_angle < 0:
			# Left fin is nearer -- extend tip up by 1px
			_draw_rect_banked(image, ox, 23, 25, 3, 4, cos_b, h_offset, COLOR_FIN)
		else:
			_draw_rect_banked(image, ox, 38, 40, 3, 4, cos_b, h_offset, COLOR_FIN)

	# --- Horizontal stabilizers ---
	_draw_stabilizer_left(image, ox, 14, 23, 30, 34, cos_b, h_offset, COLOR_STABILIZER)
	_draw_stabilizer_right(image, ox, 40, 49, 30, 34, cos_b, h_offset, COLOR_STABILIZER)

	# Hard bank: show a wing stub on the upward side
	if is_hard_bank:
		if bank_angle < 0:
			# Hard left: show left wing stub top-left area
			_draw_rect_banked(image, ox, 10, 22, 12, 16, cos_b, h_offset, COLOR_STABILIZER)
		else:
			# Hard right: show right wing stub top-right area
			_draw_rect_banked(image, ox, 41, 53, 12, 16, cos_b, h_offset, COLOR_STABILIZER)

	# --- Engine nozzles ---
	# Left nozzle: oval cols 26-31, rows 40-44
	_draw_oval_banked(image, ox, 26, 31, 40, 44, cos_b, h_offset, COLOR_NOZZLE_OUTER)
	_draw_rect_banked(image, ox, 27, 30, 41, 43, cos_b, h_offset, COLOR_NOZZLE_INNER)

	# Right nozzle: oval cols 32-37, rows 40-44
	_draw_oval_banked(image, ox, 32, 37, 40, 44, cos_b, h_offset, COLOR_NOZZLE_OUTER)
	_draw_rect_banked(image, ox, 33, 36, 41, 43, cos_b, h_offset, COLOR_NOZZLE_INNER)

	# --- Afterburner flames ---
	# Below each nozzle, 3 layers tapering from 6px wide to 1px over 12px length.
	var left_nozzle_cx := roundi((26 + 31) * 0.5 * cos_b) + (FRAME_W / 2 - roundi(32 * cos_b)) + h_offset
	var right_nozzle_cx := roundi((32 + 37) * 0.5 * cos_b) + (FRAME_W / 2 - roundi(32 * cos_b)) + h_offset
	_draw_afterburner_flame(image, ox, left_nozzle_cx, 45)
	_draw_afterburner_flame(image, ox, right_nozzle_cx, 45)


# --- Drawing helpers ---

## Applies horizontal banking transform to a column coordinate.
## Squishes x toward center (col 32) by cos_b, then shifts by h_offset.
static func _bank_x(col: int, cos_b: float, h_offset: int) -> int:
	return roundi((col - 32) * cos_b) + 32 + h_offset


## Draw a filled rectangle with horizontal banking applied.
static func _draw_rect_banked(
	image: Image, ox: int,
	col_left: int, col_right: int, row_top: int, row_bottom: int,
	cos_b: float, h_offset: int, color: Color
) -> void:
	var x0 := _bank_x(col_left, cos_b, h_offset)
	var x1 := _bank_x(col_right, cos_b, h_offset)
	if x0 > x1:
		var tmp := x0
		x0 = x1
		x1 = tmp
	for y in range(row_top, row_bottom + 1):
		for x in range(x0, x1 + 1):
			if _in_bounds(image, ox + x, y):
				image.set_pixel(ox + x, y, color)


## Draw a filled oval inscribed in the given bounding box, with banking.
static func _draw_oval_banked(
	image: Image, ox: int,
	col_left: int, col_right: int, row_top: int, row_bottom: int,
	cos_b: float, h_offset: int, color: Color
) -> void:
	var bx0 := _bank_x(col_left, cos_b, h_offset)
	var bx1 := _bank_x(col_right, cos_b, h_offset)
	if bx0 > bx1:
		var tmp := bx0
		bx0 = bx1
		bx1 = tmp
	var cx_2 := bx0 + bx1  # 2 * center_x (avoid float)
	var cy_2 := row_top + row_bottom
	var rx := (bx1 - bx0)  # diameter (use as 2*rx for integer math)
	var ry := (row_bottom - row_top)
	if rx <= 0 or ry <= 0:
		return
	for y in range(row_top, row_bottom + 1):
		for x in range(bx0, bx1 + 1):
			var dx := 2 * x - cx_2
			var dy := 2 * y - cy_2
			# Check (dx/rx)^2 + (dy/ry)^2 <= 1, scaled to integers
			if dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry:
				if _in_bounds(image, ox + x, y):
					image.set_pixel(ox + x, y, color)


## Draw a tail fin (main body + wider base + narrow tip).
static func _draw_fin(
	image: Image, ox: int,
	main_l: int, main_r: int, main_t: int, main_b: int,
	base_l: int, base_r: int, base_t: int, base_b: int,
	tip_l: int, tip_r: int, tip_t: int, tip_b: int,
	cos_b: float, h_offset: int, _scale: float, color: Color
) -> void:
	_draw_rect_banked(image, ox, main_l, main_r, main_t, main_b, cos_b, h_offset, color)
	_draw_rect_banked(image, ox, base_l, base_r, base_t, base_b, cos_b, h_offset, color)
	_draw_rect_banked(image, ox, tip_l, tip_r, tip_t, tip_b, cos_b, h_offset, color)


## Draw left horizontal stabilizer (tapers: full height at right edge, 1px at left).
static func _draw_stabilizer_left(
	image: Image, ox: int,
	col_left: int, col_right: int, row_top: int, row_bottom: int,
	cos_b: float, h_offset: int, color: Color
) -> void:
	var full_height := row_bottom - row_top
	var span := col_right - col_left
	if span <= 0:
		return
	for col in range(col_left, col_right + 1):
		var t := float(col - col_left) / float(span)
		var h := maxi(1, roundi(t * full_height))
		var mid := (row_top + row_bottom) / 2
		var bx := _bank_x(col, cos_b, h_offset)
		for dy in range(-h / 2, h / 2 + 1):
			if _in_bounds(image, ox + bx, mid + dy):
				image.set_pixel(ox + bx, mid + dy, color)


## Draw right horizontal stabilizer (tapers: full height at left edge, 1px at right).
static func _draw_stabilizer_right(
	image: Image, ox: int,
	col_left: int, col_right: int, row_top: int, row_bottom: int,
	cos_b: float, h_offset: int, color: Color
) -> void:
	var full_height := row_bottom - row_top
	var span := col_right - col_left
	if span <= 0:
		return
	for col in range(col_left, col_right + 1):
		var t := float(col_right - col) / float(span)
		var h := maxi(1, roundi(t * full_height))
		var mid := (row_top + row_bottom) / 2
		var bx := _bank_x(col, cos_b, h_offset)
		for dy in range(-h / 2, h / 2 + 1):
			if _in_bounds(image, ox + bx, mid + dy):
				image.set_pixel(ox + bx, mid + dy, color)


## Draw afterburner flame below a nozzle center.
## 3 layers tapering from 6px wide to 1px over 12px length.
static func _draw_afterburner_flame(
	image: Image, ox: int, nozzle_cx: int, start_row: int
) -> void:
	var flame_length := 12
	var max_half_width := 3  # 6px total width

	for row_offset in range(flame_length):
		var row := start_row + row_offset
		if row >= FRAME_H:
			break
		var t := float(row_offset) / float(flame_length - 1)
		# Taper from max_half_width down to 0
		var half_w := roundi(lerpf(float(max_half_width), 0.0, t))

		for dx in range(-half_w, half_w + 1):
			var px := ox + nozzle_cx + dx
			if not _in_bounds(image, px, row):
				continue
			var dist := absf(float(dx)) / float(maxi(half_w, 1))
			var color: Color
			if dist < 0.33:
				color = COLOR_AFTERBURN_1  # inner core
			elif dist < 0.66:
				color = COLOR_AFTERBURN_2  # mid ring
			else:
				color = COLOR_AFTERBURN_3  # outer ring
			image.set_pixel(px, row, color)


static func _in_bounds(image: Image, x: int, y: int) -> bool:
	return x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height()
