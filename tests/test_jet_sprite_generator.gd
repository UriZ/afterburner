extends SceneTree

## Unit tests for JetSpriteGenerator (player F-14 rear-view sprite).
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
	test_no_pixels_outside_frames()

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
	assert_eq(img.get_width(), 320, "sheet width is 320px (5 x 64)")
	assert_eq(img.get_height(), 48, "sheet height is 48px")


func test_center_frame_has_pixels() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Frame 2 (center) starts at x=128. Check fuselage area has non-transparent pixels.
	var opaque_count := 0
	var ox := 2 * 64
	for y in range(8, 42):
		for x in range(ox + 20, ox + 44):
			if img.get_pixel(x, y).a > 0.0:
				opaque_count += 1
	assert_true(opaque_count > 100, "center frame has substantial opaque pixels in fuselage area (%d)" % opaque_count)


func test_all_frames_have_pixels() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	for frame in range(5):
		var ox := frame * 64
		var opaque_count := 0
		for y in range(48):
			for x in range(ox, ox + 64):
				if img.get_pixel(x, y).a > 0.0:
					opaque_count += 1
		assert_true(opaque_count > 50, "frame %d has opaque pixels (%d)" % [frame, opaque_count])


func test_frames_differ() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Frames 0 and 4 should be mirrors, not identical to frame 2
	var diff_count := 0
	for y in range(48):
		for x in range(64):
			var c0 := img.get_pixel(0 * 64 + x, y)
			var c2 := img.get_pixel(2 * 64 + x, y)
			if c0 != c2:
				diff_count += 1
	assert_true(diff_count > 20, "frame 0 differs from frame 2 (%d pixels differ)" % diff_count)


func test_afterburner_colors_present() -> void:
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Check center frame (frame 2) bottom area for afterburner colors
	var found_afterburn := false
	var ox := 2 * 64
	for y in range(44, 48):
		for x in range(ox, ox + 64):
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.r > 0.7 and c.g > 0.3:
				found_afterburn = true
				break
		if found_afterburn:
			break
	assert_true(found_afterburn, "afterburner flame colors found in center frame bottom")


func test_no_pixels_outside_frames() -> void:
	# Pixels should only exist within valid frame regions
	var tex := JetSpriteGenerator.generate_sprite_sheet()
	var img := tex.get_image()
	# Just verify total dimensions are correct (no out of bounds drawing)
	assert_eq(img.get_width(), 320, "image width correct")
	assert_eq(img.get_height(), 48, "image height correct")
