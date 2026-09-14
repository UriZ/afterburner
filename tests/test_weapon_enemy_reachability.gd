extends SceneTree

## Integration test (#100): confirms vulcan cannon fire and missiles can still
## physically reach enemies now that enemies fly at altitude above the
## horizon instead of sitting on the ground plane. Drives each weapon's real
## _process() against a real, stationary enemy_jet_2d snapshot at near/mid/far
## approach depths and checks whether their screen distance ever closes to
## within their combined collision radius.

const EnemyJet2D := preload("res://scripts/enemies/enemy_jet_2d.gd")
const VulcanBullet2D := preload("res://scripts/weapons/vulcan_bullet_2d.gd")
const Missile2D := preload("res://scripts/weapons/missile_2d.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Weapon vs Sky-Enemy Reachability Tests (#100) ===")

	for d in [0.15, 0.45, 0.85]:
		test_vulcan_can_reach_enemy_at_depth(d)
	for d in [0.15, 0.45, 0.85]:
		test_missile_can_reach_enemy_at_depth(d)

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func _make_enemy(d: float, altitude: float) -> Node:
	var e := Node.new()
	e.set_script(EnemyJet2D)
	get_root().add_child(e)  # enters tree -> _ready() runs -> joins "enemies" group
	e.configure(0, 0.0, d)  # FIGHTER, centered x, at the given depth
	e.logical_altitude = altitude  # near the top of the sky band — worst case for reach
	return e


func test_vulcan_can_reach_enemy_at_depth(target_depth: float) -> void:
	print("\ntest_vulcan_can_reach_enemy_at_depth(%.2f):" % target_depth)
	var e := _make_enemy(target_depth, EnemyJet2D.ALTITUDE_MAX)
	var b := Node2D.new()
	b.set_script(VulcanBullet2D)
	b.aim_x = 0.0
	get_root().add_child(b)  # enters tree -> _ready() runs _acquire_aim_target()
	var closest_gap: float = INF
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	while t < 1.0 and b.logical_depth > b.MIN_DEPTH:
		b._process(dt)
		t += dt
		var dist: float = b.get_screen_position().distance_to(e.get_screen_position())
		var combined_r: float = b.get_collision_radius() + e.get_collision_radius()
		closest_gap = minf(closest_gap, dist - combined_r)
	assert_true(closest_gap <= 0.0, "vulcan fire closes to within collision radius of enemy at depth %.2f (closest gap %.1fpx)" % [target_depth, closest_gap])
	e.free()
	b.free()


func test_missile_can_reach_enemy_at_depth(target_depth: float) -> void:
	print("\ntest_missile_can_reach_enemy_at_depth(%.2f):" % target_depth)
	var e := _make_enemy(target_depth, EnemyJet2D.ALTITUDE_MAX)
	var m := Node2D.new()
	m.set_script(Missile2D)
	m._ready()
	m.target = e
	var closest_gap: float = INF
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	while t < 5.0 and m.logical_depth > -0.1:
		m._process(dt)
		t += dt
		var dist: float = m.get_screen_position().distance_to(e.get_screen_position())
		var combined_r: float = m.get_collision_radius() + e.get_collision_radius()
		closest_gap = minf(closest_gap, dist - combined_r)
	assert_true(closest_gap <= 0.0, "homing missile closes to within collision radius of enemy at depth %.2f (closest gap %.1fpx)" % [target_depth, closest_gap])
	e.free()
	m.free()
