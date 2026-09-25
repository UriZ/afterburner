extends SceneTree

## Unit tests for the per-stage horizon (#120): DepthUtil's runtime horizon_y,
## the projection reading it, and the ground shader's uniform push.
## Run with: godot --headless --script res://tests/test_horizon_per_stage.gd

const DepthUtil := preload("res://scripts/game/depth_util.gd")
const GroundTerrain := preload("res://scripts/game/ground_terrain_2d.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== test_horizon_per_stage ===")

	test_algebraic_invariance_at_default_horizon()
	test_projection_tracks_horizon()
	test_shader_uniforms_pushed()
	test_no_static_leak()

	# Risk 1 (spec §4): restore the default so no later test in the same
	# process inherits a stage-8/17 horizon from a test above.
	DepthUtil.set_horizon_fraction(DepthUtil.DEFAULT_HORIZON_FRACTION)

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_approx(a: float, b: float, message: String, tolerance: float = 0.01) -> void:
	assert_true(absf(a - b) < tolerance, "%s (got %.4f, expected %.4f)" % [message, a, b])


## AC1 — algebraic invariance. With horizon_fraction=0.625 (today's default),
## to_screen(x, d, a) must return bit-identical-to-tolerance values to the
## PRE-#120 formula for x in {-1,0,1}, d in {0,0.25,0.5,0.75,1}, a in
## {0,0.75,1.2} — 45 combinations. The "old formula" below is the exact
## pre-refactor arithmetic (const HORIZON_Y=420.0, hardcoded here rather than
## read from DepthUtil) so this test cannot pass by both sides drifting
## together if to_screen() ever changes.
func test_algebraic_invariance_at_default_horizon() -> void:
	print("\ntest_algebraic_invariance_at_default_horizon:")
	DepthUtil.set_horizon_fraction(DepthUtil.DEFAULT_HORIZON_FRACTION)
	const OLD_HORIZON_Y := 420.0
	const OLD_SCREEN_H := 672.0
	const OLD_SCREEN_W := 960.0
	const OLD_ALTITUDE_LIFT := 580.0
	var xs: Array[float] = [-1.0, 0.0, 1.0]
	var ds: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
	var alts: Array[float] = [0.0, 0.75, 1.2]
	var all_match := true
	var checked := 0
	for x in xs:
		for d in ds:
			for a in alts:
				var old_cx: float = OLD_SCREEN_W / 2.0
				var old_sx: float = old_cx + x * (OLD_SCREEN_W * 0.47) * (0.1 + d * 0.9)
				var old_sy: float = OLD_HORIZON_Y + d * d * ((OLD_SCREEN_H - OLD_HORIZON_Y) * 0.95 - a * OLD_ALTITUDE_LIFT)
				var expected := Vector2(old_sx, old_sy)
				var actual: Vector2 = DepthUtil.to_screen(x, d, a)
				checked += 1
				if not actual.is_equal_approx(expected):
					all_match = false
					print("    MISMATCH x=%.2f d=%.2f a=%.2f: got %s, expected %s" % [x, d, a, str(actual), str(expected)])
	assert_true(checked == 45, "exercised all 45 combinations (got %d)" % checked)
	assert_true(all_match, "to_screen() at horizon_fraction=0.625 is bit-identical to the pre-#120 formula on all 45 combinations")


## AC3 — projection tracks the horizon.
func test_projection_tracks_horizon() -> void:
	print("\ntest_projection_tracks_horizon:")
	DepthUtil.set_horizon_fraction(0.13)
	var pos0: Vector2 = DepthUtil.to_screen(0.0, 0.0)
	assert_approx(pos0.y, 672.0 * 0.13, "to_screen(0,0).y sits exactly at the new horizon")
	var pos1: Vector2 = DepthUtil.to_screen(0.0, 1.0, 0.0)
	var expected_y: float = 0.13 * 672.0 + (672.0 - 0.13 * 672.0) * 0.95
	assert_approx(pos1.y, expected_y, "to_screen(0,1,0).y reaches the expected near-bottom ground position")
	DepthUtil.set_horizon_fraction(DepthUtil.DEFAULT_HORIZON_FRACTION)


## AC4 — shader uniforms pushed. Deliberately checks the LIVE value via
## get_shader_parameter, not a value this test computed itself, so it can
## only pass if update() actually pushed it. Verified as a real negative
## control during development: temporarily deleting the
## set_shader_parameter("horizon_y", ...) line in ground_terrain_2d.gd's
## update() makes this assertion FAIL (material parameter stays unset/null)
## — restored immediately after confirming that.
func test_shader_uniforms_pushed() -> void:
	print("\ntest_shader_uniforms_pushed:")
	DepthUtil.set_horizon_fraction(0.13)
	var terrain := Node2D.new()
	terrain.set_script(GroundTerrain)
	root.add_child(terrain)
	terrain.update(0.0, 0.0, Color.WHITE, Color.BLACK, Color.GRAY)
	var material: ShaderMaterial = terrain.get("material")
	assert_true(material != null, "sanity: update() created a shader material")
	if material != null:
		var pushed_horizon: Variant = material.get_shader_parameter("horizon_y")
		var pushed_h: Variant = material.get_shader_parameter("screen_h")
		var pushed_w: Variant = material.get_shader_parameter("screen_w")
		assert_true(pushed_horizon != null and is_equal_approx(float(pushed_horizon), DepthUtil.horizon_y), "material's horizon_y shader parameter equals DepthUtil.horizon_y (%.2f)" % DepthUtil.horizon_y)
		assert_true(pushed_h != null and is_equal_approx(float(pushed_h), DepthUtil.SCREEN_H), "material's screen_h shader parameter equals DepthUtil.SCREEN_H")
		assert_true(pushed_w != null and is_equal_approx(float(pushed_w), DepthUtil.SCREEN_W), "material's screen_w shader parameter equals DepthUtil.SCREEN_W")
	terrain.queue_free()
	DepthUtil.set_horizon_fraction(DepthUtil.DEFAULT_HORIZON_FRACTION)


## AC5 — no static leak. A test that sets a non-default horizon and restores
## it must leave horizon_fraction() back at the default for whatever test
## runs next in this same process.
func test_no_static_leak() -> void:
	print("\ntest_no_static_leak:")
	DepthUtil.set_horizon_fraction(0.13)
	assert_true(is_equal_approx(DepthUtil.horizon_fraction(), 0.13), "sanity: horizon_fraction reflects the value just set")
	DepthUtil.set_horizon_fraction(DepthUtil.DEFAULT_HORIZON_FRACTION)
	assert_true(is_equal_approx(DepthUtil.horizon_fraction(), 0.625), "horizon_fraction restored to the default after explicit reset")
