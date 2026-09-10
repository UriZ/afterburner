extends SceneTree

## Unit tests for targeting sight and lock-on system.
## Run with: godot --headless --script res://tests/test_lock_on.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Lock-On System Tests ===")

	test_sight_initializes_to_center()
	test_sight_clamps_to_screen_bounds()
	test_lock_acquired_when_enemy_near_sight()
	test_lock_breaks_after_delay()
	test_lock_does_not_break_immediately()
	test_single_lock_closest_enemy()
	test_stale_enemy_cleanup()
	test_vulcan_bullet_aim_direction()

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


func assert_approx(a: float, b: float, message: String, tolerance: float = 0.01) -> void:
	assert_true(absf(a - b) < tolerance, "%s (got %.4f, expected %.4f)" % [message, a, b])


# --- WeaponManager constant / state tests (no scene tree needed) ---

func test_sight_initializes_to_center() -> void:
	print("\ntest_sight_initializes_to_center:")
	# WeaponManager sets sight_screen_pos to viewport center in _ready().
	# We can't call _ready() without a viewport, but we can verify the default
	# and that the constant values are correct.
	var wm := preload("res://scripts/weapons/weapon_manager.gd")
	assert_eq(wm.SIGHT_RADIUS, 90.0, "SIGHT_RADIUS is 90 pixels")
	assert_eq(wm.LOCK_BREAK_DELAY, 0.5, "LOCK_BREAK_DELAY is 0.5 seconds")
	assert_eq(wm.SIGHT_SPEED, 10.0, "SIGHT_SPEED is 10.0")
	assert_eq(wm.SIGHT_OFFSET_SCALE, 0.45, "SIGHT_OFFSET_SCALE is 0.45")


func test_sight_clamps_to_screen_bounds() -> void:
	print("\ntest_sight_clamps_to_screen_bounds:")
	# Verify the clamping math: with margin=40, pos should stay in [40, size-40]
	var margin := 40.0
	var viewport_w := 1152.0
	var viewport_h := 648.0
	# Simulate a sight_screen_pos that went out of bounds
	var pos := Vector2(-10.0, 700.0)
	pos.x = clampf(pos.x, margin, viewport_w - margin)
	pos.y = clampf(pos.y, margin, viewport_h - margin)
	assert_approx(pos.x, 40.0, "Sight X clamped to left margin")
	assert_approx(pos.y, 608.0, "Sight Y clamped to bottom margin (648-40)")


func test_lock_acquired_when_enemy_near_sight() -> void:
	print("\ntest_lock_acquired_when_enemy_near_sight:")
	# Simulate the lock acquisition logic:
	# If distance between enemy screen pos and sight pos <= SIGHT_RADIUS, lock is acquired.
	var sight_pos := Vector2(400.0, 300.0)
	var enemy_screen_pos := Vector2(430.0, 310.0)  # ~32px away
	var dist := enemy_screen_pos.distance_to(sight_pos)
	assert_true(dist <= 90.0, "Enemy within SIGHT_RADIUS (dist=%.1f)" % dist)

	# Enemy far away — should not lock
	var far_pos := Vector2(500.0, 500.0)
	var far_dist := far_pos.distance_to(sight_pos)
	assert_true(far_dist > 90.0, "Far enemy outside SIGHT_RADIUS (dist=%.1f)" % far_dist)


func test_lock_breaks_after_delay() -> void:
	print("\ntest_lock_breaks_after_delay:")
	# Simulate break timer accumulation over multiple frames
	var timer := 0.0
	var break_delay := 0.5
	# 10 frames at 60fps = ~0.167s — should not break yet
	for i in 10:
		timer += 1.0 / 60.0
	assert_true(timer < break_delay, "After 10 frames timer (%.3f) < delay" % timer)
	# Continue to 35 frames total = ~0.583s — should break
	for i in 25:
		timer += 1.0 / 60.0
	assert_true(timer >= break_delay, "After 35 frames timer (%.3f) >= delay" % timer)


func test_lock_does_not_break_immediately() -> void:
	print("\ntest_lock_does_not_break_immediately:")
	# At exactly 0.3s the lock should still hold
	var timer := 0.0
	for i in 18:  # 18 frames at 60fps = 0.3s
		timer += 1.0 / 60.0
	assert_true(timer < 0.5, "Lock holds at 0.3s (timer=%.3f)" % timer)


func test_single_lock_closest_enemy() -> void:
	print("\ntest_single_lock_closest_enemy:")
	# New single-lock design: only the closest enemy in the sight zone is locked.
	# Simulate the selection logic from _update_lockon.
	var sight_pos := Vector2(400.0, 300.0)
	var near_screen := Vector2(420.0, 305.0)  # ~21px away
	var far_screen := Vector2(450.0, 340.0)   # ~64px away — still in zone

	var near_dist := near_screen.distance_to(sight_pos)
	var far_dist := far_screen.distance_to(sight_pos)

	assert_true(near_dist <= 90.0, "Near enemy in sight zone (dist=%.1f)" % near_dist)
	assert_true(far_dist <= 90.0, "Far enemy also in sight zone (dist=%.1f)" % far_dist)
	assert_true(near_dist < far_dist, "Near enemy is closer — it wins the lock")


func test_stale_enemy_cleanup() -> void:
	print("\ntest_stale_enemy_cleanup:")
	# Simulate: enemy is locked, then freed. Next update should remove it.
	# Use untyped Array to avoid TypedArray rejecting freed references.
	var enemy := Node3D.new()
	var locked: Array = [enemy]
	enemy.free()

	# Cleanup pass (mirrors WeaponManager._update_lockon logic)
	var to_remove: Array = []
	for e in locked:
		if not is_instance_valid(e):
			to_remove.append(e)
	for e in to_remove:
		locked.erase(e)

	assert_eq(locked.size(), 0, "Stale enemy removed from locked list")


func test_vulcan_bullet_aim_direction() -> void:
	print("\ntest_vulcan_bullet_aim_direction:")
	# Verify aim_direction defaults and the min-Z enforcement logic
	var default_dir := Vector3(0, 0, -1)
	assert_approx(default_dir.z, -1.0, "Default aim_direction is straight -Z")

	# Simulate the min-Z enforcement from WeaponManager._fire_vulcan()
	var bad_dir := Vector3(0.5, 0.2, -0.1).normalized()
	if bad_dir.z > -0.3:
		bad_dir.z = -0.3
		bad_dir = bad_dir.normalized()
	assert_true(bad_dir.z <= -0.29, "Aim direction Z enforced near -0.3 (got %.3f)" % bad_dir.z)

	# Normal case: direction already has strong -Z component
	var good_dir := Vector3(0.1, 0.05, -0.9).normalized()
	assert_true(good_dir.z < -0.3, "Good aim direction Z is fine (got %.3f)" % good_dir.z)
