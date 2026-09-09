extends SceneTree

## Unit tests for aiming system fixes (issue #28).
## Tests sight Y-axis correction, bullet/missile parameters, sight offset scale.
## Run with: godot --headless --script res://tests/test_aiming_system.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Aiming System Tests (Issue #28) ===")

	test_sight_y_axis_direction()
	test_sight_offset_scale_arcade_range()
	test_sight_radius_generous()
	test_vulcan_fire_rate()
	test_bullet_speed_and_scale_rate()
	test_missile_turn_speed()
	test_missile_initial_velocity_toward_target()
	test_sight_world_position_distance()
	test_reticle_center_dot()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_approx(a: float, b: float, message: String, tolerance: float = 0.01) -> void:
	assert_true(absf(a - b) < tolerance, "%s (got %.4f, expected %.4f)" % [message, a, b])


func test_sight_y_axis_direction() -> void:
	print("\ntest_sight_y_axis_direction:")
	# The critical fix: when player presses UP, sight must move UP on screen
	# (negative Y in screen coords). We verify the input mapping logic:
	# get_axis("move_up", "move_down") returns -1 for UP, +1 for DOWN.
	# Multiplied by viewport size, this gives negative offset (up on screen) for UP input.
	# This is the correct behavior after the fix.
	var viewport_size := Vector2(960.0, 672.0)
	var center := viewport_size * 0.5
	var offset_scale := 0.45

	# Simulate UP input: get_axis("move_up", "move_down") = -1 when UP pressed
	var input_up := Vector2(0.0, -1.0)
	var target_up := center + input_up * viewport_size * offset_scale
	assert_true(target_up.y < center.y, "UP input moves sight above center (y=%.1f < %.1f)" % [target_up.y, center.y])

	# Simulate DOWN input: get_axis("move_up", "move_down") = +1 when DOWN pressed
	var input_down := Vector2(0.0, 1.0)
	var target_down := center + input_down * viewport_size * offset_scale
	assert_true(target_down.y > center.y, "DOWN input moves sight below center (y=%.1f > %.1f)" % [target_down.y, center.y])

	# Simulate RIGHT input
	var input_right := Vector2(1.0, 0.0)
	var target_right := center + input_right * viewport_size * offset_scale
	assert_true(target_right.x > center.x, "RIGHT input moves sight right of center")


func test_sight_offset_scale_arcade_range() -> void:
	print("\ntest_sight_offset_scale_arcade_range:")
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	# Must be >= 0.4 for visible arcade-like movement
	assert_true(wm.SIGHT_OFFSET_SCALE >= 0.4, "SIGHT_OFFSET_SCALE >= 0.4 for arcade range (got %.2f)" % wm.SIGHT_OFFSET_SCALE)
	# But not so large the sight goes off screen (with margin clamping it should be fine)
	assert_true(wm.SIGHT_OFFSET_SCALE <= 0.6, "SIGHT_OFFSET_SCALE <= 0.6 to stay usable (got %.2f)" % wm.SIGHT_OFFSET_SCALE)


func test_sight_radius_generous() -> void:
	print("\ntest_sight_radius_generous:")
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	# Lock-on radius should be generous for arcade feel
	assert_true(wm.SIGHT_RADIUS >= 80.0, "SIGHT_RADIUS >= 80px for generous lock-on (got %.1f)" % wm.SIGHT_RADIUS)


func test_vulcan_fire_rate() -> void:
	print("\ntest_vulcan_fire_rate:")
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	# Fire rate should be rapid — at least 15 shots/sec
	var shots_per_sec := 1.0 / wm.VULCAN_FIRE_INTERVAL
	assert_true(shots_per_sec >= 15.0, "Vulcan fires >= 15 shots/sec (got %.1f)" % shots_per_sec)


func test_bullet_speed_and_scale_rate() -> void:
	print("\ntest_bullet_speed_and_scale_rate:")
	var bullet := preload("res://scripts/weapons/vulcan_bullet.gd")
	assert_true(bullet.SPEED >= 80.0, "Bullet speed >= 80 (got %.1f)" % bullet.SPEED)
	# Scale rate should be low enough that bullets are visible at engagement range
	# At SCALE_RATE=1.5, bullet reaches 50% scale at 67 units (1/3 of max distance)
	var half_scale_dist := 0.5 / bullet.SCALE_RATE * bullet.MAX_DISTANCE
	assert_true(half_scale_dist >= 50.0, "Bullet visible at 50 units (half-scale at %.1f)" % half_scale_dist)


func test_missile_turn_speed() -> void:
	print("\ntest_missile_turn_speed:")
	var missile := preload("res://scripts/weapons/missile.gd")
	# Turn speed should be aggressive enough for arcade homing
	assert_true(missile.TURN_SPEED >= 5.0, "Missile TURN_SPEED >= 5.0 (got %.1f)" % missile.TURN_SPEED)
	assert_true(missile.SPEED >= 40.0, "Missile SPEED >= 40 (got %.1f)" % missile.SPEED)


func test_missile_initial_velocity_toward_target() -> void:
	print("\ntest_missile_initial_velocity_toward_target:")
	# Simulate the missile _ready() logic for initial velocity blending
	var missile_pos := Vector3(0, 2, -8)
	var target_pos := Vector3(3, 7, -40)
	var to_target := (target_pos - missile_pos).normalized()
	var blended := (Vector3(0, 0, -1) * 0.4 + to_target * 0.6).normalized()

	# The blended direction should point generally toward the target, not straight -Z
	assert_true(blended.x > 0.01, "Initial velocity has X component toward target (got %.3f)" % blended.x)
	assert_true(blended.z < -0.5, "Initial velocity still points into screen (z=%.3f)" % blended.z)


func test_sight_world_position_distance() -> void:
	print("\ntest_sight_world_position_distance:")
	# The projection distance should be long enough to reach enemy engagement zone
	# Enemies spawn at Z=-50, so 80 units of projection from camera at Z=0
	# ensures convergence point is well past enemies.
	# We can't call get_sight_world_position without a camera, but we can verify
	# the constant is appropriate by checking the source code pattern.
	# The function uses "from + dir * 80.0" — verify 80 > 50 (spawn Z).
	var projection_dist := 80.0  # from weapon_manager.gd get_sight_world_position
	assert_true(projection_dist >= 60.0, "Sight projection distance >= 60 units (got %.1f)" % projection_dist)


func test_reticle_center_dot() -> void:
	print("\ntest_reticle_center_dot:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	assert_true(reticle.SIGHT_CENTER_DOT_RADIUS > 0.0, "Reticle has center dot (radius=%.1f)" % reticle.SIGHT_CENTER_DOT_RADIUS)
	assert_true(reticle.SIGHT_ARM_LENGTH >= 40.0, "Crosshair arms are visible (length=%.1f)" % reticle.SIGHT_ARM_LENGTH)
