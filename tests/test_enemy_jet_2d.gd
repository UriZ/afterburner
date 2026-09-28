extends SceneTree

## Unit tests for enemy_jet_2d.gd — 2D sprite-scaling enemy.
## Run with: godot --headless --script res://tests/test_enemy_jet_2d.gd

const EnemyJet2D := preload("res://scripts/enemies/enemy_jet_2d.gd")
const DepthUtil := preload("res://scripts/game/depth_util.gd")
const EnemyRenderer := preload("res://scripts/enemies/enemy_sprite_renderer.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== EnemyJet2D Tests ===")

	test_type_data_completeness()
	test_fighter_stats()
	test_interceptor_stats()
	test_bomber_stats()
	test_configure_sets_position()
	test_configure_reapplies_type_data()
	test_take_damage_reduces_health()
	test_bomber_survives_one_hit()
	test_get_visual_type()
	test_get_screen_position_at_horizon()
	test_get_screen_position_at_depth_one()
	test_collision_radius_scales_with_depth()
	test_depth_util_scale_formula()
	test_enemy_renderer_colors_count()
	test_get_screen_scale_strictly_increasing_across_depths()
	test_get_screen_scale_bounded_below_saturation()
	test_get_screen_scale_peak_wingspan_in_ab2_band()
	test_get_screen_scale_near_raw_at_far_depth()
	test_min_fire_depth_value()
	test_enemy_does_not_fire_before_min_depth()
	test_enemy_fires_once_past_min_depth()
	test_configure_randomizes_altitude_within_band()
	test_enemy_never_dips_below_horizon()
	test_enemy_y_rises_monotonically_with_depth()
	test_depth_util_altitude_default_matches_ground_formula()

	print("\n=== Bank Angle Tests (#100) ===")
	test_get_bank_angle_zero_drift_is_level()
	test_get_bank_angle_sign_matches_drift_direction()
	test_get_bank_angle_scales_with_drift_magnitude()
	test_get_bank_angle_clamped_to_max()

	print("\n=== Enemy shading / nozzle / bank (#131) ===")
	test_ac1a_bank_ceiling_reaches_the_reference()
	test_ac2_bank_varies_over_an_enemys_life()
	test_oscillation_is_multiplicative_not_additive()
	test_ac3_type0_value_ladder()
	test_ac4_nozzle_construction()
	test_ac5_size_tier_gating_unbroken()
	test_ac6_bank_is_world_local_and_composes_with_roll()
	test_ac8_red_marking_not_shrunk()

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


func assert_approx(a: float, b: float, tol: float, message: String) -> void:
	assert_true(absf(a - b) < tol, "%s (got %.4f, expected %.4f ±%.4f)" % [message, a, b, tol])


func _make_enemy(type: int = 0, lx: float = 0.0, ld: float = 0.0) -> Node:
	var e := Node.new()
	e.set_script(EnemyJet2D)
	e.configure(type, lx, ld)
	return e


# --- Type data ---

func test_type_data_completeness() -> void:
	print("\ntest_type_data_completeness:")
	var e := _make_enemy()
	assert_true(e.TYPE_DATA.has(0), "TYPE_DATA has FIGHTER (0)")
	assert_true(e.TYPE_DATA.has(1), "TYPE_DATA has INTERCEPTOR (1)")
	assert_true(e.TYPE_DATA.has(2), "TYPE_DATA has BOMBER (2)")
	for type in [0, 1, 2]:
		var d: Dictionary = e.TYPE_DATA[type]
		assert_true(d.has("speed"), "type %d has speed" % type)
		assert_true(d.has("health"), "type %d has health" % type)
		assert_true(d.has("score"), "type %d has score" % type)
		assert_true(d.has("visual"), "type %d has visual" % type)
	e.free()


func test_fighter_stats() -> void:
	print("\ntest_fighter_stats:")
	var e := _make_enemy(0)
	assert_approx(e.speed, 0.35, 0.001, "Fighter speed is 0.35")
	assert_eq(e.health, 1, "Fighter health is 1")
	assert_eq(e.score_value, 100, "Fighter score is 100")
	e.free()


func test_interceptor_stats() -> void:
	print("\ntest_interceptor_stats:")
	var e := _make_enemy(1)
	assert_approx(e.speed, 0.55, 0.001, "Interceptor speed is 0.55")
	assert_eq(e.health, 1, "Interceptor health is 1")
	assert_eq(e.score_value, 200, "Interceptor score is 200")
	e.free()


func test_bomber_stats() -> void:
	print("\ntest_bomber_stats:")
	var e := _make_enemy(2)
	assert_approx(e.speed, 0.25, 0.001, "Bomber speed is 0.25")
	assert_eq(e.health, 2, "Bomber health is 2")
	assert_eq(e.score_value, 500, "Bomber score is 500")
	e.free()


# --- Configure ---

func test_configure_sets_position() -> void:
	print("\ntest_configure_sets_position:")
	var e := _make_enemy(0, 0.5, 0.3)
	assert_approx(e.logical_x, 0.5, 0.001, "configure sets logical_x")
	assert_approx(e.logical_depth, 0.3, 0.001, "configure sets logical_depth")
	e.free()


func test_configure_reapplies_type_data() -> void:
	print("\ntest_configure_reapplies_type_data:")
	var e := _make_enemy(0)
	# Now switch to bomber type via configure
	e.configure(2, 0.0, 0.0)
	assert_eq(e.enemy_type, 2, "configure switches to BOMBER")
	assert_eq(e.health, 2, "bomber health applied after reconfigure")
	assert_eq(e.score_value, 500, "bomber score applied after reconfigure")
	e.free()


# --- Damage ---

func test_take_damage_reduces_health() -> void:
	print("\ntest_take_damage_reduces_health:")
	var e := _make_enemy(2)  # bomber, 2 health
	assert_eq(e.health, 2, "Bomber starts with 2 health")
	e.take_damage(1)
	assert_eq(e.health, 1, "After 1 damage: health = 1")
	e.free()


func test_bomber_survives_one_hit() -> void:
	print("\ntest_bomber_survives_one_hit:")
	var e := _make_enemy(2)  # 2 health
	e.take_damage(1)
	assert_eq(e.health, 1, "Bomber survives first hit (health=1)")
	assert_true(is_instance_valid(e), "Bomber node still valid after one hit")
	e.free()


# --- Visual ---

func test_get_visual_type() -> void:
	print("\ntest_get_visual_type:")
	var e0 := _make_enemy(0)
	var e1 := _make_enemy(1)
	var e2 := _make_enemy(2)
	assert_eq(e0.get_visual_type(), 0, "FIGHTER visual index is 0")
	assert_eq(e1.get_visual_type(), 1, "INTERCEPTOR visual index is 1")
	assert_eq(e2.get_visual_type(), 2, "BOMBER visual index is 2")
	e0.free(); e1.free(); e2.free()


# --- Screen position ---

func test_get_screen_position_at_horizon() -> void:
	print("\ntest_get_screen_position_at_horizon:")
	var e := _make_enemy(0, 0.0, 0.0)
	var pos: Vector2 = e.get_screen_position()
	# At d=0, x_offset=0: should be exactly (SCREEN_W/2, HORIZON_Y)
	assert_approx(pos.x, 480.0, 1.0, "At depth=0, center x is 480")
	assert_approx(pos.y, 420.0, 1.0, "At depth=0, y is at horizon 420.0")
	e.free()


func test_get_screen_position_at_depth_one() -> void:
	print("\ntest_get_screen_position_at_depth_one:")
	var e := _make_enemy(0, 0.0, 1.0)
	e.logical_altitude = 1.0  # deterministic — configure() randomizes this (#100)
	var pos: Vector2 = e.get_screen_position()
	# At d=1, x_offset=0: x should still be 480
	assert_approx(pos.x, 480.0, 1.0, "At depth=1, center x is still 480")
	# sy = 420 + 1.0 * (239.4 - 1.0*580) = 420 - 340.6 = 79.4 — well ABOVE the
	# horizon (#100), not near the bottom like the old ground-only formula.
	assert_approx(pos.y, 79.4, 2.0, "At depth=1 with altitude=1.0, y is high in the sky (79.4), not near the bottom")
	assert_true(pos.y < DepthUtil.horizon_y, "enemy sits above the horizon, not below it")
	e.free()


func test_configure_randomizes_altitude_within_band() -> void:
	print("\ntest_configure_randomizes_altitude_within_band:")
	for i in range(20):
		var e := _make_enemy(0, 0.0, 0.0)
		assert_true(e.logical_altitude >= EnemyJet2D.ALTITUDE_MIN and e.logical_altitude <= EnemyJet2D.ALTITUDE_MAX,
			"logical_altitude %.3f within [%.2f, %.2f]" % [e.logical_altitude, EnemyJet2D.ALTITUDE_MIN, EnemyJet2D.ALTITUDE_MAX])
		e.free()


func test_enemy_never_dips_below_horizon() -> void:
	print("\ntest_enemy_never_dips_below_horizon:")
	# Hard rule #100/#8 in criteria.md: enemies occupy the sky, never the
	# ground zone below the horizon, across their whole approach.
	var depths: Array[float] = [0.0, 0.1, 0.3, 0.5, 0.7, EnemyJet2D.DESPAWN_DEPTH]
	var all_above := true
	for d in depths:
		for altitude in [EnemyJet2D.ALTITUDE_MIN, EnemyJet2D.ALTITUDE_MAX]:
			var e := _make_enemy(0, 0.0, d)
			e.logical_altitude = altitude
			if e.get_screen_position().y > DepthUtil.horizon_y + 0.01:
				all_above = false
			e.free()
	assert_true(all_above, "enemy y never exceeds HORIZON_Y across sampled depths and altitude band")


func test_enemy_y_rises_monotonically_with_depth() -> void:
	print("\ntest_enemy_y_rises_monotonically_with_depth:")
	var depths: Array[float] = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, EnemyJet2D.DESPAWN_DEPTH]
	var prev_y: float = INF
	var strictly_rising := true
	for d in depths:
		var e := _make_enemy(0, 0.0, d)
		e.logical_altitude = 1.0
		var y: float = e.get_screen_position().y
		if y >= prev_y:
			strictly_rising = false
		prev_y = y
		e.free()
	assert_true(strictly_rising, "enemy y strictly decreases (rises on screen) as depth increases toward the player")


func test_depth_util_altitude_default_matches_ground_formula() -> void:
	print("\ntest_depth_util_altitude_default_matches_ground_formula:")
	# altitude=0 (the default, used by every pre-existing caller) must
	# reproduce the exact old ground-only result — no regression for ground,
	# player weapons at rest, etc.
	for d in [0.0, 0.3, 0.6, 0.92, 1.0]:
		var with_default: Vector2 = DepthUtil.to_screen(0.2, d)
		var with_explicit_zero: Vector2 = DepthUtil.to_screen(0.2, d, 0.0)
		assert_true(with_default == with_explicit_zero, "to_screen(x, d) == to_screen(x, d, 0.0) at d=%.2f" % d)


# --- Collision ---

func test_collision_radius_scales_with_depth() -> void:
	print("\ntest_collision_radius_scales_with_depth:")
	var e_far := _make_enemy(0, 0.0, 0.2)
	var e_near := _make_enemy(0, 0.0, 0.9)
	var r_far: float = e_far.get_collision_radius()
	var r_near: float = e_near.get_collision_radius()
	assert_true(r_near > r_far, "Near enemy has larger collision radius (%.2f > %.2f)" % [r_near, r_far])
	e_far.free(); e_near.free()


# --- DepthUtil ---

func test_depth_util_scale_formula() -> void:
	print("\ntest_depth_util_scale_formula:")
	# At d=0: scale = 0.03
	assert_approx(DepthUtil.depth_to_scale(0.0), 0.03, 0.001, "depth_to_scale(0) = 0.03")
	# At d=1: scale = 0.03 + 3.0 = 3.03
	assert_approx(DepthUtil.depth_to_scale(1.0), 3.03, 0.001, "depth_to_scale(1) = 3.03")
	# Monotonically increasing
	assert_true(DepthUtil.depth_to_scale(0.5) > DepthUtil.depth_to_scale(0.2),
		"depth_to_scale is monotonically increasing")


# --- Scale saturation (#105: no plateau — strictly increasing, bounded) ---

func test_get_screen_scale_strictly_increasing_across_depths() -> void:
	print("\ntest_get_screen_scale_strictly_increasing_across_depths:")
	# Sample across the full approach range, including the 0.7-0.92 band that
	# used to be a dead plateau under the old minf() cap. Every step must be
	# a strict increase — a future hard cap reintroducing a plateau would
	# fail this immediately.
	var depths: Array[float] = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.92]
	var prev_scale: float = -1.0
	var all_increasing := true
	for d in depths:
		var e := _make_enemy(0, 0.0, d)
		var s: float = e.get_screen_scale()
		if s <= prev_scale:
			all_increasing = false
		prev_scale = s
		e.free()
	assert_true(all_increasing, "get_screen_scale() strictly increases across every sampled depth, no plateau")


func test_get_screen_scale_bounded_below_saturation() -> void:
	print("\ntest_get_screen_scale_bounded_below_saturation:")
	# Never reaches SCALE_SATURATION (asymptotic) or the raw quadratic value
	# it's derived from — both are hard mathematical guarantees of the
	# raw*K/(K+raw) form, not tunable behavior, so this is a regression guard
	# against a future edit reintroducing a value that can exceed either.
	var e := _make_enemy(0, 0.0, 0.92)
	var capped: float = e.get_screen_scale()
	var raw_at_despawn: float = DepthUtil.depth_to_scale(0.92)
	assert_true(capped < e.SCALE_SATURATION, "scale at despawn stays below the asymptote (%.3f < %.3f)" % [capped, e.SCALE_SATURATION])
	assert_true(capped < raw_at_despawn, "scale at despawn stays below the unsaturated raw value (%.3f < %.3f)" % [capped, raw_at_despawn])
	e.free()


func test_get_screen_scale_peak_wingspan_in_ab2_band() -> void:
	print("\ntest_get_screen_scale_peak_wingspan_in_ab2_band:")
	# #105 reopen: enemy at closest approach (DESPAWN_DEPTH) must read as
	# 25-30% of screen width, matching AB2 reference frames — not a
	# far-off speck (13%, the K=3 undershoot) and not screen-filling (#95).
	# Mirrors the renderer's actual draw pipeline: game_world.gd's
	# _draw_enemy_obj() passes s = get_screen_scale()*35.0 into
	# EnemySpriteRenderer.draw_enemy(), whose widest vertex is at
	# pos.x +- s*1.55 (the wing-underside layer), so full wingspan = 3.1*s.
	var e := _make_enemy(0, 0.0, EnemyJet2D.DESPAWN_DEPTH)
	var s: float = e.get_screen_scale() * 35.0
	var wingspan_px: float = 3.1 * s
	var pct: float = wingspan_px / DepthUtil.SCREEN_W * 100.0
	assert_true(pct >= 25.0 and pct <= 30.0, "peak wingspan is 25-30%% of screen width (%.1f%%, %.1fpx)" % [pct, wingspan_px])
	e.free()


func test_get_screen_scale_near_raw_at_far_depth() -> void:
	print("\ntest_get_screen_scale_near_raw_at_far_depth:")
	# At small depths, raw scale is tiny relative to SCALE_SATURATION, so the
	# saturating curve should barely distort it — distant enemies look the
	# same as before this fix.
	var e := _make_enemy(0, 0.0, 0.2)
	var raw_scale: float = DepthUtil.depth_to_scale(0.2)
	var actual: float = e.get_screen_scale()
	assert_approx(actual, raw_scale, 0.02, "get_screen_scale() is close to raw scale far from saturation")
	e.free()


# --- Firing depth gate (#103: no shots until the enemy is visibly close) ---

func test_min_fire_depth_value() -> void:
	print("\ntest_min_fire_depth_value:")
	var e := _make_enemy()
	assert_true(e.MIN_FIRE_DEPTH > 0.0, "MIN_FIRE_DEPTH is positive, gating early shots (%.2f)" % e.MIN_FIRE_DEPTH)
	assert_true(e.MIN_FIRE_DEPTH < e.DESPAWN_DEPTH, "MIN_FIRE_DEPTH is reachable before despawn (%.2f < %.2f)" % [e.MIN_FIRE_DEPTH, e.DESPAWN_DEPTH])
	e.free()


func test_enemy_does_not_fire_before_min_depth() -> void:
	print("\ntest_enemy_does_not_fire_before_min_depth:")
	var e := _make_enemy(0, 0.0, 0.0)
	e.set("_fire_timer", 0.0)  # timer expired, but still below MIN_FIRE_DEPTH
	e._process(0.001)
	assert_true(e.get("_fire_timer") <= 0.0, "fire_timer stays expired (not reset) while below MIN_FIRE_DEPTH")
	e.free()


func test_enemy_fires_once_past_min_depth() -> void:
	print("\ntest_enemy_fires_once_past_min_depth:")
	var e := _make_enemy(0, 0.0, 0.0)
	e.logical_depth = e.MIN_FIRE_DEPTH
	e.set("_fire_timer", 0.0)
	# _process() attempts to fire, which calls _find_player() -> get_tree().
	# Godot logs a harmless "data.tree is null" engine error for the orphaned
	# test node here (get_tree() still correctly returns null and the code
	# handles it); it does not affect the assertion below.
	e._process(0.001)
	assert_approx(e.fire_interval, e.get("_fire_timer"), 0.001, "fire_timer resets to fire_interval once past MIN_FIRE_DEPTH")
	e.free()


# --- Enemy renderer ---

# --- Bank angle (#100: reference frames show enemies canted into their turn) ---

func test_get_bank_angle_zero_drift_is_level() -> void:
	print("\ntest_get_bank_angle_zero_drift_is_level:")
	var e := _make_enemy(0)
	e.configure(0, 0.0, 0.0, 0.0)
	assert_approx(e.get_bank_angle(), 0.0, 0.001, "zero x_drift means no bank")
	e.free()


func test_get_bank_angle_sign_matches_drift_direction() -> void:
	print("\ntest_get_bank_angle_sign_matches_drift_direction:")
	var e := _make_enemy(0)
	e.configure(0, 0.0, 0.0, 0.08)
	assert_true(e.get_bank_angle() > 0.0, "positive drift banks positive (%.3f)" % e.get_bank_angle())
	e.configure(0, 0.0, 0.0, -0.08)
	assert_true(e.get_bank_angle() < 0.0, "negative drift banks negative (%.3f)" % e.get_bank_angle())
	e.free()


func test_get_bank_angle_scales_with_drift_magnitude() -> void:
	print("\ntest_get_bank_angle_scales_with_drift_magnitude:")
	var e := _make_enemy(0)
	# The phase must be pinned to the SAME value on both sides (#131 G4).
	# configure() re-seeds _bank_phase randomly per enemy, and the oscillation
	# factor spans [0.10, 1.00], so comparing two independently-seeded draws
	# makes this test about the random seed rather than about drift: a shallow
	# enemy at factor 1.00 out-banks a steep one at 0.10. That is an
	# intermittent failure, which is worse than a consistent one.
	e.configure(0, 0.0, 0.0, 0.03)
	e._bank_phase = 0.0
	var shallow: float = e.get_bank_angle()
	e.configure(0, 0.0, 0.0, 0.10)
	e._bank_phase = 0.0
	var steep: float = e.get_bank_angle()
	assert_true(steep > shallow, "larger drift banks harder at equal phase (%.3f > %.3f)" % [steep, shallow])
	e.free()


func test_get_bank_angle_clamped_to_max() -> void:
	print("\ntest_get_bank_angle_clamped_to_max:")
	var e := _make_enemy(0)
	e.configure(0, 0.0, 0.0, 10.0)  # absurdly large drift
	assert_approx(e.get_bank_angle(), e.MAX_BANK_RAD, 0.001, "bank never exceeds MAX_BANK_RAD")
	e.configure(0, 0.0, 0.0, -10.0)
	assert_approx(e.get_bank_angle(), -e.MAX_BANK_RAD, 0.001, "bank never exceeds -MAX_BANK_RAD")
	e.free()


func test_enemy_renderer_colors_count() -> void:
	print("\ntest_enemy_renderer_colors_count:")
	assert_eq(EnemyRenderer.ENEMY_COLORS.size(), 3, "3 color sets (FIGHTER/INTERCEPTOR/BOMBER)")
	for i in range(3):
		var c: Dictionary = EnemyRenderer.ENEMY_COLORS[i]
		assert_true(c.has("fuselage"), "type %d has fuselage color" % i)
		assert_true(c.has("engine_intake"), "type %d has engine_intake color" % i)
		assert_true(c.has("dot_color"), "type %d has dot_color" % i)


# ============================================================================
# #131 — enemy shading, nozzles, bank
# ============================================================================

# The widest formation drift in game_manager_2d.gd (scattered: randf_range(-0.12,
# 0.12)). Every figure in AC 1a is anchored to it, so it is named once here.
const MAX_FORMATION_DRIFT: float = 0.12
# The arcade's large enemy banks at ~57 deg (wing axis, 3x magnified crop of
# assets/reference/ab2-arcade-closeup-enemies.jpg: dx 705 / dy 1080).
const ARCADE_PEAK_BANK_DEG: float = 57.0


func test_ac1a_bank_ceiling_reaches_the_reference() -> void:
	print("\ntest_ac1a_bank_ceiling_reaches_the_reference:")
	# DETERMINISTIC half of AC 1 — computed from the constants, so it cannot be
	# passed by a lucky draw or missed by an unlucky one. This is the criterion
	# that makes G1 meaningful: a build that raises only MAX_BANK_RAD and leaves
	# BANK_DRIFT_SCALE at 5.0 computes 34.38 deg and fails here by >20 deg.
	var peak_factor: float = EnemyJet2D.BANK_OSC_BASE + EnemyJet2D.BANK_OSC_AMOUNT
	var raw: float = MAX_FORMATION_DRIFT * EnemyJet2D.BANK_DRIFT_SCALE * peak_factor
	var ceiling_deg: float = rad_to_deg(clampf(raw, -EnemyJet2D.MAX_BANK_RAD, EnemyJet2D.MAX_BANK_RAD))
	print("    max_drift %.2f x scale %.1f x (BASE %.2f + AMOUNT %.2f) = %.4f rad -> %.2f deg"
		% [MAX_FORMATION_DRIFT, EnemyJet2D.BANK_DRIFT_SCALE, EnemyJet2D.BANK_OSC_BASE,
		   EnemyJet2D.BANK_OSC_AMOUNT, raw, ceiling_deg])
	assert_approx(ceiling_deg, ARCADE_PEAK_BANK_DEG, 2.0,
		"computed bank ceiling reaches the measured arcade peak (57 deg +/- 2)")

	# Two-sided by construction: over-scaling clamps and falls out of the band
	# just as under-scaling does. Demonstrated rather than asserted about the
	# shipped values, so the band is shown to PIN the ceiling, not floor it.
	var over: float = rad_to_deg(clampf(MAX_FORMATION_DRIFT * 12.0 * peak_factor, -EnemyJet2D.MAX_BANK_RAD, EnemyJet2D.MAX_BANK_RAD))
	assert_true(absf(over - ARCADE_PEAK_BANK_DEG) > 2.0,
		"the 57+/-2 band is two-sided: scale 12.0 would read %.2f deg and fail it too" % over)

	# The clamp is a GUARD, not the binding constraint, and must sit above the
	# ceiling with headroom. If this inverts, the clamp starts truncating the
	# measured peak — which is exactly the pre-#131 state (0.6000 vs 0.6109).
	assert_true(EnemyJet2D.MAX_BANK_RAD > raw,
		"MAX_BANK_RAD (%.4f) is a non-binding guard above the ceiling (%.4f), headroom %.2f deg"
		% [EnemyJet2D.MAX_BANK_RAD, raw, rad_to_deg(EnemyJet2D.MAX_BANK_RAD - raw)])


func test_ac2_bank_varies_over_an_enemys_life() -> void:
	print("\ntest_ac2_bank_varies_over_an_enemys_life:")
	# Pre-#131 _x_drift was assigned once in configure() and never reassigned,
	# so get_bank_angle() returned the same number forever and a capture caught
	# statues. Drive _process over a full oscillation period and require the
	# bank to actually move. Phase is pinned to 0 so the swept range is
	# deterministic rather than seed-dependent.
	var period: float = TAU / EnemyJet2D.BANK_OSC_RATE
	for drift in [0.05, 0.07, 0.10, 0.12]:  # the four live formation drifts
		var e := _make_enemy(0)
		e.configure(0, 0.0, 0.0, drift)
		e._bank_phase = 0.0
		var lo: float = 1e9
		var hi: float = -1e9
		var steps := 240
		for i in range(steps):
			var b: float = e.get_bank_angle()
			lo = minf(lo, b)
			hi = maxf(hi, b)
			e._bank_phase += EnemyJet2D.BANK_OSC_RATE * (period / float(steps))
		var swing_deg: float = rad_to_deg(hi - lo)
		print("    drift %.2f: bank sweeps %.1f - %.1f deg, swing %.1f deg"
			% [drift, rad_to_deg(lo), rad_to_deg(hi), swing_deg])
		assert_true(swing_deg >= 15.0,
			"drift %.2f sweeps >= 15 deg over its roll cycle (%.1f)" % [drift, swing_deg])
		e.free()


func test_oscillation_is_multiplicative_not_additive() -> void:
	print("\ntest_oscillation_is_multiplicative_not_additive:")
	# An aircraft that is not turning must not be banked. The additive form
	# (drift*scale + sin(phase)*amount) gives a zero-drift enemy a constant
	# +/-20 deg roll for no reason; the multiplicative form gives it zero at
	# EVERY phase. Checked across a full cycle, not at one phase -- the additive
	# form is also zero at phase 0 and pi, so a single-phase check passes it.
	var e := _make_enemy(0)
	e.configure(0, 0.0, 0.0, 0.0)
	var worst := 0.0
	for i in range(64):
		e._bank_phase = TAU * float(i) / 64.0
		worst = maxf(worst, absf(e.get_bank_angle()))
	assert_true(worst < 0.001,
		"a zero-drift enemy is level at every phase (worst %.5f rad) — the additive form peaks at 0.35 rad here" % worst)
	e.free()

	# And the oscillation never flips the sign of a turn: the factor floor is
	# BASE - AMOUNT, which must stay positive or an enemy would momentarily bank
	# AWAY from the direction it is drifting.
	var factor_floor: float = EnemyJet2D.BANK_OSC_BASE - EnemyJet2D.BANK_OSC_AMOUNT
	assert_true(factor_floor > 0.0,
		"oscillation factor floor (BASE - AMOUNT = %.2f) stays positive, so bank never reverses against the drift" % factor_floor)


func test_ac3_type0_value_ladder() -> void:
	print("\ntest_ac3_type0_value_ladder:")
	# G2. Body value = max channel, over the four body tiers. Type 0 was the
	# outlier at 0.102 while types 1 and 2 sat at 0.251 and 0.219.
	var body_tiers := ["fuselage", "wing_base", "wing_underside", "panel_accent"]
	for t in range(3):
		var c: Dictionary = EnemyRenderer.ENEMY_COLORS[t]
		var values: Array[float] = []
		for key in body_tiers:
			var col: Color = c[key]
			values.append(maxf(col.r, maxf(col.g, col.b)))
		var spread: float = values.max() - values.min()
		var distinct := {}
		for v in values:
			distinct[snappedf(v, 0.001)] = true
		print("    type %d: %s  spread %.3f, %d distinct tiers"
			% [t, str(values.map(func(v): return snappedf(v, 0.001))), spread, distinct.size()])
		assert_true(spread >= 0.20, "type %d body value spread >= 0.20 (%.3f)" % [t, spread])
		assert_eq(distinct.size(), 4, "type %d retains 4 distinct body tiers" % t)

		# The nacelle must remain the darkest element — widening the ladder must
		# not be achieved by brightening the interior (spec risk 5).
		var interior: Color = c["engine_interior"]
		var interior_v: float = maxf(interior.r, maxf(interior.g, interior.b))
		assert_true(interior_v < values.min(),
			"type %d engine_interior (%.3f) is darker than every body tier (min %.3f)" % [t, interior_v, values.min()])

	# The wing must read as TWO tiers, not one mass: that is what the spread is
	# for, and it is the pair that carries it.
	var c0: Dictionary = EnemyRenderer.ENEMY_COLORS[0]
	var wt: Color = c0["wing_base"]
	var wu: Color = c0["wing_underside"]
	var wing_gap: float = maxf(wt.r, maxf(wt.g, wt.b)) - maxf(wu.r, maxf(wu.g, wu.b))
	assert_true(wing_gap >= 0.15,
		"type 0's two wing tiers are separated by >= 0.15 in value (%.3f; was 0.059)" % wing_gap)

	# Hue is preserved — G2 is a value change, not a recolour.
	for key in body_tiers:
		var col: Color = c0[key]
		assert_true(col.h * 360.0 > 70.0 and col.h * 360.0 < 110.0,
			"type 0 %s keeps its green hue (%.1f deg)" % [key, col.h * 360.0])


func test_ac4_nozzle_construction() -> void:
	print("\ntest_ac4_nozzle_construction:")
	# G3. Radii are literals in the renderer's draw calls, so they are asserted
	# through the same constants the draw uses (see test_ac8 for the guard on
	# the red disc itself).
	var red := 0.13
	var interior := 0.087
	var core := 0.052
	var ratio: float = (core * 2.0) / (red * 2.0)
	print("    core/red diameter ratio = %.3f" % ratio)
	assert_true(ratio >= 0.38 and ratio <= 0.47,
		"core/red diameter ratio in [0.38, 0.47] (%.3f)" % ratio)
	# Companion size constraint: the core must not swallow the dark rim.
	assert_true(core < interior and interior < red,
		"core (%.3f) < interior (%.3f) < red (%.3f) — the dark rim survives" % [core, interior, red])
	# And the construction the criteria rule requires: dark rim, hot core.
	for t in range(3):
		var c: Dictionary = EnemyRenderer.ENEMY_COLORS[t]
		var i_col: Color = c["engine_interior"]
		var g_col: Color = c["engine_glow"]
		var i_v: float = maxf(i_col.r, maxf(i_col.g, i_col.b))
		var g_v: float = maxf(g_col.r, maxf(g_col.g, g_col.b))
		assert_true(g_v > i_v, "type %d glow core (%.3f) is hotter than its dark rim (%.3f)" % [t, g_v, i_v])


func test_ac5_size_tier_gating_unbroken() -> void:
	print("\ntest_ac5_size_tier_gating_unbroken:")
	# The thresholds are deliberately untouched (the spec has no measurement of
	# the arcade's smallest tier, so it does not move them). This checks they
	# still work: just above each threshold the corresponding layer appears and
	# nothing below it disappears.
	#
	# Monotonicity is asserted only WITHIN the layered regime (s >= 1.5). Below
	# that the renderer is in dot MODE — a single circle with no orientation —
	# and the dot is replaced by the sprite rather than kept under it, so "dot"
	# legitimately vanishes at the 1.5 boundary. The first version of this test
	# treated dot as a layer and failed on exactly that; the model was wrong,
	# not the renderer. The mode switch is asserted separately below.
	var ok := true
	for s in [1.6, 4.1, 6.1, 8.1, 10.1, 16.1, 30.0]:
		var layers_at_s := _layers_visible_at(s)
		var layers_bigger := _layers_visible_at(s + 6.0)
		for layer in layers_at_s:
			if layer not in layers_bigger:
				ok = false
				print("    layer '%s' present at s=%.1f but MISSING at s=%.1f" % [layer, s, s + 6.0])
	assert_true(ok, "size-tier gating is monotone above s=1.5: no layer disappears as the sprite grows")
	assert_eq(_layers_visible_at(1.4), ["dot"], "below 1.5 the sprite is dot-only")
	assert_true("dot" not in _layers_visible_at(1.6),
		"at 1.6 the dot is REPLACED by the layered sprite, not drawn under it (mode switch, not a lost layer)")
	assert_true("leading_edge" in _layers_visible_at(4.1), "leading edge appears just above s=4")
	assert_true("glow_core" in _layers_visible_at(6.1), "hot core appears just above s=6")
	assert_true("canopy" in _layers_visible_at(8.1), "canopy appears just above s=8")
	assert_true("tail" in _layers_visible_at(10.1), "tail stub appears just above s=10")
	assert_true("chevrons" in _layers_visible_at(16.1), "wing-tip chevrons appear just above s=16")


func _layers_visible_at(s: float) -> Array:
	# Mirrors enemy_sprite_renderer.gd's gate structure. Kept as a list rather
	# than a count so a MISSING layer names itself in the failure output.
	if s < 1.5:
		return ["dot"]
	var layers := ["wing_underside", "wing_base", "fuselage", "panel_stripe", "intake"]
	if s >= 4.0:
		layers.append("leading_edge")
		layers.append("intake_interior")
	if s > 6.0:
		layers.append("glow_core")
	if s >= 8.0:
		layers.append("canopy")
	if s >= 10.0:
		layers.append("tail")
	if s >= 16.0:
		layers.append("chevrons")
	return layers


func test_ac6_bank_is_world_local_and_composes_with_roll() -> void:
	print("\ntest_ac6_bank_is_world_local_and_composes_with_roll:")
	# Enemies are plain Node, drawn into GameWorld's canvas, so once world roll
	# is applied to that canvas the drawn orientation is world_roll + bank for
	# free. get_bank_angle() must therefore return the enemy's OWN bank only.
	# Adding roll_rad here would make the composed orientation 100 deg instead
	# of 60 — invisible in a level-flight capture, which is why this is a test
	# and not a comment.
	var saved_roll: float = DepthUtil.roll_rad
	DepthUtil.roll_rad = deg_to_rad(40.0)

	# Solve the drift that yields exactly 20 deg of bank at a pinned phase.
	var e := _make_enemy(0)
	e.configure(0, 0.0, 0.0, 0.0)
	e._bank_phase = PI / 2.0  # factor == BASE + AMOUNT == 1.0, the ceiling case
	var factor: float = EnemyJet2D.BANK_OSC_BASE + EnemyJet2D.BANK_OSC_AMOUNT
	e._x_drift = deg_to_rad(20.0) / (EnemyJet2D.BANK_DRIFT_SCALE * factor)

	var local_deg: float = rad_to_deg(e.get_bank_angle())
	assert_approx(local_deg, 20.0, 0.5,
		"get_bank_angle() returns the enemy's OWN bank (20 deg), NOT 60 — it must not fold in roll_rad")

	var composed_deg: float = rad_to_deg(DepthUtil.roll_rad + e.get_bank_angle())
	assert_approx(composed_deg, 60.0, 1.0,
		"world roll 40 deg + enemy bank 20 deg composes to 60 deg +/- 1 (got %.2f)" % composed_deg)

	# What the negative control would produce, stated so the failure mode is
	# named in the output rather than left to a reader's arithmetic: if
	# get_bank_angle() added roll_rad it would return 60 locally and the canvas
	# would add 40 again.
	var double_counted: float = rad_to_deg(DepthUtil.roll_rad + (DepthUtil.roll_rad + e.get_bank_angle()))
	assert_approx(double_counted, 100.0, 1.0,
		"double-counting roll would read 100 deg — the value this test exists to exclude")
	e.free()
	DepthUtil.roll_rad = saved_roll

	# Structural half: nothing in the enemy path may read roll_rad at all.
	# Validated against the real file, and the negative control in the #131
	# control script confirms it trips when roll_rad is added to the enemy path.
	for path in ["res://scripts/enemies/enemy_jet_2d.gd", "res://scripts/enemies/enemy_sprite_renderer.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_true(f != null, "%s is readable for the roll_rad scan" % path)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		var offending := 0
		for line in src.split("\n"):
			var t := line.strip_edges()
			if t.begins_with("#") or t.begins_with("##"):
				continue  # the contract is DOCUMENTED in comments on purpose
			if "roll_rad" in t:
				offending += 1
				print("    %s: executable line references roll_rad: %s" % [path, t])
		assert_eq(offending, 0, "%s never reads roll_rad in executable code" % path)


func test_ac8_red_marking_not_shrunk() -> void:
	print("\ntest_ac8_red_marking_not_shrunk:")
	# Ours is 9% of wingspan against the arcade's 14% — already SMALLER. The
	# cycle-1 "red roundel" wording invites shrinking it; this guards against
	# acting on that, the same way #100's comment guards the oversized version.
	var f := FileAccess.open("res://scripts/enemies/enemy_sprite_renderer.gd", FileAccess.READ)
	assert_true(f != null, "renderer source is readable")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	assert_true("s * 0.13, c[\"engine_intake\"]" in src,
		"the red intake disc is still drawn at radius s*0.13 (AC 8 — do not shrink a non-gap)")
	assert_true("s * 0.087, c[\"engine_interior\"]" in src,
		"the dark interior is still s*0.087")
	assert_true("s * 0.052, c[\"engine_glow\"]" in src,
		"the hot core is s*0.052 (G3: 25% -> 40% of the red diameter)")
