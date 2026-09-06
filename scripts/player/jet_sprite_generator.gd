class_name JetSpriteGenerator
extends RefCounted

## Generates an 800x96 sprite sheet with 5 top-rear dorsal-view F-14 banking frames.
## View: ~25-30deg elevation above and behind — you see the TOP of the wings,
## cockpit canopy as a dark dome, engines foreshortened at the bottom.
## Banking: one wing foreshortens while the other extends (roll perspective).

const FRAME_W := 160
const FRAME_H := 96
const FRAME_COUNT := 5
const SHEET_WIDTH := FRAME_W * FRAME_COUNT  # 800
const CENTER_X := 80  # horizontal center of each frame
const CENTER_Y := 48  # vertical center

# Banking parameters: [left_wing_scale, right_wing_scale, fuselage_shift_x]
# Frame 0: hard left bank — left wing foreshortens, right extends
# Frame 1: soft left bank
# Frame 2: level flight — symmetric
# Frame 3: soft right bank
# Frame 4: hard right bank
const BANK_PARAMS := [
	[0.30, 1.15, -6],   # hard left
	[0.65, 1.08, -3],   # soft left
	[1.00, 1.00,  0],   # center
	[1.08, 0.65,  3],   # soft right
	[1.15, 0.30,  6],   # hard right
]

# --- Palette ---
# Fuselage top surface (lit by sun from above)
const COL_FUSE_TOP := Color(0.68, 0.66, 0.62)
const COL_FUSE_MID := Color(0.58, 0.56, 0.52)
const COL_FUSE_DARK := Color(0.45, 0.43, 0.40)
# Wings — slightly bluer tint (painted metal)
const COL_WING_TOP := Color(0.60, 0.62, 0.65)
const COL_WING_MID := Color(0.50, 0.52, 0.56)
const COL_WING_EDGE := Color(0.42, 0.44, 0.48)
# Cockpit canopy — dark blue dome
const COL_CANOPY := Color(0.10, 0.37, 0.66)  # #1A5FA8 ≈
const COL_CANOPY_HIGHLIGHT := Color(0.30, 0.55, 0.80)
const COL_CANOPY_FRAME := Color(0.35, 0.34, 0.32)
# Tail fins
const COL_FIN := Color(0.48, 0.50, 0.55)
const COL_FIN_EDGE := Color(0.38, 0.40, 0.45)
# Engine nozzles (foreshortened, viewed from above — small)
const COL_NOZZLE := Color(0.22, 0.22, 0.24)
const COL_NOZZLE_GLOW := Color(0.80, 0.40, 0.10)
# Afterburner
const COL_FLAME_CORE := Color(1.00, 0.90, 0.40)
const COL_FLAME_MID := Color(1.00, 0.55, 0.10)
const COL_FLAME_OUTER := Color(0.85, 0.28, 0.05)
# Detail lines
const COL_PANEL_LINE := Color(0.42, 0.40, 0.38)
const COL_INTAKE := Color(0.35, 0.35, 0.37)


static func generate_sprite_sheet() -> ImageTexture:
	var image := Image.create(SHEET_WIDTH, FRAME_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	for i in range(FRAME_COUNT):
		_draw_frame(image, i)

	return ImageTexture.create_from_image(image)


static func _draw_frame(img: Image, frame: int) -> void:
	var ox := frame * FRAME_W
	var params: Array = BANK_PARAMS[frame]
	var lw_scale: float = params[0]
	var rw_scale: float = params[1]
	var shift_x: int = params[2]

	# Draw order: back to front (painter's algorithm)
	# 1. Afterburner flames (behind everything)
	_draw_afterburners(img, ox, shift_x)
	# 2. Tail fins (behind fuselage top)
	_draw_tail_fins(img, ox, lw_scale, rw_scale, shift_x)
	# 3. Wings (the dominant element)
	_draw_wings(img, ox, lw_scale, rw_scale, shift_x)
	# 4. Fuselage spine (on top of wings)
	_draw_fuselage(img, ox, shift_x)
	# 5. Cockpit canopy (topmost, forward of fuselage)
	_draw_canopy(img, ox, shift_x)
	# 6. Engine nozzles (visible at bottom, foreshortened)
	_draw_nozzles(img, ox, shift_x)
	# 7. Panel lines and detail
	_draw_details(img, ox, lw_scale, rw_scale, shift_x)


# --- FUSELAGE: Central spine running from nose to tail ---
# Viewed from above, it's a long narrow shape, widest at mid-body.
static func _draw_fuselage(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx

	# Nose cone (rows 10-20) — narrow point
	for row in range(10, 20):
		var t := float(row - 10) / 10.0
		var hw := roundi(lerpf(2.0, 6.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_TOP)

	# Forward fuselage (rows 20-36) — widens to cockpit area
	for row in range(20, 36):
		var t := float(row - 20) / 16.0
		var hw := roundi(lerpf(6.0, 10.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_TOP)

	# Mid fuselage (rows 36-60) — widest, between the wings
	for row in range(36, 60):
		var t := float(row - 36) / 24.0
		var hw := roundi(lerpf(10.0, 12.0, t))
		var col := COL_FUSE_TOP if t < 0.5 else COL_FUSE_MID
		_hline(img, ox, cx - hw, cx + hw, row, col)

	# Rear fuselage (rows 60-78) — narrows toward engines
	for row in range(60, 78):
		var t := float(row - 60) / 18.0
		var hw := roundi(lerpf(12.0, 8.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_MID)

	# Engine housing (rows 78-86) — splits into two nacelles
	for row in range(78, 86):
		var t := float(row - 78) / 8.0
		var hw := roundi(lerpf(8.0, 6.0, t))
		# Left nacelle
		_hline(img, ox, cx - hw, cx - 2, row, COL_FUSE_DARK)
		# Right nacelle
		_hline(img, ox, cx + 2, cx + hw, row, COL_FUSE_DARK)

	# Center spine highlight (single bright line down the middle)
	for row in range(12, 76):
		_set_px(img, ox + cx, row, COL_FUSE_TOP.lerp(Color.WHITE, 0.15))


# --- WINGS: The dominant visual element ---
# From above, wings are wide swept-back delta shapes extending from the mid-fuselage.
# Each wing is drawn independently with its own scale for banking.
static func _draw_wings(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Wing vertical span: rows 38-56 (centered around row 47)
	# At row 38 (leading edge), wings start narrow near fuselage
	# At row ~47, maximum span (20px to 140px in level flight)
	# At row 56 (trailing edge), wings sweep back to fuselage

	# Left wing
	_draw_single_wing(img, ox, cx, lw_scale, true)
	# Right wing
	_draw_single_wing(img, ox, cx, rw_scale, false)


static func _draw_single_wing(img: Image, ox: int, cx: int, scale: float, is_left: bool) -> void:
	# Wing geometry: swept-back shape
	# Leading edge: row 36, starts at fuselage edge
	# Max chord: row 44, extends to max span
	# Trailing edge: row 56, sweeps back

	var wing_rows_start := 36
	var wing_rows_peak := 44
	var wing_rows_end := 56
	var max_span := roundi(60.0 * scale)  # distance from center at widest point

	if max_span < 3:
		return  # Too foreshortened to draw

	for row in range(wing_rows_start, wing_rows_end + 1):
		var span: int
		if row <= wing_rows_peak:
			# Leading edge: span increases linearly
			var t := float(row - wing_rows_start) / float(wing_rows_peak - wing_rows_start)
			span = roundi(lerpf(8.0 * scale, float(max_span), t * t))  # quadratic ease-in for sweep
		else:
			# Trailing edge: span decreases, but with a straighter trailing edge
			var t := float(row - wing_rows_peak) / float(wing_rows_end - wing_rows_peak)
			span = roundi(lerpf(float(max_span), 14.0 * scale, t))

		if span < 1:
			continue

		# Color: lighter near leading edge, darker toward trailing edge
		var row_t := float(row - wing_rows_start) / float(wing_rows_end - wing_rows_start)
		var col: Color
		if row_t < 0.3:
			col = COL_WING_TOP
		elif row_t < 0.7:
			col = COL_WING_MID
		else:
			col = COL_WING_EDGE

		# Wing edge highlight on the outboard tip (1px lighter)
		var fuselage_hw := 10  # don't draw over fuselage

		if is_left:
			var x_start := maxi(0, cx - span)
			var x_end := cx - fuselage_hw
			if x_start < x_end:
				_hline(img, ox, x_start, x_end, row, col)
				# Leading/trailing edge highlight
				if row == wing_rows_start or row == wing_rows_end:
					_hline(img, ox, x_start, x_end, row, COL_WING_EDGE)
				# Wingtip highlight
				_set_px(img, ox + x_start, row, COL_WING_EDGE)
		else:
			var x_start := cx + fuselage_hw
			var x_end := mini(FRAME_W - 1, cx + span)
			if x_start < x_end:
				_hline(img, ox, x_start, x_end, row, col)
				if row == wing_rows_start or row == wing_rows_end:
					_hline(img, ox, x_start, x_end, row, COL_WING_EDGE)
				_set_px(img, ox + x_end, row, COL_WING_EDGE)


# --- COCKPIT CANOPY: Dark blue dome visible from above ---
# Prominent feature at rows 20-32, centered on fuselage
static func _draw_canopy(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx

	# Canopy frame (slightly wider than the canopy itself)
	for row in range(19, 34):
		var t := float(row - 19) / 15.0
		# Oval shape: widest at center
		var dist_from_center := absf(t - 0.5) * 2.0
		var hw := roundi(lerpf(5.0, 1.0, dist_from_center * dist_from_center))
		_hline(img, ox, cx - hw - 1, cx + hw + 1, row, COL_CANOPY_FRAME)

	# Canopy glass — dark blue dome
	for row in range(20, 33):
		var t := float(row - 20) / 13.0
		var dist_from_center := absf(t - 0.45) * 2.0  # Slightly forward-biased peak
		var hw := roundi(lerpf(4.0, 1.0, dist_from_center * dist_from_center))
		_hline(img, ox, cx - hw, cx + hw, row, COL_CANOPY)

	# Specular highlight on canopy (a bright streak)
	for row in range(22, 28):
		_set_px(img, ox + cx - 1, row, COL_CANOPY_HIGHLIGHT)
		if row >= 23 and row <= 26:
			_set_px(img, ox + cx - 2, row, COL_CANOPY_HIGHLIGHT)


# --- TAIL FINS: Twin vertical stabilizers ---
# Viewed from above, these appear as narrow shapes projecting upward from the rear fuselage.
# They are "above" the fuselage plane so they project outward at an angle.
static func _draw_tail_fins(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Each fin projects outward and slightly backward from the rear fuselage
	# In top-down view, they appear as angled lines/slivers
	var fin_base_row := 64
	var fin_tip_row := 56

	# Left fin — angles outward to the left
	var left_spread := roundi(8.0 * lw_scale)
	if left_spread >= 2:
		for row in range(fin_tip_row, fin_base_row + 1):
			var t := float(row - fin_tip_row) / float(fin_base_row - fin_tip_row)
			var offset := roundi(lerpf(float(left_spread), 4.0, t))
			var fin_x := cx - offset
			_set_px(img, ox + fin_x, row, COL_FIN)
			_set_px(img, ox + fin_x - 1, row, COL_FIN)
			if t > 0.3 and t < 0.8:
				_set_px(img, ox + fin_x + 1, row, COL_FIN_EDGE)

	# Right fin — angles outward to the right
	var right_spread := roundi(8.0 * rw_scale)
	if right_spread >= 2:
		for row in range(fin_tip_row, fin_base_row + 1):
			var t := float(row - fin_tip_row) / float(fin_base_row - fin_tip_row)
			var offset := roundi(lerpf(float(right_spread), 4.0, t))
			var fin_x := cx + offset
			_set_px(img, ox + fin_x, row, COL_FIN)
			_set_px(img, ox + fin_x + 1, row, COL_FIN)
			if t > 0.3 and t < 0.8:
				_set_px(img, ox + fin_x - 1, row, COL_FIN_EDGE)


# --- ENGINE NOZZLES: Small foreshortened circles at the bottom ---
# Viewed from above, nozzles are foreshortened — appear as small ovals.
static func _draw_nozzles(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx
	var nozzle_row := 82

	# Left nozzle (centered at cx-5)
	_draw_oval(img, ox, cx - 8, cx - 2, nozzle_row - 2, nozzle_row + 2, COL_NOZZLE)
	_draw_oval(img, ox, cx - 7, cx - 3, nozzle_row - 1, nozzle_row + 1, COL_NOZZLE_GLOW)

	# Right nozzle (centered at cx+5)
	_draw_oval(img, ox, cx + 2, cx + 8, nozzle_row - 2, nozzle_row + 2, COL_NOZZLE)
	_draw_oval(img, ox, cx + 3, cx + 7, nozzle_row - 1, nozzle_row + 1, COL_NOZZLE_GLOW)


# --- AFTERBURNER FLAMES: Small orange glow below nozzles ---
static func _draw_afterburners(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx
	# Shorter flames than the old rear view (foreshortened perspective)
	_draw_flame(img, ox, cx - 5, 85)
	_draw_flame(img, ox, cx + 5, 85)


static func _draw_flame(img: Image, ox: int, flame_cx: int, start_row: int) -> void:
	var flame_len := 10  # Short — viewed from above
	for row_off in range(flame_len):
		var row := start_row + row_off
		if row >= FRAME_H:
			break
		var t := float(row_off) / float(flame_len - 1)
		var hw := roundi(lerpf(3.0, 0.0, t))
		# Flicker
		if row_off > 1 and row_off < flame_len - 1 and row_off % 2 == 0:
			hw = maxi(0, hw - 1)

		for dx in range(-hw, hw + 1):
			var px := ox + flame_cx + dx
			if not _in_bounds(img, px, row):
				continue
			var dist := absf(float(dx)) / float(maxi(hw, 1))
			var col: Color
			if dist < 0.35:
				col = COL_FLAME_CORE
			elif dist < 0.65:
				col = COL_FLAME_MID
			else:
				col = COL_FLAME_OUTER
			img.set_pixel(px, row, col)


# --- DETAIL LINES: Panel lines, intake shadows, wing markings ---
static func _draw_details(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Fuselage center panel line
	for row in range(20, 78):
		_set_px(img, ox + cx, row, COL_PANEL_LINE)

	# Intake shadows on fuselage sides (rows 50-62)
	for row in range(50, 62):
		_set_px(img, ox + cx - 8, row, COL_INTAKE)
		_set_px(img, ox + cx + 8, row, COL_INTAKE)

	# Wing spar lines (structural detail running along each wing)
	var spar_row := 46  # Near the middle of the wing span
	var left_span := roundi(55.0 * lw_scale)
	var right_span := roundi(55.0 * rw_scale)

	if left_span > 12:
		for x in range(cx - left_span + 4, cx - 12):
			_set_px(img, ox + x, spar_row, COL_PANEL_LINE)
			_set_px(img, ox + x, spar_row + 4, COL_PANEL_LINE)

	if right_span > 12:
		for x in range(cx + 12, cx + right_span - 4):
			_set_px(img, ox + x, spar_row, COL_PANEL_LINE)
			_set_px(img, ox + x, spar_row + 4, COL_PANEL_LINE)


# --- Drawing primitives ---

static func _hline(img: Image, ox: int, x0: int, x1: int, row: int, color: Color) -> void:
	var xa := mini(x0, x1)
	var xb := maxi(x0, x1)
	for x in range(xa, xb + 1):
		_set_px(img, ox + x, row, color)


static func _set_px(img: Image, x: int, y: int, color: Color) -> void:
	if _in_bounds(img, x, y):
		img.set_pixel(x, y, color)


static func _draw_oval(img: Image, ox: int, x0: int, x1: int, y0: int, y1: int, color: Color) -> void:
	var cx_2 := x0 + x1
	var cy_2 := y0 + y1
	var rx := x1 - x0
	var ry := y1 - y0
	if rx <= 0 or ry <= 0:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := 2 * x - cx_2
			var dy := 2 * y - cy_2
			if dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry:
				_set_px(img, ox + x, y, color)


static func _in_bounds(img: Image, x: int, y: int) -> bool:
	return x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height()
