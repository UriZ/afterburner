extends SceneTree

## Unit tests for missile_2d.gd and explosion_2d.gd
## Tests missile data model, trail buffer, and explosion phases.
## Run with: godot --headless --script res://tests/test_missile_2d.gd
##
## NOTE: must extend SceneTree, not Node — `--headless --script` only runs
## the script's main loop if it extends SceneTree/MainLoop. A plain `Node`
## script is loaded but never ticked, so the process hangs until timeout.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

## Minimal stand-in for enemy_jet_2d.gd's public homing contract (logical_x,
## logical_altitude) — missile_2d.gd checks `"logical_altitude" in target`
## duck-typed, so a bare scriptless Node won't expose these as readable
## properties the way a real enemy does.
class FakeTarget extends Node:
	var logical_x: float = 0.0
	var logical_depth: float = 0.0
	var logical_altitude: float = 0.0

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== test_missile_2d ===")
	test_missile_initial_state()
	test_missile_trail_buffer()
	test_missile_collision_radius_scales_with_depth()
	test_explosion_phases()
	test_missile_screen_position()
	test_explosion_radius_clamped()
	test_missile_homes_toward_target_altitude()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func assert_true(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
		_passed += 1
	else:
		push_error("  FAIL: %s" % label)
		_failed += 1


func assert_approx(a: float, b: float, label: String, tolerance: float = 0.01) -> void:
	assert_true(abs(a - b) < tolerance, label)


func _make_missile() -> Node2D:
	var script: GDScript = preload("res://scripts/weapons/missile_2d.gd")
	var m := Node2D.new()
	m.set_script(script)
	get_root().add_child(m)
	# NOTIFICATION_READY isn't propagated synchronously here (no frame loop
	# pumps it during _initialize()), so call _ready() directly — same code
	# the engine would run, just not deferred to a tick that never happens.
	m._ready()
	return m


func _make_explosion() -> Node2D:
	var script: GDScript = preload("res://scripts/effects/explosion_2d.gd")
	var e := Node2D.new()
	e.set_script(script)
	get_root().add_child(e)
	e._ready()
	return e


func test_missile_initial_state() -> void:
	var m := _make_missile()
	assert_true(m.logical_depth == 0.9, "missile starts at depth 0.9")
	assert_true(m.speed == 0.8, "missile speed is 0.8")
	assert_true(m.logical_x == 0.0, "missile starts at center x")
	assert_true(m.is_in_group("missiles"), "missile in 'missiles' group")
	m.queue_free()


func test_missile_trail_buffer() -> void:
	var m := _make_missile()
	# Trail starts empty
	assert_true(m._trail_count == 0, "trail empty at start")
	# Trail max size
	assert_true(m.TRAIL_MAX == 40, "trail max is 40 samples")
	# Trail buffer preallocated
	assert_true(m._trail.size() == 40, "trail buffer size 40")
	m.queue_free()


func test_missile_collision_radius_scales_with_depth() -> void:
	var m := _make_missile()
	m.logical_depth = 0.9
	var r_near: float = m.get_collision_radius()
	m.logical_depth = 0.3
	var r_far: float = m.get_collision_radius()
	assert_true(r_near > r_far, "closer missile has larger collision radius")
	assert_true(r_near > 0.0, "collision radius is positive")
	m.queue_free()


func test_missile_screen_position() -> void:
	var m := _make_missile()
	# At center x=0, d=0.9 — should be near screen center horizontally
	m.logical_x = 0.0
	m.logical_depth = 0.9
	var pos: Vector2 = m.get_screen_position()
	assert_approx(pos.x, 480.0, "center x at logical 0.0", 10.0)
	assert_true(pos.y > _DepthUtil.HORIZON_Y, "missile below horizon")

	# At horizon (depth=0) should be near horizon y
	m.logical_depth = 0.0
	var pos_horizon: Vector2 = m.get_screen_position()
	assert_approx(pos_horizon.y, _DepthUtil.HORIZON_Y, "depth=0 near horizon", 5.0)
	m.queue_free()


func test_explosion_phases() -> void:
	var e := _make_explosion()
	assert_true(e.is_in_group("explosions"), "explosion in 'explosions' group")
	assert_true(e.base_radius == 60.0, "default base_radius 60")
	assert_true(e._sparks.size() == 10, "10 sparks generated")
	assert_true(e._smoke_puffs.size() == 8, "8 smoke puffs generated")
	# Lifetime starts at 0
	assert_true(e._lifetime == 0.0, "lifetime starts at 0")
	e.queue_free()


func test_missile_homes_toward_target_altitude() -> void:
	# Enemies live at altitude, not the ground plane (#100). Missile Y-homing
	# must mirror the existing X-homing onto the target's actual position.
	var m := _make_missile()
	var target := FakeTarget.new()
	target.logical_x = 0.3
	target.logical_depth = 0.2
	target.logical_altitude = 1.0
	m.target = target
	m.logical_altitude = 0.0
	for i in range(30):  # past HOMING_DELAY (0.3s) at 1/60s steps
		m._process(1.0 / 60.0)
	assert_true(m.logical_altitude > 0.0, "missile altitude homes toward the target's nonzero altitude (%.3f)" % m.logical_altitude)
	assert_true(m.get_screen_position().y < _DepthUtil.HORIZON_Y, "homed missile has risen above the horizon toward the airborne target")
	m.queue_free()
	target.queue_free()


func test_explosion_radius_clamped() -> void:
	# Bug #97: close-range enemy kills pass depth_to_scale(d)*240, which peaks
	# near 727 (depth_to_scale maxes at ~3.03) — this used to blow the fire
	# and smoke layers up far past the 960px viewport, leaving only a giant
	# flat glow/smoke circle visible. base_radius must clamp to a sane range.
	var e := _make_explosion()
	e.base_radius = 727.0
	assert_true(e.base_radius <= e.MAX_BASE_RADIUS, "oversized base_radius is clamped down")
	e.base_radius = 1.0
	assert_true(e.base_radius >= e.MIN_BASE_RADIUS, "undersized base_radius is clamped up")
	e.base_radius = 90.0
	assert_true(e.base_radius == 90.0, "in-range base_radius passes through unchanged")
	e.queue_free()
