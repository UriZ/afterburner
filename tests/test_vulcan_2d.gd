extends SceneTree

## Unit tests for vulcan_bullet_2d.gd, weapon_manager_2d.gd, reticle_2d.gd
## Run with: godot --headless --script res://tests/test_vulcan_2d.gd

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("=== VulcanBullet2D / WeaponManager2D / Reticle2D Tests ===")

	test_bullet_initial_state()
	test_bullet_screen_position()
	test_bullet_collision_radius_scales()
	test_bullet_min_depth()
	test_bullet_altitude_ramps_toward_aim_and_lifts_above_horizon()
	test_weapon_manager_constants()
	test_reticle_blink_defaults()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_approx(a: float, b: float, message: String, tol: float = 0.01) -> void:
	assert_true(absf(a - b) < tol, message)


func _make_bullet() -> Node2D:
	var script: GDScript = load("res://scripts/weapons/vulcan_bullet_2d.gd")
	var b := Node2D.new()
	b.set_script(script)
	get_root().add_child(b)
	return b


func test_bullet_initial_state() -> void:
	print("\ntest_bullet_initial_state:")
	var b := _make_bullet()
	assert_true(b.logical_depth == 0.9, "bullet starts at depth 0.9")
	assert_true(b.logical_x == 0.0, "bullet starts at center x")
	assert_true(b.aim_x == 0.0, "aim_x defaults to 0")
	assert_true(b.BULLET_SPEED == 3.5, "bullet speed 3.5 depth units/sec")
	b.queue_free()


func test_bullet_screen_position() -> void:
	print("\ntest_bullet_screen_position:")
	var b := _make_bullet()

	# At logical x=0, depth=0.9, should map to screen center x ~480
	b.logical_x = 0.0
	b.logical_depth = 0.9
	var pos: Vector2 = b.get_screen_position()
	assert_approx(pos.x, 480.0, "center x at logical 0.0", 5.0)
	assert_true(pos.y > _DepthUtil.HORIZON_Y, "bullet below horizon at depth 0.9")

	# At depth=0.0 should be at horizon y
	b.logical_depth = 0.0
	var horizon_pos: Vector2 = b.get_screen_position()
	assert_approx(horizon_pos.y, _DepthUtil.HORIZON_Y, "depth=0 maps to horizon y", 2.0)

	# Lateral offset: positive x should be right of center
	b.logical_depth = 0.5
	b.logical_x = 0.5
	var right_pos: Vector2 = b.get_screen_position()
	assert_true(right_pos.x > 480.0, "positive logical_x is right of center")
	b.queue_free()


func test_bullet_collision_radius_scales() -> void:
	print("\ntest_bullet_collision_radius_scales:")
	var b := _make_bullet()
	b.logical_depth = 0.9
	var r_near: float = b.get_collision_radius()
	b.logical_depth = 0.3
	var r_far: float = b.get_collision_radius()
	assert_true(r_near > r_far, "closer bullet (d=0.9) has larger collision radius than far (d=0.3)")
	assert_true(r_far > 0.0, "collision radius always positive")
	b.queue_free()


func test_bullet_min_depth() -> void:
	print("\ntest_bullet_min_depth:")
	var b := _make_bullet()
	assert_true(b.MIN_DEPTH == 0.05, "bullets despawn at MIN_DEPTH 0.05")
	assert_true(b.MIN_DEPTH < b.logical_depth, "MIN_DEPTH < starting depth")
	b.queue_free()


func test_bullet_altitude_ramps_toward_aim_and_lifts_above_horizon() -> void:
	print("\ntest_bullet_altitude_ramps_toward_aim_and_lifts_above_horizon:")
	# Vulcan has no locked target, so it can't home in Y like missile_2d.gd —
	# it ramps toward a fixed sky-band altitude instead (#100), so sustained
	# fire can still reach enemies that now live above the horizon.
	var b := _make_bullet()
	assert_true(b.logical_altitude == 0.0, "bullet starts at ground-plane altitude 0 (matches player, no visual jump)")
	assert_true(b.aim_altitude == b.DEFAULT_AIM_ALTITUDE, "aim_altitude defaults to DEFAULT_AIM_ALTITUDE")
	for i in range(10):
		b._process(1.0 / 60.0)
	assert_true(b.logical_altitude > 0.5, "altitude has ramped substantially toward aim_altitude after ~0.17s (%.3f)" % b.logical_altitude)
	assert_true(b.get_screen_position().y < _DepthUtil.HORIZON_Y, "ramped bullet now sits above the horizon")
	b.queue_free()


func test_weapon_manager_constants() -> void:
	print("\ntest_weapon_manager_constants:")
	var script: GDScript = load("res://scripts/weapons/weapon_manager_2d.gd")
	var wm := Node.new()
	wm.set_script(script)
	get_root().add_child(wm)

	assert_true(wm.VULCAN_FIRE_INTERVAL == 0.08, "vulcan fire interval 0.08s (~12/sec)")
	assert_true(wm.LOCK_RADIUS == 80.0, "lock radius 80px")
	assert_true(wm.SIGHT_AHEAD_Y == 120.0, "sight leads 120px above player")
	assert_true(wm.locked_enemy == null, "no locked enemy at start")
	assert_true(wm.locked_enemy_bracket_size == 48.0, "default bracket size 48px")
	wm.queue_free()


func test_reticle_blink_defaults() -> void:
	print("\ntest_reticle_blink_defaults:")
	var script: GDScript = load("res://scripts/ui/reticle_2d.gd")
	var r := Node2D.new()
	r.set_script(script)
	get_root().add_child(r)

	assert_true(r._blink_visible == true, "blink visible by default")
	assert_true(r._blink_timer == 0.0, "blink timer at 0")
	assert_true(r.BLINK_COUNT == 3, "3 blink cycles")
	assert_approx(r.BLINK_INTERVAL, 0.06, "60ms blink interval", 0.001)
	r.queue_free()
