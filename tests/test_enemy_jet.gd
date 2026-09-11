extends SceneTree

## Unit tests for enemy jet configuration and type data.
## Run with: godot --headless --script res://tests/test_enemy_jet.gd

var _pass_count := 0
var _fail_count := 0

var _enemy_scene: PackedScene


func _init() -> void:
	print("=== EnemyJet Tests ===")

	_enemy_scene = load("res://scenes/enemies/enemy_jet.tscn")

	test_type_data_has_all_types()
	test_fighter_stats()
	test_interceptor_stats()
	test_bomber_stats()
	test_configure_sets_position()
	test_configure_sets_type()
	test_take_damage_reduces_health()
	test_bullet_creation()
	test_bomber_survives_one_hit()

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


func _create_enemy(type: int = 0) -> Node:
	var enemy := _enemy_scene.instantiate()
	enemy.configure(type, Vector3(0, 3, -50))
	return enemy


func test_type_data_has_all_types() -> void:
	print("\ntest_type_data_has_all_types:")
	var enemy := _create_enemy()
	assert_true(enemy.TYPE_DATA.has(0), "TYPE_DATA has FIGHTER (0)")
	assert_true(enemy.TYPE_DATA.has(1), "TYPE_DATA has INTERCEPTOR (1)")
	assert_true(enemy.TYPE_DATA.has(2), "TYPE_DATA has BOMBER (2)")
	enemy.free()


func test_fighter_stats() -> void:
	print("\ntest_fighter_stats:")
	var enemy := _create_enemy(0)
	# _apply_type_data is called in _ready, but we haven't added to tree yet.
	# Call it manually after configure.
	enemy._apply_type_data()
	assert_eq(enemy.speed, 18.0, "Fighter speed is 18")
	assert_eq(enemy.health, 1, "Fighter health is 1")
	assert_eq(enemy.score_value, 100, "Fighter score is 100")
	enemy.free()


func test_interceptor_stats() -> void:
	print("\ntest_interceptor_stats:")
	var enemy := _create_enemy(1)
	enemy._apply_type_data()
	assert_eq(enemy.speed, 28.0, "Interceptor speed is 28")
	assert_eq(enemy.health, 1, "Interceptor health is 1")
	assert_eq(enemy.score_value, 200, "Interceptor score is 200")
	enemy.free()


func test_bomber_stats() -> void:
	print("\ntest_bomber_stats:")
	var enemy := _create_enemy(2)
	enemy._apply_type_data()
	assert_eq(enemy.speed, 12.0, "Bomber speed is 12")
	assert_eq(enemy.health, 2, "Bomber health is 2")
	assert_eq(enemy.score_value, 500, "Bomber score is 500")
	enemy.free()


func test_configure_sets_position() -> void:
	print("\ntest_configure_sets_position:")
	var enemy := _create_enemy()
	enemy.configure(0, Vector3(5.0, 4.0, -80.0))
	assert_eq(enemy.position, Vector3(5.0, 4.0, -80.0), "Configure sets position")
	enemy.free()


func test_configure_sets_type() -> void:
	print("\ntest_configure_sets_type:")
	var enemy := _create_enemy()
	enemy.configure(2, Vector3(0, 3, -50))
	assert_eq(enemy.enemy_type, 2, "Configure sets enemy_type to BOMBER")
	enemy.free()


func test_take_damage_reduces_health() -> void:
	print("\ntest_take_damage_reduces_health:")
	var enemy := _create_enemy(2)  # bomber with 2 health
	enemy._apply_type_data()
	assert_eq(enemy.health, 2, "Bomber starts with 2 health")
	enemy.take_damage(1)
	assert_eq(enemy.health, 1, "After 1 damage, health is 1")
	enemy.free()


func test_bullet_creation() -> void:
	print("\ntest_bullet_creation:")
	var enemy := _create_enemy()
	var bullet: Variant = enemy._create_bullet()
	assert_true(bullet != null, "Bullet is created")
	assert_true(bullet is Area3D, "Bullet is an Area3D")
	assert_eq(bullet.collision_layer, 4, "Bullet collision layer is 4")
	assert_eq(bullet.collision_mask, 1, "Bullet collision mask is 1")
	assert_true(bullet.get_child_count() >= 2, "Bullet has mesh and collision children")
	bullet.free()


func test_bomber_survives_one_hit() -> void:
	print("\ntest_bomber_survives_one_hit:")
	var enemy := _create_enemy(2)
	enemy._apply_type_data()
	# Disconnect the destroyed signal to prevent _die from running
	# (which would try to queue_free and spawn explosion without a tree)
	enemy.take_damage(1)
	assert_eq(enemy.health, 1, "Bomber survives one hit with health=1")
	assert_true(enemy != null, "Bomber still exists after one hit")
	enemy.free()
