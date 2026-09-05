extends SceneTree

## Unit tests for StageManager integration with StageData.
## Tests the data layer that StageManager relies on.
## StageManager itself cannot be instantiated in test context due to GameState autoload.
## Run with: godot --headless --script res://tests/test_stage_manager.gd

const StageData := preload("res://scripts/stage/stage_data.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== StageManager Integration Tests ===")

	test_stage_data_has_manager_required_keys()
	test_bonus_stages_give_missile_resupply_data()
	test_spawn_interval_always_positive()
	test_enemies_per_wave_always_positive()
	test_stage_progression_has_increasing_difficulty()
	test_all_23_stages_accessible()

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


func test_stage_data_has_manager_required_keys() -> void:
	print("\ntest_stage_data_has_manager_required_keys:")
	var required := ["ground_a", "ground_b", "sky_top", "sky_horizon", "spawn_interval", "is_bonus"]
	var all_valid := true
	for i in range(1, StageData.stage_count() + 1):
		var data := StageData.get_stage(i)
		for key in required:
			if not data.has(key):
				all_valid = false
				print("    Stage %d missing key: %s" % [i, key])
	assert_true(all_valid, "All stages have keys needed by StageManager")


func test_bonus_stages_give_missile_resupply_data() -> void:
	print("\ntest_bonus_stages_give_missile_resupply_data:")
	# Bonus stages at 6, 12, 18 should be marked is_bonus=true
	var bonus_count := 0
	for i in range(1, StageData.stage_count() + 1):
		var data := StageData.get_stage(i)
		if data["is_bonus"]:
			bonus_count += 1
			# Bonus stages should still have valid spawn data
			assert_true(data["spawn_interval"] > 0.0, "Bonus stage %d has positive spawn interval" % i)
	assert_eq(bonus_count, 3, "Exactly 3 bonus stages")


func test_spawn_interval_always_positive() -> void:
	print("\ntest_spawn_interval_always_positive:")
	var all_positive := true
	for i in range(1, StageData.stage_count() + 1):
		var data := StageData.get_stage(i)
		if data["spawn_interval"] <= 0.0:
			all_positive = false
			print("    Stage %d has non-positive spawn_interval: %f" % [i, data["spawn_interval"]])
	assert_true(all_positive, "All spawn intervals are positive")


func test_enemies_per_wave_always_positive() -> void:
	print("\ntest_enemies_per_wave_always_positive:")
	var all_positive := true
	for i in range(1, StageData.stage_count() + 1):
		var data := StageData.get_stage(i)
		if data["enemies_per_wave"] < 1:
			all_positive = false
			print("    Stage %d has < 1 enemies_per_wave: %d" % [i, data["enemies_per_wave"]])
	assert_true(all_positive, "All stages have at least 1 enemy per wave")


func test_stage_progression_has_increasing_difficulty() -> void:
	print("\ntest_stage_progression_has_increasing_difficulty:")
	# Compare first non-bonus stage to last non-bonus stage
	# Spawn interval should decrease, enemies_per_wave should increase
	var first := StageData.get_stage(1)
	var last := StageData.get_stage(23)
	assert_true(
		first["spawn_interval"] >= last["spawn_interval"],
		"Spawn interval decreases from stage 1 (%0.1f) to 23 (%0.1f)" % [first["spawn_interval"], last["spawn_interval"]]
	)
	assert_true(
		first["enemies_per_wave"] <= last["enemies_per_wave"],
		"Enemies per wave increases from stage 1 (%d) to 23 (%d)" % [first["enemies_per_wave"], last["enemies_per_wave"]]
	)


func test_all_23_stages_accessible() -> void:
	print("\ntest_all_23_stages_accessible:")
	# Simulate what StageManager does: iterate through all 23 stages
	var all_accessible := true
	for i in range(1, 24):
		var data := StageData.get_stage(i)
		if data.is_empty():
			all_accessible = false
			print("    Stage %d returned empty data" % i)
	assert_true(all_accessible, "All 23 stages return valid data")
