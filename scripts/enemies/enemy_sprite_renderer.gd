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


static func draw_enemy(canvas: CanvasItem, type: int, pos: Vector2, s: float, bank_rad: float = 0.0) -> void:
	## Draw one enemy jet onto the canvas at screen position pos with scale s,
	## banked bank_rad radians (see enemy_jet_2d.gd's get_bank_angle() — #100:
	## reference frames show enemies canted into their turn, never flat).
	## s = depth_to_scale(d) * 35.0
	var c: Dictionary = ENEMY_COLORS[clamp(type, 0, 2)]

	if s < 1.5:
		# Dot mode: just a colored dot — too small for a bank to read, and a
		# dot has no orientation anyway, so skip the transform entirely.
		canvas.draw_circle(pos, maxf(1.2, s * 0.5), c["dot_color"])
		return

	# Every vertex below is drawn relative to the origin; draw_set_transform
	# positions and rotates the whole sprite in one step, so bank reads as a
	# rigid roll of the silhouette rather than a skew of individual layers.
	canvas.draw_set_transform(pos, bank_rad, Vector2.ONE)

	# Layer 1: Wing undersides (darkest, drawn first — behind fuselage)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(-s * 0.12, s * 0.10),
		Vector2(-s * 1.55, s * 0.38),
		Vector2(-s * 1.30, s * 0.52),
		Vector2(-s * 0.08, s * 0.28),
	]), [c["wing_underside"]])
	canvas.draw_polygon(PackedVector2Array([
		Vector2(s * 0.12, s * 0.10),
		Vector2(s * 1.55, s * 0.38),
		Vector2(s * 1.30, s * 0.52),
		Vector2(s * 0.08, s * 0.28),
	]), [c["wing_underside"]])

	# Layer 2: Main wings (top surface)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(-s * 0.14, -s * 0.05),
		Vector2(-s * 1.45, s * 0.32),
		Vector2(-s * 1.30, s * 0.50),
		Vector2(-s * 0.10, s * 0.10),
	]), [c["wing_base"]])
	canvas.draw_polygon(PackedVector2Array([
		Vector2(s * 0.14, -s * 0.05),
		Vector2(s * 1.45, s * 0.32),
		Vector2(s * 1.30, s * 0.50),
		Vector2(s * 0.10, s * 0.10),
	]), [c["wing_base"]])

	# Layer 3: Fuselage (7-vertex polygon)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(0.0,       -s * 1.10),
		Vector2(s * 0.20,  -s * 0.35),
		Vector2(s * 0.26,   s * 0.05),
		Vector2(s * 0.22,   s * 0.45),
		Vector2(-s * 0.22,  s * 0.45),
		Vector2(-s * 0.26,  s * 0.05),
		Vector2(-s * 0.20, -s * 0.35),
	]), [c["fuselage"]])

	# Layer 4: Fuselage center shadow stripe
	canvas.draw_polygon(PackedVector2Array([
		Vector2(-s * 0.06, -s * 0.80),
		Vector2(s * 0.06,  -s * 0.80),
		Vector2(s * 0.10,   s * 0.45),
		Vector2(-s * 0.10,  s * 0.45),
	]), [c["panel_accent"]])

	# Layer 5: Engine intake ring (red disc accent — was s*0.24, wider than the
	# fuselage itself and read as an oversized bullseye; reference shows a
	# modest marking, not a dominant roundel)
	var intake_center := Vector2(0.0, -s * 0.05)
	canvas.draw_circle(intake_center, s * 0.13, c["engine_intake"])
	if s >= 4.0:
		canvas.draw_circle(intake_center, s * 0.087, c["engine_interior"])
		if s > 6.0:
			canvas.draw_circle(intake_center, s * 0.033, c["engine_glow"])

	# Layer 6: Canopy (only at s >= 8)
	if s >= 8.0:
		canvas.draw_polygon(PackedVector2Array([
			Vector2(0.0,      -s * 0.78),
			Vector2(s * 0.09, -s * 0.52),
			Vector2(-s * 0.09, -s * 0.52),
		]), [c["canopy"]])
		if s >= 14.0:
			canvas.draw_polygon(PackedVector2Array([
				Vector2(-s * 0.03, -s * 0.72),
				Vector2(s * 0.04,  -s * 0.62),
				Vector2(s * 0.03,  -s * 0.58),
				Vector2(-s * 0.04, -s * 0.65),
			]), [Color(1.0, 1.0, 1.0, 0.55)])

	# Layer 7: Wing tip chevrons (only at s >= 16)
	if s >= 16.0:
		canvas.draw_polygon(PackedVector2Array([
			Vector2(-s * 1.42, s * 0.30),
			Vector2(-s * 1.30, s * 0.22),
			Vector2(-s * 1.22, s * 0.38),
		]), [c["panel_accent"]])
		canvas.draw_polygon(PackedVector2Array([
			Vector2(s * 1.42, s * 0.30),
			Vector2(s * 1.30, s * 0.22),
			Vector2(s * 1.22, s * 0.38),
		]), [c["panel_accent"]])

	# Layer 8: Tail stub (only at s >= 10)
	if s >= 10.0:
		canvas.draw_polygon(PackedVector2Array([
			Vector2(-s * 0.05, s * 0.40),
			Vector2(s * 0.05,  s * 0.40),
			Vector2(s * 0.03,  s * 0.55),
			Vector2(-s * 0.03, s * 0.55),
		]), [c["panel_accent"]])

	# Reset so the transform doesn't leak into whatever GameWorld draws next
	# (ground, other enemies, HUD) — every _draw_enemy_obj() call must leave
	# the canvas transform as it found it.
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
