extends SceneTree

## Unit tests for player_jet_2d.gd — constants, movement bounds, public interface.
## Run with: godot --headless --script res://tests/test_player_jet_2d.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("=== PlayerJet2D Tests ===")

	# Load AFTER autoloads are initialized (use _initialize, not _init)
	var jet_scene: PackedScene = load("res://scenes/player/player_jet_2d.tscn")

	test_constants(jet_scene)
	test_respawn_in_bounds(jet_scene)
	test_move_bounds_cover_screen(jet_scene)
	test_get_screen_position(jet_scene)
	test_get_collision_radius(jet_scene)
	test_get_bank_angle_starts_zero(jet_scene)
	test_is_vulnerable_states(jet_scene)
	test_player_in_group(jet_scene)

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func _make_jet(scene: PackedScene) -> Node2D:
	var jet: Node2D = scene.instantiate()
	get_root().add_child(jet)
	return jet


func test_constants(scene: PackedScene) -> void:
	print("\ntest_constants:")
	var jet: Node2D = _make_jet(scene)
	assert_true(jet.SCREEN_W == 960.0, "SCREEN_W is 960")
	assert_true(jet.SCREEN_H == 672.0, "SCREEN_H is 672")
	assert_true(jet.PLAYER_SCALE == 75.0, "PLAYER_SCALE is 75")
	assert_true(jet.MAX_BANK_ANGLE == 45.0, "MAX_BANK_ANGLE is 45 degrees")
	jet.queue_free()


func test_respawn_in_bounds(scene: PackedScene) -> void:
	print("\ntest_respawn_in_bounds:")
	var jet: Node2D = _make_jet(scene)
	var rp: Vector2 = jet.RESPAWN_POSITION
	assert_true(rp.x >= jet.MOVE_MIN.x and rp.x <= jet.MOVE_MAX.x,
		"Respawn X within horizontal bounds")
	assert_true(rp.y >= jet.MOVE_MIN.y and rp.y <= jet.MOVE_MAX.y,
		"Respawn Y within vertical bounds")
	assert_true(abs(rp.x - 480.0) < 10.0, "Respawn near horizontal center")
	jet.queue_free()


func test_move_bounds_cover_screen(scene: PackedScene) -> void:
	print("\ntest_move_bounds_cover_screen:")
	var jet: Node2D = _make_jet(scene)
	var mn: Vector2 = jet.MOVE_MIN
	var mx: Vector2 = jet.MOVE_MAX
	var x_coverage: float = (mx.x - mn.x) / 960.0
	var y_coverage: float = (mx.y - mn.y) / 672.0
	assert_true(x_coverage >= 0.80,
		"X bounds cover >=80%% of screen (%.0f%%)" % (x_coverage * 100))
	assert_true(y_coverage >= 0.50,
		"Y bounds cover >=50%% of screen (%.0f%%)" % (y_coverage * 100))
	assert_true(mn.x > 0.0, "Left margin exists")
	assert_true(mx.x < 960.0, "Right margin exists")
	jet.queue_free()


func test_get_screen_position(scene: PackedScene) -> void:
	print("\ntest_get_screen_position:")
	var jet: Node2D = _make_jet(scene)
	jet.position = Vector2(320.0, 400.0)
	var sp: Vector2 = jet.get_screen_position()
	assert_true(sp.x == 320.0 and sp.y == 400.0,
		"get_screen_position() returns current node position")
	jet.queue_free()


func test_get_collision_radius(scene: PackedScene) -> void:
	print("\ntest_get_collision_radius:")
	var jet: Node2D = _make_jet(scene)
	var r: float = jet.get_collision_radius()
	var expected: float = jet.PLAYER_SCALE * 0.6
	assert_true(absf(r - expected) < 0.01,
		"Collision radius = PLAYER_SCALE * 0.6 (got %.1f, expected %.1f)" % [r, expected])
	jet.queue_free()


func test_get_bank_angle_starts_zero(scene: PackedScene) -> void:
	print("\ntest_get_bank_angle_starts_zero:")
	var jet: Node2D = _make_jet(scene)
	assert_true(jet.get_bank_angle() == 0.0, "Bank angle starts at 0")
	jet.queue_free()


func test_is_vulnerable_states(scene: PackedScene) -> void:
	print("\ntest_is_vulnerable_states:")
	var jet: Node2D = _make_jet(scene)

	# Just added to tree: starts invincible (set in _ready)
	assert_true(jet._is_invincible == true, "Starts invincible after _ready()")
	assert_true(jet.is_vulnerable() == false, "Not vulnerable while invincible")

	# Simulate invincibility expired
	jet._is_invincible = false
	jet._is_dying = false
	assert_true(jet.is_vulnerable() == true, "Vulnerable when alive and not invincible")

	jet._is_dying = true
	assert_true(jet.is_vulnerable() == false, "Not vulnerable while dying")

	jet.queue_free()


func test_player_in_group(scene: PackedScene) -> void:
	print("\ntest_player_in_group:")
	var jet: Node2D = _make_jet(scene)
	# In headless script mode _ready() may not run via add_child; call manually.
	if not jet.is_in_group("player"):
		jet._ready()
	assert_true(jet.is_in_group("player"), "PlayerJet2D self-registers in 'player' group")
	jet.queue_free()
