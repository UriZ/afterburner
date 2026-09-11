extends Control

## Targeting sight renderer.
## Reads state from WeaponManager — contains no game logic.

const COLOR_WHITE := Color.WHITE

# Sight (tiny cross above player jet)
const SIGHT_ARM_LENGTH := 8.0
const SIGHT_GAP := 4.0
const SIGHT_STROKE := 2.0

# Lock brackets (L-shaped corners at enemy screen position)
const BRACKET_ARM := 10.0
const BRACKET_STROKE := 2.0

# Blink on lock acquisition: 3 blinks of 60ms each
const BLINK_COUNT := 3
const BLINK_INTERVAL := 0.06

var _weapon_manager: Node = null
var _prev_locked: Node3D = null
var _blink_timer := 0.0
var _blink_visible := true


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _weapon_manager == null:
		_weapon_manager = _find_weapon_manager()
		return

	var current: Node3D = _weapon_manager.locked_enemy if is_instance_valid(_weapon_manager.locked_enemy) else null

	# Detect new lock — trigger blink sequence
	if current != null and current != _prev_locked:
		_blink_timer = BLINK_COUNT * BLINK_INTERVAL * 2.0  # full on/off cycles

	_prev_locked = current

	if _blink_timer > 0.0:
		_blink_timer = maxf(_blink_timer - delta, 0.0)
		# Toggle visibility each BLINK_INTERVAL
		var cycle := floori(_blink_timer / BLINK_INTERVAL)
		_blink_visible = (cycle % 2 == 0)
	else:
		_blink_visible = true

	queue_redraw()


func _draw() -> void:
	if _weapon_manager == null:
		return

	var locked: Node3D = _weapon_manager.locked_enemy if is_instance_valid(_weapon_manager.locked_enemy) else null
	var sight_pos: Vector2 = _weapon_manager.sight_screen_pos

	_draw_crosshair(sight_pos)

	if locked != null and _blink_visible:
		var enemy_pos: Vector2 = _weapon_manager.locked_enemy_screen_pos
		var bracket_size: float = _weapon_manager.locked_enemy_bracket_size
		_draw_enemy_brackets(enemy_pos, bracket_size)


func _draw_crosshair(pos: Vector2) -> void:
	var g := SIGHT_GAP
	var a := SIGHT_ARM_LENGTH
	var w := SIGHT_STROKE
	draw_line(pos + Vector2(-g - a, 0), pos + Vector2(-g, 0), COLOR_WHITE, w)
	draw_line(pos + Vector2(g, 0), pos + Vector2(g + a, 0), COLOR_WHITE, w)
	draw_line(pos + Vector2(0, -g - a), pos + Vector2(0, -g), COLOR_WHITE, w)
	draw_line(pos + Vector2(0, g), pos + Vector2(0, g + a), COLOR_WHITE, w)


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
	return players[0].get_node_or_null("WeaponManager")
