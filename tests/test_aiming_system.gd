extends SceneTree

## Unit tests for the targeting system redesign (issue #63).
## Sight follows jet (no independent cursor), brackets at enemy position, all white.
## Run with: godot --headless --script res://tests/test_aiming_system.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Targeting System Tests (Issue #63) ===")

	test_sight_arm_length_tiny()
	test_sight_gap_small()
	test_sight_stroke_thin()
	test_no_sight_center_dot()
	test_sight_follows_jet_not_cursor()
	test_sight_radius_lock_on()
	test_bracket_arm_length()
	test_vulcan_fire_rate()
	test_bullet_speed_and_scale_rate()
	test_missile_turn_speed()
	test_all_white_colors()

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


func test_sight_arm_length_tiny() -> void:
	print("\ntest_sight_arm_length_tiny:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	assert_true(reticle.SIGHT_ARM_LENGTH == 8.0, "Sight arm length is 8px (got %.1f)" % reticle.SIGHT_ARM_LENGTH)


func test_sight_gap_small() -> void:
	print("\ntest_sight_gap_small:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	assert_true(reticle.SIGHT_GAP == 4.0, "Sight gap is 4px (got %.1f)" % reticle.SIGHT_GAP)


func test_sight_stroke_thin() -> void:
	print("\ntest_sight_stroke_thin:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	assert_true(reticle.SIGHT_STROKE == 2.0, "Sight stroke is 2px (got %.1f)" % reticle.SIGHT_STROKE)


func test_no_sight_center_dot() -> void:
	print("\ntest_no_sight_center_dot:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	# Spec: no center dot. Reticle should NOT have SIGHT_CENTER_DOT_RADIUS constant.
	assert_true(not "SIGHT_CENTER_DOT_RADIUS" in reticle, "No center dot constant on reticle")


func test_sight_follows_jet_not_cursor() -> void:
	print("\ntest_sight_follows_jet_not_cursor:")
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	# Spec: sight follows jet. No SIGHT_OFFSET_SCALE for independent cursor movement.
	assert_true(not "SIGHT_OFFSET_SCALE" in wm, "No SIGHT_OFFSET_SCALE (independent cursor removed)")
	# Sight offset is fixed 40px above jet
	assert_true(wm.SIGHT_OFFSET_Y == -40.0, "Sight offset is -40px above jet (got %.1f)" % wm.SIGHT_OFFSET_Y)


func test_sight_radius_lock_on() -> void:
	print("\ntest_sight_radius_lock_on:")
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	assert_true(wm.SIGHT_RADIUS >= 80.0, "Lock radius >= 80px (got %.1f)" % wm.SIGHT_RADIUS)


func test_bracket_arm_length() -> void:
	print("\ntest_bracket_arm_length:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	assert_true(reticle.BRACKET_ARM == 10.0, "Bracket corner arm is 10px (got %.1f)" % reticle.BRACKET_ARM)


func test_vulcan_fire_rate() -> void:
	print("\ntest_vulcan_fire_rate:")
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	var shots_per_sec := 1.0 / wm.VULCAN_FIRE_INTERVAL
	assert_true(shots_per_sec >= 15.0, "Vulcan fires >= 15 shots/sec (got %.1f)" % shots_per_sec)


func test_bullet_speed_and_scale_rate() -> void:
	print("\ntest_bullet_speed_and_scale_rate:")
	var bullet := preload("res://scripts/weapons/vulcan_bullet.gd")
	assert_true(bullet.SPEED >= 80.0, "Bullet speed >= 80 (got %.1f)" % bullet.SPEED)
	var half_scale_dist := 0.5 / bullet.SCALE_RATE * bullet.MAX_DISTANCE
	assert_true(half_scale_dist >= 50.0, "Bullet visible at 50 units (half-scale at %.1f)" % half_scale_dist)


func test_missile_turn_speed() -> void:
	print("\ntest_missile_turn_speed:")
	var missile := preload("res://scripts/weapons/missile.gd")
	assert_true(missile.TURN_SPEED >= 5.0, "Missile TURN_SPEED >= 5.0 (got %.1f)" % missile.TURN_SPEED)
	assert_true(missile.SPEED >= 40.0, "Missile SPEED >= 40 (got %.1f)" % missile.SPEED)


func test_all_white_colors() -> void:
	print("\ntest_all_white_colors:")
	var reticle := preload("res://scripts/ui/reticle.gd")
	assert_true(reticle.COLOR_WHITE == Color.WHITE, "COLOR_WHITE is pure white")
	# Spec: no green/red — only white. Verify no COLOR_NO_LOCK or COLOR_LOCKED exist.
	assert_true(not "COLOR_NO_LOCK" in reticle, "No COLOR_NO_LOCK (all white)")
	assert_true(not "COLOR_LOCKED" in reticle, "No COLOR_LOCKED (all white)")
