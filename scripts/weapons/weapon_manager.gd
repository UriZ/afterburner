extends Node3D

## Manages vulcan cannon and missile firing, cooldowns, and lock-on targeting.
## Attach as a child of PlayerJet.

const VulcanBulletScene := preload("res://scenes/weapons/vulcan_bullet.tscn")
const MissileScene := preload("res://scenes/weapons/missile.tscn")

## Vulcan settings
const VULCAN_FIRE_INTERVAL := 0.1  # 10 shots/sec
const BULLET_SPREAD := 0.15  # slight random offset for arcade feel

## Missile settings
const MISSILE_FIRE_COOLDOWN := 0.4  # minimum time between missile shots

## Lock-on settings — defines a rectangular zone in NDC space (0-1)
## centered on screen where lock-on detection works.
const LOCKON_RECT := Rect2(0.3, 0.3, 0.4, 0.4)  # center 40% of screen

var _vulcan_cooldown := 0.0
var _missile_cooldown := 0.0
var _locked_target: Node3D = null

## Container node for spawned projectiles. Set during _ready to keep the
## scene tree clean — projectiles are siblings of the player, not children.
var _projectile_container: Node = null


func _ready() -> void:
	# Projectiles go into a container at the scene root so they don't move
	# with the player. We walk up to the scene root.
	_projectile_container = _find_scene_root()


func _process(delta: float) -> void:
	_vulcan_cooldown = maxf(_vulcan_cooldown - delta, 0.0)
	_missile_cooldown = maxf(_missile_cooldown - delta, 0.0)

	_update_lockon()

	if Input.is_action_pressed("fire_vulcan"):
		_fire_vulcan()

	if Input.is_action_just_pressed("fire_missile"):
		_fire_missile()


func _fire_vulcan() -> void:
	if _vulcan_cooldown > 0.0:
		return

	_vulcan_cooldown = VULCAN_FIRE_INTERVAL

	var bullet: Area3D = VulcanBulletScene.instantiate()
	# Spawn at the player jet's world position with slight random spread
	var spread_x := randf_range(-BULLET_SPREAD, BULLET_SPREAD)
	var spread_y := randf_range(-BULLET_SPREAD * 0.5, BULLET_SPREAD * 0.5)
	bullet.position = get_parent().global_position + Vector3(spread_x, spread_y, 0.0)

	_projectile_container.add_child(bullet)


func _fire_missile() -> void:
	if _missile_cooldown > 0.0:
		return

	if not GameState.use_missile():
		return  # no missiles left

	_missile_cooldown = MISSILE_FIRE_COOLDOWN

	var missile: Area3D = MissileScene.instantiate()
	missile.position = get_parent().global_position
	missile.target = _locked_target  # may be null — that's fine, missile flies straight

	_projectile_container.add_child(missile)


func _update_lockon() -> void:
	# Scan for enemies in the "enemies" group that fall within the lock-on
	# reticle zone on screen.
	_locked_target = null

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var screen_pos := camera.unproject_position(enemy.global_position)
		var viewport_size := get_viewport().get_visible_rect().size

		# Normalize to 0-1
		var ndc := screen_pos / viewport_size

		if LOCKON_RECT.has_point(ndc):
			# Pick the closest enemy to the center of the reticle
			var center := LOCKON_RECT.get_center()
			var d := ndc.distance_to(center)
			if d < best_dist:
				best_dist = d
				_locked_target = enemy


func _find_scene_root() -> Node:
	var node := get_parent()
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node
