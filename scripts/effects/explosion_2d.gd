extends Node2D

## 2D explosion effect. Two distinct visual types (criteria.md rule 10):
##
## - Fireball (is_kill=false): player death, ground impacts, large hits.
##   A 14-tongue radiating sunburst (ab2-arcade-huge-explosion.jpg): a dark
##   orange-red outer star with a brighter yellow-orange inner star nested
##   inside it, dark maroon mottle blotches scattered through the mid-body,
##   and an irregular white-hot core. Phases: flash -> fire -> trailing
##   smoke -> debris sparks. Duration 1.0s.
## - Kill puff (is_kill=true): enemy aircraft kills. A single dense
##   cauliflower-edged cream/white polygon — per ab2-arcade-desert-
##   explosions.png / ab2-arcade-closeup-enemies.jpg, aircraft kills read as
##   pale opaque puffs, not fireballs, with NO orange or red anywhere.
##   Duration 0.55s.
##
## Both bodies are OPAQUE for nearly all of their life (alpha only fades in
## the final stretch) and built from simple (non-self-intersecting) radial
## polygons — per-vertex jittered angle/radius, angles generated in
## monotonic order with jitter capped below half the angular step, so every
## polygon is star-shaped and can never self-intersect (Godot rejects bowtie
## polygon data at draw time). Round 5 gate (criteria.md rule 12) found the
## previous design translucent, with visible gaps between separate offset
## lobes, and facets far coarser than the reference's fine fringe — fixed by
## drawing each body as ONE simple polygon (gapless by construction) with a
## high vertex count, then layering smaller uniform scalings of that SAME
## polygon on top for shading. A smaller scaling of a star-shaped polygon is
## always strictly inside the larger one, so the nested layers can never
## open a gap either.

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

# Vertex count for the kill-puff cauliflower blob. At the puff's max radius
# (~40px) this puts neighbouring vertices a few px apart around the
# perimeter — the fine bump scale rule 12b asks for, instead of the ~6-9
# vertex polygons that used to read as giant flat facets.
const KILL_BLOB_VERTS := 40

# Number of radiating tongues on the fireball's sunburst silhouette, per
# ab2-arcade-huge-explosion.jpg. Each tongue is a tip vertex + a valley
# vertex, so the underlying star polygon has TONGUE_COUNT * 2 vertices.
const TONGUE_COUNT := 14

var base_radius: float = 60.0:  # set by spawner based on enemy depth
	set(value):
		base_radius = clampf(value, MIN_BASE_RADIUS, MAX_BASE_RADIUS)

var _lifetime: float = 0.0
var _duration: float = FIRE_DURATION
var _sparks: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []
var _puff_blob: Dictionary       # kill puff: single cauliflower silhouette
var _center_outer: Dictionary    # fireball: outer (darker) tongue star
var _center_core: Dictionary     # fireball: inner (brighter) tongue star
var _mottle_patches: Array[Dictionary] = []  # fireball: dark internal blotches
var _hot_core: Dictionary        # fireball: irregular white-hot core blob


func _ready() -> void:
	add_to_group("explosions")
	_duration = KILL_DURATION if is_kill else FIRE_DURATION
	_init_sparks()
	_init_smoke()
	_init_shapes()


## Builds a simple (non-self-intersecting) irregular radial polygon: one
## radius jitter value per evenly-spaced angle step, with occasional longer
## "spike" vertices for ragged edges. Angle jitter is capped below half the
## angular step so vertex order stays monotonic.
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


## Builds the angle set for a tongue star: two vertices per tongue (tip,
## then valley), evenly spaced with small monotonic-safe jitter.
func _make_star_angles(num_tongues: int) -> PackedFloat32Array:
	var n := num_tongues * 2
	var step: float = TAU / n
	var ang_jitter: float = step * 0.3
	var angles := PackedFloat32Array()
	for i in range(n):
		angles.append(step * i + randf_range(-ang_jitter, ang_jitter))
	return angles


## Builds radii for a tongue star over a pre-built angle set: even indices
## are tongue tips (reaching tip_min..tip_max, occasionally an elongated
## tongue), odd indices are the concave valleys between tongues. Passing the
## SAME angles array to both the outer and inner star, with the inner
## star's tip/valley ranges kept strictly below the outer star's, guarantees
## every inner tongue lines up with — and nests inside — its outer tongue.
func _make_star_radii(angles: PackedFloat32Array, valley_min: float, valley_max: float, tip_min: float, tip_max: float, elongate_chance: float, elongate_min: float, elongate_max: float) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	for i in range(angles.size()):
		if i % 2 == 0:
			var r: float = randf_range(tip_min, tip_max)
			if randf() < elongate_chance:
				r = randf_range(elongate_min, elongate_max)
			radii.append(r)
		else:
			radii.append(randf_range(valley_min, valley_max))
	return radii


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


func _init_shapes() -> void:
	if is_kill:
		# One dense simple polygon — gapless by construction, unlike the old
		# 4 separately-offset low-vertex lobes (rule 12a/b). No spike chance:
		# a handful of enlarged vertices among many small ones reads as a
		# few sharp points, not the reference's uniform fine cauliflower
		# scallops — keep every vertex in the same narrow radius band.
		_puff_blob = _make_blob(KILL_BLOB_VERTS, 0.86, 1.0, 0.0, 1.0, 1.0)
		return
	var angles := _make_star_angles(TONGUE_COUNT)
	_center_outer = {"angles": angles, "radii": _make_star_radii(angles, 0.30, 0.46, 0.85, 1.05, 0.22, 1.15, 1.35)}
	_center_core = {"angles": angles, "radii": _make_star_radii(angles, 0.16, 0.28, 0.55, 0.72, 0.15, 0.72, 0.80)}
	_init_mottle()
	_hot_core = _make_blob(10, 0.8, 1.0, 0.0, 1.0, 1.0)


func _init_mottle() -> void:
	# Dark maroon blotches scattered through the fireball's mid-body — the
	# internal detail rule 12c asks for, kept close enough to center that
	# they stay inside the outer tongue star's tightest valley (0.30).
	var count := 6
	for i in range(count):
		var angle := randf() * TAU
		_mottle_patches.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist_frac": randf_range(0.05, 0.18),
			"size_frac": randf_range(0.08, 0.15),
			"blob": _make_blob(7, 0.7, 1.0, 0.0, 1.0, 1.0),
		})


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
	# Opaque for nearly all of the fire phase — only fades in the final 40%,
	# so the burst reads as a solid mass, never a translucent haze (rule 12a).
	var alpha: float = 1.0 - smoothstep(0.6, 1.0, t)

	# Radiating tongue-star silhouette (14 tongues), matching the sunburst
	# shape in ab2-arcade-huge-explosion.jpg (rule 12c). Outer/inner stars
	# share one angle set so tongues line up; the inner star's radii are
	# always smaller, so it's guaranteed to nest inside the outer silhouette
	# rather than poking out through a valley at a mismatched angle.
	#
	# Colors are pushed well away from every stage's ground/sky hue (desert
	# skies measure ~(0.85, 0.45, 0.05) — nearly identical to a naive "dark
	# orange" tongue fill, which made the whole sunburst vanish into a
	# desert background). Outer goes deep saturated RED (not orange), inner
	# goes bright yellow, so the burst reads as a bright hot mass against
	# any stage background, not just a blue sky.
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _center_outer), Color(0.85, 0.14, 0.02, alpha))
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _center_core), Color(1.0, 0.68, 0.04, alpha))

	# Dark mottled patches scattered through the mid-body — the reference
	# shows blotchy maroon patches between the tongues and the hot core, not
	# a smooth gradient (rule 12c).
	for patch in _mottle_patches:
		var center: Vector2 = patch["dir"] * patch["dist_frac"] * r_base
		var pr: float = patch["size_frac"] * r_base
		draw_colored_polygon(_blob_polygon(center, pr, patch["blob"]), Color(0.4, 0.04, 0.01, alpha))

	# Bright white-hot core — an irregular blob, not a perfect circle, so it
	# reads as part of the mottled interior rather than a flat disc.
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base * 0.24, _hot_core), Color(1.0, 0.97, 0.82, alpha))


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
	var growth: float = smoothstep(0.0, 0.2, t)
	var shrink: float = smoothstep(0.55, 1.0, t)
	# Peaks at exactly r_cap (growth contributes up to 0.22, matching the
	# 0.78 baseline) rather than overshooting past it — composite-render
	# measurement showed a 0.3 growth term put the peak diameter at ~12.2%
	# of screen height, right at the edge of rule 10's 10-12% band.
	var r_base: float = r_cap * (0.78 + growth * 0.22 - shrink * 0.22)
	# Opaque for nearly all of the puff's life — only fades in the final
	# quarter, so it reads as a solid cream cloud, never a translucent haze
	# (rule 12a).
	var alpha: float = 1.0 - smoothstep(0.75, 1.0, t)

	if _lifetime < 0.4:
		_draw_sparks()

	# Single cohesive cauliflower silhouette — one simple polygon, no offset
	# lobe scatter (that used to blow the puff's true extent well past
	# r_cap and leave gaps of sky between lobes, rule 12a/b). Three nested
	# scalings of the SAME shape give it shading/depth while guaranteeing
	# full coverage — a smaller scaling of a star-shaped polygon can never
	# open a gap against a larger scaling of itself.
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _puff_blob), Color(0.78, 0.76, 0.69, alpha))
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base * 0.86, _puff_blob), Color(0.92, 0.90, 0.86, alpha))
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base * 0.52, _puff_blob), Color(0.99, 0.98, 0.95, alpha))

	# Brief white ignition point — white is not a fireball color, still
	# permitted on a kill puff.
	var flash_a: float = alpha * (1.0 - smoothstep(0.0, 0.25, t))
	if flash_a > 0.0:
		draw_circle(Vector2.ZERO, r_base * 0.26, Color(1.0, 1.0, 0.97, flash_a))


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
