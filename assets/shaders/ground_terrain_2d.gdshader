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

	vec2 cell_p = vec2(world_x * CELL_FREQ_X, world_d * CELL_FREQ_D);

	// Domain warp: perturb the sample point with a lower-frequency noise
	// field before evaluating Worley. An un-warped Worley grid reads as a
	// too-regular round-pebble mosaic (cobblestone paving); the reference
	// ground is jagged, irregular scree, not uniform cobbles. Warping breaks
	// the grid alignment so cell boundaries come out irregular/spiky instead
	// of smoothly round.
	vec2 warp = vec2(value_noise(cell_p * 0.5 + 11.0), value_noise(cell_p * 0.5 + 47.0)) - 0.5;
	cell_p += warp * 1.1;

	float cell_id;
	float cell_dist = worley(cell_p, cell_id);
	float region = value_noise(vec2(world_x * REGION_FREQ, world_d * REGION_FREQ));
	// High-frequency grain multiplied over the final color so flat cell faces
	// don't read as smooth/cartoonish — the reference's texture is visibly
	// noisy even within a single rock, not a flat fill.
	float grain = value_noise(cell_p * 3.3);

	vec3 dark = color_b.rgb;
	vec3 light = color_a.rgb;
	vec3 crevice = color_b.rgb * 0.5;

	// Per-cell tint biased toward mid-tones (avoid pure-light/pure-dark
	// extremes so the field reads as one terrain, not scattered confetti).
	// cell_dist is smallest AT each cell's feature point (its center) and
	// largest at the boundary between cells — so the crevice belongs at
	// high cell_dist, the lit rock face at low cell_dist. (First pass had
	// this inverted, painting a dark dot at every cell center instead of a
	// seam at its edge — read as polka-dots/cobblestone rather than rock.)
	vec3 rock_color = mix(dark, light, cell_id * 0.6 + 0.2);
	vec3 terrain = mix(rock_color, crevice, smoothstep(0.34, 0.58, cell_dist));
	terrain = mix(terrain, mix(dark, light, region), 0.25);
	terrain *= mix(0.82, 1.1, grain);

	// Haze: ground fades into the sky's horizon tone as UV.y -> 0 (the
	// horizon), replacing the old hard white stroke with a density falloff —
	// no visible seam where sky meets ground, matching every reference.
	float haze = smoothstep(0.0, 0.16, UV.y);
	terrain = mix(haze_color.rgb, terrain, haze);

	COLOR = vec4(terrain, 1.0);
}
