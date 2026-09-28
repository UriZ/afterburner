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
	test_ground_palette_measured_stages()
	test_ground_palette_unmeasured_stages_unchanged()
	test_ground_c_is_a_value_step_not_a_third_hue()
	test_stage_1_ground_is_the_arcade_sea()
	test_every_stage_carries_a_124_ground_annotation()
	test_scroll_speed_per_stage()
	test_scroll_speed_regimes_are_ordered_correctly()

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
	var required_keys := ["ground_a", "ground_b", "ground_c", "sky_top", "sky_horizon", "spawn_interval", "enemies_per_wave", "is_bonus", "horizon_fraction", "scroll_speed"]
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


# ============================================================================
# #124 — per-stage ground palettes
# ============================================================================
#
# Every expectation below was GENERATED from tools/measure_ground_palette.py's
# JSON output (the measured nine) or from the pre-#124 committed values (the
# unmeasured fourteen), not hand-typed. Per-stage literals rather than a rule:
# #123's lesson is that a "law" inferred from a couple of stages is how a wrong
# generalisation gets a passing test to vouch for it.

# stage -> [ground_a, ground_b, ground_c, measured hue in degrees]
const MEASURED_GROUNDS := {
	1: [Color(0.000, 0.077, 0.925), Color(0.000, 0.066, 0.796), Color(0.000, 0.072, 0.861), 235.0],
	2: [Color(0.733, 0.482, 0.130), Color(0.441, 0.290, 0.078), Color(0.587, 0.386, 0.104), 35.0],
	4: [Color(0.000, 0.416, 0.035), Color(0.000, 0.282, 0.024), Color(0.000, 0.349, 0.029), 125.0],
	8: [Color(0.831, 0.485, 0.000), Color(0.529, 0.309, 0.000), Color(0.680, 0.397, 0.000), 35.0],
	10: [Color(0.771, 0.522, 0.175), Color(0.469, 0.318, 0.106), Color(0.620, 0.420, 0.140), 35.0],
	14: [Color(0.576, 0.543, 0.171), Color(0.248, 0.234, 0.074), Color(0.412, 0.388, 0.122), 55.0],
	15: [Color(0.518, 0.475, 0.006), Color(0.259, 0.238, 0.003), Color(0.388, 0.356, 0.004), 55.0],
	16: [Color(0.000, 0.392, 0.673), Color(0.000, 0.279, 0.478), Color(0.000, 0.336, 0.575), 205.0],
	23: [Color(0.000, 0.078, 0.939), Color(0.000, 0.067, 0.806), Color(0.000, 0.073, 0.873), 235.0],
}

# The fourteen the validated method could NOT read. These are the pre-#124
# values, asserted so that "unmeasurable, left unchanged" cannot quietly become
# "unmeasurable, filled in by eye" — which is the exact failure #124 exists to
# prevent. Two of them (3 and 17) are KNOWN-WRONG against their proven
# reference frames (a bright orange ground on a night stage, a bright green one
# on an olive field); they are pinned here as the honest gap they are, not as
# correct values. Changing one requires a measurement, and then this table.
const UNMEASURED_GROUNDS := {
	3: [Color(0.900, 0.660, 0.180), Color(0.550, 0.316, 0.083), Color(0.580, 0.600, 0.120)],
	5: [Color(0.340, 0.900, 0.180), Color(0.083, 0.550, 0.083), Color(0.350, 0.260, 0.100)],
	6: [Color(0.180, 0.540, 0.900), Color(0.083, 0.181, 0.550), Color(0.850, 0.900, 0.950)],
	7: [Color(0.590, 0.666, 0.720), Color(0.320, 0.367, 0.400), Color(0.830, 0.860, 0.890)],
	9: [Color(0.900, 0.540, 0.180), Color(0.550, 0.164, 0.083), Color(0.550, 0.450, 0.100)],
	11: [Color(0.420, 0.180, 0.900), Color(0.238, 0.083, 0.550), Color(0.600, 0.300, 0.850)],
	12: [Color(0.420, 0.180, 0.900), Color(0.199, 0.083, 0.550), Color(0.950, 0.850, 0.300)],
	13: [Color(0.180, 0.450, 0.900), Color(0.083, 0.270, 0.550), Color(0.620, 0.780, 0.950)],
	17: [Color(0.396, 0.900, 0.180), Color(0.083, 0.550, 0.083), Color(0.300, 0.280, 0.080)],
	18: [Color(0.900, 0.612, 0.180), Color(0.550, 0.183, 0.083), Color(0.550, 0.420, 0.120)],
	19: [Color(0.900, 0.402, 0.180), Color(0.550, 0.238, 0.083), Color(0.950, 0.350, 0.050)],
	20: [Color(0.420, 0.180, 0.900), Color(0.316, 0.083, 0.550), Color(0.550, 0.280, 0.800)],
	21: [Color(0.180, 0.468, 0.900), Color(0.083, 0.238, 0.550), Color(0.620, 0.780, 0.950)],
	22: [Color(0.900, 0.450, 0.180), Color(0.550, 0.149, 0.083), Color(0.550, 0.380, 0.100)],
}


func _colors_match(a: Color, b: Color) -> bool:
	# The table ships 3 decimals, so 0.0005 is the rounding floor, not a tolerance.
	return absf(a.r - b.r) < 0.0006 and absf(a.g - b.g) < 0.0006 and absf(a.b - b.b) < 0.0006


func _hue_distance_deg(a_deg: float, b_deg: float) -> float:
	var d := fmod(absf(a_deg - b_deg), 360.0)
	return minf(d, 360.0 - d)


func test_ground_palette_measured_stages() -> void:
	print("\ntest_ground_palette_measured_stages:")
	var keys := ["ground_a", "ground_b", "ground_c"]
	var all_ok := true
	for stage_no in MEASURED_GROUNDS:
		var expected: Array = MEASURED_GROUNDS[stage_no]
		var stage: Dictionary = StageData.get_stage(stage_no)
		for i in range(3):
			if not _colors_match(stage[keys[i]], expected[i]):
				all_ok = false
				print("    Stage %d %s is %s, measurement says %s" % [stage_no, keys[i], str(stage[keys[i]]), str(expected[i])])
	assert_eq(MEASURED_GROUNDS.size(), 9, "9 of 23 stages were measurable by the validated method")
	assert_true(all_ok, "All 9 measured stages hold exactly the value the tool derived")


func test_ground_palette_unmeasured_stages_unchanged() -> void:
	print("\ntest_ground_palette_unmeasured_stages_unchanged:")
	var keys := ["ground_a", "ground_b", "ground_c"]
	var all_ok := true
	for stage_no in UNMEASURED_GROUNDS:
		var expected: Array = UNMEASURED_GROUNDS[stage_no]
		var stage: Dictionary = StageData.get_stage(stage_no)
		for i in range(3):
			if not _colors_match(stage[keys[i]], expected[i]):
				all_ok = false
				print("    Stage %d %s changed to %s without a measurement (was %s)" % [stage_no, keys[i], str(stage[keys[i]]), str(expected[i])])
	assert_eq(MEASURED_GROUNDS.size() + UNMEASURED_GROUNDS.size(), 23, "Every stage is accounted for as measured or unmeasured")
	assert_true(all_ok, "All 14 unmeasurable stages still hold their pre-#124 values")


func test_ground_c_is_a_value_step_not_a_third_hue() -> void:
	print("\ntest_ground_c_is_a_value_step_not_a_third_hue:")
	# ground_terrain_2d.gdshader derives base_hue from color_a and pins every
	# cluster to it, reading color_c for S/V only. A ground_c with its own hue
	# is therefore silently discarded by the renderer — the state this file's
	# header documented as correct for three rounds. Asserted only for the
	# measured stages: the unmeasured fourteen still carry legacy ground_c hues
	# and pinning them here would demand a measurement this issue could not make.
	var all_ok := true
	for stage_no in MEASURED_GROUNDS:
		var stage: Dictionary = StageData.get_stage(stage_no)
		var a: Color = stage["ground_a"]
		var b: Color = stage["ground_b"]
		var c: Color = stage["ground_c"]
		if _hue_distance_deg(c.h * 360.0, a.h * 360.0) > 1.0:
			all_ok = false
			print("    Stage %d ground_c hue %.1f != ground_a hue %.1f (shader would discard it)" % [stage_no, c.h * 360.0, a.h * 360.0])
		if not (c.v > b.v and c.v < a.v):
			all_ok = false
			print("    Stage %d ground_c value %.3f is not between ground_b %.3f and ground_a %.3f" % [stage_no, c.v, b.v, a.v])
	assert_true(all_ok, "Measured stages: ground_c shares ground_a's hue and sits between the two value steps")


func test_stage_1_ground_is_the_arcade_sea() -> void:
	print("\ntest_stage_1_ground_is_the_arcade_sea:")
	# #124 AC 4. The arcade sea hue measured 235 deg over 15 HUD-proven stage-1
	# frames, corroborated at 237 (exact-colour mode) and 228 (chroma mean).
	# The island is #135's and is deliberately NOT represented here.
	var measured_sea_hue := 235.0
	var ground_a: Color = StageData.get_stage(1)["ground_a"]
	var delta := _hue_distance_deg(ground_a.h * 360.0, measured_sea_hue)
	assert_true(delta <= 20.0, "Stage 1 ground hue %.1f is within 20 deg of the measured arcade sea hue %.1f (delta %.1f)" % [ground_a.h * 360.0, measured_sea_hue, delta])
	# Sea, not island: a green ground here means the island leaked into the
	# sample, which is exactly how the first selector failed (40/46 frames).
	assert_true(ground_a.b > ground_a.g and ground_a.b > ground_a.r, "Stage 1 ground is blue-dominant (sea), not the green island")


func test_every_stage_carries_a_124_ground_annotation() -> void:
	print("\ntest_every_stage_carries_a_124_ground_annotation:")
	# AC 3: a rejected stage must be annotated with WHY, not silently skipped.
	# Parses the source because the annotation lives in comments. The stage-line
	# count assertion is the negative control: without it a bad path or a
	# changed comment prefix makes this test pass while checking nothing.
	var f := FileAccess.open("res://scripts/stage/stage_data.gd", FileAccess.READ)
	assert_true(f != null, "stage_data.gd is readable for the annotation scan")
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var stage_lines := 0
	var measured := 0
	var unmeasurable := 0
	for line in text.split("\n"):
		var t := line.strip_edges()
		if t.begins_with('{ "ground_a"'):
			stage_lines += 1
		elif t.begins_with("# #124 GROUND (measured)"):
			measured += 1
		elif t.begins_with("# #124 GROUND: UNMEASURABLE"):
			unmeasurable += 1
	assert_eq(stage_lines, 23, "Annotation scan found all 23 stage entries (negative control — a scan that finds none would pass every count below)")
	assert_eq(measured, MEASURED_GROUNDS.size(), "Every measured stage carries a '#124 GROUND (measured)' citation")
	assert_eq(unmeasurable, UNMEASURED_GROUNDS.size(), "Every unmeasurable stage carries a '#124 GROUND: UNMEASURABLE' annotation with its reason")
	assert_eq(measured + unmeasurable, 23, "No stage is left without a #124 ground annotation")


# ============================================================================
# #139 — per-stage world speed
# ============================================================================

func test_scroll_speed_per_stage() -> void:
	print("\ntest_scroll_speed_per_stage:")
	# Explicit per-stage assertions, the same shape as #120's horizon test, so
	# a future edit that silently changes an unmeasured stage's speed is caught
	# here. There are exactly TWO measurements behind these 23 numbers: the
	# arcade stage-1 cruise FLOOR (>= 95.7 %W/s) and the arcade stage-8
	# certified canyon flow (1.9433 px/frame at a 192 px work width).
	assert_true(is_equal_approx(StageData.get_stage(8)["scroll_speed"], 0.804),
		"stage 8 scroll_speed is 0.804 (canyon; solved from our measured 1.7623 px/f at v=0.729 against the arcade's certified 1.9433)")
	assert_true(is_equal_approx(StageData.get_stage(17)["scroll_speed"], 0.752),
		"stage 17 scroll_speed is 0.752 (canyon REGIME ASSUMPTION — stage 8's value corrected for stage 17's own span; no arcade stage-17 flow measurement exists)")
	var all_cruise := true
	for i in range(1, StageData.stage_count() + 1):
		if i == 8 or i == 17:
			continue
		var v: float = StageData.get_stage(i)["scroll_speed"]
		if not is_equal_approx(v, 2.8):
			all_cruise = false
			print("    Stage %d scroll_speed is %s, expected the cruise 2.8" % [i, str(v)])
	assert_true(all_cruise, "All 21 non-canyon stages hold the measured cruise value 2.8")


func test_scroll_speed_regimes_are_ordered_correctly() -> void:
	print("\ntest_scroll_speed_regimes_are_ordered_correctly:")
	# The defect #139 exists to fix, stated as an invariant rather than as
	# three more literals. Apparent flow is k*v*span, span = SCREEN_H -
	# horizon_y, so a single global v would make our canyons the FASTEST
	# stages in the game (their span is 2.32-2.48x cruise) while the arcade's
	# canyon runs at most 0.63x its cruise. This asserts the ordering the
	# arcade actually has — canyon apparent flow below cruise — computed from
	# the shipped data rather than restating the numbers above.
	var screen_h := 672.0
	var cruise := StageData.get_stage(1)
	var cruise_flow: float = cruise["scroll_speed"] * (screen_h - screen_h * float(cruise["horizon_fraction"]))
	var worst_canyon_ratio := 0.0
	for i in [8, 17]:
		var s := StageData.get_stage(i)
		var flow: float = s["scroll_speed"] * (screen_h - screen_h * float(s["horizon_fraction"]))
		var ratio := flow / cruise_flow
		print("    stage %d apparent-flow ratio vs cruise: %.3f" % [i, ratio])
		worst_canyon_ratio = maxf(worst_canyon_ratio, ratio)
		assert_true(ratio < 1.0, "stage %d canyon apparent flow is BELOW cruise (ratio %.3f) — a single global speed gives 2.32-2.48" % [i, ratio])
		# NEGATIVE CONTROL: the same arithmetic with one global speed, i.e. the
		# pre-#139 state. If this did NOT come out inverted, the invariant above
		# would be passing on geometry that never had the defect.
		var global_ratio := (screen_h - screen_h * float(s["horizon_fraction"])) / (screen_h - screen_h * float(cruise["horizon_fraction"]))
		assert_true(global_ratio > 2.3, "negative control: with ONE global speed, stage %d would run %.3fx cruise — the inverted relationship #139 exists to fix" % [i, global_ratio])

	# NOT ASSERTED, deliberately: that our ratio is <= the arcade's 0.63.
	#
	# Ours is 0.666. The arcade's 0.63 is 1.9433 / 3.063, and 3.063 is a FLOOR
	# (arcade stage 1 fails the aliasing gate, which only ever reads low), so
	# the arcade's true ratio is <= 0.63 by an unknown amount. Our cruise value
	# is set to just clear that floor while our canyon matches the arcade's
	# certified canyon exactly, so our ratio sits slightly ABOVE the arcade's
	# upper limit BY CONSTRUCTION, and it will keep doing so until someone can
	# measure the arcade's true cruise speed — which #139 section 5.1 shows
	# cannot be done from the available footage at any frame rate.
	#
	# Asserting `<= 0.63` here would demand two-sided parity against a bound,
	# which is the exact discipline error this issue spent a gate on. The first
	# version of this test did assert it and failed at 0.666; the number was
	# right and the assertion was wrong. What is testable is the DIRECTION.
	print("    (canyon/cruise ratio %.3f; the arcade's is <=0.634 — ours sits just above because our cruise closes a FLOOR from below, not a parity target)" % worst_canyon_ratio)
