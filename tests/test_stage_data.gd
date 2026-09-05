extends SceneTree

## Unit tests for StageData.
## Run with: godot --headless --script res://tests/test_stage_data.gd

const StageData := preload("res://scripts/stage/stage_data.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== StageData Tests ===")

	test_stage_count()
	test_all_stages_have_required_keys()
	test_stage_colors_are_valid()
	test_bonus_stages_at_correct_positions()
	test_difficulty_scaling()
	test_get_stage_clamps()
	test_no_duplicate_ground_colors()

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


func test_stage_count() -> void:
	print("\ntest_stage_count:")
	assert_eq(StageData.stage_count(), 23, "There are exactly 23 stages")


func test_all_stages_have_required_keys() -> void:
	print("\ntest_all_stages_have_required_keys:")
	var required_keys := ["ground_a", "ground_b", "sky_top", "sky_horizon", "spawn_interval", "enemies_per_wave", "is_bonus"]
	var all_valid := true
	for i in range(StageData.stage_count()):
		var stage := StageData.get_stage(i + 1)
		for key in required_keys:
			if not stage.has(key):
				all_valid = false
				print("    Stage %d missing key: %s" % [i + 1, key])
	assert_true(all_valid, "All stages have all required keys")


func test_stage_colors_are_valid() -> void:
	print("\ntest_stage_colors_are_valid:")
	var all_valid := true
	for i in range(StageData.stage_count()):
		var stage := StageData.get_stage(i + 1)
		for key in ["ground_a", "ground_b", "sky_top", "sky_horizon"]:
			var c: Color = stage[key]
			if c.r < 0.0 or c.r > 1.0 or c.g < 0.0 or c.g > 1.0 or c.b < 0.0 or c.b > 1.0:
				all_valid = false
				print("    Stage %d %s has out-of-range color: %s" % [i + 1, key, str(c)])
	assert_true(all_valid, "All stage colors have components in [0, 1]")


func test_bonus_stages_at_correct_positions() -> void:
	print("\ntest_bonus_stages_at_correct_positions:")
	# Bonus stages should be at positions 6, 12, 18
	var bonus_positions := [6, 12, 18]
	for pos in bonus_positions:
		var stage := StageData.get_stage(pos)
		assert_true(stage["is_bonus"], "Stage %d is a bonus stage" % pos)

	# Non-bonus stages should not be bonus
	var non_bonus_count := 0
	for i in range(1, StageData.stage_count() + 1):
		var stage := StageData.get_stage(i)
		if i not in bonus_positions:
			if not stage["is_bonus"]:
				non_bonus_count += 1
	assert_eq(non_bonus_count, 20, "Exactly 20 non-bonus stages")


func test_difficulty_scaling() -> void:
	print("\ntest_difficulty_scaling:")
	# Spawn interval should generally decrease (get harder) across stages
	var first_stage := StageData.get_stage(1)
	var last_stage := StageData.get_stage(23)
	assert_true(
		first_stage["spawn_interval"] > last_stage["spawn_interval"],
		"First stage has longer spawn interval than last stage"
	)
	# First stage enemies per wave should be <= last stage
	assert_true(
		first_stage["enemies_per_wave"] <= last_stage["enemies_per_wave"],
		"Last stage has more enemies per wave than first stage"
	)


func test_get_stage_clamps() -> void:
	print("\ntest_get_stage_clamps:")
	# Stage 0 should clamp to stage 1
	var stage_zero := StageData.get_stage(0)
	var stage_one := StageData.get_stage(1)
	assert_eq(stage_zero, stage_one, "Stage 0 clamps to stage 1")

	# Stage 100 should clamp to stage 23
	var stage_100 := StageData.get_stage(100)
	var stage_23 := StageData.get_stage(23)
	assert_eq(stage_100, stage_23, "Stage 100 clamps to stage 23")


func test_no_duplicate_ground_colors() -> void:
	print("\ntest_no_duplicate_ground_colors:")
	# Each stage should have visually distinct ground colors (ground_a != ground_b)
	var all_distinct := true
	for i in range(StageData.stage_count()):
		var stage := StageData.get_stage(i + 1)
		if stage["ground_a"] == stage["ground_b"]:
			all_distinct = false
			print("    Stage %d has identical ground_a and ground_b" % (i + 1))
	assert_true(all_distinct, "No stage has identical ground_a and ground_b")
