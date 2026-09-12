class_name EnemySpriteRenderer
extends RefCounted

## Static draw functions for 2D enemy jets.
## Called by GameWorld._draw() to render enemies at their screen positions.
##
## Enemy type index: 0=FIGHTER (olive green), 1=INTERCEPTOR (blue-grey), 2=BOMBER (charcoal)
## All colors derived from ab2-arcade-closeup-enemies.jpg reference.

const ENEMY_COLORS: Array[Dictionary] = [
	# Type 0: FIGHTER — dark olive green
	{
		"fuselage":        Color(0.180, 0.251, 0.094),  # #2E4018
		"wing_base":       Color(0.145, 0.208, 0.082),  # #253515
		"wing_underside":  Color(0.102, 0.149, 0.063),  # #1A2610
		"panel_accent":    Color(0.110, 0.173, 0.055),  # #1C2C0E
		"engine_intake":   Color(0.800, 0.102, 0.039),  # #CC1A0A
		"engine_interior": Color(0.039, 0.031, 0.031),  # #0A0808
		"engine_glow":     Color(1.0, 0.55, 0.08, 0.7),
		"canopy":          Color(0.620, 0.733, 0.831),  # #9EBBD4
		"dot_color":       Color(0.800, 0.200, 0.133),  # #CC3322
	},
	# Type 1: INTERCEPTOR — blue-grey
	{
		"fuselage":        Color(0.478, 0.549, 0.620),  # #7A8C9E
		"wing_base":       Color(0.416, 0.486, 0.557),  # #6A7C8E
		"wing_underside":  Color(0.290, 0.361, 0.431),  # #4A5C6E
		"panel_accent":    Color(0.227, 0.298, 0.369),  # #3A4C5E
		"engine_intake":   Color(0.800, 0.102, 0.039),  # #CC1A0A
		"engine_interior": Color(0.039, 0.031, 0.031),  # #0A0808
		"engine_glow":     Color(1.0, 0.55, 0.08, 0.7),
		"canopy":          Color(0.722, 0.831, 0.910),  # #B8D4E8
		"dot_color":       Color(0.533, 0.600, 0.667),  # #8899AA
	},
	# Type 2: BOMBER — dark charcoal grey
	{
		"fuselage":        Color(0.345, 0.361, 0.376),  # #585C60
		"wing_base":       Color(0.282, 0.286, 0.298),  # #48494C
		"wing_underside":  Color(0.196, 0.204, 0.227),  # #32343A
		"panel_accent":    Color(0.145, 0.149, 0.157),  # #252628
		"engine_intake":   Color(1.000, 0.251, 0.125),  # #FF4020
		"engine_interior": Color(0.039, 0.031, 0.031),  # #0A0808
		"engine_glow":     Color(1.0, 0.65, 0.15, 0.8),
		"canopy":          Color(0.533, 0.627, 0.690),  # #88A0B0
		"dot_color":       Color(0.667, 0.200, 0.000),  # #AA3300
	},
]


static func draw_enemy(canvas: CanvasItem, type: int, pos: Vector2, s: float) -> void:
	## Draw one enemy jet onto the canvas at screen position pos with scale s.
	## s = depth_to_scale(d) * 35.0
	var c: Dictionary = ENEMY_COLORS[clamp(type, 0, 2)]

	if s < 1.5:
		# Dot mode: just a colored dot
		canvas.draw_circle(pos, maxf(1.2, s * 0.5), c["dot_color"])
		return

	# Layer 1: Wing undersides (darkest, drawn first — behind fuselage)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(pos.x - s * 0.12, pos.y + s * 0.10),
		Vector2(pos.x - s * 1.55, pos.y + s * 0.38),
		Vector2(pos.x - s * 1.30, pos.y + s * 0.52),
		Vector2(pos.x - s * 0.08, pos.y + s * 0.28),
	]), [c["wing_underside"]])
	canvas.draw_polygon(PackedVector2Array([
		Vector2(pos.x + s * 0.12, pos.y + s * 0.10),
		Vector2(pos.x + s * 1.55, pos.y + s * 0.38),
		Vector2(pos.x + s * 1.30, pos.y + s * 0.52),
		Vector2(pos.x + s * 0.08, pos.y + s * 0.28),
	]), [c["wing_underside"]])

	# Layer 2: Main wings (top surface)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(pos.x - s * 0.14, pos.y - s * 0.05),
		Vector2(pos.x - s * 1.45, pos.y + s * 0.32),
		Vector2(pos.x - s * 1.30, pos.y + s * 0.50),
		Vector2(pos.x - s * 0.10, pos.y + s * 0.10),
	]), [c["wing_base"]])
	canvas.draw_polygon(PackedVector2Array([
		Vector2(pos.x + s * 0.14, pos.y - s * 0.05),
		Vector2(pos.x + s * 1.45, pos.y + s * 0.32),
		Vector2(pos.x + s * 1.30, pos.y + s * 0.50),
		Vector2(pos.x + s * 0.10, pos.y + s * 0.10),
	]), [c["wing_base"]])

	# Layer 3: Fuselage (7-vertex polygon)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(pos.x,            pos.y - s * 1.10),
		Vector2(pos.x + s * 0.20, pos.y - s * 0.35),
		Vector2(pos.x + s * 0.26, pos.y + s * 0.05),
		Vector2(pos.x + s * 0.22, pos.y + s * 0.45),
		Vector2(pos.x - s * 0.22, pos.y + s * 0.45),
		Vector2(pos.x - s * 0.26, pos.y + s * 0.05),
		Vector2(pos.x - s * 0.20, pos.y - s * 0.35),
	]), [c["fuselage"]])

	# Layer 4: Fuselage center shadow stripe
	canvas.draw_polygon(PackedVector2Array([
		Vector2(pos.x - s * 0.06, pos.y - s * 0.80),
		Vector2(pos.x + s * 0.06, pos.y - s * 0.80),
		Vector2(pos.x + s * 0.10, pos.y + s * 0.45),
		Vector2(pos.x - s * 0.10, pos.y + s * 0.45),
	]), [c["panel_accent"]])

	# Layer 5: Engine intake ring (red disc — key visual)
	var intake_center := Vector2(pos.x, pos.y - s * 0.05)
	canvas.draw_circle(intake_center, s * 0.24, c["engine_intake"])
	if s >= 4.0:
		canvas.draw_circle(intake_center, s * 0.16, c["engine_interior"])
		if s > 6.0:
			canvas.draw_circle(intake_center, s * 0.06, c["engine_glow"])

	# Layer 6: Canopy (only at s >= 8)
	if s >= 8.0:
		canvas.draw_polygon(PackedVector2Array([
			Vector2(pos.x,            pos.y - s * 0.78),
			Vector2(pos.x + s * 0.09, pos.y - s * 0.52),
			Vector2(pos.x - s * 0.09, pos.y - s * 0.52),
		]), [c["canopy"]])
		if s >= 14.0:
			canvas.draw_polygon(PackedVector2Array([
				Vector2(pos.x - s * 0.03, pos.y - s * 0.72),
				Vector2(pos.x + s * 0.04, pos.y - s * 0.62),
				Vector2(pos.x + s * 0.03, pos.y - s * 0.58),
				Vector2(pos.x - s * 0.04, pos.y - s * 0.65),
			]), [Color(1.0, 1.0, 1.0, 0.55)])

	# Layer 7: Wing tip chevrons (only at s >= 16)
	if s >= 16.0:
		canvas.draw_polygon(PackedVector2Array([
			Vector2(pos.x - s * 1.42, pos.y + s * 0.30),
			Vector2(pos.x - s * 1.30, pos.y + s * 0.22),
			Vector2(pos.x - s * 1.22, pos.y + s * 0.38),
		]), [c["panel_accent"]])
		canvas.draw_polygon(PackedVector2Array([
			Vector2(pos.x + s * 1.42, pos.y + s * 0.30),
			Vector2(pos.x + s * 1.30, pos.y + s * 0.22),
			Vector2(pos.x + s * 1.22, pos.y + s * 0.38),
		]), [c["panel_accent"]])

	# Layer 8: Tail stub (only at s >= 10)
	if s >= 10.0:
		canvas.draw_polygon(PackedVector2Array([
			Vector2(pos.x - s * 0.05, pos.y + s * 0.40),
			Vector2(pos.x + s * 0.05, pos.y + s * 0.40),
			Vector2(pos.x + s * 0.03, pos.y + s * 0.55),
			Vector2(pos.x - s * 0.03, pos.y + s * 0.55),
		]), [c["panel_accent"]])
