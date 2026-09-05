class_name JetSpriteGenerator
extends RefCounted

## Generates a 320x64 placeholder sprite sheet with 5 F-14 banking frames.
## Bank angles: [-35, -15, 0, 15, 35] degrees (hard-left to hard-right).

const FRAME_SIZE := 64
const FRAME_COUNT := 5
const SHEET_WIDTH := FRAME_SIZE * FRAME_COUNT
const SHEET_HEIGHT := FRAME_SIZE

# Palette
const COLOR_FUSELAGE := Color(0.45, 0.50, 0.58)    # grey-blue
const COLOR_CANOPY := Color(0.3, 0.85, 0.9)         # cyan
const COLOR_WING := Color(0.30, 0.33, 0.38)         # darker grey
const COLOR_TAIL := Color(0.38, 0.42, 0.48)         # mid grey
const COLOR_EXHAUST := Color(0.25, 0.25, 0.28)      # dark grey

const BANK_ANGLES := [-35.0, -15.0, 0.0, 15.0, 35.0]


static func generate_sprite_sheet() -> ImageTexture:
	var image := Image.create(SHEET_WIDTH, SHEET_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	for i in range(FRAME_COUNT):
		_draw_jet_frame(image, i, BANK_ANGLES[i])

	var texture := ImageTexture.create_from_image(image)
	return texture


static func _draw_jet_frame(image: Image, frame_index: int, bank_angle: float) -> void:
	var ox := frame_index * FRAME_SIZE  # x offset for this frame
	var cx := ox + FRAME_SIZE / 2       # center x
	var cy := FRAME_SIZE / 2            # center y

	var bank_rad := deg_to_rad(bank_angle)
	var cos_b := cos(bank_rad)
	var sin_b := sin(bank_rad)

	# --- Fuselage (ellipse, tall and narrow) ---
	_draw_rotated_ellipse(image, cx, cy, 5, 18, bank_rad, COLOR_FUSELAGE)

	# --- Canopy (small ellipse near top of fuselage) ---
	var canopy_offset_y := -6
	var canopy_cx := cx + roundi(sin_b * canopy_offset_y * -1)
	var canopy_cy := cy + roundi(cos_b * canopy_offset_y)
	_draw_rotated_ellipse(image, canopy_cx, canopy_cy, 3, 3, bank_rad, COLOR_CANOPY)

	# --- Wings (two trapezoids, sheared by bank) ---
	# Wing span narrows when banked to simulate perspective
	var wing_span := roundi(20.0 * abs(cos_b))
	var wing_y_offset := 2  # slightly below center

	# Left wing
	var wing_center_y := cy + roundi(cos_b * wing_y_offset)
	var wing_center_x := cx + roundi(sin_b * wing_y_offset * -1)
	_draw_wing(image, wing_center_x, wing_center_y, -wing_span, bank_rad, COLOR_WING, ox)

	# Right wing
	_draw_wing(image, wing_center_x, wing_center_y, wing_span, bank_rad, COLOR_WING, ox)

	# --- Tail fins (small lines at the back) ---
	var tail_y_offset := 14
	var tail_cx := cx + roundi(sin_b * tail_y_offset * -1)
	var tail_cy := cy + roundi(cos_b * tail_y_offset)
	var tail_span := roundi(8.0 * abs(cos_b))
	_draw_wing(image, tail_cx, tail_cy, -tail_span, bank_rad, COLOR_TAIL, ox)
	_draw_wing(image, tail_cx, tail_cy, tail_span, bank_rad, COLOR_TAIL, ox)

	# --- Exhaust nozzle ---
	var exhaust_y_offset := 18
	var exhaust_cx := cx + roundi(sin_b * exhaust_y_offset * -1)
	var exhaust_cy := cy + roundi(cos_b * exhaust_y_offset)
	_draw_rotated_ellipse(image, exhaust_cx, exhaust_cy, 3, 2, bank_rad, COLOR_EXHAUST)


static func _draw_rotated_ellipse(
	image: Image, cx: int, cy: int, rx: int, ry: int,
	angle: float, color: Color
) -> void:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var max_r := maxi(rx, ry)
	for dy in range(-max_r, max_r + 1):
		for dx in range(-max_r, max_r + 1):
			# Rotate point back to ellipse-local space
			var lx := dx * cos_a + dy * sin_a
			var ly := -dx * sin_a + dy * cos_a
			if rx > 0 and ry > 0:
				var dist := (lx * lx) / float(rx * rx) + (ly * ly) / float(ry * ry)
				if dist <= 1.0:
					var px := cx + dx
					var py := cy + dy
					if _in_bounds(image, px, py):
						image.set_pixel(px, py, color)


static func _draw_wing(
	image: Image, cx: int, cy: int, span: int,
	bank_angle: float, color: Color, frame_ox: int
) -> void:
	if span == 0:
		return
	var sign_val := 1 if span > 0 else -1
	var abs_span := absi(span)
	var cos_b := cos(bank_angle)
	var sin_b := sin(bank_angle)

	for i in range(abs_span):
		var t := float(i) / float(abs_span)
		var wing_half_height := roundi(lerpf(4.0, 1.0, t))  # taper toward tip
		var local_x := sign_val * i
		for h in range(-wing_half_height, wing_half_height + 1):
			# Rotate (local_x, h) by bank angle
			var rx := roundi(local_x * cos_b - h * sin_b)
			var ry := roundi(local_x * sin_b + h * cos_b)
			var px := cx + rx
			var py := cy + ry
			if px >= frame_ox and px < frame_ox + FRAME_SIZE and _in_bounds(image, px, py):
				image.set_pixel(px, py, color)


static func _in_bounds(image: Image, x: int, y: int) -> bool:
	return x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height()
