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
