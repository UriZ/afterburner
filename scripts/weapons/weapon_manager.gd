extends Node3D

## Manages vulcan cannon, missile firing, targeting sight, and lock-on system.
## Attach as a child of PlayerJet.

const VulcanBulletScene := preload("res://scenes/weapons/vulcan_bullet.tscn")
const MissileScene := preload("res://scenes/weapons/missile.tscn")

## Vulcan settings
const VULCAN_FIRE_INTERVAL := 0.06  # ~17 shots/sec — rapid arcade feel
const BULLET_SPREAD := 0.12  # slight random offset for arcade feel

## Missile settings
const MISSILE_FIRE_COOLDOWN := 0.4  # minimum time between missile shots

## Sight settings
const SIGHT_RADIUS := 90.0  # pixels — generous lock-on circle (arcade feel)
const MAX_LOCKS := 3
const LOCK_BREAK_DELAY := 0.5  # seconds before lock breaks after enemy leaves sight
const SIGHT_SPEED := 10.0  # lerp responsiveness — snappy tracking
const SIGHT_OFFSET_SCALE := 0.45  # fraction of screen the sight leads ahead (arcade-sized movement)

## Targeting state — read by Reticle for drawing
var sight_screen_pos := Vector2.ZERO
var locked_enemies: Array = []  # untyped — freed enemies can't be erased from typed arrays
var _lock_timers: Dictionary = {}  # enemy -> float (time since enemy left sight zone)

var _vulcan_cooldown := 0.0
var _missile_cooldown := 0.0

## Container node for spawned projectiles.
var _projectile_container: Node = null


func _ready() -> void:
	_projectile_container = _find_scene_root()
	sight_screen_pos = get_viewport().get_visible_rect().size * 0.5


func _process(delta: float) -> void:
	_vulcan_cooldown = maxf(_vulcan_cooldown - delta, 0.0)
	_missile_cooldown = maxf(_missile_cooldown - delta, 0.0)

	_update_sight(delta)
	_update_lockon(delta)

	if Input.is_action_pressed("fire_vulcan"):
		_fire_vulcan()

	if Input.is_action_just_pressed("fire_missile"):
		_fire_missile()


func _update_sight(delta: float) -> void:
	# Screen-space input: X is normal, Y is INVERTED (screen Y grows downward,
	# but "move_up" should move the sight UP on screen = negative Y).
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")  # flipped: up->negative screen Y
	)
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var target_pos := center + input * viewport_size * SIGHT_OFFSET_SCALE
	sight_screen_pos = sight_screen_pos.lerp(target_pos, SIGHT_SPEED * delta)

	var margin := 40.0
	sight_screen_pos.x = clampf(sight_screen_pos.x, margin, viewport_size.x - margin)
	sight_screen_pos.y = clampf(sight_screen_pos.y, margin, viewport_size.y - margin)


func _update_lockon(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var in_zone_this_frame: Array[Node3D] = []

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if camera.is_position_behind(enemy.global_position):
			continue
		var screen_pos := camera.unproject_position(enemy.global_position)
		var dist_to_sight := screen_pos.distance_to(sight_screen_pos)

		if dist_to_sight <= SIGHT_RADIUS:
			in_zone_this_frame.append(enemy)
			if enemy not in locked_enemies and locked_enemies.size() < MAX_LOCKS:
				locked_enemies.append(enemy)
				_lock_timers.erase(enemy)
				AudioManager.play_lockon_beep()
			elif enemy in locked_enemies:
				_lock_timers.erase(enemy)

	# Update break timers for locked enemies not in zone this frame
	# Use untyped array because freed objects can't be appended to Array[Node3D]
	var to_remove: Array = []
	for enemy in locked_enemies:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
			continue
		if enemy not in in_zone_this_frame:
			if enemy not in _lock_timers:
				_lock_timers[enemy] = 0.0
			_lock_timers[enemy] += delta
			if _lock_timers[enemy] >= LOCK_BREAK_DELAY:
				to_remove.append(enemy)

	for enemy in to_remove:
		locked_enemies.erase(enemy)
		_lock_timers.erase(enemy)


func get_sight_world_position() -> Vector3:
	## Returns a world-space point along the camera ray through the sight.
	## Distance of 80 units ensures bullets converge at enemy engagement range
	## (enemies spawn at Z=-50, camera at Z=0).
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(0, 0, -50)
	var from := camera.project_ray_origin(sight_screen_pos)
	var dir := camera.project_ray_normal(sight_screen_pos)
	return from + dir * 80.0


func _fire_vulcan() -> void:
	if _vulcan_cooldown > 0.0:
		return

	_vulcan_cooldown = VULCAN_FIRE_INTERVAL
	AudioManager.play_vulcan_fire()

	var bullet: Area3D = VulcanBulletScene.instantiate()
	var player_pos: Vector3 = get_parent().global_position
	var spread_x := randf_range(-BULLET_SPREAD, BULLET_SPREAD)
	var spread_y := randf_range(-BULLET_SPREAD * 0.5, BULLET_SPREAD * 0.5)
	bullet.position = player_pos + Vector3(spread_x, spread_y, 0.0)

	# Aim toward sight world position
	var sight_world := get_sight_world_position()
	var aim_dir := (sight_world - bullet.position).normalized()
	if aim_dir.z > -0.3:
		aim_dir.z = -0.3
		aim_dir = aim_dir.normalized()
	bullet.aim_direction = aim_dir

	_projectile_container.add_child(bullet)


func _fire_missile() -> void:
	if _missile_cooldown > 0.0:
		return
	if not GameState.use_missile():
		return

	_missile_cooldown = MISSILE_FIRE_COOLDOWN
	AudioManager.play_missile_launch()

	var missile: Area3D = MissileScene.instantiate()
	missile.position = get_parent().global_position
	missile.target = _get_nearest_locked_enemy()
	_projectile_container.add_child(missile)


func _get_nearest_locked_enemy() -> Node3D:
	var player_pos: Vector3 = get_parent().global_position
	var best: Node3D = null
	var best_dist := INF
	for enemy in locked_enemies:
		if not is_instance_valid(enemy):
			continue
		var d: float = player_pos.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _find_scene_root() -> Node:
	var node := get_parent()
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node
