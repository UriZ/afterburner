extends Control

## Lock-on targeting reticle drawn with _draw().
## Polls enemy positions each frame to determine lock state, mirroring
## the detection logic in weapon_manager.gd (LOCKON_RECT center 40% of screen).

const COLOR_DEFAULT := Color(0.20, 1.00, 0.40)
const COLOR_LOCKED  := Color(1.00, 0.20, 0.10)

## Inner bracket dimensions (spec: 32x32 gap, 12px arm length, 2px stroke)
const BRACKET_ARM  := 12.0
const BRACKET_GAP  := 16.0  # half-gap from center — 32px total inner area
const STROKE       := 2.0
const LOCK_INSET   := 4.0   # brackets animate inward when locked
const OUTER_OFFSET := 20.0  # outer ring offset from bracket tips when locked

## Match weapon_manager.gd LOCKON_RECT constant — center 40% of screen
const LOCKON_RECT := Rect2(0.3, 0.3, 0.4, 0.4)

var _locked := false
var _lock_anim := 0.0  # 0.0 = open, 1.0 = fully locked (drives inset lerp)


func _process(delta: float) -> void:
	var was_locked := _locked
	_locked = _check_lock()

	# Smooth animation toward target state
	var target := 1.0 if _locked else 0.0
	_lock_anim = move_toward(_lock_anim, target, delta * 8.0)

	if was_locked != _locked or _lock_anim != target:
		queue_redraw()


func _check_lock() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var viewport_size := get_viewport().get_visible_rect().size
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var ndc := camera.unproject_position(enemy.global_position) / viewport_size
		if LOCKON_RECT.has_point(ndc):
			return true
	return false


func _draw() -> void:
	var color := COLOR_DEFAULT.lerp(COLOR_LOCKED, _lock_anim)
	var inset := LOCK_INSET * _lock_anim
	var center := size * 0.5

	_draw_brackets(center, color, inset)

	# Outer box only when locked
	if _lock_anim > 0.01:
		_draw_outer_box(center, color, _lock_anim)


func _draw_brackets(center: Vector2, color: Color, inset: float) -> void:
	var g := BRACKET_GAP + inset  # gap from center to inner bracket corner

	# Each corner: draw two lines forming an L-shape
	# top-left
	_draw_corner(center + Vector2(-g, -g), Vector2(-BRACKET_ARM, 0.0), Vector2(0.0, -BRACKET_ARM), color)
	# top-right
	_draw_corner(center + Vector2(g, -g), Vector2(BRACKET_ARM, 0.0), Vector2(0.0, -BRACKET_ARM), color)
	# bottom-left
	_draw_corner(center + Vector2(-g, g), Vector2(-BRACKET_ARM, 0.0), Vector2(0.0, BRACKET_ARM), color)
	# bottom-right
	_draw_corner(center + Vector2(g, g), Vector2(BRACKET_ARM, 0.0), Vector2(0.0, BRACKET_ARM), color)


func _draw_corner(origin: Vector2, arm_h: Vector2, arm_v: Vector2, color: Color) -> void:
	draw_line(origin, origin + arm_h, color, STROKE)
	draw_line(origin, origin + arm_v, color, STROKE)


func _draw_outer_box(center: Vector2, color: Color, alpha: float) -> void:
	var faded := Color(color.r, color.g, color.b, color.a * alpha)
	var half := BRACKET_GAP + BRACKET_ARM + OUTER_OFFSET
	var rect := Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
	draw_rect(rect, faded, false, STROKE * 0.5)
