extends Control

## Targeting sight renderer.
## Reads state from WeaponManager — contains no game logic.

const COLOR_NO_LOCK := Color(0.20, 1.00, 0.40)  # green
const COLOR_LOCKED := Color(1.00, 0.20, 0.10)    # red
const COLOR_LOCK_FLASH := Color.WHITE
const LOCK_FLASH_DURATION := 0.1  # seconds — white flash on new lock

# Crosshair dimensions
const SIGHT_ARM_LENGTH := 48.0
const SIGHT_GAP := 10.0
const SIGHT_STROKE := 3.0
const SIGHT_CENTER_DOT_RADIUS := 3.0

# Lock brackets drawn around the crosshair when locked
const BRACKET_SIZE := 32.0   # half-size of the bracket box
const BRACKET_ARM := 12.0    # length of each bracket corner arm
const BRACKET_STROKE := 2.5

var _weapon_manager: Node = null
var _prev_locked: Node3D = null
var _flash_timer := 0.0


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _weapon_manager == null:
		_weapon_manager = _find_weapon_manager()
		return

	var current := _weapon_manager.locked_enemy if is_instance_valid(_weapon_manager.locked_enemy) else null

	# Detect new lock — trigger flash
	if current != null and current != _prev_locked:
		_flash_timer = LOCK_FLASH_DURATION

	_prev_locked = current
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _weapon_manager == null:
		return

	var locked: Node3D = _weapon_manager.locked_enemy if is_instance_valid(_weapon_manager.locked_enemy) else null
	var pos: Vector2 = _weapon_manager.sight_screen_pos
	var is_locked: bool = locked != null
	var is_flashing: bool = _flash_timer > 0.0

	var color: Color
	if is_flashing:
		color = COLOR_LOCK_FLASH
	elif is_locked:
		color = COLOR_LOCKED
	else:
		color = COLOR_NO_LOCK

	_draw_crosshair(pos, color)

	if is_locked:
		_draw_lock_brackets(pos, color)


func _draw_crosshair(pos: Vector2, color: Color) -> void:
	draw_line(pos + Vector2(-SIGHT_GAP - SIGHT_ARM_LENGTH, 0),
			  pos + Vector2(-SIGHT_GAP, 0), color, SIGHT_STROKE)
	draw_line(pos + Vector2(SIGHT_GAP, 0),
			  pos + Vector2(SIGHT_GAP + SIGHT_ARM_LENGTH, 0), color, SIGHT_STROKE)
	draw_line(pos + Vector2(0, -SIGHT_GAP - SIGHT_ARM_LENGTH),
			  pos + Vector2(0, -SIGHT_GAP), color, SIGHT_STROKE)
	draw_line(pos + Vector2(0, SIGHT_GAP),
			  pos + Vector2(0, SIGHT_GAP + SIGHT_ARM_LENGTH), color, SIGHT_STROKE)
	draw_circle(pos, SIGHT_CENTER_DOT_RADIUS, color)


func _draw_lock_brackets(pos: Vector2, color: Color) -> void:
	var s := BRACKET_SIZE
	var a := BRACKET_ARM
	var w := BRACKET_STROKE
	# Top-left
	draw_line(pos + Vector2(-s, -s), pos + Vector2(-s + a, -s), color, w)
	draw_line(pos + Vector2(-s, -s), pos + Vector2(-s, -s + a), color, w)
	# Top-right
	draw_line(pos + Vector2(s, -s), pos + Vector2(s - a, -s), color, w)
	draw_line(pos + Vector2(s, -s), pos + Vector2(s, -s + a), color, w)
	# Bottom-left
	draw_line(pos + Vector2(-s, s), pos + Vector2(-s + a, s), color, w)
	draw_line(pos + Vector2(-s, s), pos + Vector2(-s, s - a), color, w)
	# Bottom-right
	draw_line(pos + Vector2(s, s), pos + Vector2(s - a, s), color, w)
	draw_line(pos + Vector2(s, s), pos + Vector2(s, s - a), color, w)


func _find_weapon_manager() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0].get_node_or_null("WeaponManager")
