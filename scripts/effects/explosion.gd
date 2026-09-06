extends Sprite3D

## 10-frame procedural sprite-sheet explosion. Frees itself when done.

const FRAME_COUNT := 10
const FRAME_DURATION := 0.1   # seconds per frame — 1.0s total
const SHEET_W := 1280
const SHEET_H := 128
const CELL := 128  # px per frame

const EXPL_FLASH    := Color(1.00, 1.00, 1.00)
const EXPL_CORE     := Color(1.00, 0.95, 0.40)
const EXPL_ORANGE   := Color(1.00, 0.55, 0.05)
const EXPL_RED      := Color(0.85, 0.20, 0.05)
const EXPL_DARKRED  := Color(0.55, 0.10, 0.05)
const EXPL_SMOKE_LT := Color(0.50, 0.45, 0.40)
const EXPL_SMOKE_DK := Color(0.25, 0.22, 0.20)

var _elapsed := 0.0


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hframes = FRAME_COUNT
	frame = 0
	pixel_size = 0.06  # world size: ~7.68 units for 128px

	texture = _build_sheet()


func _process(delta: float) -> void:
	_elapsed += delta
	var new_frame := int(_elapsed / FRAME_DURATION)
	if new_frame >= FRAME_COUNT:
		queue_free()
		return
	frame = new_frame


# ---------------------------------------------------------------------------
# Sprite sheet generation
# ---------------------------------------------------------------------------

func _build_sheet() -> ImageTexture:
	var img := Image.create(SHEET_W, SHEET_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for f in FRAME_COUNT:
		_draw_frame(img, f, f * CELL)

	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


func _draw_frame(img: Image, frame_idx: int, ox: int) -> void:
	var cx := ox + 64
	var cy := 64

	match frame_idx:
		0:
			# White flash — instant bang
			_circle(img, cx, cy, 20, EXPL_FLASH)
		1:
			# Fireball expanding
			_circle(img, cx, cy, 30, EXPL_ORANGE)
			_circle(img, cx, cy, 10, EXPL_FLASH)
		2:
			# Peak fireball
			_circle(img, cx, cy, 42, EXPL_ORANGE)
			_circle(img, cx, cy, 28, EXPL_CORE)
			_circle(img, cx, cy, 8, EXPL_FLASH)
		3:
			# Fireball + first smoke ring
			_circle(img, cx, cy, 48, EXPL_ORANGE)
			_circle(img, cx, cy, 30, EXPL_CORE)
			_ring(img, cx, cy, 48, 54, EXPL_RED)
		4:
			# Smoke expanding
			_circle(img, cx, cy, 35, EXPL_ORANGE)
			_ring(img, cx, cy, 38, 52, EXPL_DARKRED)
			_ring(img, cx, cy, 52, 58, EXPL_SMOKE_LT)
		5:
			# Fire subsiding
			_circle(img, cx, cy, 25, EXPL_ORANGE)
			_ring(img, cx, cy, 28, 44, EXPL_DARKRED)
			_ring(img, cx, cy, 44, 55, EXPL_SMOKE_LT)
		6:
			# Smoke column grows
			_circle(img, cx, cy, 20, EXPL_DARKRED)
			_ring(img, cx, cy, 22, 40, EXPL_SMOKE_LT)
			_ring(img, cx, cy, 40, 56, EXPL_SMOKE_DK)
		7:
			# Mostly smoke
			_circle(img, cx, cy, 10, EXPL_DARKRED)
			_ring(img, cx, cy, 12, 45, EXPL_SMOKE_DK)
		8:
			# Dissipating smoke — half alpha
			var smoke_fade := Color(EXPL_SMOKE_DK.r, EXPL_SMOKE_DK.g, EXPL_SMOKE_DK.b, 0.5)
			_circle(img, cx, cy, 40, smoke_fade)
		9:
			# Last wisps — sparse pixels
			_sparse_pixels(img, cx, cy, 0, 30, Color(0.3, 0.28, 0.26, 0.4))


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

func _circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if _in_bounds(img, x, y) and (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, col)


func _ring(img: Image, cx: int, cy: int, r_inner: int, r_outer: int, col: Color) -> void:
	var r2_out := r_outer * r_outer
	var r2_in  := r_inner * r_inner
	for y in range(cy - r_outer, cy + r_outer + 1):
		for x in range(cx - r_outer, cx + r_outer + 1):
			var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if _in_bounds(img, x, y) and d2 <= r2_out and d2 >= r2_in:
				img.set_pixel(x, y, col)


func _sparse_pixels(img: Image, cx: int, cy: int, r_min: int, r_max: int, col: Color) -> void:
	# Checkerboard-ish scatter in the annulus
	for y in range(cy - r_max, cy + r_max + 1):
		for x in range(cx - r_max, cx + r_max + 1):
			if not _in_bounds(img, x, y):
				continue
			var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 < r_min * r_min or d2 > r_max * r_max:
				continue
			if (x + y) % 3 == 0:
				img.set_pixel(x, y, col)


func _in_bounds(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()
