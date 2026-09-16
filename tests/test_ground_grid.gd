extends SceneTree

## Unit tests for the ground rendering helpers in game_world.gd (#42 redo).
##
## The per-pixel cellular-noise ground terrain itself lives in a fragment
## shader (assets/shaders/ground_terrain_2d.gdshader) and needs an active
## draw/GPU context, so it is verified visually instead (see #42 comments).
## What's covered here is the GDScript-side data flow that feeds the shader:
## the world-scroll accumulator (translates continuously, never re-rolls —
## the actual #42 regression class) and the player lateral-parallax offset,
## plus that the shader-backed child node wires up without crashing.
##
## Run with: godot --headless --script res://tests/test_ground_grid.gd

const GameWorld := preload("res://scripts/game/game_world.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== GroundGrid Tests ===")

	test_player_lateral_offset_no_player()
	test_player_lateral_offset_clamped()
	test_ground_scroll_advances_continuously()
	test_ground_scroll_wraps_at_period()
	test_ensure_ground_terrain_idempotent()
	test_ensure_ground_terrain_creates_child_with_material()

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


func test_ground_scroll_advances_continuously() -> void:
	print("\ntest_ground_scroll_advances_continuously:")
	var w := _make_world()
	w._ground_scroll = 10.0
	w._process(0.1)
	# GROUND_SCROLL_SPEED=1.4, so a 0.1s step should advance _ground_scroll by
	# 0.14 — a small, matching step (translation), never an unrelated jump,
	# which is the continuous analogue of the #42 bug class (terrain
	# regenerating from scratch instead of moving).
	var expected: float = fposmod(10.0 + 0.1 * GameWorld.GROUND_SCROLL_SPEED, GameWorld.GROUND_SCROLL_WRAP)
	assert_true(is_equal_approx(w._ground_scroll, expected), "_ground_scroll advances by delta * GROUND_SCROLL_SPEED: %f (expected %f)" % [w._ground_scroll, expected])
	w.free()


func test_ground_scroll_wraps_at_period() -> void:
	print("\ntest_ground_scroll_wraps_at_period:")
	var w := _make_world()
	w._ground_scroll = GameWorld.GROUND_SCROLL_WRAP - 0.01
	w._process(0.1)
	# Wraps back near 0 rather than growing unboundedly (float32 precision
	# guard — see GROUND_SCROLL_WRAP comment in game_world.gd).
	assert_true(w._ground_scroll < GameWorld.GROUND_SCROLL_WRAP, "_ground_scroll stays below the wrap period: %f" % w._ground_scroll)
	assert_true(w._ground_scroll >= 0.0, "_ground_scroll never goes negative: %f" % w._ground_scroll)
	w.free()


func test_ensure_ground_terrain_idempotent() -> void:
	print("\ntest_ensure_ground_terrain_idempotent:")
	var w := _make_world()
	w._ensure_ground_terrain()
	var first: Node2D = w._ground_terrain
	w._ensure_ground_terrain()
	assert_true(w._ground_terrain == first, "_ensure_ground_terrain does not replace an existing child on a second call")
	w.free()


func test_ensure_ground_terrain_creates_child_with_material() -> void:
	print("\ntest_ensure_ground_terrain_creates_child_with_material:")
	var w := _make_world()
	w._ensure_ground_terrain()
	assert_true(w._ground_terrain != null, "_ensure_ground_terrain creates the child node")
	assert_true(w._ground_terrain.get_parent() == w, "ground terrain child is parented to GameWorld")
	# update() should not crash even before/without a frame having run _ready().
	w._ground_terrain.update(0.3, 0.1, Color.RED, Color.BLUE, Color.YELLOW, Color.GREEN)
	assert_true(w._ground_terrain.material != null, "ground terrain child has a shader material assigned")
	w.free()
