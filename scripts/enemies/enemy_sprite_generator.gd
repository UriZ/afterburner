class_name EnemySpriteGenerator
extends RefCounted

## Generates placeholder enemy jet sprites at runtime.
## Each enemy type gets a distinct silhouette and color.

const FRAME_SIZE := 48

# Enemy type palettes
const FIGHTER_BODY := Color(0.55, 0.55, 0.60)     # grey
const FIGHTER_WING := Color(0.40, 0.40, 0.45)
const FIGHTER_CANOPY := Color(0.9, 0.9, 0.3)       # yellow canopy

const INTERCEPTOR_BODY := Color(0.75, 0.20, 0.20)  # red
const INTERCEPTOR_WING := Color(0.55, 0.15, 0.15)
const INTERCEPTOR_CANOPY := Color(0.9, 0.9, 0.3)

const BOMBER_BODY := Color(0.25, 0.55, 0.25)       # green
const BOMBER_WING := Color(0.18, 0.40, 0.18)
const BOMBER_CANOPY := Color(0.9, 0.9, 0.3)


enum EnemyVisual { FIGHTER, INTERCEPTOR, BOMBER }


static func generate_texture(visual: EnemyVisual) -> ImageTexture:
	var size := FRAME_SIZE
	if visual == EnemyVisual.BOMBER:
		size = 64  # bombers are larger
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	match visual:
		EnemyVisual.FIGHTER:
			_draw_fighter(image)
		EnemyVisual.INTERCEPTOR:
			_draw_interceptor(image)
		EnemyVisual.BOMBER:
			_draw_bomber(image)

	return ImageTexture.create_from_image(image)


static func _draw_fighter(image: Image) -> void:
	var cx := FRAME_SIZE / 2
	var cy := FRAME_SIZE / 2
	# Fuselage - narrow body
	_draw_ellipse(image, cx, cy, 4, 14, FIGHTER_BODY)
	# Wings - medium span
	_draw_wing_pair(image, cx, cy + 2, 16, 3, FIGHTER_WING)
	# Tail fins
	_draw_wing_pair(image, cx, cy + 12, 7, 2, FIGHTER_WING)
	# Canopy
	_draw_ellipse(image, cx, cy - 5, 2, 3, FIGHTER_CANOPY)
	# Exhaust
	_draw_ellipse(image, cx, cy + 16, 2, 2, Color(0.2, 0.2, 0.25))


static func _draw_interceptor(image: Image) -> void:
	var cx := FRAME_SIZE / 2
	var cy := FRAME_SIZE / 2
	# Fuselage - slim and long
	_draw_ellipse(image, cx, cy, 3, 16, INTERCEPTOR_BODY)
	# Wings - swept back, narrow
	_draw_wing_pair(image, cx, cy + 3, 14, 2, INTERCEPTOR_WING)
	# Tail fins - small
	_draw_wing_pair(image, cx, cy + 13, 5, 1, INTERCEPTOR_WING)
	# Canopy
	_draw_ellipse(image, cx, cy - 6, 2, 2, INTERCEPTOR_CANOPY)
	# Exhaust
	_draw_ellipse(image, cx, cy + 17, 2, 1, Color(0.2, 0.2, 0.25))


static func _draw_bomber(image: Image) -> void:
	var cx := 32
	var cy := 32
	# Fuselage - wide and long
	_draw_ellipse(image, cx, cy, 7, 18, BOMBER_BODY)
	# Wings - large span
	_draw_wing_pair(image, cx, cy + 2, 24, 5, BOMBER_WING)
	# Tail fins
	_draw_wing_pair(image, cx, cy + 14, 10, 3, BOMBER_WING)
	# Canopy
	_draw_ellipse(image, cx, cy - 7, 3, 4, BOMBER_CANOPY)
	# Twin exhaust
	_draw_ellipse(image, cx - 3, cy + 19, 2, 2, Color(0.2, 0.2, 0.25))
	_draw_ellipse(image, cx + 3, cy + 19, 2, 2, Color(0.2, 0.2, 0.25))


static func _draw_ellipse(
	image: Image, cx: int, cy: int, rx: int, ry: int, color: Color
) -> void:
	if rx <= 0 or ry <= 0:
		return
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			var dist := float(dx * dx) / float(rx * rx) + float(dy * dy) / float(ry * ry)
			if dist <= 1.0:
				var px := cx + dx
				var py := cy + dy
				if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
					image.set_pixel(px, py, color)


static func _draw_wing_pair(
	image: Image, cx: int, cy: int, half_span: int, thickness: int, color: Color
) -> void:
	# Draw two wings symmetrically. Tapers toward tips.
	for side: int in [-1, 1]:
		for i in range(half_span):
			var t := float(i) / float(half_span)
			var h := maxi(1, roundi(lerpf(float(thickness), 1.0, t)))
			var px: int = cx + side * (i + 1)
			for dy in range(-h, h + 1):
				var py: int = cy + dy
				if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
					image.set_pixel(px, py, color)
