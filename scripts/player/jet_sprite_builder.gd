extends Node2D

## F-14 Tomcat 2D sprite proof-of-concept.
## Drawn from behind (dorsal view) using Godot's 2D _draw() API.
## Origin (0,0) is the jet center. Positive Y is down (screen space).
## Nose points UP (-Y), engines/tail point DOWN (+Y).
## Reference: assets/reference/ab2-arcade-reload-dorsal.jpg
##
## Coordinate scale: ~1 unit = 1px. Full sprite fits in ~260 x 200 px.
## Wings extend ±130 px wide; fuselage is ~160 px tall.

@export var show_afterburner: bool = true
@export var animate: bool = true

var _time: float = 0.0


func _process(delta: float) -> void:
	if animate:
		_time += delta
		queue_redraw()


func _draw() -> void:
	_draw_afterburner_flames()
	_draw_wings()
	_draw_horizontal_stabs()
	_draw_fuselage()
	_draw_engine_nacelles()
	_draw_tail_fins()
	_draw_canopy()
	_draw_panel_lines()
	_draw_engine_nozzles()


# ── Afterburner flames ────────────────────────────────────────────────────────

func _draw_afterburner_flames() -> void:
	if not show_afterburner:
		return

	var pulse := 1.0 + (0.18 * sin(_time * 18.0) if animate else 0.0)
	var jitter := (sin(_time * 23.0) * 2.5 if animate else 0.0)
	var fl := 90.0 * pulse
	var ny := 78.0   # nozzle exit Y

	for fx: float in [-18.0, 18.0]:
		# Outer glow
		draw_polygon(PackedVector2Array([
			Vector2(fx - 12, ny),
			Vector2(fx + 12, ny),
			Vector2(fx + jitter * 0.4 + 5, ny + fl * 1.1),
			Vector2(fx + jitter * 0.4,     ny + fl * 1.25),
			Vector2(fx + jitter * 0.4 - 5, ny + fl * 1.1),
		]), PackedColorArray([
			Color(1.0, 0.30, 0.05, 0.40), Color(1.0, 0.30, 0.05, 0.40),
			Color(0.9, 0.15, 0.00, 0.00), Color(0.9, 0.10, 0.00, 0.00),
			Color(0.9, 0.15, 0.00, 0.00),
		]))

		# Mid orange
		draw_polygon(PackedVector2Array([
			Vector2(fx - 8, ny),
			Vector2(fx + 8, ny),
			Vector2(fx + jitter * 0.3 + 3, ny + fl * 0.80),
			Vector2(fx + jitter * 0.3,     ny + fl * 0.90),
			Vector2(fx + jitter * 0.3 - 3, ny + fl * 0.80),
		]), PackedColorArray([
			Color(1.0, 0.55, 0.05, 0.90), Color(1.0, 0.55, 0.05, 0.90),
			Color(1.0, 0.40, 0.00, 0.25), Color(1.0, 0.35, 0.00, 0.00),
			Color(1.0, 0.40, 0.00, 0.25),
		]))

		# White-yellow core
		draw_polygon(PackedVector2Array([
			Vector2(fx - 5, ny + 2),
			Vector2(fx + 5, ny + 2),
			Vector2(fx + jitter * 0.15 + 1.5, ny + fl * 0.52),
			Vector2(fx + jitter * 0.15,        ny + fl * 0.62),
			Vector2(fx + jitter * 0.15 - 1.5, ny + fl * 0.52),
		]), PackedColorArray([
			Color(1.0, 1.00, 0.92, 1.0), Color(1.0, 1.00, 0.92, 1.0),
			Color(1.0, 0.90, 0.30, 0.65), Color(1.0, 0.85, 0.10, 0.00),
			Color(1.0, 0.90, 0.30, 0.65),
		]))


# ── Wings ─────────────────────────────────────────────────────────────────────

func _draw_wings() -> void:
	# F-14: wide combat-sweep wings. From behind, the wing glove locks at the
	# fuselage side (~±22 px) and the outer panel sweeps to ±155 px.
	# The trailing edge runs nearly flat; the leading edge sweeps back ~40°.

	var top  := Color(0.91, 0.92, 0.96)
	var mid  := Color(0.80, 0.82, 0.88)
	var shad := Color(0.62, 0.64, 0.72)

	# Left wing — 7-point shape for better leading-edge taper
	var lw := PackedVector2Array([
		Vector2(-22,  -5),   # glove root inner (by fuselage)
		Vector2(-22,  30),   # glove trailing root
		Vector2(-60,  50),   # inner panel trailing
		Vector2(-155, 68),   # tip trailing corner
		Vector2(-148, 48),   # tip mid
		Vector2(-125, 22),   # tip leading
		Vector2(-52,   2),   # inner panel leading
	])
	draw_polygon(lw, PackedColorArray([top, mid, mid, shad, shad, mid, top]))
	draw_polyline(lw + PackedVector2Array([lw[0]]), Color(0.42, 0.44, 0.52), 0.8)

	# Right wing (mirror X)
	var rw := PackedVector2Array([
		Vector2(22,  -5),
		Vector2(22,  30),
		Vector2(60,  50),
		Vector2(155, 68),
		Vector2(148, 48),
		Vector2(125, 22),
		Vector2(52,   2),
	])
	draw_polygon(rw, PackedColorArray([top, mid, mid, shad, shad, mid, top]))
	draw_polyline(rw + PackedVector2Array([rw[0]]), Color(0.42, 0.44, 0.52), 0.8)


# ── Horizontal stabilizers ────────────────────────────────────────────────────

func _draw_horizontal_stabs() -> void:
	# All-moving horizontal tail surfaces, outboard of the nacelles.
	var sc := Color(0.80, 0.81, 0.87)
	var ss := Color(0.60, 0.62, 0.70)

	var ls := PackedVector2Array([
		Vector2(-32, 55),  Vector2(-30, 70),
		Vector2(-80, 90),  Vector2(-92, 80),  Vector2(-50, 55),
	])
	draw_polygon(ls, PackedColorArray([sc, sc, ss, ss, sc]))
	draw_polyline(ls + PackedVector2Array([ls[0]]), Color(0.40, 0.42, 0.50), 0.7)

	var rs := PackedVector2Array([
		Vector2(32, 55),  Vector2(30, 70),
		Vector2(80, 90),  Vector2(92, 80),  Vector2(50, 55),
	])
	draw_polygon(rs, PackedColorArray([sc, sc, ss, ss, sc]))
	draw_polyline(rs + PackedVector2Array([rs[0]]), Color(0.40, 0.42, 0.50), 0.7)


# ── Fuselage ──────────────────────────────────────────────────────────────────

func _draw_fuselage() -> void:
	# Wide elongated body. Widest at wing root (~Y=0),
	# tapers to nose tip and to tail. Engine area bulges.

	var fh := Color(0.96, 0.97, 1.00)
	var fm := Color(0.88, 0.89, 0.95)
	var fs := Color(0.76, 0.78, 0.87)

	# Main fuselage outline
	var fp := PackedVector2Array([
		Vector2(0,   -80),  # nose tip
		Vector2(9,   -65),  Vector2(16,  -45),  Vector2(22,  -22),
		Vector2(24,   0),   Vector2(22,   22),  Vector2(30,   45),
		Vector2(26,   62),  Vector2(18,   78),
		Vector2(0,    84),  # tail tip
		Vector2(-18,  78),  Vector2(-26,  62),  Vector2(-30,  45),
		Vector2(-22,  22),  Vector2(-24,   0),  Vector2(-22, -22),
		Vector2(-16, -45),  Vector2(-9,  -65),
	])
	draw_polygon(fp, PackedColorArray([
		fh, fm, fm, fs, fs, fm, fs, fs, fm,
		fh, fm, fs, fs, fm, fs, fs, fm, fm,
	]))
	draw_polyline(fp + PackedVector2Array([fp[0]]), Color(0.35, 0.38, 0.46), 1.2)

	# Orange intake ramp stripes (F-14 identity — on either side of fuselage)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -34), Vector2(-20, -34),
		Vector2(-20, -10), Vector2(-26, -10),
	]), Color(0.85, 0.35, 0.10))
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, -34), Vector2(26, -34),
		Vector2(26, -10), Vector2(20, -10),
	]), Color(0.85, 0.35, 0.10))

	# Dorsal spine ridge
	draw_line(Vector2(0, -76), Vector2(0, 35), Color(0.84, 0.86, 0.94), 1.5)


# ── Engine nacelles ───────────────────────────────────────────────────────────

func _draw_engine_nacelles() -> void:
	for side: int in [-1, 1]:
		var cx := float(side) * 18.0
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 16:
			var a := (i / 16.0) * TAU
			pts.append(Vector2(cx + cos(a) * 12.0, 55.0 + sin(a) * 24.0))
			var t := sin(a) * 0.5 + 0.5   # 0 at top, 1 at bottom
			cols.append(Color(0.64 - t * 0.24, 0.64 - t * 0.24, 0.67 - t * 0.24))
		draw_polygon(pts, cols)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.26, 0.26, 0.30), 1.0)

		# Intake ring at top of nacelle
		draw_arc(Vector2(cx, 33.0), 10.0, 0.0, TAU, 16, Color(0.38, 0.38, 0.42), 2.0)


# ── Tail fins ─────────────────────────────────────────────────────────────────

func _draw_tail_fins() -> void:
	# Twin vertical tail fins. From behind, the fin root sits on the nacelle top,
	# the fin sweeps forward toward the nose (offset: leading edge is further
	# forward/inward). The fin has a slight outward cant.
	# Viewed from behind: left fin appears on the LEFT of center, right on RIGHT.
	var fl := Color(0.88, 0.90, 0.95)
	var fd := Color(0.52, 0.54, 0.64)

	# Left fin — centered ~over left nacelle (~X -18)
	var lf := PackedVector2Array([
		Vector2(-12,  10),   # leading edge top (swept toward nose)
		Vector2(-8,   15),   # trailing edge top
		Vector2(-12,  74),   # trailing edge base
		Vector2(-28,  72),   # leading edge base (outer)
	])
	draw_polygon(lf, PackedColorArray([fl, fl, fd, fd]))
	draw_polyline(lf + PackedVector2Array([lf[0]]), Color(0.28, 0.30, 0.38), 0.9)

	# Right fin
	var rf := PackedVector2Array([
		Vector2(12,  10),
		Vector2(8,   15),
		Vector2(12,  74),
		Vector2(28,  72),
	])
	draw_polygon(rf, PackedColorArray([fl, fl, fd, fd]))
	draw_polyline(rf + PackedVector2Array([rf[0]]), Color(0.28, 0.30, 0.38), 0.9)


# ── Engine nozzles ────────────────────────────────────────────────────────────

func _draw_engine_nozzles() -> void:
	for cx: float in [-18.0, 18.0]:
		# Outer nozzle ring
		draw_arc(Vector2(cx, 78.0), 11.0, 0.0, TAU, 16, Color(0.22, 0.18, 0.16), 3.5)

		# Dark interior
		var inner := PackedVector2Array()
		for i in 12:
			var a := (i / 12.0) * TAU
			inner.append(Vector2(cx + cos(a) * 8.0, 78.0 + sin(a) * 8.0))
		draw_colored_polygon(inner, Color(0.09, 0.07, 0.06))

		# Glowing core
		var glow_a := 0.82 + (0.22 * sin(_time * 15.0) if animate else 0.0)
		var core := PackedVector2Array()
		for i in 10:
			var a := (i / 10.0) * TAU
			core.append(Vector2(cx + cos(a) * 4.5, 78.0 + sin(a) * 4.5))
		draw_colored_polygon(core, Color(1.0, 0.58, 0.08, glow_a))


# ── Canopy ────────────────────────────────────────────────────────────────────

func _draw_canopy() -> void:
	# Outer frame (dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -63), Vector2(9, -52), Vector2(11, -38),
		Vector2(9, -26), Vector2(0, -24),
		Vector2(-9, -26), Vector2(-11, -38), Vector2(-9, -52),
	]), Color(0.20, 0.22, 0.26))

	# Glass (blue tinted)
	draw_polygon(PackedVector2Array([
		Vector2(0, -61), Vector2(8, -50), Vector2(9, -37),
		Vector2(7, -26), Vector2(0, -25),
		Vector2(-7, -26), Vector2(-9, -37), Vector2(-8, -50),
	]), PackedColorArray([
		Color(0.15, 0.22, 0.58, 0.88),
		Color(0.12, 0.18, 0.50, 0.88),
		Color(0.10, 0.15, 0.44, 0.88),
		Color(0.10, 0.15, 0.42, 0.88),
		Color(0.12, 0.18, 0.47, 0.88),
		Color(0.10, 0.15, 0.42, 0.88),
		Color(0.10, 0.15, 0.44, 0.88),
		Color(0.12, 0.18, 0.50, 0.88),
	]))

	# Canopy frame centerline divider
	draw_line(Vector2(0, -61), Vector2(0, -25), Color(0.18, 0.20, 0.24), 1.0)

	# Highlight glint
	draw_line(Vector2(-2, -59), Vector2(-5, -46), Color(1.0, 1.0, 1.0, 0.38), 2.0)


# ── Panel lines ───────────────────────────────────────────────────────────────

func _draw_panel_lines() -> void:
	var p := Color(0.52, 0.55, 0.64, 0.60)

	draw_line(Vector2(-22, -5),  Vector2(-22, 28), p, 0.8)   # left wing fold
	draw_line(Vector2(22,  -5),  Vector2(22,  28), p, 0.8)   # right wing fold
	draw_line(Vector2(-22, 10),  Vector2(22,  10), p, 0.7)   # center cross-panel
	draw_line(Vector2(-14, -42), Vector2(14, -42), p, 0.7)   # nose section
	draw_line(Vector2(-22, 55),  Vector2(22,  55), p, 0.7)   # aft panel
