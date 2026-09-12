class_name DepthUtil
extends RefCounted

## Depth-to-screen coordinate transforms for the 2D sprite-scaling renderer.

const SCREEN_W: float = 960.0
const SCREEN_H: float = 672.0
const HORIZON_Y: float = 268.8


static func depth_to_scale(d: float) -> float:
	return 0.03 + d * d * 3.0


static func to_screen(x_offset: float, d: float) -> Vector2:
	var cx: float = SCREEN_W / 2.0
	var sx: float = cx + x_offset * (SCREEN_W * 0.47) * (0.1 + d * 0.9)
	var sy: float = HORIZON_Y + d * d * (SCREEN_H - HORIZON_Y) * 0.95
	return Vector2(sx, sy)


static func scale_pixels(d: float, base_size: float) -> float:
	return depth_to_scale(d) * base_size
