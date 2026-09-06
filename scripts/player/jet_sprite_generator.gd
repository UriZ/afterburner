class_name JetSpriteGenerator
extends RefCounted

## Generates a 640x96 sprite sheet with 5 rear-view F-14 banking frames.
## Bank angles: [-35, -15, 0, 15, 35] degrees (hard-left to hard-right).

const FRAME_W := 128
const FRAME_H := 96
const FRAME_COUNT := 5
const SHEET_WIDTH := FRAME_W * FRAME_COUNT
const CENTER := 64  # horizontal center of each frame (FRAME_W / 2)

const BANK_ANGLES := [-35.0, -15.0, 0.0, 15.0, 35.0]

# Palette — warmer fuselage for contrast against blue sky/ocean
const COLOR_FUSELAGE := Color(0.60, 0.58, 0.55)
const COLOR_FUSELAGE_LIT := Color(0.70, 0.68, 0.65)
const COLOR_FIN := Color(0.45, 0.50, 0.60)
const COLOR_FIN_EDGE := Color(0.38, 0.43, 0.53)
const COLOR_STABILIZER := Color(0.40, 0.45, 0.55)
const COLOR_NOZZLE_OUTER := Color(0.20, 0.20, 0.22)
const COLOR_NOZZLE_INNER := Color(0.85, 0.45, 0.10)
const COLOR_NOZZLE_RING := Color(0.50, 0.30, 0.15)
const COLOR_AFTERBURN_1 := Color(1.00, 0.85, 0.30)
const COLOR_AFTERBURN_2 := Color(1.00, 0.50, 0.08)
const COLOR_AFTERBURN_3 := Color(0.85, 0.25, 0.05)
const COLOR_AFTERBURN_TIP := Color(0.60, 0.10, 0.02)
const COLOR_SPINE_LIGHT := Color(0.75, 0.73, 0.70)
const COLOR_PANEL_LINE := Color(0.48, 0.46, 0.43)
const COLOR_FAIRING := Color(0.50, 0.48, 0.46)


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
	var shift_x := roundi(sin_b * 16.0)
	var is_hard_bank := absf(bank_angle) > 30.0

	var h_offset := shift_x

	# --- Fuselage main body ---
	# Main rect: cols 48-78, rows 16-76 (was 24-39, 8-38)
	_draw_rect_banked(image, ox, 48, 78, 16, 76, cos_b, h_offset, COLOR_FUSELAGE)
	# Top narrows: cols 54-72, rows 12-16 (was 27-36, 6-8)
	_draw_rect_banked(image, ox, 54, 72, 12, 16, cos_b, h_offset, COLOR_FUSELAGE)
	# Rounded bottom: cols 52-74, rows 78-82 (was 26-37, 39-41)
	_draw_rect_banked(image, ox, 52, 74, 78, 82, cos_b, h_offset, COLOR_FUSELAGE)

	# --- Panel line along fuselage center (1px darker line) ---
	_draw_rect_banked(image, ox, 63, 64, 14, 76, cos_b, h_offset, COLOR_PANEL_LINE)

	# --- Cockpit spine ---
	# Cols 58-68, rows 16-32 (was 29-34, 8-16)
	_draw_rect_banked(image, ox, 58, 68, 16, 32, cos_b, h_offset, COLOR_SPINE_LIGHT)

	# --- Tail fins with inward taper ---
	var draw_left_fin := true
	var draw_right_fin := true
	if is_hard_bank:
		if bank_angle < 0:
			draw_right_fin = false
		else:
			draw_left_fin = false

	if draw_left_fin:
		# Main body: cols 44-52, rows 8-44 (was 22-26, 4-22)
		var fin_scale := 1.0 if bank_angle <= 0 else cos_b
		_draw_fin_tapered(image, ox, 44, 52, 8, 44, true, cos_b, h_offset, fin_scale, COLOR_FIN)
		# Fin edge highlight (inward taper detail)
		_draw_rect_banked(image, ox, 51, 52, 8, 40, cos_b, h_offset, COLOR_FIN_EDGE)

	if draw_right_fin:
		# Main body: cols 74-82, rows 8-44 (was 37-41, 4-22)
		var fin_scale := 1.0 if bank_angle >= 0 else cos_b
		_draw_fin_tapered(image, ox, 74, 82, 8, 44, false, cos_b, h_offset, fin_scale, COLOR_FIN)
		# Fin edge highlight
		_draw_rect_banked(image, ox, 74, 75, 8, 40, cos_b, h_offset, COLOR_FIN_EDGE)

	# Soft bank: near fin extends up slightly
	if not is_hard_bank and absf(bank_angle) > 5.0:
		if bank_angle < 0:
			_draw_rect_banked(image, ox, 46, 50, 6, 8, cos_b, h_offset, COLOR_FIN)
		else:
			_draw_rect_banked(image, ox, 76, 80, 6, 8, cos_b, h_offset, COLOR_FIN)

	# --- Horizontal stabilizers ---
	# Left: cols 28-46, rows 60-68 (was 14-23, 30-34)
	_draw_stabilizer_left(image, ox, 28, 46, 60, 68, cos_b, h_offset, COLOR_STABILIZER)
	# Right: cols 80-98, rows 60-68 (was 40-49, 30-34)
	_draw_stabilizer_right(image, ox, 80, 98, 60, 68, cos_b, h_offset, COLOR_STABILIZER)

	# --- Wing root fairings where stabilizers meet fuselage ---
	_draw_rect_banked(image, ox, 44, 50, 58, 66, cos_b, h_offset, COLOR_FAIRING)
	_draw_rect_banked(image, ox, 76, 82, 58, 66, cos_b, h_offset, COLOR_FAIRING)

	# Hard bank: show a wing stub on the upward side
	if is_hard_bank:
		if bank_angle < 0:
			# Cols 20-44, rows 24-32 (was 10-22, 12-16)
			_draw_rect_banked(image, ox, 20, 44, 24, 32, cos_b, h_offset, COLOR_STABILIZER)
		else:
			# Cols 82-106, rows 24-32 (was 41-53, 12-16)
			_draw_rect_banked(image, ox, 82, 106, 24, 32, cos_b, h_offset, COLOR_STABILIZER)

	# --- Engine nozzles with concentric ring detail ---
	# Left nozzle: cols 52-62, rows 80-88 (was 26-31, 40-44)
	_draw_oval_banked(image, ox, 52, 62, 80, 88, cos_b, h_offset, COLOR_NOZZLE_OUTER)
	_draw_oval_banked(image, ox, 54, 60, 81, 87, cos_b, h_offset, COLOR_NOZZLE_RING)
	_draw_rect_banked(image, ox, 55, 59, 82, 86, cos_b, h_offset, COLOR_NOZZLE_INNER)

	# Right nozzle: cols 64-74, rows 80-88 (was 32-37, 40-44)
	_draw_oval_banked(image, ox, 64, 74, 80, 88, cos_b, h_offset, COLOR_NOZZLE_OUTER)
	_draw_oval_banked(image, ox, 66, 72, 81, 87, cos_b, h_offset, COLOR_NOZZLE_RING)
	_draw_rect_banked(image, ox, 67, 71, 82, 86, cos_b, h_offset, COLOR_NOZZLE_INNER)

	# --- Afterburner flames (24px long, was 12) ---
	var left_nozzle_cx := roundi((52 + 62) * 0.5 * cos_b) + (CENTER - roundi(CENTER * cos_b)) + h_offset
	var right_nozzle_cx := roundi((64 + 74) * 0.5 * cos_b) + (CENTER - roundi(CENTER * cos_b)) + h_offset
	_draw_afterburner_flame(image, ox, left_nozzle_cx, 89)
	_draw_afterburner_flame(image, ox, right_nozzle_cx, 89)


# --- Drawing helpers ---

## Applies horizontal banking transform to a column coordinate.
## Squishes x toward center (col 64) by cos_b, then shifts by h_offset.
static func _bank_x(col: int, cos_b: float, h_offset: int) -> int:
	return roundi((col - CENTER) * cos_b) + CENTER + h_offset


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
	var cx_2 := bx0 + bx1
	var cy_2 := row_top + row_bottom
	var rx := (bx1 - bx0)
	var ry := (row_bottom - row_top)
	if rx <= 0 or ry <= 0:
		return
	for y in range(row_top, row_bottom + 1):
		for x in range(bx0, bx1 + 1):
			var dx := 2 * x - cx_2
			var dy := 2 * y - cy_2
			if dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry:
				if _in_bounds(image, ox + x, y):
					image.set_pixel(ox + x, y, color)


## Draw a tail fin with slight inward taper.
## is_left: true for left fin (tapers inward toward right), false for right fin.
static func _draw_fin_tapered(
	image: Image, ox: int,
	col_left: int, col_right: int, row_top: int, row_bottom: int,
	is_left: bool,
	cos_b: float, h_offset: int, _scale: float, color: Color
) -> void:
	var height := row_bottom - row_top
	if height <= 0:
		return
	for row in range(row_top, row_bottom + 1):
		# t=0 at top (tip), t=1 at bottom (base)
		var t := float(row - row_top) / float(height)
		# Taper: at the tip, narrow by 2px on the inward side
		var taper := roundi((1.0 - t) * 2.0)
		var cl := col_left
		var cr := col_right
		if is_left:
			cl += taper  # left fin tapers inward (tip shifts right)
		else:
			cr -= taper  # right fin tapers inward (tip shifts left)
		if cl <= cr:
			_draw_rect_banked(image, ox, cl, cr, row, row, cos_b, h_offset, color)


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
## 4 layers tapering from 8px wide to 1px over 24px length, with width flicker.
static func _draw_afterburner_flame(
	image: Image, ox: int, nozzle_cx: int, start_row: int
) -> void:
	var flame_length := 24
	var max_half_width := 4  # 8px total width

	for row_offset in range(flame_length):
		var row := start_row + row_offset
		if row >= FRAME_H:
			break
		var t := float(row_offset) / float(flame_length - 1)
		# Taper from max_half_width down to 0
		var half_w := roundi(lerpf(float(max_half_width), 0.0, t))
		# Flickering width variation: +/- 1px based on row parity
		if row_offset > 2 and row_offset < flame_length - 2:
			half_w += 1 if (row_offset % 3 == 0) else 0

		for dx in range(-half_w, half_w + 1):
			var px := ox + nozzle_cx + dx
			if not _in_bounds(image, px, row):
				continue
			var dist := absf(float(dx)) / float(maxi(half_w, 1))
			var color: Color
			if dist < 0.25:
				color = COLOR_AFTERBURN_1  # inner white-yellow core
			elif dist < 0.50:
				color = COLOR_AFTERBURN_2  # mid orange ring
			elif dist < 0.75:
				color = COLOR_AFTERBURN_3  # outer red ring
			else:
				color = COLOR_AFTERBURN_TIP  # edge glow
			image.set_pixel(px, row, color)


static func _in_bounds(image: Image, x: int, y: int) -> bool:
	return x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height()
