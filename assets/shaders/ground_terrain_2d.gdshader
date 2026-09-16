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
// Vegetation/accent color (#42 colour-variety follow-up) — a scatter of
// distinct-hue clumps (olive scrub on desert, soil on forest, foam on
// ocean...) over the rock base. Reference desert frames measure clump
// pixels at hue~60 (olive-yellow) against rock's hue~30-40 (orange-tan) —
// a real second hue, not a value/saturation variant of the rock colors, so
// it needs its own uniform rather than being derived from color_a/color_b.
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

// Cell frequency chosen so a rock cell spans ~30px on screen near the
// camera (bottom of frame) — measured against burst-a-02/burst-a-03, where
// near-camera rocks are ~4-5% of frame height, vs the old model's ~10-13%.
const float CELL_FREQ_X = 14.0;
const float CELL_FREQ_D = 15.0;
// Low-frequency broad tonal patches (the mottled light/dark regions visible
// across the reference beyond individual rock cells).
const float REGION_FREQ = 1.6;

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
	float aa = clamp(length(fwidth(cell_p)) * 0.14, 0.0, 1.0);

	// Domain warp: perturb the sample point before evaluating Worley. A
	// single low-frequency warp still reads as a too-regular round-pebble
	// mosaic (cobblestone paving) — the reference ground is jagged, chaotic
	// scree, not uniform cobbles. A second, higher-frequency warp layered on
	// top breaks the smooth round boundary itself into spiky, irregular
	// edges instead of just displacing a still-round cell. Its amplitude
	// fades under aa since it's the higher-frequency (more alias-prone) of
	// the two warp layers.
	vec2 warp1 = vec2(value_noise(cell_p * 0.5 + 11.0), value_noise(cell_p * 0.5 + 47.0)) - 0.5;
	vec2 warp2 = vec2(value_noise(cell_p * 1.8 + 91.0), value_noise(cell_p * 1.8 + 23.0)) - 0.5;
	cell_p += warp1 * 1.4 + warp2 * 0.7 * (1.0 - aa);

	float cell_id;
	float cell_dist = worley(cell_p, cell_id);
	float region = value_noise(vec2(world_x * REGION_FREQ, world_d * REGION_FREQ));
	// High-frequency grain multiplied over the final color so flat cell faces
	// don't read as smooth/cartoonish — the reference's texture is visibly
	// noisy even within a single rock, not a flat fill. Fades toward a
	// neutral 1.0 multiplier under aa for the same reason as warp2.
	float grain = mix(value_noise(cell_p * 3.3), 0.5, aa);

	vec3 dark = color_b.rgb;
	vec3 light = color_a.rgb;
	vec3 crevice = color_b.rgb * 0.5;

	// Vegetation clumps (#42 colour-variety follow-up): a second, decorrelated
	// noise field selects patches of color_c instead of rock tones — reference
	// desert frames show several SMALL distinct olive clumps scattered over
	// the tan/brown rock, not one wash covering the field. First pass used
	// frequency 0.8 directly in world units, where near-camera screen width
	// spans only ~2 world units — a single noise cell was over half the
	// visible ground, reading as one giant green blob instead of clumps.
	// 6.0 gives a ~0.17-world-unit period, several clump-sized patches across
	// the near-camera screen width. Faded out under aa (like the rock detail
	// above) since it's higher-frequency than the old 0.8 and would otherwise
	// shimmer once undersampled near the horizon.
	float veg_n = value_noise(world_p * 6.0 + vec2(50.0, 90.0));
	float veg = smoothstep(0.62, 0.72, veg_n) * (1.0 - aa);

	// Per-cell tint biased toward mid-tones (avoid pure-light/pure-dark
	// extremes so the field reads as one terrain, not scattered confetti).
	// cell_dist is smallest AT each cell's feature point (its center) and
	// largest at the boundary between cells — so the crevice belongs at
	// high cell_dist, the lit rock face at low cell_dist. (First pass had
	// this inverted, painting a dark dot at every cell center instead of a
	// seam at its edge — read as polka-dots/cobblestone rather than rock.)
	vec3 rock_color = mix(dark, light, cell_id * 0.6 + 0.2);
	vec3 veg_color = mix(color_c.rgb * 0.6, color_c.rgb * 1.15, cell_id);
	vec3 veg_crevice = color_c.rgb * 0.35;
	vec3 base_color = mix(rock_color, veg_color, veg);
	// cell_id is a per-cell CONSTANT that jumps discontinuously the instant
	// the nearest Worley feature point changes — at the spatial frequency
	// near the horizon (see aa above), that happens within a single pixel,
	// and no smoothstep width fixes a discontinuous field. Falling back to
	// the smooth regional tone once cells aren't resolvable is the only way
	// to stop that showing up as per-pixel color flicker.
	base_color = mix(base_color, mix(dark, light, region), aa);
	vec3 crevice_color = mix(crevice, veg_crevice, veg);
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
	// Sharper crevice band (was 0.34-0.58) — a narrower transition reads as a
	// thin, jagged crack between rock faces instead of a broad soft-shaded
	// round bevel, which is the other half of the "leopard print" defect: the
	// warp fixed the outline, this fixes the shading gradient inside it. The
	// band widens under aa so undersampled far terrain blurs smoothly instead
	// of aliasing — sharp only where the pixel grid can actually resolve it.
	vec3 terrain = mix(base_color, crevice_color, smoothstep(0.30 - 0.28 * aa, 0.40 + 0.28 * aa, cell_dist_stable));
	// Regional tonal wash stays rock-only (scaled by 1.0-veg) so it doesn't
	// desaturate the vegetation clumps' distinct hue back toward rock tan.
	terrain = mix(terrain, mix(dark, light, region), 0.25 * (1.0 - veg));
	terrain *= mix(0.82, 1.1, grain);

	// Haze: ground fades into the sky's horizon tone as UV.y -> 0 (the
	// horizon), replacing the old hard white stroke with a density falloff —
	// no visible seam where sky meets ground, matching every reference.
	float haze = smoothstep(0.0, 0.16, UV.y);
	terrain = mix(haze_color.rgb, terrain, haze);

	COLOR = vec4(terrain, 1.0);
}
