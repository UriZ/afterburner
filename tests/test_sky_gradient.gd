extends SceneTree

## Unit tests for the sky gradient shape (game_world.gd) and the per-stage sky
## palette (stage_data.gd) — issue #115.
##
## These lock in what was measured off assets/reference/motion/ab2-longplay:
## AB2's sky is a flat backdrop fill for the top ~80% of its height, several
## biomes are flat edge to edge with no horizon glow at all, and where a glow
## does exist it is a hue shift toward yellow at held saturation — NOT a
## brightness ramp and NOT a same-hue lerp (which is what made the sky
## indistinguishable from the desert ground and caused #115).
##
## Run with: godot --headless --script res://tests/test_sky_gradient.gd

const GameWorld := preload("res://scripts/game/game_world.gd")
const StageData := preload("res://scripts/stage/stage_data.gd")

# Stages the reference shows with a flat, glow-free sky (snow/ice, blue and
# teal water, night, the yellow desert). Everything else must have a glow.
const FLAT_SKY_STAGES := [6, 7, 8, 11, 12, 13, 14, 15, 16, 20, 21, 23]

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Sky Gradient Tests ===")

	test_top_of_sky_is_pure_top_color()
	test_sky_is_flat_through_the_flat_fraction()
	test_gradient_reaches_horizon_color()
	test_gradient_is_monotonic_and_stepless()
	test_flat_stages_have_no_glow()
	test_glow_stages_shift_hue_toward_yellow()
	test_all_stages_bright_enough_to_read_as_sky()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


# --- Gradient shape ---

func test_top_of_sky_is_pure_top_color() -> void:
	print("\ntest_top_of_sky_is_pure_top_color:")
	var top := Color(0.9, 0.435, 0.0)
	var horizon := Color(0.98, 0.849, 0.0)
	assert_true(
		GameWorld.sky_color_at(0.0, top, horizon).is_equal_approx(top),
		"t=0 (top of frame) is exactly sky_top"
	)


func test_sky_is_flat_through_the_flat_fraction() -> void:
	print("\ntest_sky_is_flat_through_the_flat_fraction:")
	# The reference holds one RGB value unchanged from the top of frame down to
	# ~80% of sky height (burst-a-02: #e67100 from y=60 to y=228 of a horizon at
	# y~268). Anything that drifts before then is a gradient the arcade has not.
	var top := Color(0.9, 0.435, 0.0)
	var horizon := Color(0.98, 0.849, 0.0)
	var flat := true
	for i in range(0, 80):
		if not GameWorld.sky_color_at(float(i) / 100.0, top, horizon).is_equal_approx(top):
			flat = false
			print("    drift at t=%.2f" % (float(i) / 100.0))
	assert_true(flat, "sky is pixel-flat for the whole top %d%% of its height" % int(GameWorld.SKY_FLAT_FRACTION * 100.0))


func test_gradient_reaches_horizon_color() -> void:
	print("\ntest_gradient_reaches_horizon_color:")
	var top := Color(0.9, 0.435, 0.0)
	var horizon := Color(0.98, 0.849, 0.0)
	assert_true(
		GameWorld.sky_color_at(1.0, top, horizon).is_equal_approx(horizon),
		"t=1 (horizon) is exactly sky_horizon"
	)


func test_gradient_is_monotonic_and_stepless() -> void:
	print("\ntest_gradient_is_monotonic_and_stepless:")
	# Sampled over every real glow stage at the same per-scanline resolution
	# _draw_sky() actually uses, so this measures on-screen quantisation rather
	# than a synthetic ideal. The old 50-band-over-the-whole-sky loop stepped
	# ~8px at a time right where the ramp is steepest.
	#
	# Bound is 3 of 255 levels per 1px scanline (Color channel units map 1:1 to
	# 8-bit levels at x255). smoothstep's peak slope is 1.5, so over an 84px
	# band the worst step is 1.5/84 = 1.8% of a stage's total colour delta —
	# ~2/255 on the widest-ranging stage. What this guards against is the ramp
	# later being compressed into fewer rows or a narrower slice of the sky,
	# either of which reintroduces visible banding.
	var rows := int(ceil(GameWorld.HORIZON_Y - GameWorld.HORIZON_Y * GameWorld.SKY_FLAT_FRACTION))
	var max_step := 0.0
	var worst_stage := 0
	var monotonic := true
	for stage_number in range(1, StageData.stage_count() + 1):
		if stage_number in FLAT_SKY_STAGES:
			continue
		var stage := StageData.get_stage(stage_number)
		var top: Color = stage["sky_top"]
		var horizon: Color = stage["sky_horizon"]
		var prev := GameWorld.sky_color_at(GameWorld.SKY_FLAT_FRACTION, top, horizon)
		for i in range(1, rows + 1):
			var t: float = (GameWorld.HORIZON_Y * GameWorld.SKY_FLAT_FRACTION + float(i)) / GameWorld.HORIZON_Y
			var c := GameWorld.sky_color_at(t, top, horizon)
			# Direction is stage-dependent (warm stages brighten, forest
			# desaturates), so compare against this stage's own endpoints.
			if _color_distance(prev, horizon) - _color_distance(c, horizon) < -0.0001:
				monotonic = false
			for ch in [c.r - prev.r, c.g - prev.g, c.b - prev.b]:
				if absf(ch) > max_step:
					max_step = absf(ch)
					worst_stage = stage_number
			prev = c
	assert_true(monotonic, "gradient never reverses direction on any glow stage")
	assert_true(
		max_step * 255.0 <= 3.0,
		"largest per-scanline step is %.2f of 255 levels (stage %d), under the 3-level banding bound" % [max_step * 255.0, worst_stage]
	)


# --- Per-stage palette ---

func test_flat_stages_have_no_glow() -> void:
	print("\ntest_flat_stages_have_no_glow:")
	# Flat stages must be flat by DATA (sky_top == sky_horizon), because that
	# equality is what _draw_sky() branches on to emit a single fill.
	var ok := true
	for stage_number in FLAT_SKY_STAGES:
		var stage := StageData.get_stage(stage_number)
		if not (stage["sky_top"] as Color).is_equal_approx(stage["sky_horizon"] as Color):
			ok = false
			print("    Stage %d has a glow but the reference biome is flat" % stage_number)
	assert_true(ok, "every flat-sky biome stage has sky_top == sky_horizon")


func test_glow_stages_shift_hue_toward_yellow() -> void:
	print("\ntest_glow_stages_shift_hue_toward_yellow:")
	# The #115 bug in data form: sky_top and sky_horizon shared a hue, so the
	# glow was invisible and the entire sky sat at the horizon's gold. The
	# reference's desert glow runs 29deg -> 52deg; require at least 10deg of
	# separation, and require it to move toward yellow (~55deg), not away.
	var ok := true
	for stage_number in range(1, StageData.stage_count() + 1):
		if stage_number in FLAT_SKY_STAGES:
			continue
		var stage := StageData.get_stage(stage_number)
		var top_h: float = (stage["sky_top"] as Color).h * 360.0
		var horizon_h: float = (stage["sky_horizon"] as Color).h * 360.0
		if absf(horizon_h - top_h) < 10.0:
			ok = false
			print("    Stage %d glow hue shift is only %.1fdeg" % [stage_number, absf(horizon_h - top_h)])
		elif absf(horizon_h - 55.0) >= absf(top_h - 55.0):
			ok = false
			print("    Stage %d horizon hue %.1fdeg is not closer to yellow than top %.1fdeg" % [stage_number, horizon_h, top_h])
	assert_true(ok, "every glow stage shifts >=10deg of hue toward yellow at the horizon")


func test_all_stages_bright_enough_to_read_as_sky() -> void:
	print("\ntest_all_stages_bright_enough_to_read_as_sky:")
	# Every sky measured off the reference sits at V >= 0.40 (the darkest is the
	# dusk slate #414163 at V=0.39). A literal near-black sky reads as a dead
	# screen on our renderer, not as night — see the stage_data.gd header.
	var ok := true
	for stage_number in range(1, StageData.stage_count() + 1):
		var stage := StageData.get_stage(stage_number)
		for key in ["sky_top", "sky_horizon"]:
			var v: float = (stage[key] as Color).v
			if v < 0.38:
				ok = false
				print("    Stage %d %s is too dark to read as sky (V=%.2f)" % [stage_number, key, v])
	assert_true(ok, "no stage sky falls below the reference's darkest measured value")
