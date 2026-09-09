extends Control

## Targeting sight and lock-on marker renderer.
## Reads all state from WeaponManager — contains no game logic.

const COLOR_NO_LOCK := Color(0.20, 1.00, 0.40)  # green
const COLOR_LOCKED := Color(1.00, 0.20, 0.10)   # red
const COLOR_LOCK_FLASH := Color.WHITE
const LOCK_FLASH_DURATION := 0.1  # seconds — white flash on new lock

# Sight crosshair dimensions — large enough to see during gameplay
const SIGHT_ARM_LENGTH := 48.0
const SIGHT_GAP := 10.0
const SIGHT_STROKE := 3.0
const SIGHT_CENTER_DOT_RADIUS := 3.0

# Lock marker dimensions
const LOCK_BOX_SIZE := 60.0  # half-size of lock box
const LOCK_STROKE := 3.0

var _weapon_manager: Node = null
## Tracks flash timer per enemy. Positive value = currently flashing.
var _lock_flash_timers: Dictionary = {}  # enemy Node3D -> float
## Tracks which enemies were locked last frame, to detect new locks.
var _prev_locked: Array[Node3D] = []


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _weapon_manager == null:
		_weapon_manager = _find_weapon_manager()
	_update_lock_flashes(delta)
	queue_redraw()


func _update_lock_flashes(delta: float) -> void:
	if _weapon_manager == null:
		return

	# Detect newly locked enemies
	for enemy in _weapon_manager.locked_enemies:
		if is_instance_valid(enemy) and enemy not in _prev_locked:
			_lock_flash_timers[enemy] = LOCK_FLASH_DURATION

	# Tick down flash timers
	var expired: Array = []
	for enemy in _lock_flash_timers:
		_lock_flash_timers[enemy] -= delta
		if _lock_flash_timers[enemy] <= 0.0:
			expired.append(enemy)
	for enemy in expired:
		_lock_flash_timers.erase(enemy)

	# Snapshot current locked set for next frame comparison
	_prev_locked.clear()
	for enemy in _weapon_manager.locked_enemies:
		if is_instance_valid(enemy):
			_prev_locked.append(enemy)


func _draw() -> void:
	if _weapon_manager == null:
		return

	var has_locks: bool = _weapon_manager.locked_enemies.size() > 0
	var sight_color: Color = COLOR_LOCKED if has_locks else COLOR_NO_LOCK
	_draw_sight(_weapon_manager.sight_screen_pos, sight_color)
	_draw_lock_markers()


func _draw_sight(pos: Vector2, color: Color) -> void:
	# Four arms of a crosshair with a gap in the center
	draw_line(pos + Vector2(-SIGHT_GAP - SIGHT_ARM_LENGTH, 0),
			  pos + Vector2(-SIGHT_GAP, 0), color, SIGHT_STROKE)
	draw_line(pos + Vector2(SIGHT_GAP, 0),
			  pos + Vector2(SIGHT_GAP + SIGHT_ARM_LENGTH, 0), color, SIGHT_STROKE)
	draw_line(pos + Vector2(0, -SIGHT_GAP - SIGHT_ARM_LENGTH),
			  pos + Vector2(0, -SIGHT_GAP), color, SIGHT_STROKE)
	draw_line(pos + Vector2(0, SIGHT_GAP),
			  pos + Vector2(0, SIGHT_GAP + SIGHT_ARM_LENGTH), color, SIGHT_STROKE)
	# Center dot for precise aiming feedback
	draw_circle(pos, SIGHT_CENTER_DOT_RADIUS, color)


func _draw_lock_markers() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for enemy in _weapon_manager.locked_enemies:
		if not is_instance_valid(enemy):
			continue
		if camera.is_position_behind(enemy.global_position):
			continue
		var screen_pos := camera.unproject_position(enemy.global_position)
		var is_flashing: bool = _lock_flash_timers.has(enemy)
		_draw_lock_box(screen_pos, is_flashing)


func _draw_lock_box(pos: Vector2, is_flashing: bool = false) -> void:
	## Bracket-style lock marker. White flash on new lock, then red.
	var color := COLOR_LOCK_FLASH if is_flashing else COLOR_LOCKED
	var stroke := LOCK_STROKE + (1.0 if is_flashing else 0.0)
	var s := LOCK_BOX_SIZE
	var arm := s * 0.4
	# Top-left
	draw_line(pos + Vector2(-s, -s), pos + Vector2(-s + arm, -s), color, stroke)
	draw_line(pos + Vector2(-s, -s), pos + Vector2(-s, -s + arm), color, stroke)
	# Top-right
	draw_line(pos + Vector2(s, -s), pos + Vector2(s - arm, -s), color, stroke)
	draw_line(pos + Vector2(s, -s), pos + Vector2(s, -s + arm), color, stroke)
	# Bottom-left
	draw_line(pos + Vector2(-s, s), pos + Vector2(-s + arm, s), color, stroke)
	draw_line(pos + Vector2(-s, s), pos + Vector2(-s, s - arm), color, stroke)
	# Bottom-right
	draw_line(pos + Vector2(s, s), pos + Vector2(s - arm, s), color, stroke)
	draw_line(pos + Vector2(s, s), pos + Vector2(s, s - arm), color, stroke)


func _find_weapon_manager() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0].get_node_or_null("WeaponManager")
