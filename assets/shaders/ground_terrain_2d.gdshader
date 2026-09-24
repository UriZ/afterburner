shader_type canvas_item;
render_mode unshaded;

// Per-pixel procedural ground terrain (#42 redo).
//
// Replaces the old draw_circle() rock-cluster model — ~40 large overlapping
// circles that read as foam/bubbles rather than terrain — with a cellular
// (Worley) noise field sampled once per pixel. This gives hundreds of small,
// tightly-packed rock cells with zero extra draw calls (a single quad),
// which is what actually fixes both the "feature scale 10-20x too large"
// and "count ~10x too low" defects the TL identified: density is 100% by
// construction instead of scaling with a discrete feature count.
//
// World-space identity: every fragment inverts DepthUtil's screen<->depth
// projection (res://scripts/game/depth_util.gd) to recover the persistent
// world coordinate (world_x, world_d) the ground point at that pixel
// corresponds to, then samples noise there. Only world_d's offset
// (world_scroll) advances per frame — the terrain translates through the
// field, it is never re-rolled. This is the continuous analogue of the
// discrete _feature_depth() model this replaces (see game_world.gd), so the
// same "near bands move more than far bands" guarantee holds for free: it
// falls straight out of DepthUtil's quadratic depth->screen mapping, which
// both the old and new model share.

uniform vec4 color_a : source_color = vec4(0.88, 0.65, 0.30, 1.0);
uniform vec4 color_b : source_color = vec4(0.50, 0.30, 0.12, 1.0);
// Third stage-tuned VALUE cluster (a richer/deeper tone within the same
// stage hue — e.g. shaded scrub on desert, deep foam-shadow on ocean).
// Round-7 gate CORRECTED the round-6 rule this uniform was built for: the
// reference desert near-band holds 89.2% of saturated pixels in ONE 20°
// hue bin (mean V 0.580) and varies by VALUE within that hue, not by
// scattering unrelated hues (grey stone / olive scrub / pink rock) the way
// round-6 called for and this shader shipped with — that read as
// salmon/olive/grey "confetti", not rock. fragment() now derives every
// cluster's HUE from color_a (all clusters share one hue per stage) and
// uses color_c only for its S/V "personality" (how saturated/dark that
// value step is), not its hue. Kept as its own per-stage uniform rather
// than a fixed offset from color_a/color_b since stages still want
// different amounts of value contrast (mountain wants a subtle step,
// volcanic wants a strong ember-dark step).
uniform vec4 color_c : source_color = vec4(0.55, 0.55, 0.10, 1.0);
uniform vec4 haze_color : source_color = vec4(1.0, 0.72, 0.10, 1.0);

// Mirrors DepthUtil's constants (res://scripts/game/depth_util.gd). GameWorld
// pushes these from _DepthUtil at _ready() so this shader and the GDScript
// depth math never drift apart — the same single-source-of-truth lesson as
// HORIZON_Y (#108).
uniform float horizon_y = 420.0;
uniform float screen_h = 672.0;
uniform float screen_w = 960.0;
uniform float ground_y_scale = 0.95;  // DepthUtil's (SCREEN_H-HORIZON_Y)*0.95 term
uniform float x_spread_scale = 0.47;  // DepthUtil's SCREEN_W*0.47 term
uniform float x_min_frac = 0.1;
uniform float x_span_frac = 0.9;

// Advanced every frame in GameWorld._process() at GROUND_SCROLL_SPEED —
// the same constant rate every other ground element scrolls at.
uniform float world_scroll = 0.0;
// Player parallax offset — see GameWorld._player_lateral_offset().
uniform float lateral = 0.0;

// Cell frequency chosen so a rock cell spans ~17px on screen near the
// camera (bottom of frame) — round-4 gate measured reference rocks at ~8px
// in a 686px frame (~1.2% width, 10-20px at 960 wide) with hard edges, vs
// our prior 40-90px soft blobs. The 14/15 pair this replaces gave a ~32px
// theoretical pitch that STILL measured 40-90px in practice — the actual
// culprit was the domain warp amplitude below being large enough (up to 0.7
// cell units) to walk a sample across neighboring cells' boundaries,
// visually merging them into blobs bigger than the nominal grid. Frequency
// and warp amplitude were both wrong; fixing only one would not have hit
// the 10-20px target.
const float CELL_FREQ_X = 26.0;
const float CELL_FREQ_D = 28.0;
// Low-frequency broad tonal patches (the mottled light/dark regions visible
// across the reference beyond individual rock cells).
const float REGION_FREQ = 1.6;
// Material-cluster patch frequency (#42 round-6 gate — "shape regularity"):
// small regions of grey stone / olive scrub / pink rock scattered across the
// base tan/brown rock, matching the reference's irregular multi-hue rubble
// instead of a uniform two-hue field. First pass used 1.1 (a few
// world-units-sized regions); a live capture showed that read as 2-3 giant
// single-hue "continents" filling half the screen each — much larger and
// more contiguous than the reference's fine interspersed mix. 3.2 (second
// pass) fixed the continent problem but still produced fairly large, sharply
// bounded blobs — a "paint bucket" map of solid colour regions rather than
// the reference's finer salt-and-pepper mixing. 5.5 (third pass) roughly
// halves the patch size again for a more interspersed look, still well
// below CELL_FREQ so a patch still spans several rock cells, not one.
// Raised again 5.5 -> 8.8 (#42 round-7 gate, ~1.6x): this patch scale, not
// CELL_FREQ (already tuned above), is what the round-7 measurement caught
// at 7.92% of screen width against a 4.96% reference target — these
// same-hue VALUE patches (see the cluster-selection block in fragment())
// are the "feature" that was still too large, not the individual rock
// cells within them. An earlier version of this fix mistakenly scaled
// CELL_FREQ_X/D instead, which shrank the rock grain rather than the
// patch blobs the gate actually measured, and a matched-scale crop
// against burst-a-02 confirmed that made the grain visibly finer than the
// reference while leaving patch size untouched — reverted.
const float PATCH_FREQ = 8.8;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	vec2 q = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Standard (Sam Hocevar) RGB<->HSV round-trip, used by the round-6 patch/
// cluster system below to derive a desaturated "grey stone" and a hue-shifted
// "pink rock" tone from each stage's own ground_a/ground_b at render time,
// instead of plumbing two more per-stage uniforms through GameWorld/
// stage_data.gd for every one of the 23 stages.
vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// F1 Worley distance + a per-cell id hash, giving irregular rock-cell shapes
// with dark seams at the boundaries — the core visual fix for #42.
float worley(vec2 p, out float cell_id) {
	vec2 base_cell = floor(p);
	vec2 f = fract(p);
	float min_dist = 8.0;
	cell_id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = base_cell + neighbor;
			vec2 point = hash2(cell);
			float dist = length(neighbor + point - f);
			if (dist < min_dist) {
				min_dist = dist;
				cell_id = hash1(cell * 7.0 + 3.0);
			}
		}
	}
	return min_dist;
}

void fragment() {
	// Invert DepthUtil.to_screen()'s y formula: recover this pixel's world depth.
	float screen_y = horizon_y + UV.y * (screen_h - horizon_y);
	float d = clamp(sqrt(max((screen_y - horizon_y) / ((screen_h - horizon_y) * ground_y_scale), 0.0001)), 0.0, 1.0);

	// Invert the x formula the same way to recover this pixel's world lateral offset.
	float x_spread = (screen_w * x_spread_scale) * (x_min_frac + d * x_span_frac);
	float screen_x = UV.x * screen_w;
	float off = (screen_x - screen_w * 0.5) / max(x_spread, 1.0);
	float world_x = off + lateral;
	// Subtract, not add: hold a world feature's identity fixed (world_d = W,
	// constant) and solve for how its screen depth d must change over time as
	// world_scroll grows — d = W + world_scroll, i.e. d must INCREASE (the
	// feature approaches the camera, matching the old discrete model's
	// `d_rendered = 1 - fposmod(base - scroll, 1)`, which also increases with
	// scroll). Using "+" here instead gets the sign backwards: a fixed
	// feature's d would decrease over time (receding toward the horizon) —
	// caught analytically before it shipped, not by eye.
	float world_d = d - world_scroll;

	vec2 world_p = vec2(world_x, world_d);

	// Cell-size variety was tried here as a multiplicative freq_jitter scalar
	// on world_pos and reverted: world_pos already has huge dynamic range
	// (it blows up near the horizon and off-axis — see aa below), and
	// multiplying it by a SPATIALLY-VARYING scale means the jitter's own
	// (small, slow) gradient gets multiplied by that large coordinate
	// magnitude too, via the product rule — d(pos*jitter)/dpos = jitter +
	// pos*d(jitter)/dpos, and the second term dominates once |pos| is large.
	// That derivative blowup was the actual source of the coherent radial
	// streaking this shader shipped with, not plain undersampling — no
	// amount of fwidth-based anti-aliasing below fixed it, because the
	// aliasing was being generated faster than the AA term could suppress
	// it. Fixed-frequency cell_p avoids the problem entirely; cell size
	// variety is a smaller win than a correct-looking, non-shearing field.
	vec2 cell_p = vec2(world_x * CELL_FREQ_X, world_d * CELL_FREQ_D);

	// Anti-aliasing suppression (#42 follow-up — fixes a regression the first
	// jaggedness pass introduced). world_x = off / x_spread, and x_spread ->
	// (screen_w*x_spread_scale)*x_min_frac as d -> 0, so a fixed on-screen
	// pixel step maps to an EXPLODING step in cell_p near the horizon
	// vanishing point. Undersampling a periodic/noise field past its Nyquist
	// limit doesn't fade to grey, it aliases into coherent moire — which is
	// exactly what shipped first: sharp radial streaks converging on the
	// horizon center, not jagged rock. fwidth(cell_p) is the screen-space
	// derivative Godot already computes for mipmapping; using it to fade out
	// the alias-prone high-frequency contributors (the second warp octave,
	// the crevice edge sharpness, the grain multiply) as that derivative
	// grows is the standard fix — it does NOT touch world-space identity or
	// the persistent-translation guarantee, it only widens/softens how a
	// pixel that can no longer resolve individual cells gets shaded.
	// Coefficient cut 0.22 -> 0.08 (#42 round-5 gate): even in the near field,
	// where fwidth(cell_p) should be small (see the derivation above — world_x's
	// derivative wrt screen_x shrinks as x_spread grows near d=1), 0.22 was
	// still large enough to keep aa materially above 0 close to the camera,
	// softening exactly the edges the gate measured as too soft (mean |grad|
	// 0.027 vs reference 0.078-0.090). This only weakens the anti-alias
	// response, not its shape — the horizon still gets full suppression via
	// aa_horizon below regardless of this coefficient.
	float aa = clamp(length(fwidth(cell_p)) * 0.08, 0.0, 1.0);
	// The fwidth term above is directional (it grows fastest toward the
	// screen edges at low d, since world_x = off/x_spread blows up there
	// fastest) — round-4 gate caught this as a visible band of streaks
	// radiating from the horizon vanishing point, not a uniform haze. A pure
	// UV.y floor forces the whole near-horizon strip flat regardless of x,
	// which can't produce an x-dependent (radial) pattern by construction —
	// it matches the reference anyway, where the far ground is a smooth haze
	// with no resolvable rock detail near the horizon line.
	float aa_horizon = 1.0 - smoothstep(0.0, 0.20, UV.y);
	aa = max(aa, aa_horizon);

	// Material-cluster selection (#42 round-7 gate CORRECTION of round-6).
	// Round-6 required ">=3 hue clusters per band" and this shader picked
	// one of four DIFFERENT-HUE materials per patch: grey stone, the tuned
	// base rock, a stage accent hue (olive scrub/foam/ember...), and a
	// hue-rotated "pink" rock. Round-7 pixel-measured the actual reference
	// desert near-band and found that rule was wrong: 89.2% of its
	// saturated pixels sit in ONE 20-degree hue bin (mean V 0.580) — it's
	// one rock material shaded light-to-dark, not a mosaic of differently
	// coloured rocks. What shipped instead reads as salmon/olive/grey
	// confetti. The old pink cluster's -0.07 hue ROTATION from an
	// already-low sunset hue (~10deg) wrapped past red into magenta/purple
	// (~345deg) — that is the direct cause of the "sunset ground reads
	// purple/mauve" defect flagged alongside this fix, not a separate bug.
	//
	// Every cluster below now shares ONE hue (base_hue, taken from
	// color_a — ground_a/ground_b are already the same stage hue at
	// different S/V, see stage_data.gd) and only varies saturation/value: a
	// bleached highlight, the tuned base rock (color_a/color_b, unchanged),
	// a stage-tuned mid accent (color_c's own S/V, hue PINNED instead of
	// following color_c's own hue), and a deep shadow step. A second,
	// lower-frequency noise field (PATCH_FREQ, well below CELL_FREQ so a
	// patch spans many rock cells) still picks which value step covers each
	// patch, and each keeps its own warp/crevice/grain tuning so different
	// regions don't all read as the same bright-center/dark-edge "bead" —
	// that part of round-6 (shape variety) was correct and is kept; only
	// the HUE variety is gone.
	vec3 hsv_a = rgb2hsv(color_a.rgb);
	vec3 hsv_b = rgb2hsv(color_b.rgb);
	vec3 hsv_c = rgb2hsv(color_c.rgb);
	float base_hue = hsv_a.x;
	vec3 highlight_light = hsv2rgb(vec3(base_hue, hsv_a.y * 0.55, clamp(hsv_a.z * 1.10, 0.0, 1.0)));
	vec3 highlight_dark = hsv2rgb(vec3(base_hue, hsv_b.y * 0.55, clamp(hsv_b.z * 1.25, 0.0, 1.0)));
	// Scaling V inside HSV (not multiplying the final RGB) matters here:
	// ground_c runs pale/near-white on some stages (e.g. mountain's snow
	// fleck at V~0.89), and a flat *1.25 on RGB clips all three channels to
	// 1.0 — collapsing that patch to pure white (S=0), which is the same
	// "flat/washed out" defect as the confetti fix was chasing, just at the
	// opposite (white) extreme instead of a stray hue. Clamping V in HSV
	// keeps the patch's own saturation intact at any brightness.
	vec3 accent_light = hsv2rgb(vec3(base_hue, hsv_c.y, clamp(hsv_c.z * 1.25, 0.0, 1.0)));
	vec3 accent_dark = hsv2rgb(vec3(base_hue, hsv_c.y, clamp(hsv_c.z * 0.85, 0.0, 1.0)));
	vec3 shadow_light = hsv2rgb(vec3(base_hue, clamp(hsv_b.y * 1.05, 0.0, 1.0), clamp(hsv_b.z * 0.95, 0.0, 1.0)));
	vec3 shadow_dark = shadow_light * 0.60;

	float patch_n = value_noise(world_p * PATCH_FREQ + vec2(300.0, -150.0));
	float patch_idx = floor(clamp(patch_n * 4.0, 0.0, 3.9999));

	vec3 cluster_light;
	vec3 cluster_dark;
	// warp_extra: per-cluster boundary jaggedness (multiplies the domain warp
	// below) — the highlight step is smoother/rounder, the accent/shadow
	// steps are spikier, matching how lit vs. shaded rock faces actually
	// read in the reference.
	float warp_extra;
	// thresh_bias: shifts the crevice threshold band (below) per cluster so
	// each value step gets its own amount of visible crevice/mottle instead
	// of the identical "bright fill, dark rim" treatment on every feature.
	float thresh_bias;
	float grain_lo;
	float grain_hi;
	if (patch_idx < 0.5) {
		cluster_light = highlight_light; cluster_dark = highlight_dark;
		warp_extra = 0.55; thresh_bias = 0.12; grain_lo = 0.78; grain_hi = 1.22;
	} else if (patch_idx < 1.5) {
		cluster_light = color_a.rgb; cluster_dark = color_b.rgb;
		warp_extra = 1.0; thresh_bias = 0.04; grain_lo = 0.60; grain_hi = 1.40;
	} else if (patch_idx < 2.5) {
		cluster_light = accent_light; cluster_dark = accent_dark;
		warp_extra = 1.55; thresh_bias = 0.02; grain_lo = 0.55; grain_hi = 1.45;
	} else {
		cluster_light = shadow_light; cluster_dark = shadow_dark;
		warp_extra = 1.25; thresh_bias = 0.0; grain_lo = 0.65; grain_hi = 1.35;
	}

	// Domain warp: perturb the sample point before evaluating Worley. A
	// single low-frequency warp still reads as a too-regular round-pebble
	// mosaic (cobblestone paving) — the reference ground is jagged, chaotic
	// scree, not uniform cobbles. A second, higher-frequency warp layered on
	// top breaks the smooth round boundary itself into spiky, irregular
	// edges instead of just displacing a still-round cell. Its amplitude
	// fades under aa since it's the higher-frequency (more alias-prone) of
	// the two warp layers.
	//
	// Amplitudes cut roughly 4x from the previous 1.4/0.7 (#42 round-4 gate):
	// displacing a sample by more than half a cell unit does not just
	// "jaggify" its boundary, it can walk the sample across a neighboring
	// cell's Worley region entirely, visually fusing two adjacent rocks into
	// one blob — measured as 40-90px features against a ~32px nominal grid.
	// Small warp still breaks up the round Worley boundary into an irregular
	// one without merging cells.
	//
	// Round-5 gate: 40-90px had regressed further to 86-133px (vs a 44-52px
	// reference target) even after that cut — cut again (0.35/0.18 -> 0.20/0.10)
	// and, more importantly, warp1's own SAMPLING frequency raised 0.5 -> 0.9:
	// a low-frequency warp field is smooth over many cells at once, so
	// neighboring cells get displaced by nearly the SAME vector and their
	// relative spacing barely changes — individual cells still fuse into
	// multi-cell chains even at small amplitude, because the amplitude cut
	// alone doesn't decorrelate what neighbors are being pushed toward. A
	// warp field that itself varies within a cell's width displaces adjacent
	// cells differently, actively pulling them apart instead of translating
	// the whole neighborhood in lockstep.
	vec2 warp1 = vec2(value_noise(cell_p * 0.9 + 11.0), value_noise(cell_p * 0.9 + 47.0)) - 0.5;
	vec2 warp2 = vec2(value_noise(cell_p * 1.8 + 91.0), value_noise(cell_p * 1.8 + 23.0)) - 0.5;
	// Per-cell outline variation (#42 round-6 gate: "vary the Worley cell
	// shaping per cell id"): a cheap hash of the UN-warped grid cell (not the
	// spatially-varying jitter the reverted freq_jitter experiment above used
	// — this only scales the bounded warp1/warp2 VECTORS, it never multiplies
	// cell_p itself, so it can't reproduce that derivative-blowup bug) gives
	// each cell its own jaggedness independent of which material cluster it
	// falls in, so no two neighbouring rocks share an identical outline.
	float cell_seed = hash1(floor(cell_p) * 3.0 + 17.0);
	float warp_cell_mult = mix(0.55, 1.65, cell_seed) * warp_extra;
	cell_p += warp1 * 0.20 * warp_cell_mult + warp2 * 0.10 * warp_cell_mult * (1.0 - aa);

	float cell_id;
	float cell_dist = worley(cell_p, cell_id);
	float region = value_noise(vec2(world_x * REGION_FREQ, world_d * REGION_FREQ));
	// High-frequency grain multiplied over the final color so flat cell faces
	// don't read as smooth/cartoonish — the reference's texture is visibly
	// noisy even within a single rock, not a flat fill. Fades toward a
	// neutral 1.0 multiplier under aa for the same reason as warp2.
	// Frequency raised 3.3 -> 6.0 and range widened 0.90-1.1 -> 0.75-1.25
	// (#42 round-5 gate): the reference measures frac(|grad|>0.05) at
	// 0.64-0.73 — a strong per-pixel gradient at nearly 2 out of 3 pixels,
	// characteristic of the arcade sprite's dithered/grainy look, not just
	// the Worley cell-boundary network (which only contributes edges AT
	// boundaries, a minority of pixels by area). Widening this multiplier's
	// range is symmetric around 1.0 (mix(0.75,1.25,0.5) == 1.0), so it adds
	// per-pixel contrast/gradient without shifting mean brightness — that is
	// tuned separately via the crevice threshold below.
	//
	// Re-measured after the above: mean|grad| moved 0.027 -> 0.070-0.074 and
	// frac(|grad|>0.05) moved 0.15 -> 0.48-0.50 — real progress but both
	// still short of the 0.078-0.090 / 0.64-0.73 reference band. Pushed
	// again, frequency 6.0 -> 9.0 and range 0.75-1.25 -> 0.60-1.40 (still
	// symmetric around 1.0, so mean brightness is unaffected).
	float grain = mix(value_noise(cell_p * 9.0), 0.5, aa);
	// Range now per-cluster (grain_lo/grain_hi, set above) instead of the
	// single fixed 0.60-1.40 band — the scrub/pink clusters want stronger
	// per-pixel contrast (chaotic mottle) than the smoother grey-stone
	// cluster, another way to stop every feature reading identically (#42
	// round-6 gate). Still symmetric enough around 1.0 within each cluster
	// that it doesn't reintroduce a mean-brightness regression on its own.
	float grain_mul = mix(grain_lo, grain_hi, grain);

	// Crevice tone: proportionally darker than each cluster's own dark tone
	// (not one fixed color_b-derived constant) so each value step gets its
	// own hue-matched crevice. Raised 0.50 -> 0.58 -> 0.64 across two
	// in-session measurement passes (#42 round-7 gate): after collapsing to
	// one hue per stage, a live capture first measured mean V 0.41-0.52
	// against the 0.580 reference target, short mainly because crevice
	// pixels (the majority of area, see thresh_mid below) were still tuned
	// dark for the old 4-different-hue field, where hue contrast alone
	// separated materials and crevices could run darker without flattening
	// everything toward one tone. 0.58 (paired with the thresh_mid and
	// per-cluster bias changes below) brought it to 0.51-0.60 across
	// non-VFX-obstructed frames; 0.64 is the second pass closing the rest
	// of that gap. With one hue now, crevice depth needs its own smaller
	// step to keep mean V in band without giving up the light/dark contrast
	// that reads as rock relief.
	vec3 crevice = cluster_dark * 0.64;

	// Per-cell tint biased toward mid-tones (avoid pure-light/pure-dark
	// extremes so the field reads as one terrain, not scattered confetti).
	// cell_dist is smallest AT each cell's feature point (its center) and
	// largest at the boundary between cells — so the crevice belongs at
	// high cell_dist, the lit rock face at low cell_dist. (First pass had
	// this inverted, painting a dark dot at every cell center instead of a
	// seam at its edge — read as polka-dots/cobblestone rather than rock.)
	vec3 base_color = mix(cluster_dark, cluster_light, cell_id * 0.6 + 0.2);
	// cell_id is a per-cell CONSTANT that jumps discontinuously the instant
	// the nearest Worley feature point changes — at the spatial frequency
	// near the horizon (see aa above), that happens within a single pixel,
	// and no smoothstep width fixes a discontinuous field. Falling back to
	// the smooth regional tone once cells aren't resolvable is the only way
	// to stop that showing up as per-pixel color flicker.
	base_color = mix(base_color, mix(cluster_dark, cluster_light, region), aa);
	vec3 crevice_color = crevice;
	// cell_dist itself (not just cell_id) is only continuous in VALUE, not in
	// gradient, at Worley cell boundaries — its derivative jumps where the
	// nearest feature point changes. Widening the smoothstep band alone
	// (still done below) softens that edge but does not stop cell_dist from
	// varying wildly pixel-to-pixel once cells are smaller than a pixel; the
	// boundary network itself then aliases into exactly the coherent radial
	// streaks this shader shipped with first. Pulling cell_dist toward a
	// fixed constant as aa grows removes the input that's aliasing, not just
	// the transition drawn from it — at aa=1 the crevice mix becomes a flat,
	// pixel-independent blend, which cannot moire no matter how undersampled
	// the underlying cell grid is.
	float cell_dist_stable = mix(cell_dist, 0.5, aa);
	// Threshold history: 0.33 (pre round-4) painted most of the field as
	// crevice, measuring V=0.51 against the then-target 0.67-0.69. Raising it
	// to 0.65 (round-4) overshot the other way — round-5 gate measured mean V
	// 0.645-0.659 against the CORRECT reference target of 0.564-0.569 (the
	// 0.67-0.69 literal it was tuned against was itself never measured
	// in-session). 0.52 (first round-5 pass) only moved mean V to 0.630-0.656;
	// 0.40, paired with the crevice-color cut above, is the third pass —
	// still stopping short of 0.33's original mostly-dark extreme.
	//
	// Band width coefficient cut 0.28 -> 0.08 (#42 round-5 gate): this is the
	// other half of the "edges too soft" defect (mean |grad| 0.027 vs
	// reference 0.078-0.090) — even where aa itself is now small (see the aa
	// coefficient cut above), this term was still widening the transition
	// band up to 0.62 total at aa=1, well beyond what's needed to hide
	// undersampling moiré near the horizon. Band is 0.06 wide at aa=0 (hard
	// edge, unchanged) growing to 0.22 at aa=1 (still soft far-field, just not
	// as extreme). Re-measured in-session: mean|grad| 0.027 -> 0.070-0.074,
	// frac(|grad|>0.05) 0.15 -> 0.48-0.50 — real progress, still short of the
	// 0.078-0.090 / 0.64-0.73 reference band; the grain widening above is the
	// second half of closing that remaining gap.
	// Threshold cut again 0.52 -> 0.40 (paired with the crevice-color cut
	// above): re-measured mean V at 0.621-0.646 after the first two brightness
	// passes, still ~0.06-0.08 above the 0.564 reference target — moving
	// threshold + crevice depth together, not either alone, is what closes
	// the rest of that gap.
	//
	// thresh_bias shifts this whole band per value cluster — set above, now
	// all >=0 (#42 round-7 gate: every cluster got MORE crevice-free area,
	// not less, as part of the same brightness fix as the crevice-color
	// raise above) so the highlight step stays mostly lit and even the
	// darkest (shadow) step no longer piles extra dark area on top of its
	// already-darker tone the way the old grey/scrub bias split did. Base
	// 0.40 -> 0.43: a small further uniform lift, measured alongside the
	// crevice-color change above rather than either alone (#42 round-5 gate
	// established this is a two-knob problem, not one). A small per-cell
	// jitter derived from the same cell_seed used for the warp above adds
	// one more layer of "not every feature is identical".
	float thresh_jitter = (hash1(floor(cell_p) * 3.0 + 71.0) - 0.5) * 0.10;
	float thresh_mid = 0.43 + thresh_bias + thresh_jitter;
	vec3 terrain = mix(base_color, crevice_color, smoothstep(thresh_mid - 0.08 * aa, thresh_mid + 0.06 + 0.08 * aa, cell_dist_stable));
	// Regional tonal wash cut from 0.25 to 0.15 (#42 round-4 gate): a strong
	// low-frequency wash wins uniformly over the sharpened crevice edge
	// above and reads as softening it back out — this blend is meant to hide
	// aliasing in undersampled far terrain (aa handles that via the mix
	// weight implicitly through cell_dist_stable/base_color already), not to
	// flatten near-camera contrast where edges must stay crisp. Uses the
	// active cluster's own dark/light (#42 round-6) instead of the removed
	// global dark/light, so the wash never pulls a scrub or stone patch back
	// toward the base-rock hue.
	terrain = mix(terrain, mix(cluster_dark, cluster_light, region), 0.15);
	terrain *= grain_mul;

	// Haze: ground fades into the sky's horizon tone as UV.y -> 0 (the
	// horizon), replacing the old hard white stroke with a density falloff —
	// no visible seam where sky meets ground, matching every reference.
	//
	// Width cut 0.16 -> 0.06 (#115). 0.16 of a 252px ground is ~40px of
	// sky-coloured ground, and on the desert stages (where sky, haze and ground
	// are all in the same warm hue family) that dissolved the horizon
	// completely — sky and ground read as one continuous orange mass, which is
	// the core of "the sky doesn't look like sky". Measured the reference's own
	// blend depth instead of guessing: burst-a-02 goes gold -> unambiguous
	// ground over y=268..288 of a 212px ground (0.094), and burst-c-02 does it
	// in 6px of a 267px ground (0.022); snow (burst-b-08) has no blend at all.
	// 0.06 sits inside that measured range and still antialiases the seam.
	float haze = smoothstep(0.0, 0.06, UV.y);
	terrain = mix(haze_color.rgb, terrain, haze);

	COLOR = vec4(terrain, 1.0);
}
