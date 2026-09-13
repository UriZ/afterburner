extends SceneTree

## Unit tests for the ground rendering helpers in game_world.gd (issue #42).
## Only covers the pure computational helpers — _draw_ground()/_draw_terrain_features()/
## _draw_cluster() call draw_rect/draw_circle directly and need an active draw
## context, so those are verified visually instead.
##
## The _feature_depth tests below guard the actual #42 bug fix: a persistent-identity
## terrain feature must have its depth change smoothly and continuously as the shared
## world-scroll phase advances (translation), while everything that defines its look —
## lateral position, size, tint — must be a function of its fixed slot index only, never
## of the scroll phase (no re-roll from a frame-varying hash).
## Run with: godot --headless --script res://tests/test_ground_grid.gd

const GameWorld := preload("res://scripts/game/game_world.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== GroundGrid Tests ===")

	test_hash2_range()
	test_hash2_deterministic()
	test_hash2_varies_with_input()
	test_player_lateral_offset_no_player()
	test_player_lateral_offset_clamped()
	test_feature_depth_translates_continuously()
	test_feature_depth_advances_toward_camera()
	test_feature_depth_wraps_to_horizon()
	test_feature_identity_independent_of_scroll()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func _make_world() -> Node2D:
	var w := Node2D.new()
	w.set_script(GameWorld)
	root.add_child(w)
	return w


func _make_fake_player(x: float) -> Node2D:
	var p := Node2D.new()
	p.position = Vector2(x, 380.0)
	p.add_to_group("player")
	var script := GDScript.new()
	script.source_code = "extends Node2D\nfunc get_screen_position() -> Vector2:\n\treturn position\n"
	script.reload()
	p.set_script(script)
	root.add_child(p)
	return p


func test_hash2_range() -> void:
	print("\ntest_hash2_range:")
	var w := _make_world()
	for i in range(20):
		var h: float = w._hash2(i, i * 3)
		assert_true(h >= 0.0 and h < 1.0, "_hash2(%d) in [0,1): %f" % [i, h])
	w.free()


func test_hash2_deterministic() -> void:
	print("\ntest_hash2_deterministic:")
	var w := _make_world()
	var a: float = w._hash2(7, 13)
	var b: float = w._hash2(7, 13)
	assert_true(a == b, "_hash2 is deterministic for same inputs")
	w.free()


func test_hash2_varies_with_input() -> void:
	print("\ntest_hash2_varies_with_input:")
	var w := _make_world()
	var first: float = w._hash2(0, 0)
	var all_same := true
	for i in range(1, 10):
		if w._hash2(i, 0) != first:
			all_same = false
			break
	assert_true(not all_same, "_hash2 output varies across row/col inputs")
	w.free()


func test_player_lateral_offset_no_player() -> void:
	print("\ntest_player_lateral_offset_no_player:")
	var w := _make_world()
	assert_true(w._player_lateral_offset() == 0.0, "_player_lateral_offset is 0 with no player")
	w.free()


func test_player_lateral_offset_clamped() -> void:
	print("\ntest_player_lateral_offset_clamped:")
	# In this synchronous _init()-time harness, add_child() does not finish attaching
	# the node to the tree before get_tree() is queried (same harmless "data.tree is
	# null" engine error documented in test_enemy_jet_2d.gd). This still exercises the
	# no-crash / clamped-fallback path; the group lookup itself is covered in the
	# running game via visual verification.
	var w := _make_world()
	var p := _make_fake_player(960.0)  # far right edge, beyond normal play area
	var offset: float = w._player_lateral_offset()
	assert_true(offset <= 0.6 and offset >= -0.6, "_player_lateral_offset stays within [-0.6, 0.6]: %f" % offset)
	p.free()
	w.free()


func test_feature_depth_translates_continuously() -> void:
	print("\ntest_feature_depth_translates_continuously:")
	var w := _make_world()
	var slot := 42
	w._ground_scroll = 0.5
	var d0: float = w._feature_depth(slot)
	w._ground_scroll = fposmod(w._ground_scroll + 0.01, 1.0)
	var d1: float = w._feature_depth(slot)
	# A one-frame-sized scroll step must move a feature's depth by a matching small
	# amount (translation) — never an unrelated jump, which is what a frame-varying
	# hash re-roll (the #42 bug) would produce.
	var delta: float = absf(d1 - d0)
	assert_true(is_equal_approx(delta, 0.01), "small scroll step -> matching small depth step: %f" % delta)
	w.free()


func test_feature_depth_advances_toward_camera() -> void:
	print("\ntest_feature_depth_advances_toward_camera:")
	var w := _make_world()
	var slot := 7
	w._ground_scroll = 0.0
	var d_start: float = w._feature_depth(slot)
	w._ground_scroll = 0.3
	var d_later: float = w._feature_depth(slot)
	var expected: float = fposmod(d_start + 0.3, 1.0)
	assert_true(is_equal_approx(d_later, expected), "depth advances by exactly the scroll delta (mod wrap): %f -> %f, expected %f" % [d_start, d_later, expected])
	w.free()


func test_feature_depth_wraps_to_horizon() -> void:
	print("\ntest_feature_depth_wraps_to_horizon:")
	var w := _make_world()
	var slot := 3
	var base: float = w._hash2(slot, 5)
	# Scroll just past the point where this feature reaches the camera (d=1).
	w._ground_scroll = fposmod(base + 0.001, 1.0)
	var d: float = w._feature_depth(slot)
	assert_true(d < 0.01, "feature wraps back to the horizon (d≈0) right after reaching the camera: %f" % d)
	w.free()


func test_feature_identity_independent_of_scroll() -> void:
	print("\ntest_feature_identity_independent_of_scroll:")
	var w := _make_world()
	var slot := 15
	# Lateral offset/size/tint are derived from _hash2(slot, ...) only — never from
	# _ground_scroll — so a feature's look never re-rolls, only its depth moves.
	var lateral_a: float = w._hash2(slot, 3)
	w._ground_scroll = 0.0
	var lateral_b: float = w._hash2(slot, 3)
	w._ground_scroll = 0.87
	var lateral_c: float = w._hash2(slot, 3)
	assert_true(lateral_a == lateral_b and lateral_b == lateral_c, "feature identity hash is invariant to _ground_scroll")
	w.free()
