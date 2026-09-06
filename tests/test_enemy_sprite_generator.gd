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
