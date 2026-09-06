shader_type spatial;
render_mode unshaded, cull_disabled;

// Uniforms kept for stage_manager.gd and ground_scroll.gd compatibility.
// color_a tints the overall ocean hue. color_b is unused but kept for API compat.
uniform vec4 color_a : source_color = vec4(0.10, 0.25, 0.70, 1.0);
uniform vec4 color_b : source_color = vec4(0.05, 0.15, 0.50, 1.0);
uniform float scroll_speed : hint_range(0.0, 10.0) = 8.0;
uniform float tile_scale : hint_range(1.0, 64.0) = 20.0;
uniform float scroll_offset = 0.0;

// Ocean palette
const vec3 OCEAN_DEEP  = vec3(0.05, 0.15, 0.50);
const vec3 OCEAN_MID   = vec3(0.10, 0.25, 0.70);
const vec3 OCEAN_LIGHT = vec3(0.20, 0.45, 0.85);
const vec3 OCEAN_FOAM  = vec3(0.70, 0.80, 0.95);
const vec3 OCEAN_WHITE = vec3(0.90, 0.95, 1.00);

// Sky color for horizon fade
const vec3 SKY_HAZE = vec3(0.75, 0.85, 0.98);

// Simple hash noise
float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Perspective-compressed horizontal bands.
	// pow(uv.y, 0.4) compresses bands near horizon (low uv.y), widens near camera.
	// UV.y = 0 is the near edge (bottom of ground plane), UV.y = 1 is far edge (horizon).
	// We invert so horizon is at high values for the pow compression.
	float perspective_y = pow(1.0 - uv.y, 0.4);
	float band_value = fract(perspective_y * 20.0 + scroll_offset * 0.08);

	// Band color cycling: 5 zones per cycle
	vec3 band_color;
	if (band_value < 0.15) {
		band_color = OCEAN_DEEP;
	} else if (band_value < 0.30) {
		band_color = OCEAN_MID;
	} else if (band_value < 0.50) {
		band_color = OCEAN_LIGHT;
	} else if (band_value < 0.70) {
		band_color = OCEAN_MID;
	} else if (band_value < 0.85) {
		band_color = OCEAN_DEEP;
	} else {
		// Foam band — only where noise says so
		float foam_noise = hash(floor(uv.x * 40.0) + floor(perspective_y * 80.0) * 137.0);
		if (foam_noise < 0.3) {
			band_color = OCEAN_FOAM;
		} else {
			band_color = OCEAN_DEEP;
		}
	}

	// Wave highlight foam at band boundaries
	float foam_mask = step(0.85, fract(sin(uv.x * 127.1 + TIME * 2.3) * 43758.5));
	// Only show foam near band edges (where band_value is close to a transition)
	float edge_dist = min(band_value, 1.0 - band_value);
	float edge_mask = 1.0 - smoothstep(0.0, 0.05, edge_dist);
	band_color = mix(band_color, OCEAN_WHITE, foam_mask * edge_mask * 0.6);

	// Subtle wave shimmer
	float shimmer = hash(floor(uv.x * 60.0 + TIME * 3.0) + floor(perspective_y * 40.0) * 73.0);
	band_color += vec3(0.03) * step(0.92, shimmer);

	// Tint by stage color (color_a). Blend toward stage color to allow stage variety.
	vec3 stage_tint = color_a.rgb;
	band_color = mix(band_color, band_color * (stage_tint / max(OCEAN_MID, vec3(0.01))), 0.3);

	// Horizon fade: top 20% of ground (UV.y close to 1.0 = far/horizon) fades to sky haze
	float horizon_fade = smoothstep(0.80, 1.0, uv.y);
	band_color = mix(band_color, SKY_HAZE, horizon_fade);

	ALBEDO = band_color;
}
