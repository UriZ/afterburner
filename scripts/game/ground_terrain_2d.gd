extends Node2D

## Shader-rendered ground terrain layer (#42 redo).
##
## Replaces the discrete draw_circle() rock-cluster model in game_world.gd
## (visually a "foam bubble" field, per the TL's whole-frame comparison —
## see #42) with a single quad driving a per-pixel cellular-noise fragment
## shader (assets/shaders/ground_terrain_2d.gdshader). Coverage is 100% by
## construction and independent of any feature count, which is what makes
## this cheaper than more draw_circle() calls, not more expensive.
##
## show_behind_parent draws this node's quad BEFORE GameWorld's own _draw()
## (sky, then depth-sorted enemies/bullets), so enemies/bullets still
## correctly composite on top of the ground exactly as before.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

var _material: ShaderMaterial


func _ready() -> void:
	_ensure_material()
	show_behind_parent = true


# Idempotent setup, callable directly from tests without relying on the
# engine's _ready()-on-tree-enter timing (see test_ground_grid.gd).
func _ensure_material() -> void:
	if _material != null:
		return
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/shaders/ground_terrain_2d.gdshader")
	material = _material


func _draw() -> void:
	var top: float = _DepthUtil.horizon_y
	var bottom: float = _DepthUtil.SCREEN_H
	var w: float = _DepthUtil.SCREEN_W
	var points := PackedVector2Array([
		Vector2(0.0, top), Vector2(w, top), Vector2(w, bottom), Vector2(0.0, bottom),
	])
	# Explicit UVs (rather than relying on draw_rect's implicit mapping) so
	# the shader's UV.y=0 -> horizon, UV.y=1 -> bottom-of-screen assumption
	# is guaranteed correct.
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs)


func update(world_scroll: float, lateral: float, color_a: Color, color_b: Color, haze_color: Color, color_c: Color = Color(0.55, 0.55, 0.10)) -> void:
	_ensure_material()
	_material.set_shader_parameter("world_scroll", world_scroll)
	_material.set_shader_parameter("lateral", lateral)
	_material.set_shader_parameter("color_a", color_a)
	_material.set_shader_parameter("color_b", color_b)
	_material.set_shader_parameter("color_c", color_c)
	_material.set_shader_parameter("haze_color", haze_color)
	# #120: the shader's horizon_y/screen_h/screen_w uniforms carry a comment
	# claiming "GameWorld pushes these from _DepthUtil at _ready()" — nothing
	# ever did. It worked purely because the uniform defaults (420/672/960)
	# coincided with DepthUtil's old compile-time const. Now that the horizon
	# is per-stage runtime state, the shader would keep inverting its own
	# projection at a stale 420 while this quad's geometry (_draw() above)
	# moved with the real horizon — desyncing the terrain from its own quad
	# with no error anywhere. Push every call so they can never drift apart.
	_material.set_shader_parameter("horizon_y", _DepthUtil.horizon_y)
	_material.set_shader_parameter("screen_h", _DepthUtil.SCREEN_H)
	_material.set_shader_parameter("screen_w", _DepthUtil.SCREEN_W)
	queue_redraw()
