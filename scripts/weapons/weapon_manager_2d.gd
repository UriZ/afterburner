extends Node

## 2D weapon manager: vulcan cannon + missile firing + crosshair + lock-on.
## Attach as child of PlayerJet2D.
## State is read by Reticle2D for rendering.

const VULCAN_FIRE_INTERVAL := 0.08    # ~12 bullets/sec
const BULLET_SPREAD := 0.025          # logical-x spread around crosshair
const MISSILE_FIRE_COOLDOWN := 0.4
const LOCK_RADIUS := 80.0             # screen pixels — lock-on detection radius
const LOCK_BREAK_DELAY := 0.5

# Bracket sizing/centering must derive from the enemy's ACTUAL drawn sprite,
# not an independent depth curve (#49 gate) — otherwise the bracket floats
# around at a size and position unrelated to what's on screen. 35.0 mirrors
# game_world.gd's `enemy.get_screen_scale() * 35.0`, the exact "s" the
# enemy sprite is drawn at (see enemy_sprite_renderer.gd draw_enemy).
const BRACKET_SPRITE_SCALE := 35.0
const BRACKET_SIZE_FACTOR := 2.0      # loose fit around the sprite, not snug
const BRACKET_SIZE_MIN := 24.0
const BRACKET_SIZE_MAX := 220.0
# enemy_sprite_renderer.gd draws the fuselage nose tip at pos.y - 1.10*s and
# its lowest point (wing underside) at pos.y + 0.52*s — the sprite's visual
# centroid sits at (-1.10+0.52)/2 = -0.29*s relative to `pos` (get_screen_
# position()), not AT pos. Without this correction the bracket centers on
# `pos` while the sprite's visible mass sits well above it, reading as a
# bracket offset down from the target.
const BRACKET_CENTER_Y_OFFSET := -0.29

# Crosshair lead offsets (screen pixels from player)
const SIGHT_AHEAD_Y := 120.0
const SIGHT_LEAD_X := 100.0
const SIGHT_LEAD_Y := 70.0
const SIGHT_LERP_SPEED := 8.0

## Public state — read by Reticle2D
var sight_screen_pos: Vector2 = Vector2.ZERO
var locked_enemy: Node = null
var locked_enemy_screen_pos: Vector2 = Vector2.ZERO
var locked_enemy_bracket_size: float = 48.0

var _vulcan_cooldown: float = 0.0
var _missile_cooldown: float = 0.0
var _lock_break_timer: float = 0.0
var _last_fired_left: bool = false


func _ready() -> void:
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
	var player := get_parent()
	if not player or not player.has_method("get_screen_position"):
		return
	var jet_screen: Vector2 = player.get_screen_position()

	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_down", "move_up")

	var target := jet_screen + Vector2(
		input_x * SIGHT_LEAD_X,
		-SIGHT_AHEAD_Y - input_y * SIGHT_LEAD_Y
	)
	# Never drop below player
	target.y = minf(target.y, jet_screen.y - 20.0)

	sight_screen_pos = sight_screen_pos.lerp(target, SIGHT_LERP_SPEED * delta)


func _update_lockon(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node = null
	var best_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("get_screen_position"):
			continue
		var sp: Vector2 = enemy.get_screen_position()
		var dist: float = sp.distance_to(sight_screen_pos)
		if dist <= LOCK_RADIUS and dist < best_dist:
			best_dist = dist
			best_enemy = enemy

	if best_enemy != null:
		if best_enemy != locked_enemy:
			_on_new_lock()
		locked_enemy = best_enemy
		_lock_break_timer = 0.0
	elif locked_enemy != null:
		if not is_instance_valid(locked_enemy):
			locked_enemy = null
			_lock_break_timer = 0.0
		else:
			_lock_break_timer += delta
			if _lock_break_timer >= LOCK_BREAK_DELAY:
				locked_enemy = null
				_lock_break_timer = 0.0

	# Bracket must track the locked enemy's CURRENT screen position every
	# frame it's still valid — including during the lock-break grace window
	# above. Updating this only inside the `best_enemy != null` branch left
	# it frozen at a stale position for up to LOCK_BREAK_DELAY (0.5s) while
	# the enemy sprite kept moving, visibly desyncing the bracket from the
	# jet it's supposed to be enclosing (#49 gate).
	if is_instance_valid(locked_enemy):
		locked_enemy_screen_pos = locked_enemy.get_screen_position() + _bracket_center_offset(locked_enemy)
		locked_enemy_bracket_size = _bracket_size_for_enemy(locked_enemy)


func _on_new_lock() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_lockon_beep"):
		am.play_lockon_beep()


func _bracket_size_for_enemy(enemy: Node) -> float:
	if not enemy.has_method("get_screen_scale"):
		return 48.0
	var s: float = enemy.get_screen_scale() * BRACKET_SPRITE_SCALE
	return clampf(s * BRACKET_SIZE_FACTOR, BRACKET_SIZE_MIN, BRACKET_SIZE_MAX)


func _bracket_center_offset(enemy: Node) -> Vector2:
	if not enemy.has_method("get_screen_scale"):
		return Vector2.ZERO
	var s: float = enemy.get_screen_scale() * BRACKET_SPRITE_SCALE
	return Vector2(0.0, BRACKET_CENTER_Y_OFFSET * s)


func _fire_vulcan() -> void:
	if _vulcan_cooldown > 0.0:
		return
	_vulcan_cooldown = VULCAN_FIRE_INTERVAL

	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_vulcan_fire"):
		am.play_vulcan_fire()

	var player := get_parent()
	if not player or not player.has_method("get_screen_position"):
		return

	var player_screen: Vector2 = player.get_screen_position()
	var player_logical_x: float = (player_screen.x - 480.0) / 451.2

	# Aim toward crosshair logical_x with small spread
	var sight_logical_x: float = (sight_screen_pos.x - 480.0) / 451.2
	var spread_x: float = randf_range(-BULLET_SPREAD, BULLET_SPREAD)

	var bullet := Node2D.new()
	bullet.set_script(preload("res://scripts/weapons/vulcan_bullet_2d.gd"))
	bullet.logical_x = player_logical_x
	bullet.aim_x = sight_logical_x + spread_x
	bullet.logical_depth = 0.90
	bullet.position = player_screen
	_get_container().add_child(bullet)


func _fire_missile() -> void:
	if _missile_cooldown > 0.0:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not gs.use_missile():
		return
	_missile_cooldown = MISSILE_FIRE_COOLDOWN

	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_missile_launch"):
		am.play_missile_launch()

	_last_fired_left = not _last_fired_left
	var pylon_offset_x: float = -0.08 if _last_fired_left else 0.08

	var player := get_parent()
	var player_lx: float = 0.0
	if player and player.has_method("get_screen_position"):
		var ps: Vector2 = player.get_screen_position()
		player_lx = (ps.x - 480.0) / 451.2

	var missile := Node2D.new()
	missile.set_script(preload("res://scripts/weapons/missile_2d.gd"))
	missile.logical_x = player_lx + pylon_offset_x
	missile.logical_depth = 0.90
	if is_instance_valid(locked_enemy):
		missile.target = locked_enemy
	missile.position = missile.get_screen_position()
	_get_container().add_child(missile)


func _get_container() -> Node:
	var node := get_parent()
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node
