extends Node2D

## Central 2D rendering node.
## Draws sky, ground, and all depth-sorted game objects in a single _draw() call.
## Also runs screen-space collision detection.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")
const _EnemyRenderer := preload("res://scripts/enemies/enemy_sprite_renderer.gd")
const _EnemyJet2D := preload("res://scripts/enemies/enemy_jet_2d.gd")
const _GroundTerrain := preload("res://scripts/game/ground_terrain_2d.gd")

const SCREEN_W: float = 960.0
const SCREEN_H: float = 672.0
# Single source of truth is DepthUtil.HORIZON_Y (#108) — this used to be a
# second hardcoded 268.8 that had to be kept manually in sync with
# depth_util.gd, which is exactly the kind of duplication that lets the sky
# and ground bands drift apart into a visible seam.
const HORIZON_Y: float = _DepthUtil.HORIZON_Y

var sky_top_color: Color = Color(0.08, 0.04, 0.28)
var sky_horizon_color: Color = Color(1.00, 0.72, 0.10)
var ground_color_a: Color = Color(0.88, 0.65, 0.30)
var ground_color_b: Color = Color(0.50, 0.30, 0.12)
var ground_color_c: Color = Color(0.55, 0.55, 0.10)

# Depth units/sec the ground scrolls toward the camera. Constant rate + the
# quadratic depth->screen mapping (see DepthUtil) is what makes near terrain
# rush past fast while far terrain crawls — the core speed cue.
const GROUND_SCROLL_SPEED: float = 1.4

# Wrap period for _ground_scroll (#42 redo). Large enough that the shader's
# cellular noise field (CELL_FREQ_D=15, see ground_terrain_2d.gdshader) never
# visibly repeats within a realistic play session (~708s at this speed), small
# enough to stay well inside float32 precision (error ~991*2^-23 ~= 1.2e-4,
# negligible next to the ~0.023/frame scroll delta at 60fps).
const GROUND_SCROLL_WRAP: float = 991.0

# Continuous world-depth scroll distance. Every ground pixel's terrain identity
# is a function of (world position, _ground_scroll) computed per-pixel in the
# ground shader — it translates smoothly frame to frame instead of being
# re-rolled from a frame-varying hash, which was the root cause of #42's original
# inverted/shimmering motion (terrain regenerated from scratch every frame
# instead of moving).
var _ground_scroll: float = 0.0
var _ground_terrain: Node2D

# --- Invincibility collision grace (#103) ---
# Damage checks are skipped entirely while the player is invincible, but nothing
# stops enemies/bullets from drifting into the player's collision radius during
# that window. Without this, whatever is already overlapping at the exact instant
# invincibility expires scores an instant, un-dodgeable hit. Standard arcade
# convention treats invincibility as pass-through: a body present when
# invincibility ends is exempted from damage until it clears the collision
# radius and would have to genuinely re-enter (a fresh approach, not a
# pre-loaded overlap). _collision_ignore holds instance IDs currently exempted;
# an entry is dropped the moment that body separates from the player again.
var _collision_ignore: Dictionary = {}
var _was_vulnerable: bool = true


func _process(delta: float) -> void:
	_ensure_ground_terrain()
	_ground_scroll = fposmod(_ground_scroll + delta * GROUND_SCROLL_SPEED, GROUND_SCROLL_WRAP)
	var haze: Color = sky_horizon_color
	_ground_terrain.update(_ground_scroll, _player_lateral_offset(), ground_color_a, ground_color_b, haze, ground_color_c)
	_check_collisions()
	queue_redraw()


# Idempotent — safe to call from _process() every frame (cheap null check) and
# directly from tests without relying on the engine's _ready()-on-tree-enter
# timing (see test_ground_grid.gd).
func _ensure_ground_terrain() -> void:
	if _ground_terrain != null:
		return
	_ground_terrain = Node2D.new()
	_ground_terrain.set_script(_GroundTerrain)
	add_child(_ground_terrain)


func _draw() -> void:
	_draw_sky()
	_draw_sorted_objects()


# --- Sky ---

func _draw_sky() -> void:
	var bands: int = 50
	var band_h: float = HORIZON_Y / float(bands)
	for i in range(bands):
		var t: float = float(i) / float(bands)
		# Measured directly off burst-a-02/burst-a-03 (#42 follow-up): pixel
		# color is flat (within JPEG noise) from the top of frame down to
		# ~80% of the sky's height, then brightens sharply into a haze band
		# only in the last ~20% before the horizon. A plain linear lerp across
		# the full sky height (the previous code) spreads that same total
		# color change evenly, which reads as "one flat orange" because the
		# top 80% barely moves off sky_top_color either way — smoothstep
		# concentrates the whole ramp into the band where the reference
		# actually has one.
		var te: float = smoothstep(0.75, 1.0, t)
		var color: Color = sky_top_color.lerp(sky_horizon_color, te)
		draw_rect(Rect2(0.0, float(i) * band_h, SCREEN_W, band_h + 1.0), color)
	# No horizon stroke here (#42 redo) — the ground shader's own haze blend
	# (ground_terrain_2d.gdshader, fades to sky_horizon_color as it nears the
	# horizon) is the seam between sky and ground now. Every reference shows a
	# density falloff, not a drawn line.


# --- Ground ---
# Rendered entirely by the _ground_terrain child node (ground_terrain_2d.gd),
# a single shader-driven quad — see _ensure_ground_terrain(). Moved off
# draw_circle()-per-feature (#42: ~40 large overlapping circles read as foam/
# bubbles, not terrain) onto a per-pixel cellular-noise shader, which gives
# 100% ground coverage with hundreds of small rock cells at a fixed draw-call
# cost of one quad, instead of scaling draw calls with feature count.


func _player_lateral_offset() -> float:
	var player: Node = _get_player()
	if player == null:
		return 0.0
	var px: float = player.get_screen_position().x
	return clampf((px - SCREEN_W * 0.5) / (SCREEN_W * 0.45), -1.0, 1.0) * 0.6


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

	var player: Node = _get_player()
	if player == null:
		return

	var vulnerable: bool = player.is_vulnerable()
	if vulnerable and not _was_vulnerable:
		_arm_invincibility_grace(player)
	_was_vulnerable = vulnerable

	# Player-damage collisions only run when player is vulnerable
	if not vulnerable:
		return

	var player_pos: Vector2 = player.get_screen_position()
	var player_r: float = player.get_collision_radius()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not _is_ramming_range(enemy):
			continue
		var enemy_pos: Vector2 = enemy.get_screen_position()
		var enemy_r: float = enemy.get_collision_radius()
		var overlapping: bool = player_pos.distance_to(enemy_pos) < player_r + enemy_r
		if _consume_ignore(enemy, overlapping):
			continue
		if overlapping:
			player.hit()
			enemy.take_damage(1)
			break

	for bullet in get_tree().get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(bullet):
			continue
		var bullet_pos: Vector2 = bullet.get_screen_position()
		var bullet_r: float = bullet.get_collision_radius()
		var overlapping: bool = player_pos.distance_to(bullet_pos) < player_r + bullet_r
		if _consume_ignore(bullet, overlapping):
			continue
		if overlapping:
			player.hit()
			bullet.queue_free()
			break


# Snapshot every enemy/bullet already overlapping the player's collision radius
# right as invincibility lifts, and exempt them from damage. Called once on the
# invincible -> vulnerable transition.
func _arm_invincibility_grace(player: Node) -> void:
	_collision_ignore.clear()
	var player_pos: Vector2 = player.get_screen_position()
	var player_r: float = player.get_collision_radius()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and _is_ramming_range(enemy) and player_pos.distance_to(enemy.get_screen_position()) < player_r + enemy.get_collision_radius():
			_collision_ignore[enemy.get_instance_id()] = true
	for bullet in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(bullet) and player_pos.distance_to(bullet.get_screen_position()) < player_r + bullet.get_collision_radius():
			_collision_ignore[bullet.get_instance_id()] = true


# Body-collision (ramming) eligibility gate (#103 regression fix). Every
# enemy's screen-Y sweeps monotonically from the horizon, down through the
# player's fixed screen-Y, then on up into the sky (see RAM_MIN_DEPTH in
# enemy_jet_2d.gd) — a side effect of the sky-altitude approach (#100) that
# didn't exist on the old ground-plane path. Two failure modes without this
# gate: (1) every enemy spawns at logical_depth=0, right at the horizon,
# already only ~40px from the player's screen-Y — well inside the player's
# own 78px collision radius regardless of x position, so a freshly-spawned,
# not-yet-visible speck could "hit" within a frame of appearing, bypassing
# the invincibility grace entirely (grace only exempts bodies present at the
# invincible->vulnerable transition, not ones that spawn afterward); (2) the
# player's screen-Y crossing itself (d roughly 0.30-0.45, depending on the
# enemy's altitude roll) is a second near-guaranteed vertical alignment,
# independent of x. Gating eligibility to strictly after that crossing band
# means ramming only becomes possible once the enemy is already separating
# from the player's screen-Y again — a body hit then needs a genuinely
# near-dead-center approach surviving all the way to near-despawn, matching
# AB2 where ramming isn't really a mechanic; enemy bullets are the real
# threat.
func _is_ramming_range(enemy: Node) -> bool:
	return enemy.logical_depth >= _EnemyJet2D.RAM_MIN_DEPTH


# Returns true (and keeps the exemption) if `obj` is still an exempted body that
# is still overlapping the player. Drops the exemption the moment it separates,
# re-arming it for a genuine future collision.
func _consume_ignore(obj: Object, overlapping: bool) -> bool:
	var id: int = obj.get_instance_id()
	if not _collision_ignore.has(id):
		return false
	if not overlapping:
		_collision_ignore.erase(id)
		return false
	return true


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
