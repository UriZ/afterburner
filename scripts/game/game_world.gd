extends Node2D

## Central 2D rendering node.
## Draws sky, ground, and all depth-sorted game objects in a single _draw() call.
## Also runs screen-space collision detection.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")
const _EnemyRenderer := preload("res://scripts/enemies/enemy_sprite_renderer.gd")

const SCREEN_W: float = 960.0
const SCREEN_H: float = 672.0
const HORIZON_Y: float = 268.8

var sky_top_color: Color = Color(0.72, 0.28, 0.04)
var sky_horizon_color: Color = Color(0.95, 0.62, 0.18)
var ground_color_a: Color = Color(0.78, 0.55, 0.25)
var ground_color_b: Color = Color(0.65, 0.42, 0.18)
var _ground_scroll: float = 0.0


func _process(delta: float) -> void:
	_ground_scroll = fmod(_ground_scroll + delta * 48.0, 60.0)
	_check_collisions()
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_ground()
	_draw_sorted_objects()


# --- Sky ---

func _draw_sky() -> void:
	var bands: int = 50
	var band_h: float = HORIZON_Y / float(bands)
	for i in range(bands):
		var t: float = float(i) / float(bands)
		var color: Color = sky_top_color.lerp(sky_horizon_color, t)
		draw_rect(Rect2(0.0, float(i) * band_h, SCREEN_W, band_h + 1.0), color)


# --- Ground ---

func _draw_ground() -> void:
	var stripe_count: int = 80
	for i in range(stripe_count):
		var raw: float = float(i) + _ground_scroll
		var t: float = float(i) / float(stripe_count)
		var y_start: float = HORIZON_Y + t * t * (SCREEN_H - HORIZON_Y)
		var t2: float = (float(i) + 1.0) / float(stripe_count)
		var y_end: float = HORIZON_Y + t2 * t2 * (SCREEN_H - HORIZON_Y)
		var color: Color = ground_color_a if int(raw) % 2 == 0 else ground_color_b
		draw_rect(Rect2(0.0, y_start, SCREEN_W, maxf(y_end - y_start + 1.0, 1.0)), color)


# --- Depth-sorted objects ---

func _draw_sorted_objects() -> void:
	var objects: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if "logical_depth" in enemy:
			objects.append(enemy)
	for bullet in get_tree().get_nodes_in_group("enemy_bullets"):
		if "logical_depth" in bullet:
			objects.append(bullet)

	objects.sort_custom(func(a: Node, b: Node) -> bool: return a.logical_depth < b.logical_depth)

	for obj in objects:
		if obj.is_in_group("enemies"):
			_draw_enemy_obj(obj)
		elif obj.is_in_group("enemy_bullets"):
			_draw_bullet_obj(obj)


func _draw_enemy_obj(enemy: Node) -> void:
	var d: float = enemy.logical_depth
	var s: float = _DepthUtil.depth_to_scale(d) * 35.0
	var pos: Vector2 = enemy.get_screen_position()
	_EnemyRenderer.draw_enemy(self, enemy.get_visual_type(), pos, s)


func _draw_bullet_obj(bullet: Node) -> void:
	var d: float = bullet.logical_depth
	if d < 0.05:
		return
	var pos: Vector2 = bullet.get_screen_position()
	var r: float = _DepthUtil.depth_to_scale(d) * 6.0
	draw_circle(pos, maxf(r, 1.5), Color(1.0, 0.5, 0.05))


# --- Collision detection ---

func _check_collisions() -> void:
	var player: Node = _get_player()
	if player == null or not player.is_vulnerable():
		return

	var player_pos: Vector2 = player.get_screen_position()
	var player_r: float = player.get_collision_radius()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_pos: Vector2 = enemy.get_screen_position()
		var enemy_r: float = enemy.get_collision_radius()
		if player_pos.distance_to(enemy_pos) < player_r + enemy_r:
			player.hit()
			enemy.take_damage(1)
			break

	for bullet in get_tree().get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(bullet):
			continue
		var bullet_pos: Vector2 = bullet.get_screen_position()
		var bullet_r: float = bullet.get_collision_radius()
		if player_pos.distance_to(bullet_pos) < player_r + bullet_r:
			player.hit()
			bullet.queue_free()
			break

	for b in get_tree().get_nodes_in_group("player_bullets"):
		if not is_instance_valid(b):
			continue
		var b_pos: Vector2 = b.get_screen_position()
		var b_r: float = b.get_collision_radius()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var e_pos: Vector2 = enemy.get_screen_position()
			var e_r: float = enemy.get_collision_radius()
			if b_pos.distance_to(e_pos) < b_r + e_r:
				enemy.take_damage(1)
				b.queue_free()
				break

	for missile in get_tree().get_nodes_in_group("missiles"):
		if not is_instance_valid(missile):
			continue
		var m_pos: Vector2 = missile.get_screen_position()
		var m_r: float = missile.get_collision_radius()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var e_pos: Vector2 = enemy.get_screen_position()
			var e_r: float = enemy.get_collision_radius()
			if m_pos.distance_to(e_pos) < m_r + e_r:
				enemy.take_damage(1)
				if missile.has_method("explode"):
					missile.explode()
				break


func _get_player() -> Node:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
