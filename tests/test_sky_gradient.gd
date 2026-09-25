extends SceneTree

## Unit tests for the sky gradient shape (game_world.gd) and the per-stage sky
## palette (stage_data.gd) — issues #115 and #123.
##
## AB2's sky is a flat backdrop fill for the top ~80% of its height, and most
## stages are flat edge to edge with no horizon glow at all.
##
## Rewritten for #123. The previous version asserted that every glow stage
## "shifts >=10deg of hue toward yellow" — a rule generalised from exactly two
## reference frames (desert and olive) and then applied to eleven stages. With
## all 23 stages now measured against verified arcade footage, it is false:
## stage 14 shifts AWAY from yellow, stage 20 barely moves hue and brightens
## instead, and stage 22 shifts toward cyan. A test that encodes an
## over-generalisation makes the over-generalisation harder to find, so the
## glow assertion here now only requires that a glow stage's horizon differs
## measurably from its top, without prescribing a direction.
##
## Run with: godot --headless --script res://tests/test_sky_gradient.gd

const GameWorld := preload("res://scripts/game/game_world.gd")
const StageData := preload("res://scripts/stage/stage_data.gd")

# The five stages whose verified arcade footage shows a measurable change
# between the top of the sky and the horizon. See stage_data.gd's header for
# the timestamps each was measured at. Every other stage is flat.
const GLOW_STAGES := [2, 14, 17, 20, 22]

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Sky Gradient Tests ===")

	test_top_of_sky_is_pure_top_color()
	test_sky_is_flat_through_the_flat_fraction()
	test_gradient_reaches_horizon_color()
	test_gradient_is_monotonic_and_stepless()
	test_only_verified_glow_stages_have_a_glow()
	test_glow_is_actually_visible()
	test_night_stages_are_dark_and_day_stages_are_not()

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
	for stage_number in GLOW_STAGES:
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

func test_only_verified_glow_stages_have_a_glow() -> void:
	print("\ntest_only_verified_glow_stages_have_a_glow:")
	# Flatness is expressed as data: sky_top == sky_horizon is what _draw_sky()
	# branches on to emit a single fill. Asserted in BOTH directions, because
	# #123's defect was a glow applied to stages that do not have one.
	var ok := true
	for stage_number in range(1, StageData.stage_count() + 1):
		var stage := StageData.get_stage(stage_number)
		var flat: bool = (stage["sky_top"] as Color).is_equal_approx(stage["sky_horizon"] as Color)
		var should_glow: bool = stage_number in GLOW_STAGES
		if flat and should_glow:
			ok = false
			print("    Stage %d is flat but the verified footage shows a glow" % stage_number)
		elif not flat and not should_glow:
			ok = false
			print("    Stage %d has a glow the verified footage does not show" % stage_number)
	assert_true(ok, "glow/flat matches the verified arcade footage for all 23 stages")


func test_glow_is_actually_visible() -> void:
	print("\ntest_glow_is_actually_visible:")
	# The #115 bug in data form: sky_top and sky_horizon shared a hue and
	# differed by ~0.05 V, so the "glow" was invisible and the whole sky sat at
	# the horizon colour. Requiring a visible difference catches that without
	# prescribing a direction — the five verified glows disagree on direction
	# (see this file's header), so any directional rule would be wrong.
	var ok := true
	for stage_number in GLOW_STAGES:
		var stage := StageData.get_stage(stage_number)
		var d := _color_distance(stage["sky_top"], stage["sky_horizon"])
		if d < 0.08:
			ok = false
			print("    Stage %d glow is only %.3f from its top colour — invisible in play" % [stage_number, d])
	assert_true(ok, "every glow stage's horizon is visibly different from its top")


func test_night_stages_are_dark_and_day_stages_are_not() -> void:
	print("\ntest_night_stages_are_dark_and_day_stages_are_not:")
	# Replaces a #115 test that required V >= 0.38 on EVERY stage, justified by
	# a claim that a literal near-black night "reads as a dead screen". #123's
	# measurement says otherwise: arcade stage 3's sky is #030303 across 80% of
	# the sky band. The old floor was an assumption dressed as a measurement, so
	# the assertion is now split — night stages may be genuinely black, and
	# everything else must stay bright enough to read as daylight sky.
	const NIGHT_STAGES := [3, 11]
	var ok := true
	for stage_number in range(1, StageData.stage_count() + 1):
		var stage := StageData.get_stage(stage_number)
		for key in ["sky_top", "sky_horizon"]:
			var v: float = (stage[key] as Color).v
			if stage_number not in NIGHT_STAGES and v < 0.55:
				ok = false
				print("    Stage %d %s is too dark for a daylight stage (V=%.2f)" % [stage_number, key, v])
			elif stage_number in NIGHT_STAGES and v > 0.45:
				ok = false
				print("    Stage %d %s is too bright for a night stage (V=%.2f)" % [stage_number, key, v])
	assert_true(ok, "night stages are dark, daylight stages are bright")
