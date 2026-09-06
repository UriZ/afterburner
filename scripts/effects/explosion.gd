extends Sprite3D

## 8-frame procedural sprite-sheet explosion. Frees itself when done.

const FRAME_COUNT := 8
const FRAME_DURATION := 0.05  # seconds per frame — 0.4s total
const SHEET_W := 512
const SHEET_H := 64
const CELL := 64  # px per frame

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
	pixel_size = 0.025  # world size: ~1.6 units for 64px

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
	var cx := ox + 32
	var cy := 32

	match frame_idx:
		0:
			_circle(img, cx, cy, 8, EXPL_FLASH)
		1:
			_circle(img, cx, cy, 12, EXPL_CORE)
			_ring(img, cx, cy, 14, 16, EXPL_ORANGE)
			_circle(img, cx, cy, 3, EXPL_FLASH)
		2:
			_circle(img, cx, cy, 10, EXPL_CORE)
			_ring(img, cx, cy, 13, 16, EXPL_ORANGE)
			_ring(img, cx, cy, 17, 20, EXPL_RED)
			_ring(img, cx, cy, 20, 22, EXPL_SMOKE_LT)
		3:
			_irregular_circle(img, cx, cy, 8, EXPL_CORE, frame_idx)
			_ring(img, cx, cy, 12, 16, EXPL_ORANGE)
			_ring(img, cx, cy, 18, 22, EXPL_DARKRED)
			_smoke_wisps(img, cx, cy, 22, 28, EXPL_SMOKE_LT)
		4:
			_circle(img, cx, cy, 12, EXPL_ORANGE)
			_ring(img, cx, cy, 14, 20, EXPL_DARKRED)
			_ring(img, cx, cy, 21, 26, EXPL_SMOKE_DK)
			_sparse_pixels(img, cx, cy, 26, 30, EXPL_SMOKE_DK)
		5:
			_blobs(img, cx, cy, 14, EXPL_ORANGE)
			_ring(img, cx, cy, 16, 24, EXPL_SMOKE_LT)
			_ring(img, cx, cy, 24, 28, EXPL_SMOKE_DK)
		6:
			_irregular_circle(img, cx, cy, 20, EXPL_SMOKE_DK, frame_idx)
			_ring(img, cx, cy, 14, 20, Color(0.35, 0.30, 0.28))
		7:
			_sparse_pixels(img, cx, cy, 0, 16, Color(0.40, 0.36, 0.33, 0.6))


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


func _irregular_circle(img: Image, cx: int, cy: int, r: int, col: Color, seed_val: int) -> void:
	# Slightly bumpy circle using a cheap per-angle wobble
	for y in range(cy - r - 4, cy + r + 5):
		for x in range(cx - r - 4, cx + r + 5):
			if not _in_bounds(img, x, y):
				continue
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(float(dx * dx + dy * dy))
			var angle := atan2(float(dy), float(dx))
			var wobble := 1.0 + 0.25 * sin(angle * 5.0 + seed_val)
			if dist <= r * wobble:
				img.set_pixel(x, y, col)


func _smoke_wisps(img: Image, cx: int, cy: int, r_min: int, r_max: int, col: Color) -> void:
	# Diagonal blobs at 45° angles
	for angle_deg in [45, 135, 225, 315]:
		var rad := deg_to_rad(float(angle_deg))
		for dist in range(r_min, r_max):
			var px := cx + int(dist * cos(rad))
			var py := cy + int(dist * sin(rad))
			_circle(img, px, py, 2, col)


func _blobs(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	# Asymmetric blob cluster
	_circle(img, cx - 2, cy - 1, r, col)
	_circle(img, cx + 3, cy + 2, r - 2, col)
	_circle(img, cx - 1, cy + 3, r - 3, col)


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
