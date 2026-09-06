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
