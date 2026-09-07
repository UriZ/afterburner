extends SceneTree

## Unit tests for EnemySpriteGenerator.
## Run with: godot --headless --script res://tests/test_enemy_sprite_generator.gd

const _SpriteGen := preload("res://scripts/enemies/enemy_sprite_generator.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== EnemySpriteGenerator Tests ===")

	test_generate_fighter_texture()
	test_generate_interceptor_texture()
	test_generate_bomber_texture()
	test_bomber_is_larger()
	test_textures_are_different()
	test_fighter_wings_are_filled()
	test_interceptor_wings_are_filled()
	test_bomber_wings_are_filled()
	test_fighter_fuselage_shading()
	test_interceptor_fuselage_shading()
	test_bomber_fuselage_shading()
	test_fighter_canopy_specular()
	test_bomber_spine_shifted_left()
	test_wing_zone_shading()

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
	assert_true(a == b, "%s (got %s, expected %s)" % [message, str(a), str(b)])


func test_generate_fighter_texture() -> void:
	print("\ntest_generate_fighter_texture:")
	var tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.FIGHTER
	)
	assert_true(tex != null, "Fighter texture is not null")
	assert_eq(tex.get_width(), 48, "Fighter width is 48")
	assert_eq(tex.get_height(), 48, "Fighter height is 48")


func test_generate_interceptor_texture() -> void:
	print("\ntest_generate_interceptor_texture:")
	var tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.INTERCEPTOR
	)
	assert_true(tex != null, "Interceptor texture is not null")
	assert_eq(tex.get_width(), 48, "Interceptor width is 48")
	assert_eq(tex.get_height(), 48, "Interceptor height is 48")


func test_generate_bomber_texture() -> void:
	print("\ntest_generate_bomber_texture:")
	var tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.BOMBER
	)
	assert_true(tex != null, "Bomber texture is not null")
	assert_eq(tex.get_width(), 64, "Bomber width is 64")
	assert_eq(tex.get_height(), 64, "Bomber height is 64")


func test_bomber_is_larger() -> void:
	print("\ntest_bomber_is_larger:")
	var fighter_tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.FIGHTER
	)
	var bomber_tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.BOMBER
	)
	assert_true(
		bomber_tex.get_width() > fighter_tex.get_width(),
		"Bomber is wider than fighter"
	)


func test_textures_are_different() -> void:
	print("\ntest_textures_are_different:")
	var fighter := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.FIGHTER
	)
	var interceptor := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.INTERCEPTOR
	)
	# Compare pixel data - they should produce different images
	var f_img := fighter.get_image()
	var i_img := interceptor.get_image()
	var different := false
	for y in range(mini(f_img.get_height(), i_img.get_height())):
		for x in range(mini(f_img.get_width(), i_img.get_width())):
			if f_img.get_pixel(x, y) != i_img.get_pixel(x, y):
				different = true
				break
		if different:
			break
	assert_true(different, "Fighter and interceptor textures differ")


## Count non-transparent pixels in a rectangular region of an image.
func _count_opaque_pixels(img: Image, x0: int, y0: int, x1: int, y1: int) -> int:
	var count := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				if img.get_pixel(x, y).a > 0.0:
					count += 1
	return count


func test_fighter_wings_are_filled() -> void:
	print("\ntest_fighter_wings_are_filled:")
	var tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.FIGHTER
	)
	var img := tex.get_image()
	# Left wing area: cols 2-18, rows 10-36 — should have substantial fill
	var left_opaque := _count_opaque_pixels(img, 2, 10, 18, 36)
	# Area is 17*27 = 459 pixels. A filled triangle should cover ~50% = ~230 pixels.
	# Old broken code produced ~25 pixels (a thin diagonal line).
	assert_true(left_opaque > 100,
		"Fighter left wing has filled surface (%d opaque pixels, need >100)" % left_opaque)
	# Right wing area: cols 29-46, rows 10-36
	var right_opaque := _count_opaque_pixels(img, 29, 10, 46, 36)
	assert_true(right_opaque > 100,
		"Fighter right wing has filled surface (%d opaque pixels, need >100)" % right_opaque)


func test_interceptor_wings_are_filled() -> void:
	print("\ntest_interceptor_wings_are_filled:")
	var tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.INTERCEPTOR
	)
	var img := tex.get_image()
	# Left wing area: cols 5-19, rows 12-34
	var left_opaque := _count_opaque_pixels(img, 5, 12, 19, 34)
	assert_true(left_opaque > 60,
		"Interceptor left wing has filled surface (%d opaque pixels, need >60)" % left_opaque)
	# Right wing area: cols 28-43, rows 12-34
	var right_opaque := _count_opaque_pixels(img, 28, 12, 43, 34)
	assert_true(right_opaque > 60,
		"Interceptor right wing has filled surface (%d opaque pixels, need >60)" % right_opaque)


func test_bomber_wings_are_filled() -> void:
	print("\ntest_bomber_wings_are_filled:")
	var tex := EnemySpriteGenerator.generate_texture(
		EnemySpriteGenerator.EnemyVisual.BOMBER
	)
	var img := tex.get_image()
	# Left wing area: cols 2-23, rows 16-40
	var left_opaque := _count_opaque_pixels(img, 2, 16, 23, 40)
	assert_true(left_opaque > 150,
		"Bomber left wing has filled surface (%d opaque pixels, need >150)" % left_opaque)
	# Right wing area: cols 40-62, rows 16-40
	var right_opaque := _count_opaque_pixels(img, 40, 16, 62, 40)
	assert_true(right_opaque > 150,
		"Bomber right wing has filled surface (%d opaque pixels, need >150)" % right_opaque)


## Compute average brightness of opaque pixels in a rectangular region.
func _avg_brightness(img: Image, x0: int, y0: int, x1: int, y1: int) -> float:
	var total := 0.0
	var count := 0
	for y in range(maxi(0, y0), mini(img.get_height(), y1 + 1)):
		for x in range(maxi(0, x0), mini(img.get_width(), x1 + 1)):
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				total += (c.r + c.g + c.b) / 3.0
				count += 1
	return total / maxf(1.0, float(count))


func test_fighter_fuselage_shading() -> void:
	print("\ntest_fighter_fuselage_shading:")
	var tex := EnemySpriteGenerator.generate_texture(EnemySpriteGenerator.EnemyVisual.FIGHTER)
	var img := tex.get_image()
	# Fuselage rows 8-20: left cols 19-22 should be brighter than right cols 25-28
	var left_bright := _avg_brightness(img, 19, 8, 22, 20)
	var right_bright := _avg_brightness(img, 25, 8, 28, 20)
	assert_true(left_bright > right_bright,
		"Fighter fuselage left brighter than right (%.3f > %.3f)" % [left_bright, right_bright])


func test_interceptor_fuselage_shading() -> void:
	print("\ntest_interceptor_fuselage_shading:")
	var tex := EnemySpriteGenerator.generate_texture(EnemySpriteGenerator.EnemyVisual.INTERCEPTOR)
	var img := tex.get_image()
	# Fuselage rows 11-34: left cols 20-22 should be brighter than right cols 25-27
	var left_bright := _avg_brightness(img, 20, 11, 22, 34)
	var right_bright := _avg_brightness(img, 25, 11, 27, 34)
	assert_true(left_bright > right_bright,
		"Interceptor fuselage left brighter than right (%.3f > %.3f)" % [left_bright, right_bright])


func test_bomber_fuselage_shading() -> void:
	print("\ntest_bomber_fuselage_shading:")
	var tex := EnemySpriteGenerator.generate_texture(EnemySpriteGenerator.EnemyVisual.BOMBER)
	var img := tex.get_image()
	# Wide fuselage rows 13-48: left cols 24-29 should be brighter than right cols 34-39
	var left_bright := _avg_brightness(img, 24, 13, 29, 48)
	var right_bright := _avg_brightness(img, 34, 13, 39, 48)
	assert_true(left_bright > right_bright,
		"Bomber fuselage left brighter than right (%.3f > %.3f)" % [left_bright, right_bright])


func test_fighter_canopy_specular() -> void:
	print("\ntest_fighter_canopy_specular:")
	var tex := EnemySpriteGenerator.generate_texture(EnemySpriteGenerator.EnemyVisual.FIGHTER)
	var img := tex.get_image()
	# Specular pixel at (22, 8) should be near-white (brightness > 0.9)
	var c := img.get_pixel(22, 8)
	var bright := (c.r + c.g + c.b) / 3.0
	assert_true(bright > 0.9,
		"Fighter canopy specular is near-white (brightness=%.3f)" % bright)


func test_bomber_spine_shifted_left() -> void:
	print("\ntest_bomber_spine_shifted_left:")
	var tex := EnemySpriteGenerator.generate_texture(EnemySpriteGenerator.EnemyVisual.BOMBER)
	var img := tex.get_image()
	# Spine highlight should be at cols 28-29 (shifted left from old 31-32)
	# Sample at row 20 to avoid belly stripe overlap at rows 28-30
	var c28 := img.get_pixel(28, 20)
	var c31 := img.get_pixel(31, 20)
	var bright_28 := (c28.r + c28.g + c28.b) / 3.0
	var bright_31 := (c31.r + c31.g + c31.b) / 3.0
	assert_true(bright_28 > bright_31,
		"Bomber spine at col 28 brighter than col 31 (%.3f > %.3f)" % [bright_28, bright_31])


func test_wing_zone_shading() -> void:
	print("\ntest_wing_zone_shading:")
	var tex := EnemySpriteGenerator.generate_texture(EnemySpriteGenerator.EnemyVisual.FIGHTER)
	var img := tex.get_image()
	# Left wing at row 20 (mid-wing): inner pixels (near fuselage, ~col 16-18) should
	# be brighter than outer pixels (~col 5-8)
	var inner_bright := _avg_brightness(img, 15, 20, 18, 20)
	var outer_bright := _avg_brightness(img, 4, 20, 8, 20)
	assert_true(inner_bright > outer_bright,
		"Fighter left wing inner brighter than outer (%.3f > %.3f)" % [inner_bright, outer_bright])
