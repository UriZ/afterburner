extends SceneTree

## Unit tests for enemy_bullet_2d.gd.
## Run with: godot --headless --script res://tests/test_enemy_bullet_2d.gd

const EnemyBullet2D := preload("res://scripts/enemies/enemy_bullet_2d.gd")
const DepthUtil := preload("res://scripts/game/depth_util.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== EnemyBullet2D Tests ===")

	test_initial_state()
	test_screen_position_uses_altitude()
	test_altitude_decays_toward_zero_as_bullet_travels()
	test_despawns_past_max_depth()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func _make_bullet() -> Node:
	var b := Node.new()
	b.set_script(EnemyBullet2D)
	return b


func test_initial_state() -> void:
	print("\ntest_initial_state:")
	var b := _make_bullet()
	assert_true(b.logical_depth == 0.0, "bullet starts at depth 0.0")
	assert_true(b.logical_altitude == 0.0, "bullet starts at altitude 0.0 (firer sets it at spawn)")
	b.free()


func test_screen_position_uses_altitude() -> void:
	print("\ntest_screen_position_uses_altitude:")
	# A bullet inherits the firer's altitude at spawn (#100) — enemy_jet_2d.gd
	# sets logical_altitude directly before adding the bullet to the tree.
	var b := _make_bullet()
	b.logical_depth = 0.5
	b.logical_altitude = 1.0
	var pos: Vector2 = b.get_screen_position()
	var expected: Vector2 = DepthUtil.to_screen(0.0, 0.5, 1.0)
	assert_true(pos == expected, "get_screen_position() matches DepthUtil.to_screen(x, d, altitude)")
	assert_true(pos.y < DepthUtil.HORIZON_Y, "bullet with nonzero altitude sits above the horizon, matching its sky-based firer")
	b.free()


func test_altitude_decays_toward_zero_as_bullet_travels() -> void:
	print("\ntest_altitude_decays_toward_zero_as_bullet_travels:")
	# The firer lives in the sky but the player doesn't — the shot must
	# visually descend from the firer's altitude toward the player's level
	# instead of holding a fixed altitude for its whole flight.
	var b := _make_bullet()
	b.logical_altitude = 1.0
	b.target_screen_pos = Vector2(480.0, 600.0)
	for i in range(30):
		b._process(1.0 / 60.0)
	assert_true(b.logical_altitude < 1.0, "altitude has decayed from its starting value (%.3f)" % b.logical_altitude)
	assert_true(b.logical_altitude >= 0.0, "altitude never overshoots past 0 toward negative")
	b.free()


func test_despawns_past_max_depth() -> void:
	print("\ntest_despawns_past_max_depth:")
	var b := _make_bullet()
	b.logical_depth = 1.29
	b.target_screen_pos = Vector2(480.0, 600.0)
	b._process(1.0)  # speed=0.6/sec — one full second easily clears the 1.3 threshold
	assert_true(b.logical_depth > 1.3, "bullet advances past the 1.3 despawn threshold")
	b.free()
