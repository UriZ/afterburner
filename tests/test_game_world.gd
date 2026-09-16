extends SceneTree

## Unit tests for game_world.gd collision detection.
## Focus: the invincibility collision grace fix (#103) — a body already
## overlapping the player's collision radius at the instant invincibility
## expires must NOT register an instant, un-dodgeable hit. It should only be
## eligible for a hit after it separates from the player and genuinely
## re-enters the radius.
## Run with: godot --headless --script res://tests/test_game_world.gd

## NOTE: runs from _process(), not _initialize() — game_world.gd's collision
## checks depend on get_tree().get_nodes_in_group(), and in --headless
## --script mode the SceneTree root isn't actually inside the tree yet during
## _initialize() (get_tree() returns null there). It only becomes usable once
## the main loop starts ticking _process().

const GameWorld := preload("res://scripts/game/game_world.gd")
const EnemyJet2D := preload("res://scripts/enemies/enemy_jet_2d.gd")

var _pass_count := 0
var _fail_count := 0
var _has_run := false


class MockPlayer extends Node2D:
	var vulnerable: bool = true
	var hit_count: int = 0
	var pos: Vector2 = Vector2(480.0, 380.0)
	var radius: float = 78.0

	func _init() -> void:
		add_to_group("player")

	func get_screen_position() -> Vector2:
		return pos

	func get_collision_radius() -> float:
		return radius

	func is_vulnerable() -> bool:
		return vulnerable

	func hit() -> void:
		hit_count += 1


class MockEnemy extends Node2D:
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 30.0
	var damage_count: int = 0
	# Deep enough to clear game_world.gd's RAM_MIN_DEPTH ramming-eligibility
	# gate (#103) by default — these tests exercise grace/overlap logic, not
	# the depth gate itself, so default to "always collidable".
	var logical_depth: float = 1.0

	func _init() -> void:
		add_to_group("enemies")

	func get_screen_position() -> Vector2:
		return pos

	func get_collision_radius() -> float:
		return radius

	func take_damage(_amount: int) -> void:
		damage_count += 1


class MockBullet extends Node2D:
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 6.0

	func _init() -> void:
		add_to_group("enemy_bullets")

	func get_screen_position() -> Vector2:
		return pos

	func get_collision_radius() -> float:
		return radius


func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true

	print("=== GameWorld Collision Tests ===")

	test_grace_exempts_overlap_present_at_invincibility_end()
	test_grace_rearms_after_separation()
	test_normal_vulnerable_collision_unaffected()
	test_grace_covers_multiple_simultaneous_overlaps()
	test_bullet_grace_matches_enemy_grace()
	test_ramming_gated_by_depth()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
	return true


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func _make_world() -> Node2D:
	var world: Node2D = GameWorld.new()
	get_root().add_child(world)
	return world


# Each test calls world.free() (immediate) rather than queue_free() at the
# end — queue_free() defers group removal until idle time, which never
# arrives between tests running back to back inside a single _process()
# call, leaking stale mock player/enemy nodes into the next test's
# get_nodes_in_group() results.


# --- Tests ---

func test_grace_exempts_overlap_present_at_invincibility_end() -> void:
	print("\ntest_grace_exempts_overlap_present_at_invincibility_end:")
	var world: Node2D = _make_world()
	var player := MockPlayer.new()
	player.vulnerable = false  # still invincible
	world.add_child(player)
	var enemy := MockEnemy.new()
	enemy.pos = player.pos  # fully overlapping the whole time
	world.add_child(enemy)

	world._check_collisions()  # while invincible: no-op, establishes _was_vulnerable=false
	assert_true(player.hit_count == 0, "no hit while still invincible")

	player.vulnerable = true  # invincibility expires this frame, enemy never moved
	world._check_collisions()
	assert_true(player.hit_count == 0, "pre-loaded overlap does not hit on invincibility expiry")
	assert_true(enemy.damage_count == 0, "enemy also exempted (mutual body-collision branch)")

	world.free()


func test_grace_rearms_after_separation() -> void:
	print("\ntest_grace_rearms_after_separation:")
	var world: Node2D = _make_world()
	var player := MockPlayer.new()
	player.vulnerable = false
	world.add_child(player)
	var enemy := MockEnemy.new()
	enemy.pos = player.pos
	world.add_child(enemy)

	world._check_collisions()
	player.vulnerable = true
	world._check_collisions()
	assert_true(player.hit_count == 0, "exempted immediately after expiry")

	enemy.pos = player.pos + Vector2(1000.0, 0.0)  # separates
	world._check_collisions()
	assert_true(player.hit_count == 0, "still no hit while separated")

	enemy.pos = player.pos  # genuine re-approach
	world._check_collisions()
	assert_true(player.hit_count == 1, "real hit registers after separation + re-entry")

	world.free()


func test_normal_vulnerable_collision_unaffected() -> void:
	print("\ntest_normal_vulnerable_collision_unaffected:")
	var world: Node2D = _make_world()
	var player := MockPlayer.new()
	player.vulnerable = true  # already vulnerable, no invincibility transition involved
	world.add_child(player)
	var enemy := MockEnemy.new()
	enemy.pos = player.pos + Vector2(1000.0, 0.0)  # far away initially
	world.add_child(enemy)

	world._check_collisions()
	assert_true(player.hit_count == 0, "no hit while enemy is out of range")

	enemy.pos = player.pos  # normal mid-game approach into collision range
	world._check_collisions()
	assert_true(player.hit_count == 1, "ordinary collision still registers immediately")

	world.free()


func test_grace_covers_multiple_simultaneous_overlaps() -> void:
	print("\ntest_grace_covers_multiple_simultaneous_overlaps:")
	var world: Node2D = _make_world()
	var player := MockPlayer.new()
	player.vulnerable = false
	world.add_child(player)
	var enemy1 := MockEnemy.new()
	enemy1.pos = player.pos
	world.add_child(enemy1)
	var enemy2 := MockEnemy.new()
	enemy2.pos = player.pos
	world.add_child(enemy2)

	world._check_collisions()
	player.vulnerable = true
	world._check_collisions()

	assert_true(world._collision_ignore.has(enemy1.get_instance_id()), "first overlapping body armed into grace list")
	assert_true(world._collision_ignore.has(enemy2.get_instance_id()), "second overlapping body also armed (not just the first)")
	assert_true(player.hit_count == 0, "no hit with two pre-loaded overlaps")

	world.free()


# Regression test for the #103 reopen: every enemy spawns at logical_depth=0,
# ~40px from the player's screen-Y — well inside the player's 78px collision
# radius regardless of x — so an un-gated body-collision check let a freshly
# spawned, not-yet-visible enemy register a hit within a frame of appearing,
# bypassing the invincibility grace entirely (grace only exempts bodies
# present at the invincible->vulnerable transition, not ones spawned after).
func test_ramming_gated_by_depth() -> void:
	print("\ntest_ramming_gated_by_depth:")
	var world: Node2D = _make_world()
	var player := MockPlayer.new()
	player.vulnerable = true
	world.add_child(player)
	var enemy := MockEnemy.new()
	enemy.pos = player.pos  # fully overlapping
	enemy.logical_depth = EnemyJet2D.RAM_MIN_DEPTH - 0.01
	world.add_child(enemy)

	world._check_collisions()
	assert_true(player.hit_count == 0, "overlapping enemy below RAM_MIN_DEPTH does not hit")

	enemy.logical_depth = EnemyJet2D.RAM_MIN_DEPTH
	world._check_collisions()
	assert_true(player.hit_count == 1, "same overlap hits once enemy reaches RAM_MIN_DEPTH")

	world.free()


func test_bullet_grace_matches_enemy_grace() -> void:
	print("\ntest_bullet_grace_matches_enemy_grace:")
	var world: Node2D = _make_world()
	var player := MockPlayer.new()
	player.vulnerable = false
	world.add_child(player)
	var bullet := MockBullet.new()
	bullet.pos = player.pos
	world.add_child(bullet)

	world._check_collisions()
	player.vulnerable = true
	world._check_collisions()
	assert_true(player.hit_count == 0, "pre-loaded bullet overlap exempted on invincibility expiry")

	bullet.pos = player.pos + Vector2(1000.0, 0.0)
	world._check_collisions()
	bullet.pos = player.pos
	world._check_collisions()
	assert_true(player.hit_count == 1, "bullet hit registers after separation + re-entry")

	world.free()
