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
	test_horizon_fraction_per_stage()

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
	var required_keys := ["ground_a", "ground_b", "ground_c", "sky_top", "sky_horizon", "spawn_interval", "enemies_per_wave", "is_bonus", "horizon_fraction"]
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
		for key in ["ground_a", "ground_b", "ground_c", "sky_top", "sky_horizon"]:
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


func test_horizon_fraction_per_stage() -> void:
	print("\ntest_horizon_fraction_per_stage:")
	# #120 AC2 — only stages 8 and 17 have measured canyon evidence; every
	# other stage keeps today's cruise value. Explicit per-stage assertions,
	# not just presence, so a future edit that silently changes an
	# unmeasured stage's horizon is caught here.
	assert_true(is_equal_approx(StageData.get_stage(8)["horizon_fraction"], 0.13), "stage 8 horizon_fraction is 0.13 (canyon, median over 41 frames)")
	assert_true(is_equal_approx(StageData.get_stage(17)["horizon_fraction"], 0.07), "stage 17 horizon_fraction is 0.07 (canyon, corrected from an unreproducible 0.10)")
	var all_others_default := true
	for i in range(1, StageData.stage_count() + 1):
		if i == 8 or i == 17:
			continue
		var hf: float = StageData.get_stage(i)["horizon_fraction"]
		if not is_equal_approx(hf, 0.625):
			all_others_default = false
			print("    Stage %d horizon_fraction is %s, expected 0.625 (unmeasured, must not change)" % [i, str(hf)])
	assert_true(all_others_default, "All 21 non-canyon stages keep the default 0.625 horizon_fraction")
