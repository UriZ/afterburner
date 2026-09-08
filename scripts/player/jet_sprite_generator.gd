class_name JetSpriteGenerator
extends RefCounted

## Generates an 800x96 sprite sheet with 5 top-rear dorsal-view F-14 banking frames.
## View: ~25-30deg elevation above and behind — you see the TOP of the wings,
## cockpit canopy as a dark dome, engines foreshortened at the bottom.
## Banking: one wing foreshortens while the other extends (roll perspective).
## Light source: top-left at ~45 degrees, consistent across all banking frames.

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

# Banking highlight bias: added to inner highlight zone fraction.
# Negative = right wing gets brighter (hard left bank); positive = left wing gets brighter.
const BANK_HIGHLIGHT_BIAS := [-0.10, -0.05, 0.0, 0.05, 0.10]

# --- Palette (3D shading, light from top-left ~45deg) ---

# Fuselage — warm grey-tan, high contrast for sky visibility
const COL_FUSE_HIGHLIGHT := Color(0.960, 0.950, 0.920) # near-white lit edge, top surface
const COL_FUSE_TOP := Color(0.780, 0.765, 0.730)       # brighter main top surface
const COL_FUSE_MID := Color(0.380, 0.370, 0.340)       # side/transition zone
const COL_FUSE_SHADOW := Color(0.120, 0.118, 0.105)    # deep underside shadow
const COL_FUSE_DEEP := Color(0.060, 0.058, 0.050)      # near-black nacelle undersides

# Wings — warm grey-green, NOT blue-grey (must contrast with blue sky)
const COL_WING_HIGHLIGHT := Color(0.820, 0.835, 0.870) # bright lit leading edge
const COL_WING_TOP := Color(0.540, 0.555, 0.490)       # warm grey-green main surface
const COL_WING_MID := Color(0.310, 0.325, 0.280)       # warm grey, no blue
const COL_WING_SHADOW := Color(0.080, 0.085, 0.090)    # very dark shadow edge
const COL_WING_EDGE_BEVEL := Color(0.120, 0.128, 0.135) # dark bevel

# Fixed wing gloves — warm tones, lit/dark split
const COL_GLOVE_LIT := Color(0.510, 0.525, 0.557)      # lit glove surface
const COL_GLOVE_BASE := Color(0.400, 0.416, 0.447)     # base glove
const COL_GLOVE_DARK := Color(0.278, 0.290, 0.318)     # shadow glove edge

# Cockpit canopy — deeper blue glass, brighter highlights
const COL_CANOPY := Color(0.050, 0.300, 0.750)         # deeper blue glass
const COL_CANOPY_SHADOW := Color(0.067, 0.220, 0.412)  # shadow side
const COL_CANOPY_HIGHLIGHT := Color(0.600, 0.820, 0.980) # brighter halo
const COL_CANOPY_SPEC := Color(1.000, 1.000, 1.000)    # pure white specular core
const COL_CANOPY_FRAME := Color(0.165, 0.161, 0.149)   # frame

# Engine nozzles
const COL_NACELLE := Color(0.118, 0.118, 0.125)
const COL_NOZZLE_RIM := Color(0.290, 0.290, 0.314)
const COL_NOZZLE_GLOW := Color(1.000, 0.600, 0.100)    # brighter orange glow

# Afterburner
const COL_FLAME_CORE := Color(1.000, 1.000, 0.500)     # brighter yellow-white
const COL_FLAME_MID := Color(1.000, 0.549, 0.102)
const COL_FLAME_OUTER := Color(0.800, 0.133, 0.000)

# Panel/detail lines — deeper for visibility
const COL_PANEL := Color(0.278, 0.271, 0.251)

# Tail fins — 3-tone per-column
const COL_FIN_TOP := Color(0.400, 0.416, 0.447)   # lit face
const COL_FIN_MID := Color(0.278, 0.294, 0.318)   # shadow face
const COL_FIN_EDGE := Color(0.188, 0.200, 0.220)  # trailing edge bevel

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
	_draw_afterburners(img, ox, shift_x)
	_draw_tail_fins(img, ox, lw_scale, rw_scale, shift_x, frame)
	_draw_wings(img, ox, lw_scale, rw_scale, shift_x, frame)
	_draw_fuselage(img, ox, shift_x, frame)
	_draw_canopy(img, ox, shift_x, frame)
	_draw_nozzles(img, ox, shift_x)
	_draw_details(img, ox, lw_scale, rw_scale, shift_x)


# --- FUSELAGE: Central spine with twin tail boom gap ---
# Cylindrical cross-section lit from top-left: left half brighter, right half darker.
static func _draw_fuselage(img: Image, ox: int, sx: int, frame: int) -> void:
	var cx := CENTER_X + sx
	var bias: float = BANK_HIGHLIGHT_BIAS[frame]

	# Nose cone (rows 4-18) — left/right column shading
	for row in range(4, 10):
		var t := float(row - 4) / 6.0
		var hw := roundi(lerpf(1.0, 4.0, t))
		_draw_fuselage_row_shaded(img, ox, cx, hw, row, bias, false)

	for row in range(10, 18):
		var t := float(row - 10) / 8.0
		var hw := roundi(lerpf(4.0, 7.0, t))
		_draw_fuselage_row_shaded(img, ox, cx, hw, row, bias, false)

	# Forward fuselage (rows 18-36) — same split, plus right edge darkening
	for row in range(18, 36):
		var t := float(row - 18) / 18.0
		var hw := roundi(lerpf(7.0, 10.0, t))
		_draw_fuselage_row_shaded(img, ox, cx, hw, row, bias, true)

	# Mid fuselage (rows 36-54) — 3-zone left/center/right
	for row in range(36, 54):
		var hw := 10
		_draw_fuselage_row_3zone(img, ox, cx, hw, row, bias)

	# Rear fuselage (rows 54-68) — darker overall, left/center/right
	for row in range(54, 68):
		var t := float(row - 54) / 14.0
		var hw := roundi(lerpf(10.0, 7.0, t))
		# Left zone: COL_FUSE_TOP, center: COL_FUSE_MID, right: COL_FUSE_SHADOW
		for x in range(cx - hw, cx + hw + 1):
			var frac := _col_frac(x, cx, hw)
			var col: Color
			if frac < 0.35 + bias * 0.5:
				col = COL_FUSE_TOP
			elif frac < 0.70:
				col = COL_FUSE_MID
			else:
				col = COL_FUSE_SHADOW
			_set_px(img, ox + x, row, col)
		# Nacelle undershadow (rows 62-68)
		if row >= 62:
			for dx in [5, 6, 7]:
				_set_px(img, ox + cx - dx, row, COL_FUSE_SHADOW)
				_set_px(img, ox + cx + dx, row, COL_FUSE_SHADOW)

	# Twin tail boom split (rows 68-80)
	for row in range(68, 80):
		var t := float(row - 68) / 12.0
		var outer_hw := roundi(lerpf(7.0, 7.0, t))
		var gap_hw := 3
		# Left nacelle — lit from left
		for x in range(cx - outer_hw, cx - gap_hw + 1):
			var nacelle_w := float(outer_hw - gap_hw)
			if nacelle_w < 1.0:
				nacelle_w = 1.0
			var nfrac := float(x - (cx - outer_hw)) / nacelle_w
			var col: Color
			if nfrac < 0.5:
				col = COL_FUSE_MID
			else:
				col = COL_FUSE_DEEP  # inner wall
			_set_px(img, ox + x, row, col)
		# Right nacelle — away from light
		for x in range(cx + gap_hw, cx + outer_hw + 1):
			var nacelle_w := float(outer_hw - gap_hw)
			if nacelle_w < 1.0:
				nacelle_w = 1.0
			var nfrac := float(x - (cx + gap_hw)) / nacelle_w
			var col: Color
			if nfrac < 0.3:
				col = COL_FUSE_DEEP  # inner wall
			else:
				col = COL_FUSE_SHADOW  # outer, away from light
			_set_px(img, ox + x, row, col)

	# Center spine highlight — slightly brighter than before
	for row in range(8, 68):
		_set_px(img, ox + cx, row, COL_FUSE_TOP.lerp(Color.WHITE, 0.25))


# Helper: compute fractional position across row (0.0=leftmost, 1.0=rightmost)
static func _col_frac(x: int, cx: int, hw: int) -> float:
	if hw <= 0:
		return 0.5
	return clampf(float(x - (cx - hw)) / float(2 * hw), 0.0, 1.0)


# Nose/forward fuselage: left half highlight, right half base, right edge mid
static func _draw_fuselage_row_shaded(img: Image, ox: int, cx: int, hw: int, row: int, bias: float, edge_darken: bool) -> void:
	if hw <= 0:
		_set_px(img, ox + cx, row, COL_FUSE_HIGHLIGHT)
		return
	var split := cx - maxi(1, hw / 3)  # left highlight boundary
	for x in range(cx - hw, cx + hw + 1):
		var col: Color
		if x <= split:
			col = COL_FUSE_HIGHLIGHT
		elif x == cx:
			col = COL_FUSE_HIGHLIGHT  # centerline ridge
		else:
			col = COL_FUSE_TOP
		_set_px(img, ox + x, row, col)
	# Right edge darkening for forward fuselage
	if edge_darken and hw >= 3:
		_set_px(img, ox + cx + hw, row, COL_FUSE_MID)
		_set_px(img, ox + cx + hw - 1, row, COL_FUSE_MID)


# Mid fuselage: 3-zone left/center/right cylindrical shading
static func _draw_fuselage_row_3zone(img: Image, ox: int, cx: int, hw: int, row: int, bias: float) -> void:
	for x in range(cx - hw, cx + hw + 1):
		var frac := _col_frac(x, cx, hw)
		var col: Color
		# Zones shift with banking bias
		var left_bound := 0.30 + bias * 0.5
		var right_bound := 0.70 + bias * 0.3
		if frac < left_bound:
			col = COL_FUSE_HIGHLIGHT
		elif frac < right_bound:
			col = COL_FUSE_TOP
		else:
			col = COL_FUSE_MID
		_set_px(img, ox + x, row, col)
	# Rightmost pixel always shadow
	_set_px(img, ox + cx + hw, row, COL_FUSE_SHADOW)


# --- WINGS: Fixed gloves + movable panels ---
static func _draw_wings(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int, frame: int) -> void:
	var cx := CENTER_X + sx
	_draw_wing_glove(img, ox, cx, lw_scale, true, frame)
	_draw_wing_glove(img, ox, cx, rw_scale, false, frame)
	_draw_single_wing(img, ox, cx, lw_scale, true, frame)
	_draw_single_wing(img, ox, cx, rw_scale, false, frame)


# --- FIXED WING GLOVES: Trapezoidal root section with lit/dark split and undershadow ---
static func _draw_wing_glove(img: Image, ox: int, cx: int, scale: float, is_left: bool, frame: int) -> void:
	var glove_inner := 10
	var glove_leading := roundi(22.0 * scale)
	var glove_trailing := roundi(18.0 * scale)

	if glove_leading < 4:
		return

	for row in range(36, 55):
		var t := float(row - 36) / 18.0
		var outer := roundi(lerpf(float(glove_leading), float(glove_trailing), t))

		if is_left:
			var x_start := cx - outer
			var x_end := cx - glove_inner
			if x_start < x_end:
				var span := x_end - x_start
				var mid := x_start + span / 2
				for x in range(x_start, x_end + 1):
					var col: Color
					if x < mid:
						col = COL_GLOVE_BASE  # outer half
					else:
						col = COL_GLOVE_LIT   # inner half (near fuselage, lit)
					_set_px(img, ox + x, row, col)
				# Outer edge pixel
				_set_px(img, ox + x_start, row, COL_GLOVE_DARK)
				# Fuselage undershadow: inner 3 pixels
				for dx in range(1, 4):
					var shadow_x := cx - glove_inner - dx
					if shadow_x >= x_start:
						_set_px(img, ox + shadow_x, row, COL_GLOVE_DARK)
		else:
			var x_start := cx + glove_inner
			var x_end := cx + outer
			if x_start < x_end:
				var span := x_end - x_start
				var mid := x_start + span / 2
				for x in range(x_start, x_end + 1):
					var col: Color
					if x < mid:
						col = COL_GLOVE_BASE  # inner half
					else:
						col = COL_GLOVE_DARK  # outer half (away from light)
					_set_px(img, ox + x, row, col)
				# Outer edge pixel
				_set_px(img, ox + x_end, row, COL_GLOVE_DARK)
				# Fuselage undershadow: inner 3 pixels
				for dx in range(0, 3):
					var shadow_x := cx + glove_inner + dx
					if shadow_x <= x_end:
						_set_px(img, ox + shadow_x, row, COL_GLOVE_DARK)


# --- MOVABLE WING PANELS: 4-zone horizontal span gradient ---
static func _draw_single_wing(img: Image, ox: int, cx: int, scale: float, is_left: bool, frame: int) -> void:
	var glove_outer := roundi(22.0 * scale)
	var max_span := roundi(60.0 * scale)
	var bias: float = BANK_HIGHLIGHT_BIAS[frame]

	if max_span < 5:
		return

	for i in range(19):  # rows 36-54
		var row := 36 + i
		var t := float(i) / 18.0
		var outer := roundi(lerpf(float(max_span), float(glove_outer), t))
		var inner := glove_outer

		# Trailing edge shadow for bottom 20% of rows
		var is_trailing := t >= 0.80

		if is_left:
			var x_start := maxi(0, cx - outer)
			var x_end := cx - inner
			if x_start < x_end:
				var span_w := float(x_end - x_start)
				# Leading edge row: all highlight
				if i == 0:
					_hline(img, ox, x_start, x_end, row, COL_WING_HIGHLIGHT)
					_set_px(img, ox + x_start, row, COL_WING_EDGE_BEVEL)
					continue

				for x in range(x_start, x_end + 1):
					# frac: 0.0 = outermost (tip), 1.0 = innermost (root)
					var frac := float(x - x_start) / span_w if span_w > 0.0 else 0.5
					var col: Color
					if is_trailing:
						col = COL_WING_SHADOW
					elif frac < 0.15:
						col = COL_WING_SHADOW   # wingtip zone
					elif frac < 0.40:
						col = COL_WING_MID       # outer wing
					elif frac < 0.75:
						col = COL_WING_TOP       # main surface
					else:
						col = COL_WING_HIGHLIGHT # root zone, lit
					_set_px(img, ox + x, row, col)
				# Wingtip bevel
				_set_px(img, ox + x_start, row, COL_WING_EDGE_BEVEL)
		else:
			var x_start := cx + inner
			var x_end := mini(FRAME_W - 1, cx + outer)
			if x_start < x_end:
				var span_w := float(x_end - x_start)
				# Leading edge row: all highlight
				if i == 0:
					_hline(img, ox, x_start, x_end, row, COL_WING_HIGHLIGHT)
					_set_px(img, ox + x_end, row, COL_WING_EDGE_BEVEL)
					continue

				# Right wing: less lit overall (away from top-left light)
				# Inner zone is COL_WING_TOP (not highlight), then degrades outward
				# With banking bias: negative bias brightens right wing
				var inner_zone: float = 0.25 - bias * 0.5  # bias<0 makes this larger
				inner_zone = clampf(inner_zone, 0.10, 0.45)

				for x in range(x_start, x_end + 1):
					# frac: 0.0 = innermost (root), 1.0 = outermost (tip)
					var frac := float(x - x_start) / span_w if span_w > 0.0 else 0.5
					var col: Color
					if is_trailing:
						col = COL_WING_SHADOW
					elif frac < inner_zone:
						col = COL_WING_TOP       # root zone (no highlight on right)
					elif frac < inner_zone + 0.35:
						col = COL_WING_MID       # middle
					elif frac < 0.85:
						col = COL_WING_SHADOW    # outer
					else:
						col = COL_WING_SHADOW    # wingtip
					_set_px(img, ox + x, row, col)
				# Wingtip bevel
				_set_px(img, ox + x_end, row, COL_WING_EDGE_BEVEL)


# --- COCKPIT CANOPY: Tandem two-seat with specular and shadow ---
static func _draw_canopy(img: Image, ox: int, sx: int, frame: int) -> void:
	var cx := CENTER_X + sx

	# --- Front canopy (rows 18-27) ---
	# Frame outline first
	for row in range(18, 28):
		var t := float(row - 18) / 9.0
		var dist := absf(t - 0.45) * 2.0
		var hw := roundi(lerpf(4.0, 1.0, dist * dist))
		_hline(img, ox, cx - hw - 1, cx + hw + 1, row, COL_CANOPY_FRAME)

	# Front canopy glass with shadow side
	for row in range(19, 27):
		var t := float(row - 19) / 7.0
		var dist := absf(t - 0.4) * 2.0
		var hw := roundi(lerpf(3.5, 1.0, dist * dist))
		for x in range(cx - hw, cx + hw + 1):
			var col: Color
			# Right side and bottom rows get shadow
			if x >= cx + hw or (row >= 25):
				col = COL_CANOPY_SHADOW
			else:
				col = COL_CANOPY
			_set_px(img, ox + x, row, col)

	# Specular: near-white core (3 pixels) + halo
	_set_px(img, ox + cx - 1, 20, COL_CANOPY_SPEC)
	_set_px(img, ox + cx - 1, 21, COL_CANOPY_SPEC)
	_set_px(img, ox + cx - 2, 21, COL_CANOPY_SPEC)
	# Halo surrounding
	_set_px(img, ox + cx - 2, 20, COL_CANOPY_HIGHLIGHT)
	_set_px(img, ox + cx - 1, 22, COL_CANOPY_HIGHLIGHT)
	_set_px(img, ox + cx - 3, 21, COL_CANOPY_HIGHLIGHT)

	# --- Gap between canopies (row 27) ---
	_hline(img, ox, cx - 3, cx + 3, 27, COL_FUSE_MID)

	# --- Rear canopy (rows 28-34) — smaller, no specular ---
	for row in range(28, 35):
		var t := float(row - 28) / 6.0
		var dist := absf(t - 0.45) * 2.0
		var hw := roundi(lerpf(3.0, 1.0, dist * dist))
		_hline(img, ox, cx - hw - 1, cx + hw + 1, row, COL_CANOPY_FRAME)

	# Rear canopy glass — slightly darker with shadow side
	var rear_canopy_col := COL_CANOPY.lerp(Color.BLACK, 0.15)
	for row in range(29, 34):
		var t := float(row - 29) / 4.0
		var dist := absf(t - 0.4) * 2.0
		var hw := roundi(lerpf(2.5, 1.0, dist * dist))
		for x in range(cx - hw, cx + hw + 1):
			var col: Color
			if x >= cx + hw or row >= 33:
				col = COL_CANOPY_SHADOW
			else:
				col = rear_canopy_col
			_set_px(img, ox + x, row, col)


# --- TAIL FINS: Twin vertical stabilizers with 3-tone per-column shading ---
static func _draw_tail_fins(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int, frame: int) -> void:
	var cx := CENTER_X + sx
	var fin_tip_row := 58
	var fin_base_row := 68

	# Left fin — 3px: lit / mid / edge
	var left_spread := roundi(10.0 * lw_scale)
	if left_spread >= 3:
		for row in range(fin_tip_row, fin_base_row + 1):
			var t := float(row - fin_tip_row) / float(fin_base_row - fin_tip_row)
			var offset := roundi(lerpf(float(left_spread), 7.0, t))
			var fin_x := cx - offset
			_set_px(img, ox + fin_x, row, COL_FIN_TOP)
			_set_px(img, ox + fin_x + 1, row, COL_FIN_MID)
			_set_px(img, ox + fin_x + 2, row, COL_FIN_EDGE)

	# Right fin — mirror: edge / mid / lit
	var right_spread := roundi(10.0 * rw_scale)
	if right_spread >= 3:
		for row in range(fin_tip_row, fin_base_row + 1):
			var t := float(row - fin_tip_row) / float(fin_base_row - fin_tip_row)
			var offset := roundi(lerpf(float(right_spread), 7.0, t))
			var fin_x := cx + offset
			_set_px(img, ox + fin_x, row, COL_FIN_TOP)
			_set_px(img, ox + fin_x - 1, row, COL_FIN_MID)
			_set_px(img, ox + fin_x - 2, row, COL_FIN_EDGE)


# --- ENGINE NOZZLES: Twin nozzles at tail of each nacelle ---
static func _draw_nozzles(img: Image, ox: int, sx: int) -> void:
	var cx := CENTER_X + sx
	var nozzle_row := 80

	_draw_oval(img, ox, cx - 9, cx - 5, nozzle_row - 2, nozzle_row + 3, COL_NOZZLE_RIM)
	_draw_oval(img, ox, cx - 8, cx - 6, nozzle_row - 1, nozzle_row + 2, COL_NACELLE)
	_set_px(img, ox + cx - 7, nozzle_row, COL_NOZZLE_GLOW)
	_set_px(img, ox + cx - 7, nozzle_row + 1, COL_NOZZLE_GLOW)

	_draw_oval(img, ox, cx + 5, cx + 9, nozzle_row - 2, nozzle_row + 3, COL_NOZZLE_RIM)
	_draw_oval(img, ox, cx + 6, cx + 8, nozzle_row - 1, nozzle_row + 2, COL_NACELLE)
	_set_px(img, ox + cx + 7, nozzle_row, COL_NOZZLE_GLOW)
	_set_px(img, ox + cx + 7, nozzle_row + 1, COL_NOZZLE_GLOW)


# --- AFTERBURNER FLAMES ---
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
		if row_off > 1 and row_off < flame_len - 1 and row_off % 2 == 0:
			hw = maxi(0, hw - 1)

		for dx in range(-hw, hw + 1):
			var px := ox + flame_cx + dx
			if not _in_bounds(img, px, row):
				continue
			var dist_val := absf(float(dx)) / float(maxi(hw, 1))
			var col: Color
			if dist_val < 0.35:
				col = COL_FLAME_CORE
			elif dist_val < 0.65:
				col = COL_FLAME_MID
			else:
				col = COL_FLAME_OUTER
			img.set_pixel(px, row, col)


# --- DETAIL LINES ---
static func _draw_details(img: Image, ox: int, lw_scale: float, rw_scale: float, sx: int) -> void:
	var cx := CENTER_X + sx

	# Center spine panel line (skip canopy area rows 18-35)
	for row in range(8, 18):
		_set_px(img, ox + cx, row, COL_PANEL)
	for row in range(36, 68):
		_set_px(img, ox + cx, row, COL_PANEL)

	# Fuselage spine rib lines
	for rib_row in [22, 36, 54, 68]:
		var hw := 6
		if rib_row == 36 or rib_row == 54:
			hw = 9
		_hline(img, ox, cx - hw, cx + hw, rib_row, COL_PANEL)

	# Wing sweep crease
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
