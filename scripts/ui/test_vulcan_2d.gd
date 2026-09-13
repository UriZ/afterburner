extends Node2D

## Test scene for vulcan_bullet_2d.gd, weapon_manager_2d.gd, and reticle_2d.gd.
## Arrow keys: move player. Z: fire vulcan. X: fire missile.
## Crosshair leads player input. Lock-on triggers when crosshair overlaps target.

const SCREEN_W := 960.0
const SCREEN_H := 672.0
const HORIZON_Y := 420.0  # mirrors DepthUtil.HORIZON_Y (#108)

# Fake enemies that weapon_manager_2d can lock onto
class FakeEnemy extends Node:
	var logical_x: float
	var logical_depth: float

	func _init(x: float, d: float) -> void:
		logical_x = x
		logical_depth = d

	func get_screen_position() -> Vector2:
		# Inline DepthUtil.to_screen to avoid class_name scoping in inner class
		# (mirrors DepthUtil.HORIZON_Y = 420.0, #108)
		var cx := 480.0
		var sx := cx + logical_x * (960.0 * 0.47) * (0.1 + logical_depth * 0.9)
		var sy := 420.0 + logical_depth * logical_depth * (672.0 - 420.0) * 0.95
		return Vector2(sx, sy)

var _fake_enemies: Array = []


func _ready() -> void:
	# Static targets at various depths and lateral positions
	var target_data := [
		[-0.4, 0.4],
		[0.0,  0.5],
		[0.35, 0.3],
		[-0.1, 0.6],
		[0.55, 0.45],
	]
	for td in target_data:
		var fe := FakeEnemy.new(td[0], td[1])
		add_child(fe)
		fe.add_to_group("enemies")
		_fake_enemies.append(fe)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Sky gradient
	var bands := 24
	var bh: float = HORIZON_Y / float(bands)
	for i in range(bands):
		var t: float = float(i) / float(bands)
		var c: Color = Color(0.08, 0.12, 0.40).lerp(Color(0.45, 0.62, 0.88), t)
		draw_rect(Rect2(0.0, float(i) * bh, SCREEN_W, bh + 1.0), c)

	# Ground
	draw_rect(Rect2(0.0, HORIZON_Y, SCREEN_W, SCREEN_H - HORIZON_Y), Color(0.38, 0.25, 0.08))

	# Draw target dots
	for fe in _fake_enemies:
		if not is_instance_valid(fe):
			continue
		var pos: Vector2 = fe.get_screen_position()
		draw_circle(pos, 8.0, Color(1.0, 0.2, 0.2))
		draw_circle(pos, 3.0, Color(1.0, 0.8, 0.8))

	# HUD hint
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 24.0),
		"Arrows: move  |  Z: vulcan  |  X: missile  |  Red dots: targets",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 1.0))
