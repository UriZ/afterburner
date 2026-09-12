extends Node2D

## Central 2D rendering node.
## Draws sky, ground, and all depth-sorted game objects in a single _draw() call.
## Also runs screen-space collision detection.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")
const _EnemyRenderer := preload("res://scripts/enemies/enemy_sprite_renderer.gd")

const SCREEN_W: float = 960.0
const SCREEN_H: float = 672.0
const HORIZON_Y: float = 268.8

var sky_top_color: Color = Color(0.08, 0.04, 0.28)
var sky_horizon_color: Color = Color(1.00, 0.72, 0.10)
var ground_color_a: Color = Color(0.88, 0.65, 0.30)
var ground_color_b: Color = Color(0.50, 0.30, 0.12)

const GROUND_ROWS: int = 40
const FEATURE_SLOTS_PER_ROW: int = 6
const FEATURE_MIN_DEPTH: float = 0.15  # skip attempts too far to read as detail
# Depth units/sec. Constant rate + the quadratic depth->screen mapping (see DepthUtil)
# is what makes near rows rush past fast while far rows crawl — the core speed cue.
const GROUND_SCROLL_SPEED: float = 1.4

var _ground_scroll: float = 0.0


func _process(delta: float) -> void:
	_ground_scroll += delta * GROUND_SCROLL_SPEED
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
# No grid, no checkerboard: a smooth horizon->camera gradient base (atmospheric haze
# far away, richer tone up close — see ab2-arcade-desert.png) with organic rock/
# vegetation clusters scattered at continuous, non-gridded lateral positions. Density
# and size grow with depth via DepthUtil, so the scroll (a plain unbounded depth
# accumulator) is what sells speed: near clusters rush past while far ones crawl.

func _draw_ground() -> void:
	var row_depth: float = 1.0 / float(GROUND_ROWS)
	var local_offset: float = fmod(_ground_scroll, row_depth)
	var row_gen_base: int = int(floor(_ground_scroll / row_depth))
	var lateral: float = _player_lateral_offset()

	for i in range(-1, GROUND_ROWS):
		var d0: float = clampf(float(i) * row_depth + local_offset, 0.0, 1.0)
		var d1: float = clampf(float(i + 1) * row_depth + local_offset, 0.0, 1.0)
		if d1 <= d0:
			continue

		var row_gen: int = row_gen_base + i
		var y0: float = _DepthUtil.to_screen(0.0, d0).y
		var y1: float = _DepthUtil.to_screen(0.0, d1).y
		var d_mid: float = (d0 + d1) * 0.5

		# Smooth base gradient with a faint per-row jitter — no hard row-to-row flip.
		var base: Color = ground_color_a.lerp(ground_color_b, d_mid)
		var jitter: float = lerp(-0.05, 0.05, _hash2(row_gen, 91))
		base = Color(base.r + jitter, base.g + jitter, base.b + jitter).clamp()
		draw_rect(Rect2(0.0, y0, SCREEN_W, maxf(y1 - y0 + 1.0, 1.0)), base)

		if d_mid > FEATURE_MIN_DEPTH:
			_draw_row_features(row_gen, d_mid, lateral)


func _player_lateral_offset() -> float:
	var player: Node = _get_player()
	if player == null:
		return 0.0
	var px: float = player.get_screen_position().x
	return clampf((px - SCREEN_W * 0.5) / (SCREEN_W * 0.45), -1.0, 1.0) * 0.6


func _draw_row_features(row_gen: int, d_mid: float, lateral: float) -> void:
	for slot in range(FEATURE_SLOTS_PER_ROW):
		if _hash2(row_gen * 17 + slot * 131, 7) > lerp(0.45, 0.97, d_mid):
			continue
		var off: float = lerp(-1.1, 1.1, _hash2(row_gen * 53 + slot * 7, 3)) - lateral
		var pos: Vector2 = _DepthUtil.to_screen(off, d_mid)
		var base_r: float = _DepthUtil.depth_to_scale(d_mid) * lerp(9.0, 20.0, _hash2(row_gen, slot * 29 + 5))
		var tint: Color = ground_color_b.darkened(0.25) if _hash2(row_gen * 71 + slot, 41) > 0.5 \
			else ground_color_a.darkened(0.05)
		_draw_cluster(pos, base_r, tint, row_gen * 97 + slot * 13)


# A cluster of overlapping lobes (dark rim behind, tinted fill on top) reads as an
# irregular rock/vegetation clump rather than a single uniform dot.
func _draw_cluster(center: Vector2, radius: float, color: Color, cluster_id: int) -> void:
	draw_circle(center, radius * 1.15, color.darkened(0.4))
	draw_circle(center, radius, color)
	for k in range(3):
		var angle: float = _hash2(cluster_id + k, 3) * TAU
		var dist: float = radius * lerp(0.35, 0.75, _hash2(cluster_id + k, 11))
		var lobe_r: float = radius * lerp(0.4, 0.8, _hash2(cluster_id + k, 19))
		draw_circle(center + Vector2(cos(angle), sin(angle)) * dist, lobe_r, color)


static func _hash2(a: int, b: int) -> float:
	var n: float = sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453
	return n - floor(n)


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
	var s: float = enemy.get_screen_scale() * 35.0
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
	# Player-weapon collisions always run regardless of player vulnerability
	_check_player_weapons_vs_enemies()

	# Player-damage collisions only run when player is vulnerable
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


func _check_player_weapons_vs_enemies() -> void:
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
