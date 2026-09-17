extends Node2D

## 2D explosion effect. Two distinct visual types (criteria.md rule 10):
##
## - Fireball (is_kill=false): player death, ground impacts, large hits.
##   A billowing cauliflower cloud (ab2-arcade-huge-explosion.jpg, motion
##   frame burst-c-10): a dark orange-red outer body with a brighter
##   yellow-orange inner body nested inside it, made of a handful of large
##   overlapping ROUNDED lobes (never straight-sided spikes, never a
##   geometric starburst), dark maroon mottle blotches scattered through the
##   mid-body, and an irregular white-hot core. Phases: flash -> fire ->
##   trailing smoke -> debris sparks. Duration 1.0s.
## - Kill puff (is_kill=true): enemy aircraft kills. A single dense
##   cauliflower-edged cream/white polygon — per ab2-arcade-desert-
##   explosions.png / ab2-arcade-closeup-enemies.jpg, aircraft kills read as
##   pale opaque puffs, not fireballs, with NO orange or red anywhere.
##   Duration 0.55s.
##
## Both bodies are OPAQUE for nearly all of their life (alpha only fades in
## the final stretch) and built from simple (non-self-intersecting) radial
## polygons at evenly-spaced angles (zero angle jitter needed — radius alone
## varies smoothly from vertex to vertex, which is what keeps every edge
## reading as curved rather than faceted). Round 5 gate (criteria.md rule 12)
## found the previous design translucent, with visible gaps between separate
## offset lobes, and facets far coarser than the reference's fine fringe —
## fixed by drawing each body as ONE simple polygon (gapless by construction)
## with a high vertex count, then layering smaller uniform scalings of that
## SAME polygon on top for shading. Round 6 gate found the fireball body had
## regressed into a literal straight-sided starburst with deep V-notch
## valleys exposing background between the points — fixed by generating the
## fireball's radius as a small number of large overlapping raised-cosine
## bumps on top of a shallow base (never dipping near zero), producing round
## puffy bulges with full background coverage, plus fine per-vertex jitter
## for surface texture. A smaller scaling of a star-shaped polygon is always
## strictly inside the larger one, so the nested layers (and the fireball's
## inner/outer bodies, which reuse the exact same scaled radii) can never
## open a gap either.
##
## Round 7 gate (criteria.md rule 12: ">=8 distinct value levels by
## histogram; a 2-3 flat-fill construction is an automatic FAIL") found both
## bodies still read as 2-3 flat colour fills once the outline was fixed.
## ab2-arcade-huge-explosion.jpg's burst-c-05 motion frame shows the real
## fireball is built from DOZENS of small overlapping round "bubbles", each
## individually shaded (dark rim -> bright mid -> occasional hot core), over
## a darker base body — not one smooth gradient. Fixed by keeping the lobed
## outer/inner bodies as a dark, gapless coverage base (so there is never a
## background gap) and scattering many small shaded bubble blobs on top,
## each with its own randomised brightness — this alone produces far more
## than 8 distinct rendered values and matches the reference's "many bright
## cores scattered through a mottled body" look. The kill puff got the same
## treatment (dense cream/pale-yellow speckle blobs over a warmer base,
## instead of a smooth grey gradient), plus a wider/spikier rim band for a
## less regular silhouette. The round-5 fix (rule 12a) resurfaced during
## fade: independently alpha-blending several stacked same-shape layers
## makes each layer's edge visible as a seam once alpha drops below 1 — the
## kill puff now collapses to a single flat polygon for the final fade
## stretch instead of re-drawing the full stack at reduced alpha.

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

# Vertex count for the fireball's outer/inner lobed-cloud body. High enough
# that the per-vertex jitter (fine surface texture) and the raised-cosine
# lobe bumps (large rounded bulges) both read as curved rather than as
# straight polygon facets at the fireball's on-screen radius.
const FIRE_BLOB_VERTS := 80

# Number of large rounded bulges summed onto the fireball's body, per the
# billowing cauliflower silhouette in ab2-arcade-huge-explosion.jpg / motion
# frame burst-c-10 — a handful of big round lobes, not a many-pointed star.
const FIRE_LOBE_COUNT := 6

# Base radius (valley floor, no lobe influence) and additional peak amplitude
# for the outer fireball body, both as a fraction of r_base. The valley
# floor is kept high (0.5) so there is no deep V-notch between lobes that
# would expose the background — the body reads as one solid puffy cloud with
# bulges on top of it, never separated rays with gaps between them.
const FIRE_OUTER_BASE := 0.5
const FIRE_OUTER_AMP := 0.55

# Inner (brighter) body is the outer body's exact radii scaled down by this
# ratio at every vertex — guarantees strict nesting inside the outer body
# the same way the kill puff's nested scalings do.
const FIRE_CORE_RATIO := 0.6

# Fine per-vertex radius noise (fraction of r_base) layered on top of the
# smooth lobe bumps — the fireball's fringe/mottle texture (rule 12).
const FIRE_EDGE_JITTER := 0.02

# Many small shaded "bubble" blobs scattered over the fireball body (rule
# 12, round 7) — ab2-arcade-huge-explosion.jpg's burst-c-05 frame shows
# dozens of these, each with its own rim/mid/hot-core shading, forming the
# cauliflower texture. Distances/sizes as a fraction of r_base.
const FIRE_BUBBLE_COUNT := 16
const FIRE_BUBBLE_DIST_MIN := 0.12
const FIRE_BUBBLE_DIST_MAX := 0.82
const FIRE_BUBBLE_SIZE_MIN := 0.20
const FIRE_BUBBLE_SIZE_MAX := 0.38
const FIRE_BUBBLE_HOT_CHANCE := 0.4  # fraction of bubbles with a bright core

# Dense speckle blobs scattered over the kill puff (rule 12, round 7) —
# replaces the old smooth 3-layer gradient with visible cream/pale-yellow
# cauliflower texture, matching ab2-arcade-desert-explosions.png's puffs.
const KILL_SPECK_COUNT := 20
const KILL_SPECK_DIST_MIN := 0.08
const KILL_SPECK_DIST_MAX := 0.78
const KILL_SPECK_SIZE_MIN := 0.10
const KILL_SPECK_SIZE_MAX := 0.22

var base_radius: float = 60.0:  # set by spawner based on enemy depth
	set(value):
		base_radius = clampf(value, MIN_BASE_RADIUS, MAX_BASE_RADIUS)

var _lifetime: float = 0.0
var _duration: float = FIRE_DURATION
var _sparks: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []
var _puff_blob: Dictionary       # kill puff: single cauliflower silhouette
var _center_outer: Dictionary    # fireball: outer (darker) lobed cloud body
var _center_core: Dictionary     # fireball: inner (brighter) lobed cloud body
var _mottle_patches: Array[Dictionary] = []  # fireball: dark internal blotches
var _hot_core: Dictionary        # fireball: irregular white-hot core blob
var _bubbles: Array[Dictionary] = []   # fireball: many small shaded body blobs
var _speckles: Array[Dictionary] = []  # kill puff: many small cream body blobs


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


## Builds an evenly-spaced angle set (zero jitter needed — a lobed blob's
## irregularity comes from its smoothly-varying radius, not from angle
## jitter, so this is trivially monotonic and always yields a simple
## polygon).
func _make_even_angles(num_verts: int) -> PackedFloat32Array:
	var step: float = TAU / num_verts
	var angles := PackedFloat32Array()
	for i in range(num_verts):
		angles.append(step * i)
	return angles


## Picks random center angle / width / amplitude for each of the fireball's
## rounded lobes. Widths overlap generously (up to 95% of the average
## angular spacing) so neighbouring lobes blend into each other rather than
## reading as separate bumps with a notch between them.
func _make_fire_lobes(num_lobes: int) -> Array:
	var avg_spacing: float = TAU / num_lobes
	var lobes := []
	for i in range(num_lobes):
		lobes.append({
			"center": randf() * TAU,
			"half_width": randf_range(0.55, 0.95) * avg_spacing,
			"amp": randf_range(0.6, 1.0),
		})
	return lobes


## Builds fireball body radii over an evenly-spaced angle set: at each
## vertex, sums a raised-cosine bump for every lobe whose half-width covers
## that angle (smooth, zero at the lobe's edge — never a sharp point), adds
## fine per-vertex jitter for surface texture, and floors the result well
## above zero so the body never pinches down to an exposed-background notch.
func _lobed_radii(num_verts: int, lobes: Array, base_r: float, amp_scale: float, jitter: float) -> PackedFloat32Array:
	var step: float = TAU / num_verts
	var radii := PackedFloat32Array()
	for i in range(num_verts):
		var a: float = step * i
		var r: float = base_r
		for lobe in lobes:
			var d: float = wrapf(a - lobe["center"], -PI, PI)
			var hw: float = lobe["half_width"]
			if absf(d) < hw:
				r += amp_scale * lobe["amp"] * 0.5 * (1.0 + cos(PI * d / hw))
		r += randf_range(-jitter, jitter)
		radii.append(maxf(r, base_r * 0.5))
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
		# 4 separately-offset low-vertex lobes (rule 12a/b). A wider smooth
		# radius band than round 6 (0.78-1.0 vs 0.86-1.0) breaks up the
		# regular-facet read gate round 7 flagged. NOT a spike_chance — a
		# lone spiked vertex reads as a literal needle point (a starburst
		# with a different name), verified and reverted via composite
		# render; the speckle overlay below is what supplies the
		# cauliflower-lump irregularity instead.
		_puff_blob = _make_blob(KILL_BLOB_VERTS, 0.78, 1.0, 0.0, 1.0, 1.0)
		_init_speckles()
		return
	var angles := _make_even_angles(FIRE_BLOB_VERTS)
	var lobes := _make_fire_lobes(FIRE_LOBE_COUNT)
	var outer_radii := _lobed_radii(FIRE_BLOB_VERTS, lobes, FIRE_OUTER_BASE, FIRE_OUTER_AMP, FIRE_EDGE_JITTER)
	# Inner (brighter) body is the outer body's radii scaled down by a fixed
	# ratio at every vertex — an exact scaled copy nests strictly inside the
	# outer silhouette by construction, no independent generation needed.
	var core_radii := PackedFloat32Array()
	core_radii.resize(outer_radii.size())
	for i in range(outer_radii.size()):
		core_radii[i] = outer_radii[i] * FIRE_CORE_RATIO
	_center_outer = {"angles": angles, "radii": outer_radii}
	_center_core = {"angles": angles, "radii": core_radii}
	_init_mottle()
	_init_bubbles()
	_hot_core = _make_blob(10, 0.8, 1.0, 0.0, 1.0, 1.0)


## Many small shaded "bubble" blobs scattered across the fireball body —
## each gets its own randomised position, size, brightness jitter, and
## chance of a bright hot core, so drawing them produces far more than 8
## distinct rendered values (rule 12, round 7) instead of the old 2-3 flat
## fills.
func _init_bubbles() -> void:
	for i in range(FIRE_BUBBLE_COUNT):
		var angle := randf() * TAU
		_bubbles.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist_frac": randf_range(FIRE_BUBBLE_DIST_MIN, FIRE_BUBBLE_DIST_MAX),
			"size_frac": randf_range(FIRE_BUBBLE_SIZE_MIN, FIRE_BUBBLE_SIZE_MAX),
			"jitter": randf_range(-0.08, 0.08),
			"hot": randf() < FIRE_BUBBLE_HOT_CHANCE,
			"blob": _make_blob(16, 0.78, 1.0, 0.0, 1.0, 1.0),
		})


## Many small shaded blobs scattered across the kill puff body — cream/
## pale-yellow with per-blob brightness jitter, giving the puff visible
## cauliflower texture instead of a smooth radial gradient (rule 12, round 7).
func _init_speckles() -> void:
	for i in range(KILL_SPECK_COUNT):
		var angle := randf() * TAU
		_speckles.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist_frac": randf_range(KILL_SPECK_DIST_MIN, KILL_SPECK_DIST_MAX),
			"size_frac": randf_range(KILL_SPECK_SIZE_MIN, KILL_SPECK_SIZE_MAX),
			"jitter": randf_range(-0.06, 0.10),
			"blob": _make_blob(9, 0.78, 1.0, 0.0, 1.0, 1.0),
		})


func _init_mottle() -> void:
	# Dark maroon speckle scattered through the fireball's mid-body — rule
	# 12c calls for FINE mottle (2-4px), not large blotches. A round-6 gate
	# composite render measured the previous 6-patch/0.08-0.15 size_frac
	# setup at 24-60px across on a typical death-fireball r_base (~300px) —
	# an order of magnitude too coarse. Many more, much smaller patches read
	# as grainy internal texture instead of separate dark blobs.
	var count := 30
	for i in range(count):
		var angle := randf() * TAU
		_mottle_patches.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist_frac": randf_range(0.10, 0.42),
			"size_frac": randf_range(0.012, 0.025),
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

	# Billowing lobed-cloud silhouette (FIRE_LOBE_COUNT rounded bulges),
	# matching the cauliflower fireball in ab2-arcade-huge-explosion.jpg /
	# burst-c-10 (rule 12c) — never a straight-sided starburst. The inner
	# body's radii are an exact scaled-down copy of the outer body's, so it's
	# guaranteed to nest inside the outer silhouette at every angle. This
	# pair is now a dark gapless BASE (round 7) — the bright, varied texture
	# comes from the many bubble blobs drawn on top, not from these two
	# flat fills, so the dark shows through as shading in the gaps between
	# bubbles, matching burst-c-05's dark-red-between-bright-blobs look.
	#
	# Colors are pushed well away from every stage's ground/sky hue (desert
	# skies measure ~(0.85, 0.45, 0.05) — nearly identical to a naive "dark
	# orange" fill, which made the whole fireball vanish into a desert
	# background). Outer goes deep maroon-red (not orange), inner goes mid
	# orange, so the burst reads as a bright hot mass against any stage
	# background, not just a blue sky.
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _center_outer), Color(0.5, 0.06, 0.02, alpha))
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _center_core), Color(0.82, 0.32, 0.04, alpha))

	# Dark mottled patches scattered through the mid-body — the reference
	# shows blotchy maroon patches between the outer bulges and the hot core,
	# not a smooth gradient (rule 12c). Darker than the base now that the
	# base itself went darker, so the blotches still read as distinct shadow
	# accents in the gaps between bubbles.
	for patch in _mottle_patches:
		var center: Vector2 = patch["dir"] * patch["dist_frac"] * r_base
		var pr: float = patch["size_frac"] * r_base
		draw_colored_polygon(_blob_polygon(center, pr, patch["blob"]), Color(0.22, 0.02, 0.01, alpha))

	# Dozens of small shaded bubble blobs (rule 12, round 7) — each is its
	# own rim -> bright mid -> occasional hot core, with a randomised
	# brightness jitter per bubble, so the body reads as many overlapping
	# lumps rather than a flat or smoothly-gradiented fill, matching
	# burst-c-05's cluster of individually-lit round bulges.
	for bub in _bubbles:
		var bcenter: Vector2 = bub["dir"] * bub["dist_frac"] * r_base
		var br: float = bub["size_frac"] * r_base
		var j: float = bub["jitter"]
		var bblob: Dictionary = bub["blob"]
		draw_colored_polygon(_blob_polygon(bcenter, br, bblob), Color(0.9, clampf(0.32 + j, 0.16, 0.56), 0.03, alpha))
		draw_colored_polygon(_blob_polygon(bcenter, br * 0.6, bblob), Color(1.0, clampf(0.62 + j, 0.45, 0.85), 0.06, alpha))
		if bub["hot"]:
			draw_colored_polygon(_blob_polygon(bcenter, br * 0.32, bblob), Color(1.0, clampf(0.92 + j * 0.5, 0.85, 1.0), clampf(0.55 + j, 0.4, 0.75), alpha))

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
	# r_cap and leave gaps of sky between lobes, rule 12a/b).
	if alpha < 0.999:
		# Fading (final stretch only): collapse to ONE flat polygon. Round 7
		# gate found that independently alpha-blending the base + speckle
		# stack during fade makes each layer's edge visible as a seam —
		# shapes "showing through" (rule 12a). A single flat fill can't seam.
		draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _puff_blob), Color(0.88, 0.81, 0.58, alpha))
		return

	# Opaque phase: base + a brighter nested layer give it depth, then dense
	# cream/pale-yellow speckle blobs on top break up what used to be a
	# smooth grey gradient into visible cauliflower texture (rule 12, round
	# 7) — colors pushed warmer (cream/pale-yellow, not neutral grey-white)
	# to match ab2-arcade-desert-explosions.png's puffs.
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base, _puff_blob), Color(0.76, 0.68, 0.45))
	draw_colored_polygon(_blob_polygon(Vector2.ZERO, r_base * 0.85, _puff_blob), Color(0.88, 0.81, 0.58))
	for speck in _speckles:
		var scenter: Vector2 = speck["dir"] * speck["dist_frac"] * r_base
		var sr: float = speck["size_frac"] * r_base
		var j: float = speck["jitter"]
		draw_colored_polygon(_blob_polygon(scenter, sr, speck["blob"]), Color(clampf(0.93 + j, 0.85, 1.0), clampf(0.87 + j, 0.78, 0.96), clampf(0.62 + j, 0.5, 0.78)))

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
