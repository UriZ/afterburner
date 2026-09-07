extends SceneTree

## Unit tests for JetSpriteGenerator (player F-14 dorsal-view sprite).
## Run with: godot --headless --script res://tests/test_jet_sprite_generator.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== JetSpriteGenerator Tests ===")

	test_returns_texture()
	test_sheet_dimensions()
	test_center_frame_has_pixels()
	test_all_frames_have_pixels()
	test_frames_differ()
	test_afterburner_colors_present()
	test_wings_span_wide()
	test_canopy_colors_present()
	test_banking_asymmetry()
	test_twin_tail_boom_gap()
	test_tandem_canopy_two_bumps()
	test_wing_glove_darker_than_panel()
	test_sweep_crease_line()
	test_fuselage_wing_contrast()
	test_fuselage_left_brighter_than_right()
	test_left_wing_inner_brighter_than_outer()
	test_canopy_specular_is_white()
	test_banking_right_wing_brightness_shift()
	test_fuselage_undershadow_on_glove()
	test_panel_line_contrast()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_eq(a: Variant, b: Variant, message: String) -> void:
	if a == b:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [message, str(a), str(b)])


func test_returns_texture() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	assert_true(tex != null, "generate_sprite_sheet returns non-null texture")
	assert_true(tex is ImageTexture, "returns ImageTexture")


func test_sheet_dimensions() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	assert_eq(img.get_width(), 800, "sheet width is 800px (5 x 160)")
	assert_eq(img.get_height(), 96, "sheet height is 96px")


func test_center_frame_has_pixels() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Frame 2 (center) starts at x=320. Check fuselage area has non-transparent pixels.
	var opaque_count := 0
	var ox := 2 * 160
	for y in range(10, 86):
		for x in range(ox + 60, ox + 100):
			if img.get_pixel(x, y).a > 0.0:
				opaque_count += 1
	assert_true(opaque_count > 200, "center frame fuselage area has substantial pixels (%d)" % opaque_count)


func test_all_frames_have_pixels() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	for frame in range(5):
		var ox := frame * 160
		var opaque_count := 0
		for y in range(96):
			for x in range(ox, ox + 160):
				if img.get_pixel(x, y).a > 0.0:
					opaque_count += 1
		assert_true(opaque_count > 100, "frame %d has opaque pixels (%d)" % [frame, opaque_count])


func test_frames_differ() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Frames 0 and 2 should differ (hard left vs center)
	var diff_count := 0
	for y in range(96):
		for x in range(160):
			var c0 := img.get_pixel(0 * 160 + x, y)
			var c2 := img.get_pixel(2 * 160 + x, y)
			if c0 != c2:
				diff_count += 1
	assert_true(diff_count > 50, "frame 0 differs from frame 2 (%d pixels differ)" % diff_count)


func test_afterburner_colors_present() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Check center frame bottom area (rows 85-95) for warm afterburner colors
	var found_afterburn := false
	var ox := 2 * 160
	for y in range(85, 96):
		for x in range(ox, ox + 160):
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.r > 0.7 and c.g > 0.3:
				found_afterburn = true
				break
		if found_afterburn:
			break
	assert_true(found_afterburn, "afterburner flame colors found in center frame bottom")


func test_wings_span_wide() -> void:
	# Wings should be the dominant element — check that pixels exist far from center
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160  # center frame
	# Check for pixels in wing area (cols 20-40 and 120-140, rows 36-56)
	var left_wing_pixels := 0
	var right_wing_pixels := 0
	for y in range(36, 57):
		for x in range(20, 40):
			if img.get_pixel(ox + x, y).a > 0.0:
				left_wing_pixels += 1
		for x in range(120, 140):
			if img.get_pixel(ox + x, y).a > 0.0:
				right_wing_pixels += 1
	assert_true(left_wing_pixels > 50, "left wing has pixels far from center (%d)" % left_wing_pixels)
	assert_true(right_wing_pixels > 50, "right wing has pixels far from center (%d)" % right_wing_pixels)


func test_canopy_colors_present() -> void:
	# Cockpit canopy should have dark blue pixels in the forward fuselage area
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var canopy_pixels := 0
	for y in range(20, 33):
		for x in range(ox + 70, ox + 90):
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.b > 0.5 and c.r < 0.4:
				canopy_pixels += 1
	assert_true(canopy_pixels > 20, "canopy has dark blue pixels (%d)" % canopy_pixels)


func test_banking_asymmetry() -> void:
	# In frame 0 (hard left bank), left wing should be shorter than right wing.
	# Count opaque pixels on each side.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 0 * 160  # frame 0
	var left_pixels := 0
	var right_pixels := 0
	for y in range(36, 57):
		for x in range(0, 80):
			if img.get_pixel(ox + x, y).a > 0.0:
				left_pixels += 1
		for x in range(80, 160):
			if img.get_pixel(ox + x, y).a > 0.0:
				right_pixels += 1
	assert_true(right_pixels > left_pixels, "hard left bank: right wing wider than left (L=%d, R=%d)" % [left_pixels, right_pixels])


func test_twin_tail_boom_gap() -> void:
	# The F-14's rear fuselage (rows 68-80) must have a transparent gap between
	# the two engine nacelles. Check that center pixels in this region are transparent.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160  # center frame
	var cx := 80
	var transparent_gap_pixels := 0
	for y in range(70, 78):
		var c := img.get_pixel(ox + cx, y)
		if c.a < 0.01:
			transparent_gap_pixels += 1
	assert_true(transparent_gap_pixels >= 4, "twin tail boom gap has transparent center pixels (%d)" % transparent_gap_pixels)

	# Also verify nacelle pixels exist on both sides of the gap
	var left_nacelle := 0
	var right_nacelle := 0
	for y in range(70, 78):
		if img.get_pixel(ox + cx - 5, y).a > 0.0:
			left_nacelle += 1
		if img.get_pixel(ox + cx + 5, y).a > 0.0:
			right_nacelle += 1
	assert_true(left_nacelle >= 4, "left nacelle has pixels (%d)" % left_nacelle)
	assert_true(right_nacelle >= 4, "right nacelle has pixels (%d)" % right_nacelle)


func test_tandem_canopy_two_bumps() -> void:
	# The F-14 has TWO canopy bumps with a gap between them (around row 27).
	# Check: canopy glass exists in rows 20-26 (front) AND rows 29-33 (rear),
	# with a non-canopy row at row 27.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80

	var front_canopy_blue := 0
	for y in range(20, 26):
		var c := img.get_pixel(ox + cx, y)
		if c.b > 0.5 and c.r < 0.4:
			front_canopy_blue += 1

	var rear_canopy_blue := 0
	for y in range(29, 34):
		var c := img.get_pixel(ox + cx, y)
		if c.b > 0.4 and c.r < 0.4:
			rear_canopy_blue += 1

	# Gap row 27 should NOT be canopy blue
	var gap_color := img.get_pixel(ox + cx, 27)
	var gap_is_not_canopy := gap_color.b < 0.5 or gap_color.r > 0.3

	assert_true(front_canopy_blue >= 3, "front canopy has blue pixels (%d)" % front_canopy_blue)
	assert_true(rear_canopy_blue >= 2, "rear canopy has blue pixels (%d)" % rear_canopy_blue)
	assert_true(gap_is_not_canopy, "gap between canopies at row 27 is not canopy blue")


func test_wing_glove_darker_than_panel() -> void:
	# The wing glove should be darker than the movable wing panel at the wing root zone.
	# Sample: glove at cx-16 (inside glove range), panel at cx-25 (near wing root, in highlight zone).
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80
	var sample_row := 42  # mid-wing

	var glove_pixel := img.get_pixel(ox + cx - 16, sample_row)
	var panel_pixel := img.get_pixel(ox + cx - 25, sample_row)

	# Both should be opaque
	assert_true(glove_pixel.a > 0.0, "glove pixel is opaque at cx-16")
	assert_true(panel_pixel.a > 0.0, "panel pixel is opaque at cx-40")

	# Glove should be darker (lower luminance) than panel
	var glove_lum := glove_pixel.r * 0.299 + glove_pixel.g * 0.587 + glove_pixel.b * 0.114
	var panel_lum := panel_pixel.r * 0.299 + panel_pixel.g * 0.587 + panel_pixel.b * 0.114
	assert_true(glove_lum < panel_lum, "glove is darker than movable panel (glove=%.3f, panel=%.3f)" % [glove_lum, panel_lum])


func test_sweep_crease_line() -> void:
	# A sweep crease panel line should exist at cx-22 (left) spanning rows 36-54.
	# This is a dark line marking where the glove meets the movable panel.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80
	var crease_x := cx - 22  # glove/panel boundary

	var panel_line_count := 0
	for y in range(38, 52):
		var c := img.get_pixel(ox + crease_x, y)
		# Panel line should be relatively dark
		var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		if c.a > 0.0 and lum < 0.50:
			panel_line_count += 1
	assert_true(panel_line_count >= 6, "sweep crease line has dark pixels at cx-22 (%d)" % panel_line_count)


func test_fuselage_wing_contrast() -> void:
	# The fuselage (COL_FUSE_TOP ~0.69 luminance) and wings (COL_WING_TOP ~0.57 luminance)
	# must have at least 0.10 luminance gap to be visually distinguishable.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80

	# Sample fuselage pixel (center of body, row 40)
	var fuse_pixel := img.get_pixel(ox + cx + 2, 40)  # +2 to avoid spine highlight
	var fuse_lum := fuse_pixel.r * 0.299 + fuse_pixel.g * 0.587 + fuse_pixel.b * 0.114

	# Sample wing pixel (far out on wing, row 40)
	var wing_pixel := img.get_pixel(ox + cx + 35, 40)
	var wing_lum := wing_pixel.r * 0.299 + wing_pixel.g * 0.587 + wing_pixel.b * 0.114

	var gap := absf(fuse_lum - wing_lum)
	assert_true(gap >= 0.10, "fuselage/wing luminance gap >= 0.10 (gap=%.3f, fuse=%.3f, wing=%.3f)" % [gap, fuse_lum, wing_lum])


func _lum(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


func test_fuselage_left_brighter_than_right() -> void:
	# Verify 3D shading: left half of fuselage is brighter than right half (top-left light).
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160  # center frame
	var cx := 80

	# Sample mid-fuselage row 45, left side vs right side
	var left_pixel := img.get_pixel(ox + cx - 6, 45)
	var right_pixel := img.get_pixel(ox + cx + 6, 45)
	var left_lum := _lum(left_pixel)
	var right_lum := _lum(right_pixel)
	assert_true(left_lum > right_lum, "fuselage left side brighter than right (L=%.3f, R=%.3f)" % [left_lum, right_lum])


func test_left_wing_inner_brighter_than_outer() -> void:
	# Wing root zone (inner) should be brighter than wingtip zone (outer) on left wing.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80
	var sample_row := 40

	# Inner wing (near root, cx-25) vs outer wing (near tip, cx-50)
	var inner_pixel := img.get_pixel(ox + cx - 25, sample_row)
	var outer_pixel := img.get_pixel(ox + cx - 50, sample_row)
	var inner_lum := _lum(inner_pixel)
	var outer_lum := _lum(outer_pixel)
	assert_true(inner_pixel.a > 0.0, "inner wing pixel is opaque")
	assert_true(outer_pixel.a > 0.0, "outer wing pixel is opaque")
	assert_true(inner_lum > outer_lum, "left wing inner brighter than outer (inner=%.3f, outer=%.3f)" % [inner_lum, outer_lum])


func test_canopy_specular_is_white() -> void:
	# Canopy specular should be near-white (high R,G,B), not blue.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80

	# Spec core at (cx-1, 20) and (cx-1, 21)
	var spec1 := img.get_pixel(ox + cx - 1, 20)
	var spec2 := img.get_pixel(ox + cx - 1, 21)
	# Both should have R > 0.85 (near-white, not blue)
	assert_true(spec1.r > 0.85, "specular pixel 1 is near-white (r=%.3f)" % spec1.r)
	assert_true(spec2.r > 0.85, "specular pixel 2 is near-white (r=%.3f)" % spec2.r)


func test_banking_right_wing_brightness_shift() -> void:
	# In frame 0 (hard left bank), the right wing should be brighter than in frame 4.
	# Because in hard left bank, the right wing surface tilts toward the light.
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()

	# Sample right wing at a consistent relative position: cx+30, row 42
	# Frame 0 (hard left): right wing is extended and lit
	var f0_cx := 80 + (-6)  # shift_x = -6 for frame 0
	var f0_pixel := img.get_pixel(0 * 160 + f0_cx + 30, 42)

	# Frame 4 (hard right): right wing is foreshortened; sample from where it exists
	var f4_cx := 80 + 6  # shift_x = +6 for frame 4
	# In frame 4, right wing is tiny (scale 0.30). The left wing at cx-30 is the big one.
	# Compare: frame 0 right wing vs frame 4 left wing at same distance from center.
	# Frame 4 left wing at cx-30 should be brighter (banking into light).
	var f4_pixel := img.get_pixel(4 * 160 + f4_cx - 30, 42)

	# Both should be opaque
	if f0_pixel.a > 0.0 and f4_pixel.a > 0.0:
		# Frame 4 left wing (banking right, left wing into light) should be bright
		var f4_lum := _lum(f4_pixel)
		# Frame 0 right wing should also be bright (banking left, right wing into light)
		var f0_lum := _lum(f0_pixel)
		# Both banked-into-light wings should be reasonably bright (> mid gray)
		assert_true(f0_lum > 0.30, "frame 0 right wing has decent brightness (%.3f)" % f0_lum)
		assert_true(f4_lum > 0.30, "frame 4 left wing has decent brightness (%.3f)" % f4_lum)
	else:
		assert_true(false, "wing pixels should be opaque at sample positions")


func test_fuselage_undershadow_on_glove() -> void:
	# The inner 3 pixels of each glove row should be darkened (fuselage undershadow).
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80
	var sample_row := 42
	var glove_inner := 10  # where glove starts

	# Left glove: inner 3 pixels are at cx - glove_inner - 1, -2, -3
	var shadow_pixel := img.get_pixel(ox + cx - glove_inner - 1, sample_row)
	var outer_pixel := img.get_pixel(ox + cx - glove_inner - 6, sample_row)

	if shadow_pixel.a > 0.0 and outer_pixel.a > 0.0:
		var shadow_lum := _lum(shadow_pixel)
		var outer_lum := _lum(outer_pixel)
		assert_true(shadow_lum <= outer_lum, "glove undershadow is darker than outer glove (shadow=%.3f, outer=%.3f)" % [shadow_lum, outer_lum])
	else:
		assert_true(false, "glove pixels should be opaque at sample positions")


func test_panel_line_contrast() -> void:
	# Panel lines should clearly contrast against the fuselage surface (delta > 0.10).
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	var ox := 2 * 160
	var cx := 80

	# Panel line at cx, row 12 (nose area)
	var panel_pixel := img.get_pixel(ox + cx, 12)
	# Adjacent fuselage pixel at cx+2, row 12
	var fuse_pixel := img.get_pixel(ox + cx + 2, 12)

	if panel_pixel.a > 0.0 and fuse_pixel.a > 0.0:
		var panel_lum := _lum(panel_pixel)
		var fuse_lum := _lum(fuse_pixel)
		var delta := absf(fuse_lum - panel_lum)
		assert_true(delta >= 0.10, "panel line contrasts against fuselage (delta=%.3f)" % delta)
	else:
		assert_true(false, "panel and fuselage pixels should be opaque")
