extends Node2D

## 2D explosion effect — 4 phase animated explosion per UI designer spec.
## Phase 1 (0-0.08s): White flash expanding circle
## Phase 2 (0.08-0.40s): Fire burst — jagged star polygon, orange/yellow/red
## Phase 3 (0.30-0.90s): Smoke cloud — overlapping fading circles
## Phase 4 (0.0-0.60s): Debris sparks flying outward
## Total duration: 1.0 second, then queue_free.

const DURATION := 1.0

var base_radius: float = 60.0  # set by spawner based on enemy depth

var _lifetime: float = 0.0
var _sparks: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("explosions")
	_init_sparks()
	_init_smoke()


func _init_sparks() -> void:
	var spark_count := 10
	for i in range(spark_count):
		var angle := randf() * TAU
		var spd := randf_range(80.0, 160.0)
		_sparks.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"speed": spd,
			"lifetime": randf_range(0.3, 0.6),
			"color": Color(1.0, 0.8, 0.133) if i % 2 == 0 else Color(1.0, 0.4, 0.0),
		})


func _init_smoke() -> void:
	var count := 8
	for i in range(count):
		var angle := randf() * TAU
		var dist := randf_range(0.0, 0.5)
		var r := randf_range(20.0, 40.0)
		_smoke_puffs.append({
			"offset_dir": Vector2(cos(angle), sin(angle)),
			"max_dist": dist,
			"radius": r,
			"delay": randf_range(0.0, 0.15),
		})


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _lifetime / DURATION

	# Phase 4: Debris sparks (0-0.6s, drawn first — behind everything)
	if _lifetime < 0.6:
		_draw_sparks()

	# Phase 3: Smoke cloud (0.3-0.9s)
	if _lifetime > 0.3 and _lifetime < 0.9:
		_draw_smoke((_lifetime - 0.3) / 0.6)

	# Phase 2: Fire burst (0.08-0.4s)
	if _lifetime > 0.08 and _lifetime < 0.4:
		_draw_fire((_lifetime - 0.08) / 0.32)

	# Phase 1: Flash (0-0.08s)
	if _lifetime < 0.08:
		_draw_flash(_lifetime / 0.08)


func _draw_flash(t: float) -> void:
	var r: float = base_radius * 2.5 * (0.2 + t * 0.8)
	var a: float = 1.0 - t * 0.7
	draw_circle(Vector2.ZERO, maxf(r, 40.0), Color(1.0, 1.0, 0.9, a))


func _draw_fire(t: float) -> void:
	# Base radius peaks at t=0.4 then shrinks
	var growth: float = smoothstep(0.0, 0.4, t)
	var shrink: float = smoothstep(0.4, 1.0, t)
	var r_base: float = base_radius * (1.8 + growth * 1.0 - shrink * 1.0)
	var alpha: float = 1.0 - smoothstep(0.6, 1.0, t)

	# Outer starburst — 8 thick jagged spikes, dark orange-red
	var r_outer: float = r_base * 1.0
	var r_inner: float = r_outer * 0.48
	var pts: int = 8
	var verts_outer := PackedVector2Array()
	for i in range(pts * 2):
		var angle: float = float(i) / float(pts * 2) * TAU
		# Alternate outer/inner, add slight random-looking wobble via sin
		var wobble: float = 1.0 + sin(float(i) * 2.3 + t * 5.0) * 0.08
		var r: float = r_outer * wobble if i % 2 == 0 else r_inner
		verts_outer.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(verts_outer, Color(0.85, 0.18, 0.0, alpha))

	# Mid starburst — orange, slightly smaller
	var r_mid: float = r_base * 0.75
	var r_mid_in: float = r_mid * 0.52
	var verts_mid := PackedVector2Array()
	for i in range(pts * 2):
		var angle: float = float(i) / float(pts * 2) * TAU + 0.2  # rotated offset
		var wobble: float = 1.0 + sin(float(i) * 1.9 + t * 7.0) * 0.07
		var r: float = r_mid * wobble if i % 2 == 0 else r_mid_in
		verts_mid.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(verts_mid, Color(1.0, 0.45, 0.0, alpha))

	# Inner orange-yellow starburst
	var r_in2: float = r_base * 0.52
	var r_in2_in: float = r_in2 * 0.55
	var verts_in2 := PackedVector2Array()
	for i in range(pts * 2):
		var angle: float = float(i) / float(pts * 2) * TAU + 0.4
		var r: float = r_in2 if i % 2 == 0 else r_in2_in
		verts_in2.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(verts_in2, Color(1.0, 0.72, 0.05, alpha))

	# Large central glow circle — yellow-white, fills ~40% of burst
	draw_circle(Vector2.ZERO, r_base * 0.40, Color(1.0, 0.93, 0.5, alpha))

	# Bright white core
	draw_circle(Vector2.ZERO, r_base * 0.20, Color(1.0, 1.0, 0.9, alpha))


func _draw_smoke(t: float) -> void:
	for puff in _smoke_puffs:
		var delay: float = puff["delay"]
		if t < delay:
			continue
		var local_t: float = (t - delay) / (1.0 - delay)
		var drift: Vector2 = puff["offset_dir"] * puff["max_dist"] * base_radius * local_t
		# Jitter
		drift += Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		var r: float = puff["radius"] * (0.6 + local_t * 0.4)
		var a: float = 0.85 * (1.0 - local_t)

		var color: Color
		if local_t < 0.3:
			color = Color(0.910, 0.894, 0.847, a)  # cream
		elif local_t < 0.65:
			color = Color(0.784, 0.769, 0.722, a)  # grey
		else:
			color = Color(0.533, 0.518, 0.502, a)  # dark grey

		draw_circle(drift, maxf(r, 2.0), color)


func _draw_sparks() -> void:
	var spark_t: float = _lifetime / 0.6
	for spark in _sparks:
		var life: float = spark["lifetime"]
		if _lifetime > life:
			continue
		var st: float = _lifetime / life
		var a: float = 1.0 - st
		var spd: float = spark["speed"]
		var end_pos: Vector2 = spark["dir"] * spd * _lifetime
		var start_pos: Vector2 = spark["dir"] * spd * maxf(_lifetime - 0.04, 0.0)
		draw_line(start_pos, end_pos, Color(spark["color"].r, spark["color"].g, spark["color"].b, a), 2.0)
