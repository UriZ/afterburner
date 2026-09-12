extends Node2D

## 2D targeting reticle renderer.
## Reads state from WeaponManager2D — no game logic here.

# Crosshair: small white cross with gap
const SIGHT_ARM := 8.0
const SIGHT_GAP := 4.0
const SIGHT_STROKE := 2.0
const COLOR_WHITE := Color(1.0, 1.0, 1.0, 1.0)

# Lock brackets: L-shaped corners
const BRACKET_ARM := 10.0
const BRACKET_STROKE := 2.0

# Blink on lock acquisition
const BLINK_COUNT := 3
const BLINK_INTERVAL := 0.06

var _weapon_manager: Node = null
var _prev_locked: Node = null
var _blink_timer: float = 0.0
var _blink_visible: bool = true


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	if _weapon_manager == null:
		_weapon_manager = _find_weapon_manager()
		return

	if not "locked_enemy" in _weapon_manager:
		_weapon_manager = null
		return

	var current: Node = null
	if is_instance_valid(_weapon_manager.locked_enemy):
		current = _weapon_manager.locked_enemy

	if current != null and current != _prev_locked:
		_blink_timer = float(BLINK_COUNT) * BLINK_INTERVAL * 2.0

	_prev_locked = current

	if _blink_timer > 0.0:
		_blink_timer = maxf(_blink_timer - delta, 0.0)
		_blink_visible = (floori(_blink_timer / BLINK_INTERVAL) % 2 == 0)
	else:
		_blink_visible = true

	queue_redraw()


func _draw() -> void:
	if _weapon_manager == null or not "sight_screen_pos" in _weapon_manager:
		return

	_draw_crosshair(_weapon_manager.sight_screen_pos)

	if is_instance_valid(_weapon_manager.locked_enemy) and _blink_visible:
		_draw_enemy_brackets(
			_weapon_manager.locked_enemy_screen_pos,
			_weapon_manager.locked_enemy_bracket_size
		)


func _draw_crosshair(pos: Vector2) -> void:
	var g := SIGHT_GAP
	var a := SIGHT_ARM
	var w := SIGHT_STROKE
	draw_line(pos + Vector2(-g - a, 0.0), pos + Vector2(-g, 0.0), COLOR_WHITE, w)
	draw_line(pos + Vector2(g, 0.0),      pos + Vector2(g + a, 0.0), COLOR_WHITE, w)
	draw_line(pos + Vector2(0.0, -g - a), pos + Vector2(0.0, -g), COLOR_WHITE, w)
	draw_line(pos + Vector2(0.0, g),      pos + Vector2(0.0, g + a), COLOR_WHITE, w)


func _draw_enemy_brackets(pos: Vector2, size: float) -> void:
	var s := size * 0.5
	var a := BRACKET_ARM
	var w := BRACKET_STROKE
	# Top-left
	draw_line(pos + Vector2(-s, -s), pos + Vector2(-s + a, -s), COLOR_WHITE, w)
	draw_line(pos + Vector2(-s, -s), pos + Vector2(-s, -s + a), COLOR_WHITE, w)
	# Top-right
	draw_line(pos + Vector2(s, -s), pos + Vector2(s - a, -s), COLOR_WHITE, w)
	draw_line(pos + Vector2(s, -s), pos + Vector2(s, -s + a), COLOR_WHITE, w)
	# Bottom-left
	draw_line(pos + Vector2(-s, s), pos + Vector2(-s + a, s), COLOR_WHITE, w)
	draw_line(pos + Vector2(-s, s), pos + Vector2(-s, s - a), COLOR_WHITE, w)
	# Bottom-right
	draw_line(pos + Vector2(s, s), pos + Vector2(s - a, s), COLOR_WHITE, w)
	draw_line(pos + Vector2(s, s), pos + Vector2(s, s - a), COLOR_WHITE, w)


func _find_weapon_manager() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0].get_node_or_null("WeaponManager2D")
