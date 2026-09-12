class_name GameEnvironment2D
extends Node2D

## AB2-style sky gradient + perspective ground stripe renderer.
## Drawn via _draw() every frame for scroll animation.

const SCREEN_W := 960.0
const SCREEN_H := 672.0
# Horizon sits at ~36% from top — matching AB2 camera angle
const HORIZON_Y := 240.0

# How fast stripes scroll (frames per full cycle)
const SCROLL_SPEED := 0.9

enum StageType { DESERT, COASTAL, NIGHT, CITY }

var _stage_type: StageType = StageType.DESERT
var _scroll: float = 0.0

# City lights: small bright dots scattered in lower half
var _city_lights: Array[Vector2] = []

# Sky palette top/horizon colors per stage type
func _sky_top() -> Color:
	match _stage_type:
		StageType.DESERT: return Color(0.72, 0.28, 0.04)
		StageType.COASTAL: return Color(0.10, 0.30, 0.75)
		StageType.NIGHT: return Color(0.00, 0.00, 0.04)
		_: return Color(0.14, 0.20, 0.42)  # CITY

func _sky_horizon() -> Color:
	match _stage_type:
		StageType.DESERT: return Color(0.95, 0.62, 0.18)
		StageType.COASTAL: return Color(0.38, 0.65, 0.90)
		StageType.NIGHT: return Color(0.01, 0.01, 0.12)
		_: return Color(0.30, 0.40, 0.62)  # CITY

func _ground_even() -> Color:
	match _stage_type:
		StageType.DESERT: return Color(0.62, 0.42, 0.20)
		StageType.COASTAL: return Color(0.10, 0.45, 0.28)
		StageType.NIGHT: return Color(0.04, 0.04, 0.10)
		_: return Color(0.36, 0.36, 0.38)  # CITY

func _ground_odd() -> Color:
	match _stage_type:
		StageType.DESERT: return Color(0.52, 0.34, 0.14)
		StageType.COASTAL: return Color(0.08, 0.35, 0.22)
		StageType.NIGHT: return Color(0.02, 0.02, 0.06)
		_: return Color(0.28, 0.28, 0.30)  # CITY


func _ready() -> void:
	_build_city_lights()


func _build_city_lights() -> void:
	_city_lights.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(320):
		var x := rng.randf_range(0.0, SCREEN_W)
		var y := rng.randf_range(HORIZON_Y + 10.0, SCREEN_H)
		_city_lights.append(Vector2(x, y))


func _process(delta: float) -> void:
	_scroll = fmod(_scroll + delta * SCROLL_SPEED * 60.0, 60.0)
	queue_redraw()


func set_stage_palette(stage_num: int) -> void:
	if stage_num <= 3:
		_stage_type = StageType.DESERT
	elif stage_num <= 8:
		_stage_type = StageType.COASTAL
	elif stage_num <= 14:
		_stage_type = StageType.CITY
	elif stage_num <= 18:
		_stage_type = StageType.NIGHT
	else:
		_stage_type = StageType.DESERT


func set_stage_type(t: int) -> void:
	_stage_type = t as StageType


func _draw() -> void:
	_draw_sky()
	_draw_ground()
	if _stage_type == StageType.NIGHT:
		_draw_city_lights()


func _draw_sky() -> void:
	var top_c := _sky_top()
	var horizon_c := _sky_horizon()
	var bands := 48
	var band_h := HORIZON_Y / float(bands)
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var c := top_c.lerp(horizon_c, t)
		draw_rect(Rect2(0.0, float(i) * band_h, SCREEN_W, band_h + 1.0), c)


func _draw_ground() -> void:
	var c_even := _ground_even()
	var c_odd := _ground_odd()
	var stripes := 80
	for i in range(stripes):
		var raw := float(i) + _scroll
		var t := float(i) / float(stripes)
		var t2 := float(i + 1) / float(stripes)
		var y_start := HORIZON_Y + t * t * (SCREEN_H - HORIZON_Y)
		var y_end := HORIZON_Y + t2 * t2 * (SCREEN_H - HORIZON_Y)
		var c := c_even if int(raw) % 2 == 0 else c_odd
		draw_rect(Rect2(0.0, y_start, SCREEN_W, maxf(1.0, y_end - y_start + 1.0)), c)


func _draw_city_lights() -> void:
	for pt in _city_lights:
		var t := (pt.y - HORIZON_Y) / (SCREEN_H - HORIZON_Y)
		var sz := maxf(1.0, t * 3.0)
		var brightness := 0.5 + t * 0.5
		var hue := fmod(pt.x * 0.003, 1.0)
		var c := Color.from_hsv(hue, 0.6, brightness, 1.0)
		draw_rect(Rect2(pt.x - sz * 0.5, pt.y - sz * 0.5, sz, sz), c)
