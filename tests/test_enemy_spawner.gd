extends SceneTree

## Unit tests for EnemySpawner formation logic.
## Run with: godot --headless --script res://tests/test_enemy_spawner.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== EnemySpawner Tests ===")

	test_v_formation_count()
	test_v_formation_leader_at_front()
	test_v_formation_symmetry()
	test_line_formation_count()
	test_line_formation_same_z()
	test_line_formation_evenly_spaced()
	test_scattered_formation_count()
	test_scattered_formation_variation()
	test_wave_definitions_valid()
	test_spawn_z_visible_range()

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


func _create_spawner() -> Node3D:
	# We can't instantiate the spawner directly since it loads scenes in _ready.
	# Instead, we'll test the formation logic by calling the methods via a script instance.
	var spawner_script := load("res://scripts/enemies/enemy_spawner.gd")
	var spawner := Node3D.new()
	spawner.set_script(spawner_script)
	return spawner


func test_v_formation_count() -> void:
	print("\ntest_v_formation_count:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._v_formation(5, 0.0, 3.0)
	assert_eq(positions.size(), 5, "V formation with count=5 produces 5 positions")
	spawner.free()


func test_v_formation_leader_at_front() -> void:
	print("\ntest_v_formation_leader_at_front:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._v_formation(3, 0.0, 3.0)
	# Leader should be at SPAWN_Z, wingmen further back (more negative Z)
	assert_true(
		positions[0].z > positions[1].z,
		"Leader Z > wingman Z (leader is closer to camera)"
	)
	spawner.free()


func test_v_formation_symmetry() -> void:
	print("\ntest_v_formation_symmetry:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._v_formation(5, 0.0, 3.0)
	# Positions 1 and 2 should be symmetric around center (0.0)
	assert_true(
		absf(positions[1].x + positions[2].x) < 0.01,
		"First pair of wingmen are symmetric around center"
	)
	spawner.free()


func test_line_formation_count() -> void:
	print("\ntest_line_formation_count:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._line_formation(4, 0.0, 3.0)
	assert_eq(positions.size(), 4, "Line formation with count=4 produces 4 positions")
	spawner.free()


func test_line_formation_same_z() -> void:
	print("\ntest_line_formation_same_z:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._line_formation(4, 0.0, 3.0)
	var all_same_z := true
	for pos in positions:
		if absf(pos.z - positions[0].z) > 0.01:
			all_same_z = false
			break
	assert_true(all_same_z, "All enemies in line formation share the same Z")
	spawner.free()


func test_line_formation_evenly_spaced() -> void:
	print("\ntest_line_formation_evenly_spaced:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._line_formation(4, 0.0, 3.0)
	# Check that spacing between consecutive enemies is equal
	var spacing := positions[1].x - positions[0].x
	var uniform := true
	for i in range(2, positions.size()):
		var s := positions[i].x - positions[i - 1].x
		if absf(s - spacing) > 0.01:
			uniform = false
			break
	assert_true(uniform, "Line formation has uniform spacing")
	spawner.free()


func test_scattered_formation_count() -> void:
	print("\ntest_scattered_formation_count:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._scattered_formation(4, 0.0, 3.0)
	assert_eq(positions.size(), 4, "Scattered formation with count=4 produces 4 positions")
	spawner.free()


func test_scattered_formation_variation() -> void:
	print("\ntest_scattered_formation_variation:")
	var spawner := _create_spawner()
	var positions: Array[Vector3] = spawner._scattered_formation(10, 0.0, 3.0)
	# With 10 enemies, there should be variation in X positions
	var min_x := positions[0].x
	var max_x := positions[0].x
	for pos in positions:
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
	assert_true(max_x - min_x > 0.5, "Scattered formation has X variation")
	spawner.free()


func test_wave_definitions_valid() -> void:
	print("\ntest_wave_definitions_valid:")
	var spawner := _create_spawner()
	var all_valid := true
	for wave_def in spawner.wave_definitions:
		if not wave_def.has("type") or not wave_def.has("count") or not wave_def.has("formation"):
			all_valid = false
			break
		if wave_def["type"] < 0 or wave_def["type"] > 2:
			all_valid = false
			break
		if wave_def["count"] < 1:
			all_valid = false
			break
		if wave_def["formation"] not in ["v", "line", "scattered"]:
			all_valid = false
			break
	assert_true(all_valid, "All wave definitions have valid type, count, and formation")
	assert_true(spawner.wave_definitions.size() > 0, "At least one wave definition exists")
	spawner.free()


func test_spawn_z_visible_range() -> void:
	print("\ntest_spawn_z_visible_range:")
	var spawner := _create_spawner()
	# SPAWN_Z must be close enough that enemies are visible at spawn.
	# Camera at Z=0; -80 was too far, -50 is the target.
	assert_true(spawner.SPAWN_Z >= -60.0, "SPAWN_Z is not too far (-60 max)")
	assert_true(spawner.SPAWN_Z <= -30.0, "SPAWN_Z is far enough for approach (-30 min)")
	spawner.free()
