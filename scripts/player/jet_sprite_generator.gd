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

# --- Palette (revised for F-14 identity and contrast) ---
# Fuselage — light grey-tan, sun-lit
const COL_FUSE_TOP := Color(0.706, 0.690, 0.659)    # #B4B0A8
const COL_FUSE_MID := Color(0.478, 0.471, 0.439)    # #7A7870
const COL_FUSE_DARK := Color(0.235, 0.231, 0.220)   # #3C3B38
# Wings — blue-grey, clearly distinct from fuselage
const COL_WING_TOP := Color(0.549, 0.565, 0.600)    # #8C9099
const COL_WING_SHADOW := Color(0.337, 0.353, 0.376) # #565A60
# Fixed wing gloves — darker than movable panels
const COL_GLOVE := Color(0.431, 0.447, 0.471)       # #6E7278
# Cockpit canopy
const COL_CANOPY := Color(0.102, 0.373, 0.659)      # #1A5FA8
const COL_CANOPY_HIGHLIGHT := Color(0.420, 0.702, 0.910) # #6BB3E8
const COL_CANOPY_FRAME := Color(0.165, 0.161, 0.149)    # #2A2926
# Engine nozzles
const COL_NACELLE := Color(0.118, 0.118, 0.125)     # #1E1E20
const COL_NOZZLE_RIM := Color(0.290, 0.290, 0.314)  # #4A4A50
const COL_NOZZLE_GLOW := Color(0.800, 0.400, 0.078) # #CC6614
# Afterburner
const COL_FLAME_CORE := Color(1.000, 0.910, 0.400)  # #FFE866
const COL_FLAME_MID := Color(1.000, 0.549, 0.102)   # #FF8C1A
const COL_FLAME_OUTER := Color(0.800, 0.133, 0.000) # #CC2200
# Panel/detail lines — 0.25 darker than surface
const COL_PANEL := Color(0.416, 0.408, 0.376)       # #6A6860
# Tail fins (reuse wing shadow — they are in shadow from above)
const COL_FIN := Color(0.337, 0.353, 0.376)
const COL_FIN_EDGE := Color(0.275, 0.290, 0.314)
# Intake shadows
const COL_INTAKE := Color(0.235, 0.231, 0.220)


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
	# 3. Wings — gloves first, then movable panels
	_draw_wings(img, ox, lw_scale, rw_scale, shift_x)
	# 4. Fuselage spine (on top of wings) — now with twin tail boom gap
	_draw_fuselage(img, ox, shift_x)
	# 5. Cockpit canopy — now tandem two-seat
	_draw_canopy(img, ox, shift_x)
	# 6. Engine nozzles (visible at bottom, foreshortened)
	_draw_nozzles(img, ox, shift_x)
	# 7. Panel lines and detail — now includes sweep crease
	_draw_details(img, ox, lw_scale, rw_scale, shift_x)


# --- FUSELAGE: Central spine with twin tail boom gap ---
# The rear fuselage splits into two engine nacelles with a transparent gap between them.
# This is the #1 F-14 identifier from above.
static func _draw_fuselage(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx

	# Nose cone (rows 4-18) — long pointed radome
	for row in range(4, 10):
		var t := float(row - 4) / 6.0
		var hw := roundi(lerpf(1.0, 4.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_TOP)

	for row in range(10, 18):
		var t := float(row - 10) / 8.0
		var hw := roundi(lerpf(4.0, 7.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_TOP)

	# Forward fuselage (rows 18-36) — under cockpit area
	for row in range(18, 36):
		var t := float(row - 18) / 18.0
		var hw := roundi(lerpf(7.0, 10.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_TOP)

	# Mid fuselage (rows 36-54) — widest, at wing attachment
	for row in range(36, 54):
		var t := float(row - 36) / 18.0
		var hw := roundi(lerpf(10.0, 10.0, t))
		var col := COL_FUSE_TOP if t < 0.5 else COL_FUSE_MID
		_hline(img, ox, cx - hw, cx + hw, row, col)

	# Rear fuselage (rows 54-68) — narrows toward engine split
	for row in range(54, 68):
		var t := float(row - 54) / 14.0
		var hw := roundi(lerpf(10.0, 7.0, t))
		_hline(img, ox, cx - hw, cx + hw, row, COL_FUSE_MID)

	# Twin tail boom split (rows 68-80) — TWO nacelles with transparent GAP
	# This is the critical F-14 identity marker
	for row in range(68, 80):
		var t := float(row - 68) / 12.0
		var outer_hw := roundi(lerpf(7.0, 7.0, t))
		var gap_hw := 3  # cx-3 to cx+3 is transparent/gap
		# Left nacelle: cx-outer_hw to cx-gap_hw
		_hline(img, ox, cx - outer_hw, cx - gap_hw, row, COL_FUSE_DARK)
		# Right nacelle: cx+gap_hw to cx+outer_hw
		_hline(img, ox, cx + gap_hw, cx + outer_hw, row, COL_FUSE_DARK)
		# The gap (cx-2 to cx+2) stays transparent — no fill

	# Center spine highlight (single bright line down the middle)
	for row in range(8, 68):
		_set_px(img, ox + cx, row, COL_FUSE_TOP.lerp(Color.WHITE, 0.15))


# --- WINGS: Fixed gloves + movable panels ---
# The F-14 has fixed trapezoidal wing gloves (darker, non-sweeping root sections)
# and variable-sweep movable panels extending outward.
static func _draw_wings(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Draw gloves first (they sit between fuselage and movable panels)
	_draw_wing_glove(img, ox, cx, lw_scale, true)
	_draw_wing_glove(img, ox, cx, rw_scale, false)
	# Then movable panels on top
	_draw_single_wing(img, ox, cx, lw_scale, true)
	_draw_single_wing(img, ox, cx, rw_scale, false)


# --- FIXED WING GLOVES: Trapezoidal root section, darker than movable panels ---
# Rows 36-54, extends from fuselage edge (cx+-12) outward to cx+-22.
# This is an F-14 identifier — no other fighter has this visible glove geometry.
static func _draw_wing_glove(img: Image, ox: int, cx: int, scale: float, is_left: bool) -> void:
	var glove_inner := 10   # starts at fuselage edge
	var glove_leading := roundi(22.0 * scale)  # wider at leading edge (row 36)
	var glove_trailing := roundi(18.0 * scale)  # narrower at trailing edge (row 54)

	if glove_leading < 4:
		return  # Too foreshortened

	for row in range(36, 55):
		var t := float(row - 36) / 18.0
		var outer := roundi(lerpf(float(glove_leading), float(glove_trailing), t))

		if is_left:
			var x_start := cx - outer
			var x_end := cx - glove_inner
			if x_start < x_end:
				_hline(img, ox, x_start, x_end, row, COL_GLOVE)
				# Outer edge darker
				_set_px(img, ox + x_start, row, COL_WING_SHADOW)
		else:
			var x_start := cx + glove_inner
			var x_end := cx + outer
			if x_start < x_end:
				_hline(img, ox, x_start, x_end, row, COL_GLOVE)
				_set_px(img, ox + x_end, row, COL_WING_SHADOW)


# --- MOVABLE WING PANELS: Swept-back triangles extending from gloves ---
static func _draw_single_wing(img: Image, ox: int, cx: int, scale: float, is_left: bool) -> void:
	# Wing extends from glove outer edge outward
	# Leading edge at row 36 is widest, trailing edge at row 54 sweeps back
	var glove_outer := roundi(22.0 * scale)  # where glove ends = wing inner edge
	var max_span := roundi(60.0 * scale)     # maximum wing tip distance from center

	if max_span < 5:
		return

	# The movable panel is a filled triangle:
	# Leading edge (row 36): from glove_outer to max_span (horizontal)
	# Trailing edge sweeps back from max_span at row 36 to glove_outer at row 54
	for row in range(36, 55):
		var t := float(row - 36) / 18.0
		# Outer edge sweeps back from max_span toward fuselage
		var outer := roundi(lerpf(float(max_span), float(glove_outer), t))
		var inner := glove_outer

		# Color: lighter near leading edge, shadow at trailing 20%
		var col: Color
		if t < 0.80:
			col = COL_WING_TOP
		else:
			col = COL_WING_SHADOW

		if is_left:
			var x_start := maxi(0, cx - outer)
			var x_end := cx - inner
			if x_start < x_end:
				_hline(img, ox, x_start, x_end, row, col)
				# Wingtip highlight
				_set_px(img, ox + x_start, row, COL_WING_SHADOW)
		else:
			var x_start := cx + inner
			var x_end := mini(FRAME_W - 1, cx + outer)
			if x_start < x_end:
				_hline(img, ox, x_start, x_end, row, col)
				_set_px(img, ox + x_end, row, COL_WING_SHADOW)


# --- COCKPIT CANOPY: Tandem two-seat (front + rear bumps) ---
# The F-14 has a pilot and RIO in tandem — two canopy bumps separated by a frame line.
static func _draw_canopy(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx

	# --- Front canopy (rows 18-27) ---
	# Frame outline first
	for row in range(18, 28):
		var t := float(row - 18) / 9.0
		var dist := absf(t - 0.45) * 2.0
		var hw := roundi(lerpf(4.0, 1.0, dist * dist))
		_hline(img, ox, cx - hw - 1, cx + hw + 1, row, COL_CANOPY_FRAME)

	# Front canopy glass
	for row in range(19, 27):
		var t := float(row - 19) / 7.0
		var dist := absf(t - 0.4) * 2.0
		var hw := roundi(lerpf(3.5, 1.0, dist * dist))
		_hline(img, ox, cx - hw, cx + hw, row, COL_CANOPY)

	# Specular highlight on front canopy (left side)
	for row in range(20, 24):
		_set_px(img, ox + cx - 1, row, COL_CANOPY_HIGHLIGHT)
		if row >= 21 and row <= 23:
			_set_px(img, ox + cx - 2, row, COL_CANOPY_HIGHLIGHT)

	# --- Gap between canopies (row 27) — fuselage spine visible ---
	_hline(img, ox, cx - 3, cx + 3, 27, COL_FUSE_MID)

	# --- Rear canopy (rows 28-34) — smaller, no specular ---
	for row in range(28, 35):
		var t := float(row - 28) / 6.0
		var dist := absf(t - 0.45) * 2.0
		var hw := roundi(lerpf(3.0, 1.0, dist * dist))
		_hline(img, ox, cx - hw - 1, cx + hw + 1, row, COL_CANOPY_FRAME)

	# Rear canopy glass — slightly darker (in shadow of front canopy)
	var rear_canopy_col := COL_CANOPY.lerp(Color.BLACK, 0.15)
	for row in range(29, 34):
		var t := float(row - 29) / 4.0
		var dist := absf(t - 0.4) * 2.0
		var hw := roundi(lerpf(2.5, 1.0, dist * dist))
		_hline(img, ox, cx - hw, cx + hw, row, rear_canopy_col)


# --- TAIL FINS: Twin vertical stabilizers ---
# Viewed from above, narrow slivers projecting from each nacelle.
static func _draw_tail_fins(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Fins project from nacelles (rows 58-68), angled outward
	var fin_tip_row := 58
	var fin_base_row := 68

	# Left fin — 3px wide band at cx-10 to cx-7
	var left_spread := roundi(10.0 * lw_scale)
	if left_spread >= 3:
		for row in range(fin_tip_row, fin_base_row + 1):
			var t := float(row - fin_tip_row) / float(fin_base_row - fin_tip_row)
			var offset := roundi(lerpf(float(left_spread), 7.0, t))
			var fin_x := cx - offset
			_set_px(img, ox + fin_x, row, COL_FIN)
			_set_px(img, ox + fin_x + 1, row, COL_FIN)
			_set_px(img, ox + fin_x + 2, row, COL_FIN_EDGE)

	# Right fin — mirror
	var right_spread := roundi(10.0 * rw_scale)
	if right_spread >= 3:
		for row in range(fin_tip_row, fin_base_row + 1):
			var t := float(row - fin_tip_row) / float(fin_base_row - fin_tip_row)
			var offset := roundi(lerpf(float(right_spread), 7.0, t))
			var fin_x := cx + offset
			_set_px(img, ox + fin_x, row, COL_FIN)
			_set_px(img, ox + fin_x - 1, row, COL_FIN)
			_set_px(img, ox + fin_x - 2, row, COL_FIN_EDGE)


# --- ENGINE NOZZLES: Twin nozzles at tail of each nacelle ---
static func _draw_nozzles(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx
	var nozzle_row := 80

	# Left nozzle (on left nacelle, centered around cx-5)
	_draw_oval(img, ox, cx - 9, cx - 5, nozzle_row - 2, nozzle_row + 3, COL_NOZZLE_RIM)
	_draw_oval(img, ox, cx - 8, cx - 6, nozzle_row - 1, nozzle_row + 2, COL_NACELLE)
	# Glow center
	_set_px(img, ox + cx - 7, nozzle_row, COL_NOZZLE_GLOW)
	_set_px(img, ox + cx - 7, nozzle_row + 1, COL_NOZZLE_GLOW)

	# Right nozzle (mirror)
	_draw_oval(img, ox, cx + 5, cx + 9, nozzle_row - 2, nozzle_row + 3, COL_NOZZLE_RIM)
	_draw_oval(img, ox, cx + 6, cx + 8, nozzle_row - 1, nozzle_row + 2, COL_NACELLE)
	_set_px(img, ox + cx + 7, nozzle_row, COL_NOZZLE_GLOW)
	_set_px(img, ox + cx + 7, nozzle_row + 1, COL_NOZZLE_GLOW)


# --- AFTERBURNER FLAMES: Twin flames from each nozzle ---
static func _draw_afterburners(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx
	_draw_flame(img, ox, cx - 7, 86)
	_draw_flame(img, ox, cx + 7, 86)


static func _draw_flame(img: Image, ox: int, flame_cx: int, start_row: int) -> void:
	var flame_len := 10
	for row_off in range(flame_len):
		var row := start_row + row_off
		if row >= FRAME_H:
			break
		var t := float(row_off) / float(flame_len - 1)
		var hw := roundi(lerpf(2.5, 0.0, t))
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


# --- DETAIL LINES: Panel lines, sweep crease, structural markings ---
static func _draw_details(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Center spine panel line (nose to tail boom split, skip canopy area rows 18-35)
	for row in range(8, 18):
		_set_px(img, ox + cx, row, COL_PANEL)
	for row in range(36, 68):
		_set_px(img, ox + cx, row, COL_PANEL)

	# Fuselage spine rib lines — horizontal structural markers
	for rib_row in [22, 36, 54, 68]:
		var hw := 6
		if rib_row == 36 or rib_row == 54:
			hw = 9
		_hline(img, ox, cx - hw, cx + hw, rib_row, COL_PANEL)

	# Wing sweep crease — marks the glove/movable-panel joint
	# Vertical line at cx+-22 from row 36 to 54
	var left_crease_x := roundi(22.0 * lw_scale)
	var right_crease_x := roundi(22.0 * rw_scale)

	if left_crease_x >= 5:
		for row in range(36, 55):
			_set_px(img, ox + cx - left_crease_x, row, COL_PANEL)

	if right_crease_x >= 5:
		for row in range(36, 55):
			_set_px(img, ox + cx + right_crease_x, row, COL_PANEL)

	# Intake shadows on fuselage sides (rows 50-62)
	for row in range(50, 62):
		_set_px(img, ox + cx - 8, row, COL_INTAKE)
		_set_px(img, ox + cx + 8, row, COL_INTAKE)


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
