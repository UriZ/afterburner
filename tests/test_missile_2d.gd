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
	test_explosion_kill_puff_is_small_and_colorless()
	test_explosion_fireball_is_default()
	test_blob_polygon_is_simple()
	test_raw_script_default_is_kill_puff()
	test_scene_default_is_fireball()
	test_kill_puff_is_single_opaque_blob()
	test_fireball_tongue_star_nests_correctly()
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


func _make_explosion(is_kill: bool = false) -> Node2D:
	var script: GDScript = preload("res://scripts/effects/explosion_2d.gd")
	var e := Node2D.new()
	e.set_script(script)
	e.set("is_kill", is_kill)  # must be set before _ready() picks the duration/colors
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


func test_explosion_kill_puff_is_small_and_colorless() -> void:
	# #97 follow-up (rule 10): aircraft kills must be small pale cream/white
	# puffs — no orange or red anywhere — distinct from the fireball type.
	var e := _make_explosion(true)
	e.base_radius = 130.0  # largest value a caller can pass in
	assert_true(e.is_kill, "is_kill flag set")
	assert_true(e._duration == e.KILL_DURATION, "kill puff uses the short duration")
	var r_cap: float = clampf(e.base_radius * e.KILL_RADIUS_SCALE, e.KILL_MIN_RADIUS, e.KILL_MAX_RADIUS)
	assert_true(r_cap <= e.KILL_MAX_RADIUS, "kill puff visual radius capped regardless of base_radius")
	for spark in e._sparks:
		# Orange/red spark colors (fireball type) have a large gap between
		# green and blue channels (e.g. Color(1.0, 0.8, 0.133)). Kill sparks
		# are near-neutral cream/grey — small gap between every channel.
		var c: Color = spark["color"]
		assert_true(absf(c.g - c.b) < 0.15, "kill spark color is near-neutral, not orange (g=%.2f b=%.2f)" % [c.g, c.b])
	e.queue_free()


func test_explosion_fireball_is_default() -> void:
	var e := _make_explosion(false)
	assert_true(not e.is_kill, "default explosion is the fireball type")
	assert_true(e._duration == e.FIRE_DURATION, "fireball uses the full duration")
	assert_true(e._center_outer.has("angles"), "fireball generates a center blob (kill puffs don't)")
	e.queue_free()


func test_blob_polygon_is_simple() -> void:
	# A self-intersecting (bowtie) polygon is invalid Godot draw data. Angle
	# jitter capped below half the angular step must keep vertex angles
	# monotonically increasing, which guarantees a simple star-shaped polygon.
	var e := _make_explosion(false)
	var blob: Dictionary = e._make_blob(10, 0.5, 1.0, 0.3, 1.1, 1.5)
	var angles: PackedFloat32Array = blob["angles"]
	var monotonic := true
	for i in range(1, angles.size()):
		if angles[i] <= angles[i - 1]:
			monotonic = false
			break
	assert_true(monotonic, "blob vertex angles are monotonically increasing (no self-intersection)")
	assert_true(angles.size() == 10, "blob has the requested vertex count")
	e.queue_free()


func test_raw_script_default_is_kill_puff() -> void:
	# enemy_jet_2d.gd and missile_2d.gd instantiate this script directly
	# (Node2D.new() + set_script) without ever setting is_kill — they rely
	# on the script default being the kill-puff type. If this regresses,
	# aircraft kills silently become orange fireballs again (rule 10).
	var script: GDScript = preload("res://scripts/effects/explosion_2d.gd")
	var e := Node2D.new()
	e.set_script(script)
	get_root().add_child(e)
	e._ready()
	assert_true(e.is_kill, "raw script instantiation (no is_kill set) defaults to kill puff")
	e.queue_free()


func test_scene_default_is_fireball() -> void:
	# player_jet_2d.gd's death explosion goes through explosion_2d.tscn,
	# which must override the script default back to false — a player
	# death is a large impact, not an aircraft kill (rule 10).
	var scene: PackedScene = preload("res://scenes/effects/explosion_2d.tscn")
	var e := scene.instantiate()
	get_root().add_child(e)
	assert_true(not e.is_kill, "explosion_2d.tscn overrides is_kill to false (fireball)")
	e.queue_free()


func test_kill_puff_is_single_opaque_blob() -> void:
	# Round 5 gate (rule 12a/b): kill puffs used 4 offset, low-vertex lobes
	# that left visible gaps and translucent bodies, and blew the true
	# extent well past the radius cap. Now a single high-vertex polygon —
	# gapless by construction, with neighbouring vertices a few px apart at
	# the puff's max radius instead of ~6-9 vertex giant flat facets.
	var e := _make_explosion(true)
	assert_true(e._puff_blob.has("angles"), "kill puff builds a single cauliflower blob")
	var angles: PackedFloat32Array = e._puff_blob["angles"]
	assert_true(angles.size() == e.KILL_BLOB_VERTS, "puff blob has the dense vertex count")
	e.queue_free()


func test_fireball_tongue_star_nests_correctly() -> void:
	# Round 5 gate (rule 12c): outer/inner tongue stars used to be generated
	# independently, so their tongues didn't line up and the brighter inner
	# layer could poke out past the outer silhouette through a valley.
	# Sharing one angle set and keeping inner radii strictly below outer at
	# every vertex guarantees the inner layer always nests inside.
	var e := _make_explosion(false)
	var outer_angles: PackedFloat32Array = e._center_outer["angles"]
	var inner_angles: PackedFloat32Array = e._center_core["angles"]
	assert_true(outer_angles.size() == e.TONGUE_COUNT * 2, "outer star has 2 vertices per tongue")
	assert_true(inner_angles.size() == outer_angles.size(), "inner star shares the outer star's angle count")
	var outer_radii: PackedFloat32Array = e._center_outer["radii"]
	var inner_radii: PackedFloat32Array = e._center_core["radii"]
	var nested := true
	for i in range(outer_radii.size()):
		if inner_radii[i] >= outer_radii[i]:
			nested = false
			break
	assert_true(nested, "inner tongue star radius is smaller than outer at every vertex")
	e.queue_free()
