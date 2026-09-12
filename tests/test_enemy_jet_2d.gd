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
	test_get_screen_scale_capped_at_despawn()
	test_get_screen_scale_uncapped_at_far_depth()
	test_max_visual_scale_value()

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
	assert_approx(pos.y, 268.8, 1.0, "At depth=0, y is at horizon 268.8")
	e.free()


func test_get_screen_position_at_depth_one() -> void:
	print("\ntest_get_screen_position_at_depth_one:")
	var e := _make_enemy(0, 0.0, 1.0)
	var pos: Vector2 = e.get_screen_position()
	# At d=1, x_offset=0: x should still be 480, y should be near bottom
	assert_approx(pos.x, 480.0, 1.0, "At depth=1, center x is still 480")
	# sy = 268.8 + 1.0 * (672 - 268.8) * 0.95 = 268.8 + 382.96 = 651.76
	assert_approx(pos.y, 651.76, 2.0, "At depth=1, y is near bottom (651.76)")
	e.free()


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


# --- Scale cap ---

func test_get_screen_scale_capped_at_despawn() -> void:
	print("\ntest_get_screen_scale_capped_at_despawn:")
	# At DESPAWN_DEPTH (0.92): raw depth_to_scale = 0.03 + 0.92^2 * 3 = ~2.567
	# get_screen_scale() must return MAX_VISUAL_SCALE (1.5), not 2.567
	var e := _make_enemy(0, 0.0, 0.92)
	var raw_scale: float = DepthUtil.depth_to_scale(0.92)
	var capped: float = e.get_screen_scale()
	assert_true(raw_scale > e.MAX_VISUAL_SCALE, "raw scale at DESPAWN_DEPTH exceeds cap (%.3f > %.3f)" % [raw_scale, e.MAX_VISUAL_SCALE])
	assert_approx(capped, e.MAX_VISUAL_SCALE, 0.001, "get_screen_scale() returns MAX_VISUAL_SCALE at despawn depth")
	e.free()


func test_get_screen_scale_uncapped_at_far_depth() -> void:
	print("\ntest_get_screen_scale_uncapped_at_far_depth:")
	# At d=0.2: raw = 0.03 + 0.04 * 3 = 0.15 — well below cap
	var e := _make_enemy(0, 0.0, 0.2)
	var raw_scale: float = DepthUtil.depth_to_scale(0.2)
	var capped: float = e.get_screen_scale()
	assert_approx(capped, raw_scale, 0.001, "get_screen_scale() equals raw scale when below cap")
	e.free()


func test_max_visual_scale_value() -> void:
	print("\ntest_max_visual_scale_value:")
	var e := _make_enemy()
	# Cap must be <= 1.5 so enemies are not screen-filling at close range
	assert_true(e.MAX_VISUAL_SCALE <= 1.5, "MAX_VISUAL_SCALE <= 1.5 (got %.2f)" % e.MAX_VISUAL_SCALE)
	# Cap must be > 0.5 so enemies are visible at close range
	assert_true(e.MAX_VISUAL_SCALE > 0.5, "MAX_VISUAL_SCALE > 0.5 (got %.2f)" % e.MAX_VISUAL_SCALE)
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
