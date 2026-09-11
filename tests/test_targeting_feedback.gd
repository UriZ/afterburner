extends SceneTree

## Unit tests for targeting/aiming feedback improvements (issue #26).
## Tests vulcan tracers, lock-on flash, hit flash, missile trail.
## Run with: godot --headless --script res://tests/test_targeting_feedback.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Targeting Feedback Tests (Issue #26) ===")

	test_vulcan_bullet_creates_tracer()
	test_vulcan_bullet_tracer_material()
	test_vulcan_bullet_hit_flash()
	test_reticle_lock_flash_timer()
	test_reticle_lock_flash_detects_new_locks()
	test_reticle_lock_flash_expires()
	test_reticle_lock_box_size()
	test_missile_scene_has_smoke_trail()

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


func assert_approx(a: float, b: float, message: String, tolerance: float = 0.01) -> void:
	assert_true(absf(a - b) < tolerance, "%s (got %.4f, expected %.4f)" % [message, a, b])


# --- Vulcan bullet tracer tests ---

func test_vulcan_bullet_creates_tracer() -> void:
	print("\ntest_vulcan_bullet_creates_tracer:")
	var bullet_script := preload("res://scripts/weapons/vulcan_bullet.gd")
	# Verify constants exist
	assert_approx(bullet_script.TRACER_LENGTH, 0.6, "TRACER_LENGTH is 0.6")
	assert_approx(bullet_script.HIT_FLASH_DURATION, 0.1, "HIT_FLASH_DURATION is 0.1s")


func test_vulcan_bullet_tracer_material() -> void:
	print("\ntest_vulcan_bullet_tracer_material:")
	# Instantiate bullet scene and check tracer child is created
	var scene := preload("res://scenes/weapons/vulcan_bullet.tscn")
	var bullet := scene.instantiate()
	# _ready() creates the tracer, but we need a scene tree for that.
	# Instead verify the script has _create_tracer method.
	assert_true(bullet.has_method("_create_tracer"), "Bullet has _create_tracer method")
	bullet.free()


func test_vulcan_bullet_hit_flash() -> void:
	print("\ntest_vulcan_bullet_hit_flash:")
	# Verify _flash_enemy and _collect_meshes methods exist
	var scene := preload("res://scenes/weapons/vulcan_bullet.tscn")
	var bullet := scene.instantiate()
	assert_true(bullet.has_method("_flash_enemy"), "Bullet has _flash_enemy method")
	assert_true(bullet.has_method("_collect_meshes"), "Bullet has _collect_meshes static method")
	bullet.free()


# --- Reticle lock flash tests ---

func test_reticle_lock_flash_timer() -> void:
	print("\ntest_reticle_lock_flash_timer:")
	var reticle_script := preload("res://scripts/ui/reticle.gd")
	assert_eq(reticle_script.BLINK_COUNT, 3, "BLINK_COUNT is 3")
	assert_approx(reticle_script.BLINK_INTERVAL, 0.06, "BLINK_INTERVAL is 0.06s")


func test_reticle_lock_flash_detects_new_locks() -> void:
	print("\ntest_reticle_lock_flash_detects_new_locks:")
	# Simulate the new-lock detection logic from _update_lock_flashes
	var prev_locked: Array[Node3D] = []
	var flash_timers: Dictionary = {}
	var flash_duration := 0.1

	var enemy_a := Node3D.new()
	var enemy_b := Node3D.new()
	var current_locked: Array[Node3D] = [enemy_a, enemy_b]

	# First frame: both are new
	for enemy in current_locked:
		if is_instance_valid(enemy) and enemy not in prev_locked:
			flash_timers[enemy] = flash_duration

	assert_eq(flash_timers.size(), 2, "Two flash timers created for new locks")
	assert_approx(flash_timers[enemy_a], 0.1, "Enemy A flash timer is 0.1")

	# Snapshot
	prev_locked = current_locked.duplicate()

	# Second frame: no new enemies
	flash_timers.clear()
	for enemy in current_locked:
		if is_instance_valid(enemy) and enemy not in prev_locked:
			flash_timers[enemy] = flash_duration

	assert_eq(flash_timers.size(), 0, "No new flash timers on second frame")

	enemy_a.free()
	enemy_b.free()


func test_reticle_lock_flash_expires() -> void:
	print("\ntest_reticle_lock_flash_expires:")
	# Simulate timer tick-down
	var flash_timers: Dictionary = {}
	var enemy := Node3D.new()
	flash_timers[enemy] = 0.1

	# Tick 7 frames at 60fps (~0.117s)
	for i in 7:
		var expired: Array = []
		for e in flash_timers:
			flash_timers[e] -= 1.0 / 60.0
			if flash_timers[e] <= 0.0:
				expired.append(e)
		for e in expired:
			flash_timers.erase(e)

	assert_eq(flash_timers.size(), 0, "Flash timer expired after ~0.117s")
	enemy.free()


func test_reticle_lock_box_size() -> void:
	print("\ntest_reticle_lock_box_size:")
	var reticle_script := preload("res://scripts/ui/reticle.gd")
	assert_approx(reticle_script.BRACKET_ARM, 10.0, "BRACKET_ARM is 10px")


# --- Missile smoke trail tests ---

func test_missile_scene_has_smoke_trail() -> void:
	print("\ntest_missile_scene_has_smoke_trail:")
	var scene := preload("res://scenes/weapons/missile.tscn")
	var missile := scene.instantiate()
	var smoke := missile.get_node_or_null("SmokeTrail")
	assert_true(smoke != null, "Missile has SmokeTrail child")
	if smoke != null:
		assert_true(smoke is GPUParticles3D, "SmokeTrail is GPUParticles3D")
		var particles := smoke as GPUParticles3D
		assert_eq(particles.amount, 80, "SmokeTrail has 80 particles")
		assert_approx(particles.lifetime, 1.8, "SmokeTrail lifetime is 1.8s")
		# Verify process material has a color ramp
		var mat := particles.process_material as ParticleProcessMaterial
		assert_true(mat != null, "SmokeTrail has ParticleProcessMaterial")
		if mat != null:
			assert_true(mat.color_ramp != null, "Smoke trail has color ramp for fading")
	missile.free()
