extends Node2D

## 2D explosion effect — 4 phase animated explosion per UI designer spec.
## Phase 1 (0-0.08s): White flash expanding circle
## Phase 2 (0.08-0.40s): Fire burst — cluster of overlapping glow circles (puffy cloud lobes), orange/yellow/red
## Phase 3 (0.30-0.90s): Smoke cloud — overlapping fading circles
## Phase 4 (0.0-0.60s): Debris sparks flying outward
## Total duration: 1.0 second, then queue_free.

const DURATION := 1.0

# Screen is 960x672 (see depth_util.gd). Clamp so the widest layer (the fire
# starburst, which peaks at ~2.8x base_radius) never blows past the viewport —
# spawners can pass depth-scaled values that exceed 700+ for close-range kills
# (depth_to_scale peaks at ~3.0), which previously produced an oversized flat
# disc showing only the innermost glow layer instead of the full explosion.
const MAX_BASE_RADIUS := 130.0
const MIN_BASE_RADIUS := 20.0

var base_radius: float = 60.0:  # set by spawner based on enemy depth
	set(value):
		base_radius = clampf(value, MIN_BASE_RADIUS, MAX_BASE_RADIUS)

var _lifetime: float = 0.0
var _sparks: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []
var _fire_lobes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("explosions")
	_init_sparks()
	_init_smoke()
	_init_fire_lobes()


func _init_sparks() -> void:
	var spark_count := 10
	for i in range(spark_count):
		var angle := randf() * TAU
		# speed_frac resolved against base_radius in _draw_sparks
		var spd_frac := randf_range(0.8, 1.6)
		_sparks.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"speed_frac": spd_frac,
			"lifetime": randf_range(0.3, 0.6),
			"color": Color(1.0, 0.8, 0.133) if i % 2 == 0 else Color(1.0, 0.4, 0.0),
		})


func _init_fire_lobes() -> void:
	# Fixed layout of overlapping glow lobes, positioned once so the cloud
	# shape doesn't reshuffle every frame (see _draw_fire).
	var count := 10
	for i in range(count):
		var angle: float = (float(i) / float(count)) * TAU + randf_range(-0.22, 0.22)
		_fire_lobes.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist_frac": randf_range(0.28, 0.60),
			"size_frac": randf_range(0.40, 0.62),
		})


func _init_smoke() -> void:
	var count := 8
	for i in range(count):
		var angle := randf() * TAU
		# Spread puffs well apart (0.35-0.85 of base_radius) so they read as
		# distinct cauliflower lumps trailing off the fireball — the old
		# 0.0-0.5 range with 0.25-0.55 radii put every puff on top of its
		# neighbor, and since draw_circle alpha-blends identical colors flat,
		# the whole cluster collapsed into one or two giant pale discs (#97
		# follow-up) instead of a puffy cloud.
		var dist := randf_range(0.35, 0.85)
		var r_frac := randf_range(0.18, 0.38)
		_smoke_puffs.append({
			"offset_dir": Vector2(cos(angle), sin(angle)),
			"max_dist": dist,
			"radius_frac": r_frac,
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

	# Phase 3: Smoke cloud (0.45-0.9s) — starts after the fireball has had
	# most of its screen time, so the burst (not pale smoke) is what reads
	# as the explosion (#97 follow-up: smoke was dominating 60% of the
	# lifetime and reading as flat pale discs instead of a fireball).
	if _lifetime > 0.45 and _lifetime < 0.9:
		_draw_smoke((_lifetime - 0.45) / 0.45)

	# Phase 2: Fire burst (0.08-0.5s)
	if _lifetime > 0.08 and _lifetime < 0.5:
		_draw_fire((_lifetime - 0.08) / 0.42)

	# Phase 1: Flash (0-0.08s)
	if _lifetime < 0.08:
		_draw_flash(_lifetime / 0.08)


func _draw_flash(t: float) -> void:
	# Kept clearly smaller than the fire burst's peak (2.8x) that follows it —
	# at the old 2.5x multiplier the flash was nearly as wide as the fireball
	# itself, so it read as its own giant pale disc rather than a brief
	# ignition spark (#97 follow-up).
	var r: float = base_radius * 1.4 * (0.2 + t * 0.8)
	var a: float = 1.0 - t * 0.7
	draw_circle(Vector2.ZERO, maxf(r, base_radius * 0.5), Color(1.0, 1.0, 0.9, a))


func _draw_fire(t: float) -> void:
	# Base radius peaks at t=0.4 then shrinks
	var growth: float = smoothstep(0.0, 0.4, t)
	var shrink: float = smoothstep(0.4, 1.0, t)
	var r_base: float = base_radius * (1.8 + growth * 1.0 - shrink * 1.0)
	var alpha: float = 1.0 - smoothstep(0.6, 1.0, t)

	# Puffy cloud of overlapping glow lobes — redesigned per #97 (a starburst
	# with fewer spikes is still a starburst; the reference has no straight
	# edges anywhere, per burst-c-05 / ab2-arcade-huge-explosion.jpg /
	# ab2-arcade-desert-explosions.png). Each lobe is 3 concentric circles
	# (dark red rim -> orange -> yellow core), matching the overlapping
	# glowing-sphere look of the original.
	for lobe in _fire_lobes:
		var center: Vector2 = lobe["dir"] * lobe["dist_frac"] * r_base
		var lr: float = lobe["size_frac"] * r_base * 0.6
		draw_circle(center, lr, Color(0.80, 0.16, 0.0, alpha))
		draw_circle(center, lr * 0.68, Color(1.0, 0.45, 0.0, alpha))
		draw_circle(center, lr * 0.38, Color(1.0, 0.80, 0.15, alpha))

	# Central glow, fills the gaps between lobes
	draw_circle(Vector2.ZERO, r_base * 0.55, Color(1.0, 0.72, 0.15, alpha))
	draw_circle(Vector2.ZERO, r_base * 0.32, Color(1.0, 0.93, 0.5, alpha))

	# Bright white-hot core
	draw_circle(Vector2.ZERO, r_base * 0.16, Color(1.0, 1.0, 0.9, alpha))


func _draw_smoke(t: float) -> void:
	for puff in _smoke_puffs:
		var delay: float = puff["delay"]
		if t < delay:
			continue
		var local_t: float = (t - delay) / (1.0 - delay)
		# Puffs start already spread out (40% of their offset) instead of
		# easing up from the center — at local_t=0 they're at peak alpha, so
		# starting bunched at the origin was what actually collapsed them
		# into one pale disc; the spread range above never got a chance to
		# show before alpha had already faded (#97 follow-up).
		var spread: float = 0.4 + local_t * 0.6
		var drift: Vector2 = puff["offset_dir"] * puff["max_dist"] * base_radius * spread
		# Jitter
		drift += Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		# Puffs shrink as they dissipate rather than growing — a puff that
		# keeps expanding while fading reads as an ever-larger pale disc
		# instead of trailing smoke (#97 follow-up).
		var r: float = puff["radius_frac"] * base_radius * (0.85 - local_t * 0.35)
		var a: float = 0.75 * (1.0 - local_t)

		var color: Color
		if local_t < 0.3:
			color = Color(0.910, 0.894, 0.847, a)  # cream
		elif local_t < 0.65:
			color = Color(0.784, 0.769, 0.722, a)  # grey
		else:
			color = Color(0.533, 0.518, 0.502, a)  # dark grey

		# Two-tone shading (dim outer + lighter core) gives each puff visible
		# roundness — a lumpy cauliflower bump instead of a flat translucent
		# disc — matching the fire lobes' layered-glow technique.
		var rr: float = maxf(r, 2.0)
		draw_circle(drift, rr, color)
		draw_circle(drift, rr * 0.6, color.lightened(0.18))


func _draw_sparks() -> void:
	for spark in _sparks:
		var life: float = spark["lifetime"]
		if _lifetime > life:
			continue
		var st: float = _lifetime / life
		var a: float = 1.0 - st
		var spd: float = spark["speed_frac"] * base_radius
		var end_pos: Vector2 = spark["dir"] * spd * _lifetime
		var start_pos: Vector2 = spark["dir"] * spd * maxf(_lifetime - 0.04, 0.0)
		draw_line(start_pos, end_pos, Color(spark["color"].r, spark["color"].g, spark["color"].b, a), 2.0)
