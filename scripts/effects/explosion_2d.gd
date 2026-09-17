extends Node2D

## 2D explosion effect. Two distinct visual types (criteria.md rule 10):
##
## - Fireball (is_kill=false): player death, ground impacts, large hits.
##   Ragged orange/red/yellow burst with a dark smoke fringe, matching
##   assets/reference/ab2-arcade-huge-explosion.jpg. Phases: flash -> fire ->
##   trailing smoke -> debris sparks. Duration 1.0s.
## - Kill puff (is_kill=true): enemy aircraft kills. Small pale cream/white
##   cauliflower cloud with NO orange or red anywhere — per
##   ab2-arcade-desert-explosions.png / ab2-arcade-closeup-enemies.jpg, aircraft
##   kills read as pale puffs, not fireballs. Duration 0.55s.
##
## Silhouettes are irregular polygons — per-vertex jittered angle/radius, with
## occasional long "tongue" spikes — not overlapping circles. A ring of
## circles at randomized phase still reads as a symmetric flower; the
## primitive itself was the defect (criteria.md rule 12). Vertex angles are
## generated in monotonic order (jitter capped below half the angular step)
## so every polygon is simple/star-shaped and can never self-intersect —
## Godot rejects bowtie polygon data at draw time.

## Defaults to true (kill puff) because the two aircraft-kill call sites
## (enemy_jet_2d.gd, missile_2d.gd) instantiate this script directly and
## don't set this flag — they own their own files, out of scope here. The
## one fireball caller (player_jet_2d.gd) goes through explosion_2d.tscn,
## which overrides this back to false. Do not flip this default without
## also updating the .tscn override.
@export var is_kill: bool = true

const FIRE_DURATION := 1.0
const KILL_DURATION := 0.55

# Screen is 960x672 (see depth_util.gd). Clamp so the widest layer never
# blows past the viewport — spawners can pass depth-scaled values that
# exceed 700+ for close-range kills (depth_to_scale peaks at ~3.0).
const MAX_BASE_RADIUS := 130.0
const MIN_BASE_RADIUS := 20.0

# Kill puffs are capped independently and much smaller than fireballs — a
# 40px radius is ~12% of the 672px screen height, matching rule 10's "10-12%
# screen height" target for an aircraft kill regardless of how large the
# clamped base_radius the caller passed in is.
const KILL_MAX_RADIUS := 40.0
const KILL_MIN_RADIUS := 22.0
const KILL_RADIUS_SCALE := 0.35

var base_radius: float = 60.0:  # set by spawner based on enemy depth
	set(value):
		base_radius = clampf(value, MIN_BASE_RADIUS, MAX_BASE_RADIUS)

var _lifetime: float = 0.0
var _duration: float = FIRE_DURATION
var _sparks: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []
var _fire_lobes: Array[Dictionary] = []
var _center_outer: Dictionary
var _center_core: Dictionary


func _ready() -> void:
	add_to_group("explosions")
	_duration = KILL_DURATION if is_kill else FIRE_DURATION
	_init_sparks()
	_init_smoke()
	_init_fire_lobes()


## Builds a simple (non-self-intersecting) irregular radial polygon: one
## radius jitter value per evenly-spaced angle step, with occasional longer
## "spike" vertices for ragged flame tongues. Angle jitter is capped below
## half the angular step so vertex order stays monotonic.
func _make_blob(num_verts: int, r_min: float, r_max: float, spike_chance: float, spike_min: float, spike_max: float) -> Dictionary:
	var step: float = TAU / num_verts
	var ang_jitter: float = step * 0.35
	var angles := PackedFloat32Array()
	var radii := PackedFloat32Array()
	for i in range(num_verts):
		angles.append(step * i + randf_range(-ang_jitter, ang_jitter))
		if randf() < spike_chance:
			radii.append(randf_range(spike_min, spike_max))
		else:
			radii.append(randf_range(r_min, r_max))
	return {"angles": angles, "radii": radii}


func _blob_polygon(center: Vector2, radius: float, blob: Dictionary) -> PackedVector2Array:
	var angles: PackedFloat32Array = blob["angles"]
	var radii: PackedFloat32Array = blob["radii"]
	var pts := PackedVector2Array()
	pts.resize(angles.size())
	for i in range(angles.size()):
		pts[i] = center + Vector2(cos(angles[i]), sin(angles[i])) * (radius * radii[i])
	return pts


func _init_sparks() -> void:
	var spark_count := 6 if is_kill else 10
	for i in range(spark_count):
		var angle := randf() * TAU
		var spd_frac := randf_range(0.8, 1.6)
		# Kill-puff debris stays cream/white — no orange or red (rule 10).
		var color: Color
		if is_kill:
			color = Color(1.0, 1.0, 0.95) if i % 2 == 0 else Color(0.85, 0.83, 0.78)
		else:
			color = Color(1.0, 0.8, 0.133) if i % 2 == 0 else Color(1.0, 0.4, 0.0)
		_sparks.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"speed_frac": spd_frac,
			"lifetime": randf_range(0.15, 0.35) if is_kill else randf_range(0.3, 0.6),
			"color": color,
		})


func _init_fire_lobes() -> void:
	# Offset lobe clusters (chunky lumps), each an irregular blob rather than
	# a fixed-position concentric-circle stack — reused for both the fireball
	# burst and the kill-puff cauliflower cloud.
	var count := 4 if is_kill else 5
	for i in range(count):
		var angle: float = (float(i) / float(count)) * TAU + randf_range(-0.3, 0.3)
		_fire_lobes.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist_frac": randf_range(0.18, 0.45),
			"size_frac": randf_range(0.55, 0.85),
			"outer": _make_blob(9, 0.6, 0.95, 0.22, 1.1, 1.4),
			"mid": _make_blob(8, 0.55, 0.9, 0.15, 1.0, 1.2),
			"core": _make_blob(7, 0.5, 0.85, 0.0, 1.0, 1.0),
		})
	if not is_kill:
		_center_outer = _make_blob(12, 0.6, 0.95, 0.2, 1.05, 1.3)
		_center_core = _make_blob(10, 0.55, 0.9, 0.0, 1.0, 1.0)


func _init_smoke() -> void:
	var count := 8
	for i in range(count):
		var angle := randf() * TAU
		# Spread puffs well apart so they read as distinct cauliflower lumps
		# trailing off the fireball rather than collapsing into one disc.
		var dist := randf_range(0.35, 0.85)
		var r_frac := randf_range(0.18, 0.38)
		_smoke_puffs.append({
			"offset_dir": Vector2(cos(angle), sin(angle)),
			"max_dist": dist,
			"radius_frac": r_frac,
			"delay": randf_range(0.0, 0.15),
			"blob": _make_blob(8, 0.7, 1.0, 0.2, 1.05, 1.25),
		})


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if is_kill:
		_draw_kill_puff()
		return

	# Phase 4: Debris sparks (0-0.6s, drawn first — behind everything)
	if _lifetime < 0.6:
		_draw_sparks()

	# Phase 3: Smoke cloud (0.45-0.9s) — starts after the fireball has had
	# most of its screen time, so the burst (not pale smoke) is what reads
	# as the explosion.
	if _lifetime > 0.45 and _lifetime < 0.9:
		_draw_smoke((_lifetime - 0.45) / 0.45)

	# Phase 2: Fire burst (0.08-0.5s)
	if _lifetime > 0.08 and _lifetime < 0.5:
		_draw_fire((_lifetime - 0.08) / 0.42)

	# Phase 1: Flash (0-0.08s)
	if _lifetime < 0.08:
		_draw_flash(_lifetime / 0.08)


func _draw_flash(t: float) -> void:
	# Kept clearly smaller than the fire burst's peak that follows it, so it
	# reads as a brief ignition spark rather than its own giant pale disc.
	var r: float = base_radius * 1.4 * (0.2 + t * 0.8)
	var a: float = 1.0 - t * 0.7
	draw_circle(Vector2.ZERO, maxf(r, base_radius * 0.5), Color(1.0, 1.0, 0.9, a))


func _draw_fire(t: float) -> void:
	# Base radius peaks at t=0.4 then shrinks
	var growth: float = smoothstep(0.0, 0.4, t)
	var shrink: float = smoothstep(0.4, 1.0, t)
	var r_base: float = base_radius * (1.8 + growth * 1.0 - shrink * 1.0)
	var alpha: float = 1.0 - smoothstep(0.6, 1.0, t)

	# Ragged, spiky lobe clusters — dark smoke fringe -> red-orange -> yellow
	# core. No straight edges or radial symmetry, matching the jagged
	# silhouette in ab2-arcade-huge-explosion.jpg (rule 12).
	for lobe in _fire_lobes:
		var center: Vector2 = lobe["dir"] * lobe["dist_frac"] * r_base
		var lr: float = lobe["size_frac"] * r_base * 0.65
		draw_colored_polygon(_blob_polygon(center, lr, lobe["outer"]), Color(0.22, 0.05, 0.02, alpha * 0.85))
		draw_colored_polygon(_blob_polygon(center, lr * 0.72, lobe["mid"]), Color(0.85, 0.24, 0.02, alpha))
		draw_colored_polygon(_blob_polygon(center, lr * 0.42, lobe["core"]), Color(1.0, 0.72, 0.12, alpha))

	# Central mass fills the gaps between lobes — also irregular, its own
	# blob shape (not a plain circle).
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base * 0.58, _center_outer), Color(0.85, 0.24, 0.02, alpha))
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base * 0.34, _center_core), Color(1.0, 0.85, 0.35, alpha))

	# Bright white-hot core point — small enough that a circle here doesn't
	# affect the overall ragged silhouette.
	draw_circle(Vector2.ZERO, r_base * 0.14, Color(1.0, 1.0, 0.9, alpha))


func _draw_smoke(t: float) -> void:
	for puff in _smoke_puffs:
		var delay: float = puff["delay"]
		if t < delay:
			continue
		var local_t: float = (t - delay) / (1.0 - delay)
		# Puffs start already spread out (40% of their offset) instead of
		# easing up from the center, and shrink (not grow) as they fade —
		# an ever-expanding puff reads as one giant pale disc instead of
		# trailing smoke.
		var spread: float = 0.4 + local_t * 0.6
		var drift: Vector2 = puff["offset_dir"] * puff["max_dist"] * base_radius * spread
		drift += Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		var r: float = puff["radius_frac"] * base_radius * (0.85 - local_t * 0.35)
		var a: float = 0.75 * (1.0 - local_t)
		if a <= 0.01 or r <= 1.0:
			continue

		var color: Color
		if local_t < 0.3:
			color = Color(0.910, 0.894, 0.847, a)  # cream
		elif local_t < 0.65:
			color = Color(0.784, 0.769, 0.722, a)  # grey
		else:
			color = Color(0.533, 0.518, 0.502, a)  # dark grey

		var rr: float = maxf(r, 2.0)
		draw_colored_polygon(_blob_polygon(drift, rr, puff["blob"]), color)
		draw_colored_polygon(_blob_polygon(drift, rr * 0.55, puff["blob"]), color.lightened(0.18))


func _draw_kill_puff() -> void:
	var t: float = _lifetime / _duration
	var r_cap: float = clampf(base_radius * KILL_RADIUS_SCALE, KILL_MIN_RADIUS, KILL_MAX_RADIUS)
	var growth: float = smoothstep(0.0, 0.25, t)
	var shrink: float = smoothstep(0.55, 1.0, t)
	var r_base: float = r_cap * (0.7 + growth * 0.5 - shrink * 0.3)
	var alpha: float = 1.0 - smoothstep(0.7, 1.0, t)

	if _lifetime < 0.4:
		_draw_sparks()

	# Cauliflower lobes — irregular cream/white polygons only. NO orange or
	# red anywhere (rule 10: aircraft kills are pale puffs, not fireballs).
	for lobe in _fire_lobes:
		var center: Vector2 = lobe["dir"] * lobe["dist_frac"] * r_base
		var lr: float = lobe["size_frac"] * r_base
		draw_colored_polygon(_blob_polygon(center, lr, lobe["outer"]), Color(0.784, 0.769, 0.722, alpha * 0.9))
		draw_colored_polygon(_blob_polygon(center, lr * 0.68, lobe["mid"]), Color(0.910, 0.894, 0.847, alpha))

	# Brief white ignition point — white is not a fireball color, still
	# permitted on a kill puff.
	var flash_a: float = alpha * (1.0 - smoothstep(0.0, 0.3, t))
	if flash_a > 0.0:
		draw_circle(Vector2.ZERO, r_base * 0.32, Color(1.0, 1.0, 0.97, flash_a))


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
