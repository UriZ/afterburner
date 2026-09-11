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
const SIGHT_RADIUS := 250.0  # pixels — lock-on radius around sight
const LOCK_BREAK_DELAY := 0.5  # seconds before lock breaks after enemy leaves sight
## Dynamic sight: leads the jet, driven by player input
const SIGHT_AHEAD_Y := 120.0  # px above jet screen pos by default
const SIGHT_LEAD_X := 100.0   # px of horizontal lead per unit of input (-1..1)
const SIGHT_LEAD_Y := 70.0    # px of vertical lead per unit of input
const SIGHT_LERP_SPEED := 8.0 # smoothing

## Targeting state — read by Reticle for drawing
var sight_screen_pos := Vector2.ZERO
var locked_enemy: Node3D = null  # single locked target
var locked_enemy_screen_pos := Vector2.ZERO  # enemy's projected screen position
var locked_enemy_bracket_size := 48.0  # bracket size scaled by distance
var _lock_break_timer := 0.0  # time since locked enemy left sight zone

var _vulcan_cooldown := 0.0
var _missile_cooldown := 0.0
var _last_fired_left := false  # alternates wing-pylon launch side

## Container node for spawned projectiles.
var _projectile_container: Node = null


func _ready() -> void:
	_projectile_container = _find_scene_root()
	var center := get_viewport().get_visible_rect().size * 0.5
	sight_screen_pos = center + Vector2(0.0, -SIGHT_AHEAD_Y)


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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# Project jet into screen space
	var player := get_parent() as Node3D
	if player == null:
		return
	var jet_world: Vector3 = player.global_position
	if camera.is_position_behind(jet_world):
		return
	var jet_screen: Vector2 = camera.unproject_position(jet_world)

	# Read raw input direction (-1..1 on each axis)
	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_down", "move_up")  # up = positive

	# Target: above the jet, leading in the input direction
	var target := jet_screen + Vector2(
		input_x * SIGHT_LEAD_X,
		-SIGHT_AHEAD_Y + input_y * SIGHT_LEAD_Y   # negative Y = up on screen
	)

	# Never let sight drop below jet (keep it visually ahead)
	target.y = minf(target.y, jet_screen.y - 20.0)

	sight_screen_pos = sight_screen_pos.lerp(target, SIGHT_LERP_SPEED * delta)


func _update_lockon(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# Find the closest enemy inside the sight radius
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node3D = null
	var best_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if camera.is_position_behind(enemy.global_position):
			continue
		var screen_pos := camera.unproject_position(enemy.global_position)
		var dist_to_sight := screen_pos.distance_to(sight_screen_pos)
		if dist_to_sight <= SIGHT_RADIUS and dist_to_sight < best_dist:
			best_dist = dist_to_sight
			best_enemy = enemy

	if best_enemy != null:
		# Acquired a new lock — beep only on change
		if best_enemy != locked_enemy:
			AudioManager.play_lockon_beep()
		locked_enemy = best_enemy
		locked_enemy_screen_pos = camera.unproject_position(best_enemy.global_position)
		locked_enemy_bracket_size = _get_enemy_bracket_size(best_enemy, camera)
		_lock_break_timer = 0.0
	elif locked_enemy != null:
		# No enemy in zone — tick break timer
		if not is_instance_valid(locked_enemy):
			locked_enemy = null
			_lock_break_timer = 0.0
		else:
			_lock_break_timer += delta
			if _lock_break_timer >= LOCK_BREAK_DELAY:
				locked_enemy = null
				_lock_break_timer = 0.0


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

	_last_fired_left = not _last_fired_left
	var pylon_x := -0.8 if _last_fired_left else 0.8
	var spawn_offset := Vector3(pylon_x, -0.15, 0.1)

	var missile: Area3D = MissileScene.instantiate()
	missile.position = get_parent().global_position + spawn_offset
	missile.target = locked_enemy if is_instance_valid(locked_enemy) else null
	_projectile_container.add_child(missile)


func _get_enemy_bracket_size(enemy: Node3D, camera: Camera3D) -> float:
	## Scale brackets 60px (near) → 36px (far) based on distance to camera.
	var dist := camera.global_position.distance_to(enemy.global_position)
	return clampf(remap(dist, 10.0, 60.0, 60.0, 36.0), 36.0, 60.0)


func _find_scene_root() -> Node:
	var node := get_parent()
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node
