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
	assert_true(pos.y < DepthUtil.HORIZON_Y, "enemy sits above the horizon, not below it")
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
			if e.get_screen_position().y > DepthUtil.HORIZON_Y + 0.01:
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

func test_enemy_renderer_colors_count() -> void:
	print("\ntest_enemy_renderer_colors_count:")
	assert_eq(EnemyRenderer.ENEMY_COLORS.size(), 3, "3 color sets (FIGHTER/INTERCEPTOR/BOMBER)")
	for i in range(3):
		var c: Dictionary = EnemyRenderer.ENEMY_COLORS[i]
		assert_true(c.has("fuselage"), "type %d has fuselage color" % i)
		assert_true(c.has("engine_intake"), "type %d has engine_intake color" % i)
		assert_true(c.has("dot_color"), "type %d has dot_color" % i)
