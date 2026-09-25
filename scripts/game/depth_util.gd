class_name DepthUtil
extends RefCounted

## Depth-to-screen coordinate transforms for the 2D sprite-scaling renderer.

const SCREEN_W: float = 960.0
const SCREEN_H: float = 672.0

# Horizon is now PER STAGE (#120) — AB2's cruise stages sit at 60-65% from
# top, but canyon stages (8, 17) put it near the top of the frame. A single
# compile-time const can't represent that, so the horizon is runtime state,
# set once per stage from game_manager_2d.gd's _apply_stage() and read by
# every projection/draw site below. 0.625 (420/672) is today's cruise value
# and remains the default and the value for every stage that has no measured
# canyon evidence — see stage_data.gd's STAGES table.
const DEFAULT_HORIZON_FRACTION: float = 0.625
static var horizon_y: float = SCREEN_H * DEFAULT_HORIZON_FRACTION

# Pixel lift applied per unit of `altitude` at the same d^2 growth rate as the
# ground descent term below (#100). A flying object (enemy jet, weapon homing
# on one) is not on the ground plane, so it needs to rise above the horizon
# as it approaches instead of descending below it. altitude=0 (the default)
# reproduces the exact old ground-only formula for every existing caller —
# only callers that pass a nonzero altitude opt into the sky-rise behavior.
# Deliberately an ABSOLUTE pixel count, not scaled by ground_span(): altitude
# is a world quantity, and where the horizon sits must not change how high an
# enemy flies. Scaling this by span would collapse the enemy lift to
# 565-580 ≈ -15px at a 12% horizon — enemies would hug the horizon line.
const ALTITUDE_LIFT_PIXELS: float = 580.0


## Sets the horizon for the current stage, given as a fraction of SCREEN_H
## (0 = top of frame, 1 = bottom). Called exactly once per stage from
## game_manager_2d.gd's _apply_stage() — do not write horizon_y from
## rendering code. Clamped to keep the ground/sky bands both nonempty.
static func set_horizon_fraction(f: float) -> void:
	horizon_y = SCREEN_H * clampf(f, 0.05, 0.90)


static func horizon_fraction() -> float:
	return horizon_y / SCREEN_H


static func ground_span() -> float:
	return SCREEN_H - horizon_y


static func depth_to_scale(d: float) -> float:
	return 0.03 + d * d * 3.0


static func to_screen(x_offset: float, d: float, altitude: float = 0.0) -> Vector2:
	var cx: float = SCREEN_W / 2.0
	var sx: float = cx + x_offset * (SCREEN_W * 0.47) * (0.1 + d * 0.9)
	var sy: float = horizon_y + d * d * (ground_span() * 0.95 - altitude * ALTITUDE_LIFT_PIXELS)
	return Vector2(sx, sy)


static func scale_pixels(d: float, base_size: float) -> float:
	return depth_to_scale(d) * base_size
